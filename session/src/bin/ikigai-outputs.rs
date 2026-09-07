//! Keeps the display layout across the monitors' sleep.
//!
//! On NVIDIA a DisplayPort monitor drops off the bus when it powers down, so waking the
//! screens looks like a hotplug to cosmic-comp: every output goes away and comes back.
//! cosmic-comp (1.7.0) then re-applies its saved layout, but the first render after the
//! modeset fails on the driver ("Failed to switch primary-plane scanout flags"), the
//! reset fails too, and it falls back to each output's preferred mode (60 Hz) laid out in
//! connector order, which it saves as the new layout. The user comes back to the wrong
//! order at the wrong refresh rate every time.
//!
//! This client watches wlr-output-management. It remembers the layout of every set of
//! heads that has sat still, and when heads have come or gone and the set that settles
//! is one it knows with a different layout, it applies the remembered one in a single
//! configuration. A layout the user changes on purpose (cosmic-settings, cosmic-randr)
//! comes with no head arriving or leaving, so it is remembered rather than undone.

use std::collections::{BTreeMap, HashMap};
use std::time::Duration;

use cosmic_client_toolkit::cosmic_protocols::output_management::v1::client::zcosmic_output_configuration_head_v1::ZcosmicOutputConfigurationHeadV1;
use cosmic_client_toolkit::cosmic_protocols::output_management::v1::client::zcosmic_output_configuration_v1::ZcosmicOutputConfigurationV1;
use cosmic_client_toolkit::cosmic_protocols::output_management::v1::client::zcosmic_output_head_v1::{
    self, AdaptiveSyncAvailability, AdaptiveSyncStateExt, ZcosmicOutputHeadV1,
};
use cosmic_client_toolkit::cosmic_protocols::output_management::v1::client::zcosmic_output_manager_v1::ZcosmicOutputManagerV1;
use cosmic_client_toolkit::sctk::reexports::calloop::timer::{TimeoutAction, Timer};
use cosmic_client_toolkit::sctk::reexports::calloop::{EventLoop, LoopHandle, RegistrationToken};
use cosmic_client_toolkit::sctk::reexports::calloop_wayland_source::WaylandSource;
use wayland_client::backend::ObjectId;
use wayland_client::globals::{GlobalListContents, registry_queue_init};
use wayland_client::protocol::{wl_output, wl_registry};
use wayland_client::{Connection, Dispatch, Proxy, QueueHandle, event_created_child};
use wayland_protocols_wlr::output_management::v1::client::zwlr_output_configuration_head_v1::ZwlrOutputConfigurationHeadV1;
use wayland_protocols_wlr::output_management::v1::client::zwlr_output_configuration_v1::{self, ZwlrOutputConfigurationV1};
use wayland_protocols_wlr::output_management::v1::client::zwlr_output_head_v1::{self, AdaptiveSyncState, ZwlrOutputHeadV1};
use wayland_protocols_wlr::output_management::v1::client::zwlr_output_manager_v1::{self, ZwlrOutputManagerV1};
use wayland_protocols_wlr::output_management::v1::client::zwlr_output_mode_v1::{self, ZwlrOutputModeV1};

/// How long the heads must sit still after the compositor's last `done` before the
/// layout counts. Waking the screens is a burst of removals, additions and re-configs
/// over two to three seconds on the box this was written for.
const SETTLE: Duration = Duration::from_secs(2);
/// Restores attempted for one settled set before its layout is taken as it is.
const MAX_ATTEMPTS: u32 = 3;

/// One head's configuration, everything a `zwlr_output_configuration_v1` can set plus
/// COSMIC's extras. Refresh in mHz like the protocol.
#[derive(Clone, Debug, PartialEq)]
struct HeadConfig {
    enabled: bool,
    mode: (i32, i32, i32),
    position: (i32, i32),
    transform: wl_output::Transform,
    scale: f64,
    adaptive_sync: Option<AdaptiveSyncStateExt>,
    mirroring: Option<String>,
    xwayland_primary: bool,
}

/// A layout by head name; the key set is the set of heads it is for.
type Layout = BTreeMap<String, HeadConfig>;

#[derive(Clone, Debug, PartialEq)]
enum Action {
    Restore(Layout),
    Record,
}

/// The rule: a known set that comes back different after heads moved is restored, a
/// bounded number of times; everything else is what the user wants and is remembered.
fn decide(known: &HashMap<Vec<String>, Layout>, names: &[String], layout: &Layout, changed: bool, attempts: u32) -> Action {
    if !changed || attempts >= MAX_ATTEMPTS {
        return Action::Record;
    }
    match known.get(names) {
        Some(wanted) if wanted != layout => Action::Restore(wanted.clone()),
        _ => Action::Record,
    }
}

#[derive(Debug)]
struct Mode {
    wlr: ZwlrOutputModeV1,
    width: i32,
    height: i32,
    refresh: i32,
}

struct Head {
    wlr: ZwlrOutputHeadV1,
    cosmic: Option<ZcosmicOutputHeadV1>,
    name: String,
    enabled: bool,
    modes: Vec<Mode>,
    current_mode: Option<ObjectId>,
    position: (i32, i32),
    transform: wl_output::Transform,
    scale: f64,
    adaptive_sync: Option<AdaptiveSyncStateExt>,
    adaptive_sync_support: Option<AdaptiveSyncAvailability>,
    mirroring: Option<String>,
    xwayland_primary: bool,
}

impl Head {
    fn config(&self) -> HeadConfig {
        let mode = self
            .current_mode
            .as_ref()
            .and_then(|id| self.modes.iter().find(|m| m.wlr.id() == *id))
            .map(|m| (m.width, m.height, m.refresh))
            .unwrap_or_default();
        HeadConfig {
            enabled: self.enabled,
            mode,
            position: self.position,
            transform: self.transform,
            scale: self.scale,
            adaptive_sync: self.adaptive_sync,
            mirroring: self.mirroring.clone(),
            xwayland_primary: self.xwayland_primary,
        }
    }

    /// The mode for a remembered config: the exact one, else the same size nearest in
    /// refresh (the compositor's list can differ by a millihertz between plugs).
    fn find_mode(&self, (w, h, refresh): (i32, i32, i32)) -> Option<&Mode> {
        let same_size = || self.modes.iter().filter(|m| m.width == w && m.height == h);
        same_size()
            .find(|m| m.refresh == refresh)
            .or_else(|| same_size().min_by_key(|m| (m.refresh - refresh).abs()))
    }
}

struct Outputs {
    qh: QueueHandle<Outputs>,
    handle: LoopHandle<'static, Outputs>,
    manager: ZwlrOutputManagerV1,
    cosmic: Option<ZcosmicOutputManagerV1>,
    serial: u32,
    heads: HashMap<ObjectId, Head>,
    /// Mode object → the head it belongs to; the mode's own events name no head.
    mode_owner: HashMap<ObjectId, ObjectId>,
    known: HashMap<Vec<String>, Layout>,
    /// A head arrived or left since the last settled layout.
    changed: bool,
    attempts: u32,
    settle: Option<RegistrationToken>,
    pending: Option<(ZwlrOutputConfigurationV1, Layout)>,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let conn = Connection::connect_to_env()?;
    let (globals, queue) = registry_queue_init::<Outputs>(&conn)?;
    let qh = queue.handle();
    let manager: ZwlrOutputManagerV1 = globals.bind(&qh, 2..=4, ()).map_err(|e| format!("zwlr_output_manager_v1: {e}"))?;
    let cosmic: Option<ZcosmicOutputManagerV1> = globals.bind(&qh, 1..=3, ()).ok();
    if cosmic.is_none() {
        eprintln!("ikigai-outputs: no zcosmic_output_manager_v1; scale, mirroring and the Xwayland primary are left alone");
    }

    let mut event_loop: EventLoop<Outputs> = EventLoop::try_new()?;
    let handle = event_loop.handle();
    WaylandSource::new(conn, queue).insert(handle.clone()).map_err(|e| e.error)?;
    let mut outputs = Outputs {
        qh,
        handle,
        manager,
        cosmic,
        serial: 0,
        heads: HashMap::new(),
        mode_owner: HashMap::new(),
        known: HashMap::new(),
        changed: false,
        attempts: 0,
        settle: None,
        pending: None,
    };
    event_loop.run(None, &mut outputs, |_| {})?;
    Ok(())
}

impl Outputs {
    fn schedule_settle(&mut self) {
        if let Some(token) = self.settle.take() {
            self.handle.remove(token);
        }
        let timer = Timer::from_duration(SETTLE);
        self.settle = self
            .handle
            .insert_source(timer, |_, _, outputs: &mut Outputs| {
                outputs.settle = None;
                outputs.settled();
                TimeoutAction::Drop
            })
            .ok();
    }

    fn names(&self) -> Vec<String> {
        let mut names: Vec<String> = self.heads.values().map(|h| h.name.clone()).collect();
        names.sort();
        names
    }

    fn layout(&self) -> Layout {
        self.heads.values().map(|h| (h.name.clone(), h.config())).collect()
    }

    fn settled(&mut self) {
        if self.pending.is_some() || self.heads.is_empty() {
            return;
        }
        let names = self.names();
        let layout = self.layout();
        let changed = std::mem::replace(&mut self.changed, false);
        match decide(&self.known, &names, &layout, changed, self.attempts) {
            Action::Restore(wanted) => {
                self.attempts += 1;
                eprintln!("ikigai-outputs: {} came back as {}; restoring {} (attempt {})", names.join("+"), describe(&layout), describe(&wanted), self.attempts);
                if let Err(err) = self.apply(&wanted) {
                    eprintln!("ikigai-outputs: cannot restore: {err}");
                    self.attempts = 0;
                    self.known.insert(names, layout);
                }
            }
            Action::Record => {
                if changed && self.attempts > 0 {
                    eprintln!("ikigai-outputs: giving up on {}", names.join("+"));
                }
                self.attempts = 0;
                if self.known.get(&names) != Some(&layout) {
                    eprintln!("ikigai-outputs: {} is {}", names.join("+"), describe(&layout));
                    self.known.insert(names, layout);
                }
            }
        }
    }

    /// One `zwlr_output_configuration_v1` for every head, so the compositor moves them
    /// together (one at a time, cosmic-randr's way, shuffles the others out of overlap).
    fn apply(&mut self, wanted: &Layout) -> Result<(), String> {
        let qh = &self.qh;
        let config = self.manager.create_configuration(self.serial, qh, ());
        let cosmic_config = self.cosmic.as_ref().map(|c| c.get_configuration(&config, qh, ()));
        let head_by_name = |name: &str| self.heads.values().find(|h| h.name == name).ok_or_else(|| format!("no head {name}"));
        let result = (|| {
            for (name, want) in wanted {
                let head = head_by_name(name)?;
                if !want.enabled {
                    config.disable_head(&head.wlr);
                    continue;
                }
                let ch: ZwlrOutputConfigurationHeadV1 = match &want.mirroring {
                    Some(from) => {
                        let from = head_by_name(from)?;
                        let cosmic_config = cosmic_config.as_ref().ok_or("mirroring needs the COSMIC extension")?;
                        cosmic_config.mirror_head(&head.wlr, &from.wlr, qh, ())
                    }
                    None => config.enable_head(&head.wlr, qh, ()),
                };
                let cch: Option<ZcosmicOutputConfigurationHeadV1> = self.cosmic.as_ref().map(|c| c.get_configuration_head(&ch, qh, ()));
                let mode = head.find_mode(want.mode).ok_or_else(|| format!("{name} has no {}x{} mode", want.mode.0, want.mode.1))?;
                ch.set_mode(&mode.wlr);
                if want.mirroring.is_none() {
                    ch.set_position(want.position.0, want.position.1);
                }
                ch.set_transform(want.transform);
                match &cch {
                    Some(cch) => cch.set_scale_1000((want.scale * 1000.0).round() as i32),
                    None => ch.set_scale(want.scale),
                }
                if let Some(vrr) = want.adaptive_sync
                    && head.adaptive_sync != Some(vrr)
                    && head.adaptive_sync_support.is_some_and(|s| s != AdaptiveSyncAvailability::Unsupported)
                {
                    match cch.as_ref().filter(|c| c.version() >= 2) {
                        Some(cch) => cch.set_adaptive_sync_ext(vrr),
                        None => ch.set_adaptive_sync(if vrr == AdaptiveSyncStateExt::Disabled { AdaptiveSyncState::Disabled } else { AdaptiveSyncState::Enabled }),
                    }
                }
            }
            Ok::<(), String>(())
        })();
        if let Err(err) = result {
            config.destroy();
            return Err(err);
        }
        config.apply();
        self.pending = Some((config, wanted.clone()));
        Ok(())
    }

    /// The Xwayland primary is a request on the manager, outside any configuration;
    /// sent once the configuration went through so the two writes land in order.
    fn restore_primary(&self, wanted: &Layout) {
        let Some(cosmic) = self.cosmic.as_ref().filter(|c| c.version() >= 3) else { return };
        let Some(name) = wanted.iter().find(|(_, c)| c.xwayland_primary).map(|(n, _)| n) else { return };
        let Some(head) = self.heads.values().find(|h| h.name == *name) else { return };
        if !head.xwayland_primary {
            cosmic.set_xwayland_primary(head.cosmic.as_ref());
        }
    }

    fn head_mut(&mut self, id: &ObjectId) -> Option<&mut Head> {
        self.heads.get_mut(id)
    }

    fn mode_mut(&mut self, id: &ObjectId) -> Option<&mut Mode> {
        let owner = self.mode_owner.get(id)?.clone();
        self.heads.get_mut(&owner)?.modes.iter_mut().find(|m| m.wlr.id() == *id)
    }
}

fn describe(layout: &Layout) -> String {
    layout
        .iter()
        .map(|(name, c)| {
            if !c.enabled {
                return format!("{name} off");
            }
            let (w, h, r) = c.mode;
            let mut s = format!("{name} {w}x{h}@{:.3} at {},{}", r as f64 / 1000.0, c.position.0, c.position.1);
            if let Some(from) = &c.mirroring {
                s.push_str(&format!(" mirroring {from}"));
            }
            if c.xwayland_primary {
                s.push_str(" primary");
            }
            s
        })
        .collect::<Vec<_>>()
        .join(", ")
}

impl Dispatch<wl_registry::WlRegistry, GlobalListContents> for Outputs {
    fn event(_: &mut Self, _: &wl_registry::WlRegistry, _: wl_registry::Event, _: &GlobalListContents, _: &Connection, _: &QueueHandle<Self>) {}
}

impl Dispatch<ZwlrOutputManagerV1, ()> for Outputs {
    fn event(outputs: &mut Self, _: &ZwlrOutputManagerV1, event: zwlr_output_manager_v1::Event, _: &(), _: &Connection, qh: &QueueHandle<Self>) {
        match event {
            zwlr_output_manager_v1::Event::Head { head } => {
                let cosmic = outputs.cosmic.as_ref().map(|c| c.get_head(&head, qh, head.id()));
                outputs.heads.insert(
                    head.id(),
                    Head {
                        wlr: head,
                        cosmic,
                        name: String::new(),
                        enabled: false,
                        modes: Vec::new(),
                        current_mode: None,
                        position: (0, 0),
                        transform: wl_output::Transform::Normal,
                        scale: 1.0,
                        adaptive_sync: None,
                        adaptive_sync_support: None,
                        mirroring: None,
                        xwayland_primary: false,
                    },
                );
                outputs.changed = true;
            }
            zwlr_output_manager_v1::Event::Done { serial } => {
                outputs.serial = serial;
                outputs.schedule_settle();
            }
            zwlr_output_manager_v1::Event::Finished => {
                eprintln!("ikigai-outputs: the compositor finished the output manager");
                std::process::exit(0);
            }
            _ => {}
        }
    }

    event_created_child!(Outputs, ZwlrOutputManagerV1, [
        zwlr_output_manager_v1::EVT_HEAD_OPCODE => (ZwlrOutputHeadV1, ()),
    ]);
}

impl Dispatch<ZwlrOutputHeadV1, ()> for Outputs {
    fn event(outputs: &mut Self, head: &ZwlrOutputHeadV1, event: zwlr_output_head_v1::Event, _: &(), _: &Connection, _: &QueueHandle<Self>) {
        use zwlr_output_head_v1::Event;
        if let Event::Finished = event {
            if head.version() >= 3 {
                head.release();
            }
            if let Some(gone) = outputs.heads.remove(&head.id()) {
                for mode in &gone.modes {
                    outputs.mode_owner.remove(&mode.wlr.id());
                }
                if let Some(cosmic) = gone.cosmic {
                    cosmic.release();
                }
            }
            outputs.changed = true;
            return;
        }
        if let Event::Mode { mode } = &event {
            outputs.mode_owner.insert(mode.id(), head.id());
        }
        let Some(h) = outputs.head_mut(&head.id()) else { return };
        match event {
            Event::Name { name } => h.name = name,
            Event::Mode { mode } => h.modes.push(Mode { wlr: mode, width: 0, height: 0, refresh: 0 }),
            Event::Enabled { enabled } => h.enabled = enabled != 0,
            Event::CurrentMode { mode } => h.current_mode = Some(mode.id()),
            Event::Position { x, y } => h.position = (x, y),
            Event::Transform { transform } => {
                if let Ok(t) = transform.into_result() {
                    h.transform = t;
                }
            }
            Event::Scale { scale } => h.scale = scale,
            Event::AdaptiveSync { state } => {
                // The COSMIC head reports the same with its Automatic state; keep that
                // when it speaks, since it comes after this.
                h.adaptive_sync = match state.into_result() {
                    Ok(AdaptiveSyncState::Enabled) => Some(AdaptiveSyncStateExt::Always),
                    Ok(AdaptiveSyncState::Disabled) => Some(AdaptiveSyncStateExt::Disabled),
                    _ => h.adaptive_sync,
                };
            }
            _ => {}
        }
    }

    event_created_child!(Outputs, ZwlrOutputHeadV1, [
        zwlr_output_head_v1::EVT_MODE_OPCODE => (ZwlrOutputModeV1, ()),
    ]);
}

impl Dispatch<ZwlrOutputModeV1, ()> for Outputs {
    fn event(outputs: &mut Self, mode: &ZwlrOutputModeV1, event: zwlr_output_mode_v1::Event, _: &(), _: &Connection, _: &QueueHandle<Self>) {
        use zwlr_output_mode_v1::Event;
        if let Event::Finished = event {
            if mode.version() >= 3 {
                mode.release();
            }
            if let Some(owner) = outputs.mode_owner.remove(&mode.id())
                && let Some(head) = outputs.heads.get_mut(&owner)
            {
                head.modes.retain(|m| m.wlr.id() != mode.id());
            }
            return;
        }
        let Some(m) = outputs.mode_mut(&mode.id()) else { return };
        match event {
            Event::Size { width, height } => (m.width, m.height) = (width, height),
            Event::Refresh { refresh } => m.refresh = refresh,
            _ => {}
        }
    }
}

impl Dispatch<ZcosmicOutputHeadV1, ObjectId> for Outputs {
    fn event(outputs: &mut Self, _: &ZcosmicOutputHeadV1, event: zcosmic_output_head_v1::Event, head: &ObjectId, _: &Connection, _: &QueueHandle<Self>) {
        use zcosmic_output_head_v1::Event;
        let Some(h) = outputs.head_mut(head) else { return };
        match event {
            Event::Scale1000 { scale_1000 } => h.scale = f64::from(scale_1000) / 1000.0,
            Event::Mirroring { name } => h.mirroring = name,
            Event::AdaptiveSyncAvailable { available } => h.adaptive_sync_support = available.into_result().ok(),
            Event::AdaptiveSyncExt { state } => h.adaptive_sync = state.into_result().ok(),
            Event::XwaylandPrimary { state } => h.xwayland_primary = state != 0,
            _ => {}
        }
    }
}

impl Dispatch<ZwlrOutputConfigurationV1, ()> for Outputs {
    fn event(outputs: &mut Self, config: &ZwlrOutputConfigurationV1, event: zwlr_output_configuration_v1::Event, _: &(), _: &Connection, _: &QueueHandle<Self>) {
        use zwlr_output_configuration_v1::Event;
        let Some((_, wanted)) = outputs.pending.take_if(|(c, _)| c == config) else { return };
        config.destroy();
        match event {
            Event::Succeeded => {
                eprintln!("ikigai-outputs: restored");
                outputs.restore_primary(&wanted);
            }
            Event::Failed => {
                eprintln!("ikigai-outputs: the compositor refused the layout");
                outputs.changed = true;
                outputs.schedule_settle();
            }
            Event::Cancelled => {
                eprintln!("ikigai-outputs: the outputs changed under the restore");
                outputs.changed = true;
                outputs.schedule_settle();
            }
            _ => {}
        }
    }
}

impl Dispatch<ZcosmicOutputManagerV1, ()> for Outputs {
    fn event(_: &mut Self, _: &ZcosmicOutputManagerV1, _: <ZcosmicOutputManagerV1 as Proxy>::Event, _: &(), _: &Connection, _: &QueueHandle<Self>) {}
}

impl Dispatch<ZcosmicOutputConfigurationV1, ()> for Outputs {
    fn event(_: &mut Self, _: &ZcosmicOutputConfigurationV1, _: <ZcosmicOutputConfigurationV1 as Proxy>::Event, _: &(), _: &Connection, _: &QueueHandle<Self>) {}
}

impl Dispatch<ZwlrOutputConfigurationHeadV1, ()> for Outputs {
    fn event(_: &mut Self, _: &ZwlrOutputConfigurationHeadV1, _: <ZwlrOutputConfigurationHeadV1 as Proxy>::Event, _: &(), _: &Connection, _: &QueueHandle<Self>) {}
}

impl Dispatch<ZcosmicOutputConfigurationHeadV1, ()> for Outputs {
    fn event(_: &mut Self, _: &ZcosmicOutputConfigurationHeadV1, _: <ZcosmicOutputConfigurationHeadV1 as Proxy>::Event, _: &(), _: &Connection, _: &QueueHandle<Self>) {}
}

#[cfg(test)]
mod tests {
    use super::*;

    fn head(mode: (i32, i32, i32), x: i32, primary: bool) -> HeadConfig {
        HeadConfig {
            enabled: true,
            mode,
            position: (x, 0),
            transform: wl_output::Transform::Normal,
            scale: 1.0,
            adaptive_sync: Some(AdaptiveSyncStateExt::Disabled),
            mirroring: None,
            xwayland_primary: primary,
        }
    }

    fn names() -> Vec<String> {
        vec!["DP-5".into(), "DP-6".into()]
    }

    fn wanted() -> Layout {
        [("DP-5".to_owned(), head((2560, 1440, 240000), 2560, true)), ("DP-6".to_owned(), head((2560, 1440, 240000), 0, false))].into()
    }

    fn fallback() -> Layout {
        [("DP-5".to_owned(), head((2560, 1440, 59951), 0, false)), ("DP-6".to_owned(), head((2560, 1440, 59951), 2560, false))].into()
    }

    #[test]
    fn a_known_set_back_different_after_a_hotplug_is_restored() {
        let known = HashMap::from([(names(), wanted())]);
        assert_eq!(decide(&known, &names(), &fallback(), true, 0), Action::Restore(wanted()));
    }

    #[test]
    fn a_change_without_a_hotplug_is_the_users() {
        let known = HashMap::from([(names(), wanted())]);
        assert_eq!(decide(&known, &names(), &fallback(), false, 0), Action::Record);
    }

    #[test]
    fn an_unknown_set_and_an_unchanged_one_are_recorded() {
        assert_eq!(decide(&HashMap::new(), &names(), &fallback(), true, 0), Action::Record);
        let known = HashMap::from([(names(), wanted())]);
        assert_eq!(decide(&known, &names(), &wanted(), true, 0), Action::Record);
    }

    #[test]
    fn restores_are_bounded() {
        let known = HashMap::from([(names(), wanted())]);
        assert_eq!(decide(&known, &names(), &fallback(), true, MAX_ATTEMPTS), Action::Record);
    }
}
