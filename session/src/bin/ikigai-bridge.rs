use std::collections::HashMap;
use std::io::{self, ErrorKind, Read, Write};
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::PathBuf;

use cosmic_client_toolkit::cosmic_protocols::toplevel_info::v1::client::zcosmic_toplevel_handle_v1;
use cosmic_client_toolkit::cosmic_protocols::toplevel_management::v1::client::zcosmic_toplevel_manager_v1;
use cosmic_client_toolkit::sctk::output::{OutputHandler, OutputState};
use cosmic_client_toolkit::sctk::reexports::calloop::generic::Generic;
use cosmic_client_toolkit::sctk::reexports::calloop::{EventLoop, Interest, LoopHandle, Mode, PostAction};
use cosmic_client_toolkit::sctk::reexports::calloop_wayland_source::WaylandSource;
use cosmic_client_toolkit::sctk::registry::{ProvidesRegistryState, RegistryState};
use cosmic_client_toolkit::toplevel_info::{ToplevelInfoHandler, ToplevelInfoState};
use cosmic_client_toolkit::toplevel_management::{ToplevelManagerHandler, ToplevelManagerState};
use cosmic_client_toolkit::workspace::{self, WorkspaceHandler, WorkspaceState};
use ikigai_session::ipc::{Event, Request, State, Toplevel, Workspace};
use wayland_client::globals::registry_queue_init;
use wayland_client::protocol::{wl_output, wl_seat};
use wayland_client::{Connection, Dispatch, Proxy, QueueHandle, WEnum};
use wayland_protocols::ext::foreign_toplevel_list::v1::client::ext_foreign_toplevel_handle_v1::ExtForeignToplevelHandleV1;
use wayland_protocols::ext::workspace::v1::client::ext_workspace_handle_v1::{ExtWorkspaceHandleV1, State as WorkspaceFlags};

type ClientId = u64;

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
    seat: wl_seat::WlSeat,
    published: HashMap<String, Toplevel>,
    published_workspaces: Vec<Workspace>,
    focus_seq: u64,
    clients: HashMap<ClientId, Client>,
    next_client: ClientId,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let runtime_dir = PathBuf::from(std::env::var_os("XDG_RUNTIME_DIR").ok_or("XDG_RUNTIME_DIR is not set")?);
    let socket_path = runtime_dir.join("ikigai-bridge.sock");

    let conn = Connection::connect_to_env()?;
    let (globals, queue) = registry_queue_init(&conn)?;
    let qh = queue.handle();
    let registry_state = RegistryState::new(&globals);
    let seat: wl_seat::WlSeat = globals.bind(&qh, 1..=7, ())?;
    let mut bridge = Bridge {
        output_state: OutputState::new(&globals, &qh),
        info: ToplevelInfoState::try_new(&registry_state, &qh).ok_or("compositor lacks ext-foreign-toplevel-list")?,
        manager: ToplevelManagerState::try_new(&registry_state, &qh),
        workspaces: WorkspaceState::new(&registry_state, &qh),
        registry_state,
        seat,
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
        if let Err(message) = self.apply(&request) {
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
            Request::ActivateWorkspace { .. } => unreachable!(),
        }
        Ok(())
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
        if self.published.remove(&id).is_some() {
            self.broadcast(&Event::Closed { id });
        }
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
