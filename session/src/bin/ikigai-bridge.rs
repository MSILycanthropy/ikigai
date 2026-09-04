use std::collections::HashMap;
use std::io::{self, ErrorKind, Read, Write};
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::PathBuf;

use cosmic_client_toolkit::cosmic_protocols::toplevel_info::v1::client::zcosmic_toplevel_handle_v1;
use cosmic_client_toolkit::cosmic_protocols::toplevel_management::v1::client::zcosmic_toplevel_manager_v1;
use cosmic_client_toolkit::screencopy::{
    CaptureFrame, CaptureOptions, CaptureSession, CaptureSource, Formats, Frame, ScreencopyFrameData, ScreencopyFrameDataExt,
    ScreencopyHandler, ScreencopySessionData, ScreencopySessionDataExt, ScreencopyState,
};
use cosmic_client_toolkit::sctk::output::{OutputHandler, OutputState};
use cosmic_client_toolkit::sctk::reexports::calloop::generic::Generic;
use cosmic_client_toolkit::sctk::reexports::calloop::{EventLoop, Interest, LoopHandle, Mode, PostAction};
use cosmic_client_toolkit::sctk::reexports::calloop_wayland_source::WaylandSource;
use cosmic_client_toolkit::sctk::registry::{ProvidesRegistryState, RegistryState};
use cosmic_client_toolkit::sctk::shm::slot::{Buffer, SlotPool};
use cosmic_client_toolkit::sctk::shm::{Shm, ShmHandler};
use cosmic_client_toolkit::toplevel_info::{ToplevelInfoHandler, ToplevelInfoState};
use cosmic_client_toolkit::toplevel_management::{ToplevelManagerHandler, ToplevelManagerState};
use cosmic_client_toolkit::workspace::{self, WorkspaceHandler, WorkspaceState};
use ikigai_session::ipc::{Event, Geometry, Request, State, Toplevel, Workspace};
use ikigai_session::thumb;
use wayland_client::globals::registry_queue_init;
use wayland_client::protocol::{wl_output, wl_seat, wl_shm};
use wayland_client::{Connection, Dispatch, Proxy, QueueHandle, WEnum};
use wayland_protocols::ext::foreign_toplevel_list::v1::client::ext_foreign_toplevel_handle_v1::ExtForeignToplevelHandleV1;
use wayland_protocols::ext::image_copy_capture::v1::client::ext_image_copy_capture_frame_v1::FailureReason;
use wayland_protocols::ext::workspace::v1::client::ext_workspace_handle_v1::{ExtWorkspaceHandleV1, State as WorkspaceFlags};

type ClientId = u64;

/// Previews are shrunk to this width at most; Quickshell scales them the rest of the way.
const THUMB_WIDTH: u32 = 320;

/// The session lives until its frame lands or fails; dropping it destroys the protocol object.
struct Capture {
    _session: CaptureSession,
    buffer: Option<Buffer>,
    size: (u32, u32),
    order: thumb::Order,
}

struct SessionData {
    inner: ScreencopySessionData,
    id: String,
}

impl ScreencopySessionDataExt for SessionData {
    fn screencopy_session_data(&self) -> &ScreencopySessionData {
        &self.inner
    }
}

struct FrameData {
    inner: ScreencopyFrameData,
    id: String,
}

impl ScreencopyFrameDataExt for FrameData {
    fn screencopy_frame_data(&self) -> &ScreencopyFrameData {
        &self.inner
    }
}

struct Client {
    stream: UnixStream,
    inbox: Vec<u8>,
}

struct Bridge {
    registry_state: RegistryState,
    output_state: OutputState,
    info: ToplevelInfoState,
    manager: Option<ToplevelManagerState>,
    workspaces: WorkspaceState,
    screencopy: ScreencopyState,
    shm: Shm,
    pool: SlotPool,
    qh: QueueHandle<Bridge>,
    seat: wl_seat::WlSeat,
    captures: HashMap<String, Capture>,
    thumbs: HashMap<String, PathBuf>,
    thumb_dir: PathBuf,
    thumb_seq: u64,
    published: HashMap<String, Toplevel>,
    published_workspaces: Vec<Workspace>,
    focus_seq: u64,
    clients: HashMap<ClientId, Client>,
    next_client: ClientId,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let runtime_dir = PathBuf::from(std::env::var_os("XDG_RUNTIME_DIR").ok_or("XDG_RUNTIME_DIR is not set")?);
    let socket_path = runtime_dir.join("ikigai-bridge.sock");
    let thumb_dir = runtime_dir.join("ikigai/thumbs");
    let _ = std::fs::remove_dir_all(&thumb_dir);
    std::fs::create_dir_all(&thumb_dir)?;

    let conn = Connection::connect_to_env()?;
    let (globals, queue) = registry_queue_init(&conn)?;
    let qh = queue.handle();
    let registry_state = RegistryState::new(&globals);
    let seat: wl_seat::WlSeat = globals.bind(&qh, 1..=7, ())?;
    let shm = Shm::bind(&globals, &qh)?;
    let pool = SlotPool::new(4096, &shm)?;
    let mut bridge = Bridge {
        output_state: OutputState::new(&globals, &qh),
        info: ToplevelInfoState::try_new(&registry_state, &qh).ok_or("compositor lacks ext-foreign-toplevel-list")?,
        manager: ToplevelManagerState::try_new(&registry_state, &qh),
        workspaces: WorkspaceState::new(&registry_state, &qh),
        screencopy: ScreencopyState::new(&globals, &qh),
        shm,
        pool,
        qh: qh.clone(),
        registry_state,
        seat,
        captures: HashMap::new(),
        thumbs: HashMap::new(),
        thumb_dir,
        thumb_seq: 0,
        published: HashMap::new(),
        published_workspaces: Vec::new(),
        focus_seq: 0,
        clients: HashMap::new(),
        next_client: 0,
    };
    if bridge.manager.is_none() {
        eprintln!("ikigai-bridge: no zcosmic_toplevel_manager_v1, requests will fail");
    }

    let _ = std::fs::remove_file(&socket_path);
    let listener = UnixListener::bind(&socket_path)?;
    listener.set_nonblocking(true)?;

    let mut event_loop: EventLoop<Bridge> = EventLoop::try_new()?;
    let handle = event_loop.handle();
    WaylandSource::new(conn, queue).insert(handle.clone()).map_err(|e| e.error)?;
    let accept_handle = handle.clone();
    handle
        .insert_source(Generic::new(listener, Interest::READ, Mode::Level), move |_, listener, bridge| {
            loop {
                match listener.accept() {
                    Ok((stream, _)) => bridge.accept(stream, &accept_handle)?,
                    Err(err) if err.kind() == ErrorKind::WouldBlock => return Ok(PostAction::Continue),
                    Err(err) => return Err(err),
                }
            }
        })
        .map_err(|e| e.error)?;

    eprintln!("ikigai-bridge: listening on {}", socket_path.display());
    event_loop.run(None, &mut bridge, |_| {})?;
    Ok(())
}

impl Bridge {
    fn accept(&mut self, stream: UnixStream, handle: &LoopHandle<Bridge>) -> io::Result<()> {
        stream.set_nonblocking(true)?;
        let id = self.next_client;
        self.next_client += 1;
        let poll_fd = stream.try_clone()?;
        self.clients.insert(id, Client { stream, inbox: Vec::new() });
        let snapshot = Event::Snapshot {
            toplevels: self.published.values().cloned().collect(),
            workspaces: self.published_workspaces.clone(),
        };
        self.send(id, &snapshot);
        handle
            .insert_source(Generic::new(poll_fd, Interest::READ, Mode::Level), move |_, _, bridge| {
                Ok(if bridge.read_from(id) { PostAction::Continue } else { PostAction::Remove })
            })
            .map_err(|e| io::Error::other(e.error))?;
        Ok(())
    }

    /// Returns false once the client is gone.
    fn read_from(&mut self, id: ClientId) -> bool {
        let Some(client) = self.clients.get_mut(&id) else { return false };
        let mut buf = [0u8; 4096];
        loop {
            match (&client.stream).read(&mut buf) {
                Ok(0) => break,
                Ok(n) => client.inbox.extend_from_slice(&buf[..n]),
                Err(err) if err.kind() == ErrorKind::WouldBlock => {
                    let lines = take_lines(&mut client.inbox);
                    for line in lines {
                        self.handle_line(id, &line);
                    }
                    return true;
                }
                Err(_) => break,
            }
        }
        self.clients.remove(&id);
        false
    }

    fn handle_line(&mut self, id: ClientId, line: &str) {
        match serde_json::from_str::<Request>(line) {
            Ok(request) => self.handle_request(id, request),
            Err(err) => self.send(id, &Event::Error { message: format!("bad request: {err}") }),
        }
    }

    fn handle_request(&mut self, id: ClientId, request: Request) {
        let result = match &request {
            Request::Capture { ids } => {
                let _: () = ids.iter().for_each(|t| self.capture(t));
                Ok(())
            },
            Request::Geometry => {
                self.send_geometry(id);
                Ok(())
            },
            _ => self.apply(&request),
        };
        if let Err(message) = result {
            self.send(id, &Event::Error { message });
        }
    }

    fn apply(&self, request: &Request) -> Result<(), String> {
        let Some(target) = request.id() else {
            let Request::ActivateWorkspace { workspace } = request else { unreachable!() };
            self.workspace(workspace)?.activate();
            self.workspaces.workspace_manager().get().map_err(|e| e.to_string())?.commit();
            return Ok(());
        };
        let manager = &self.manager.as_ref().ok_or("compositor lacks zcosmic_toplevel_manager_v1")?.manager;
        let toplevel = self
            .info
            .toplevels()
            .find(|t| t.identifier == target)
            .and_then(|t| t.cosmic_toplevel.as_ref())
            .ok_or_else(|| format!("unknown toplevel {target}"))?;
        match request {
            Request::Activate { .. } => manager.activate(toplevel, &self.seat),
            Request::Close { .. } => manager.close(toplevel),
            Request::Minimize { .. } => manager.set_minimized(toplevel),
            Request::Unminimize { .. } => manager.unset_minimized(toplevel),
            Request::Maximize { .. } => manager.set_maximized(toplevel),
            Request::Unmaximize { .. } => manager.unset_maximized(toplevel),
            Request::MoveToWorkspace { workspace, .. } => {
                let workspace = self.workspace(workspace)?;
                let output = self.group_outputs(workspace).next().ok_or("workspace has no output")?;
                manager.move_to_ext_workspace(toplevel, workspace, &output);
            }
            Request::ActivateWorkspace { .. } | Request::Capture { .. } | Request::Geometry => unreachable!(),
        }
        Ok(())
    }

    /// One session per window, torn down after its first frame; the compositor renders the
    /// window into our buffer on demand, so even a covered window gets a fresh picture.
    fn capture(&mut self, id: &str) {
        if self.captures.contains_key(id) {
            return;
        }
        let Some(handle) = self.info.toplevels().find(|t| t.identifier == id).map(|t| t.foreign_toplevel.clone()) else {
            return;
        };
        let data = SessionData { inner: ScreencopySessionData::default(), id: id.to_owned() };
        match self.screencopy.capturer().create_session(&CaptureSource::Toplevel(handle), CaptureOptions::empty(), &self.qh, data) {
            Ok(session) => {
                self.captures.insert(id.to_owned(), Capture { _session: session, buffer: None, size: (0, 0), order: thumb::Order::Bgrx });
            }
            Err(err) => eprintln!("ikigai-bridge: capture of {id}: {err}"),
        }
    }

    fn send_geometry(&mut self, client: ClientId) {
        let windows = self
            .info
            .toplevels()
            .flat_map(|t| {
                t.geometry.iter().filter_map(|(output, g)| {
                    let output = self.output_state.info(output)?.name?;
                    Some(Geometry { id: t.identifier.clone(), output, x: g.x, y: g.y, width: g.width, height: g.height })
                })
            })
            .collect();
        self.send(client, &Event::Geometry { windows });
    }

    fn drop_capture(&mut self, id: &str) {
        self.captures.remove(id);
    }

    fn drop_thumb(&mut self, id: &str) {
        if let Some(path) = self.thumbs.remove(id) {
            let _ = std::fs::remove_file(path);
        }
    }

    fn workspace(&self, id: &str) -> Result<&ExtWorkspaceHandleV1, String> {
        self.workspaces
            .workspaces()
            .find(|w| workspace_key(w) == id)
            .map(|w| &w.handle)
            .ok_or_else(|| format!("unknown workspace {id}"))
    }

    fn group_outputs<'a>(&'a self, workspace: &'a ExtWorkspaceHandleV1) -> impl Iterator<Item = wl_output::WlOutput> + 'a {
        self.workspaces
            .workspace_groups()
            .filter(move |g| g.workspaces.contains(workspace))
            .flat_map(|g| g.outputs.iter().cloned())
    }

    fn output_names(&self, outputs: impl Iterator<Item = wl_output::WlOutput>) -> Vec<String> {
        let mut names: Vec<String> = outputs.filter_map(|o| self.output_state.info(&o)?.name).collect();
        names.sort();
        names
    }

    fn publish_workspaces(&mut self) {
        let workspaces: Vec<Workspace> = self
            .workspaces
            .workspaces()
            .map(|w| Workspace {
                id: workspace_key(w),
                name: w.name.clone(),
                active: w.state.contains(WorkspaceFlags::Active),
                outputs: self.output_names(self.group_outputs(&w.handle)),
            })
            .collect();
        if workspaces == self.published_workspaces {
            return;
        }
        self.published_workspaces = workspaces.clone();
        self.broadcast(&Event::Workspaces { workspaces });
        let handles: Vec<_> = self.info.toplevels().map(|t| t.foreign_toplevel.clone()).collect();
        for handle in &handles {
            self.publish(handle);
        }
    }

    fn send(&mut self, id: ClientId, event: &Event) {
        let line = encode(event);
        if let Some(client) = self.clients.get_mut(&id)
            && client.stream.write_all(line.as_bytes()).is_err()
        {
            self.clients.remove(&id);
        }
    }

    fn broadcast(&mut self, event: &Event) {
        let line = encode(event);
        self.clients.retain(|_, client| client.stream.write_all(line.as_bytes()).is_ok());
    }

    fn publish(&mut self, handle: &ExtForeignToplevelHandleV1) {
        let Some(mut toplevel) = self.describe(handle) else { return };
        let previous = self.published.get(&toplevel.id);
        let activated = |t: &Toplevel| t.states.contains(&State::Activated);
        toplevel.last_active = match previous {
            Some(p) if activated(p) || !activated(&toplevel) => p.last_active,
            None if !activated(&toplevel) => 0,
            _ => {
                self.focus_seq += 1;
                self.focus_seq
            }
        };
        if previous == Some(&toplevel) {
            return;
        }
        self.published.insert(toplevel.id.clone(), toplevel.clone());
        self.broadcast(&Event::Toplevel { toplevel });
    }

    fn describe(&self, handle: &ExtForeignToplevelHandleV1) -> Option<Toplevel> {
        let info = self.info.info(handle)?;
        let mut states: Vec<State> = info.state.iter().filter_map(|s| state_of(*s)).collect();
        states.sort();
        let mut workspaces: Vec<String> = info
            .workspace
            .iter()
            .filter_map(|w| self.workspaces.workspace_info(w).map(workspace_key))
            .collect();
        workspaces.sort();
        Some(Toplevel {
            id: info.identifier.clone(),
            app_id: info.app_id.clone(),
            title: info.title.clone(),
            states,
            outputs: self.output_names(info.output.iter().cloned()),
            workspaces,
            last_active: 0,
        })
    }
}

/// A stalled client that fills its socket buffer gets dropped rather than buffered.
fn encode(event: &Event) -> String {
    let mut line = serde_json::to_string(event).expect("events are always serializable");
    line.push('\n');
    line
}

fn take_lines(inbox: &mut Vec<u8>) -> Vec<String> {
    let mut lines = Vec::new();
    while let Some(end) = inbox.iter().position(|&b| b == b'\n') {
        let line: Vec<u8> = inbox.drain(..=end).collect();
        lines.push(String::from_utf8_lossy(&line[..end]).trim().to_owned());
    }
    lines.retain(|l| !l.is_empty());
    lines
}

/// cosmic-comp only assigns ext ids to pinned workspaces; the object id is unique per connection.
fn workspace_key(workspace: &workspace::Workspace) -> String {
    workspace.id.clone().unwrap_or_else(|| workspace.handle.id().protocol_id().to_string())
}

fn state_of(state: zcosmic_toplevel_handle_v1::State) -> Option<State> {
    use zcosmic_toplevel_handle_v1::State as S;
    Some(match state {
        S::Activated => State::Activated,
        S::Maximized => State::Maximized,
        S::Minimized => State::Minimized,
        S::Fullscreen => State::Fullscreen,
        S::Sticky => State::Sticky,
        _ => return None,
    })
}

impl ToplevelInfoHandler for Bridge {
    fn toplevel_info_state(&mut self) -> &mut ToplevelInfoState {
        &mut self.info
    }
    fn new_toplevel(&mut self, _: &Connection, _: &QueueHandle<Self>, t: &ExtForeignToplevelHandleV1) {
        self.publish(t);
    }
    fn update_toplevel(&mut self, _: &Connection, _: &QueueHandle<Self>, t: &ExtForeignToplevelHandleV1) {
        self.publish(t);
    }
    fn toplevel_closed(&mut self, _: &Connection, _: &QueueHandle<Self>, t: &ExtForeignToplevelHandleV1) {
        let Some(id) = self.info.info(t).map(|i| i.identifier.clone()) else { return };
        self.drop_capture(&id);
        self.drop_thumb(&id);
        if self.published.remove(&id).is_some() {
            self.broadcast(&Event::Closed { id });
        }
    }
}

impl ScreencopyHandler for Bridge {
    fn screencopy_state(&mut self) -> &mut ScreencopyState {
        &mut self.screencopy
    }

    fn init_done(&mut self, _: &Connection, qh: &QueueHandle<Self>, session: &CaptureSession, formats: &Formats) {
        let Some(id) = session.data::<SessionData>().map(|d| d.id.clone()) else { return };
        let (width, height) = formats.buffer_size;
        let format = [wl_shm::Format::Xrgb8888, wl_shm::Format::Argb8888, wl_shm::Format::Xbgr8888, wl_shm::Format::Abgr8888]
            .into_iter()
            .find(|f| formats.shm_formats.contains(f));
        let (Some(format), true) = (format, width > 0 && height > 0) else {
            eprintln!("ikigai-bridge: capture of {id}: no usable buffer ({width}x{height}, {:?})", formats.shm_formats);
            self.drop_capture(&id);
            return;
        };
        let buffer = match self.pool.create_buffer(width as i32, height as i32, width as i32 * 4, format) {
            Ok((buffer, _)) => buffer,
            Err(err) => {
                eprintln!("ikigai-bridge: capture of {id}: {err}");
                self.drop_capture(&id);
                return;
            }
        };
        let data = FrameData { inner: ScreencopyFrameData::default(), id: id.clone() };
        session.capture(buffer.wl_buffer(), &[], qh, data);
        if let Some(capture) = self.captures.get_mut(&id) {
            capture.buffer = Some(buffer);
            capture.size = (width, height);
            capture.order = match format {
                wl_shm::Format::Xbgr8888 | wl_shm::Format::Abgr8888 => thumb::Order::Rgbx,
                _ => thumb::Order::Bgrx,
            };
        }
    }

    fn stopped(&mut self, _: &Connection, _: &QueueHandle<Self>, session: &CaptureSession) {
        if let Some(id) = session.data::<SessionData>().map(|d| d.id.clone()) {
            self.drop_capture(&id);
        }
    }

    fn ready(&mut self, _: &Connection, _: &QueueHandle<Self>, frame: &CaptureFrame, _: Frame) {
        let Some(id) = frame.data::<FrameData>().map(|d| d.id.clone()) else { return };
        let Some(capture) = self.captures.remove(&id) else { return };
        let (width, height) = capture.size;
        let Some(canvas) = capture.buffer.as_ref().and_then(|b| b.canvas(&mut self.pool)) else { return };
        let image = thumb::shrink(canvas, width, height, width * 4, capture.order, THUMB_WIDTH);
        self.thumb_seq += 1;
        let path = self.thumb_dir.join(format!("{id}-{}.ppm", self.thumb_seq));
        if let Err(err) = thumb::write_ppm(&image, &path) {
            eprintln!("ikigai-bridge: thumbnail of {id}: {err}");
            return;
        }
        self.drop_thumb(&id);
        self.thumbs.insert(id.clone(), path.clone());
        self.broadcast(&Event::Thumbnail { id, path: path.to_string_lossy().into_owned(), width: image.width, height: image.height });
    }

    fn failed(&mut self, _: &Connection, _: &QueueHandle<Self>, frame: &CaptureFrame, reason: WEnum<FailureReason>) {
        if let Some(id) = frame.data::<FrameData>().map(|d| d.id.clone()) {
            eprintln!("ikigai-bridge: capture of {id} failed: {reason:?}");
            self.drop_capture(&id);
        }
    }
}

impl ShmHandler for Bridge {
    fn shm_state(&mut self) -> &mut Shm {
        &mut self.shm
    }
}

impl ToplevelManagerHandler for Bridge {
    fn toplevel_manager_state(&mut self) -> &mut ToplevelManagerState {
        self.manager.as_mut().expect("manager requests are guarded by is_some")
    }
    fn capabilities(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: Vec<WEnum<zcosmic_toplevel_manager_v1::ZcosmicToplelevelManagementCapabilitiesV1>>,
    ) {
    }
}

impl WorkspaceHandler for Bridge {
    fn workspace_state(&mut self) -> &mut WorkspaceState {
        &mut self.workspaces
    }
    fn done(&mut self) {
        self.publish_workspaces();
    }
}

impl ProvidesRegistryState for Bridge {
    fn registry(&mut self) -> &mut RegistryState {
        &mut self.registry_state
    }
    cosmic_client_toolkit::sctk::registry_handlers!(OutputState);
}

impl OutputHandler for Bridge {
    fn output_state(&mut self) -> &mut OutputState {
        &mut self.output_state
    }
    fn new_output(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_output::WlOutput) {}
    fn update_output(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_output::WlOutput) {}
    fn output_destroyed(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_output::WlOutput) {}
}

impl Dispatch<wl_seat::WlSeat, ()> for Bridge {
    fn event(_: &mut Self, _: &wl_seat::WlSeat, _: wl_seat::Event, _: &(), _: &Connection, _: &QueueHandle<Self>) {}
}

cosmic_client_toolkit::sctk::delegate_output!(Bridge);
cosmic_client_toolkit::sctk::delegate_registry!(Bridge);
cosmic_client_toolkit::delegate_toplevel_info!(Bridge);
cosmic_client_toolkit::delegate_toplevel_manager!(Bridge);
cosmic_client_toolkit::delegate_workspace!(Bridge);
cosmic_client_toolkit::delegate_screencopy!(Bridge);
cosmic_client_toolkit::sctk::delegate_shm!(Bridge);
