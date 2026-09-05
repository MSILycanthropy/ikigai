use serde::Deserialize;
use std::collections::HashMap;
use std::fs::{File, OpenOptions};
use std::io::{self, BufRead, BufReader, Read, Write};
use std::os::fd::{AsRawFd, OwnedFd};
use std::os::unix::net::UnixStream;
use std::path::{Path, PathBuf};
use std::process::{Child, Command, ExitCode, Stdio};
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::thread::JoinHandle;
use std::time::{Duration, Instant};

use rustix::io::FdFlags;
use rustix::process::{Pid, Signal, kill_process};
use signal_hook::consts::{SIGHUP, SIGINT, SIGTERM};

const TARGET: &str = "ikigai-session.target";
const SHELL_IPC: &str = "ikigai-shell";
const SESSION_PATH_VAR: &str = "IKIGAI_SESSION_PATH";
const HANDSHAKE_TIMEOUT: Duration = Duration::from_secs(10);
const LOCK_CONFIRM_TIMEOUT: Duration = Duration::from_secs(3);
const LOCK_POLL: Duration = Duration::from_millis(50);

// Same values cosmic-session's start-cosmic exports, minus what we don't ship. Qt apps
// take their palette, fonts and icons from the GTK theme: "cosmic" names no plugin.
const SESSION_ENV: &[(&str, &str)] = &[
    ("XDG_CURRENT_DESKTOP", "COSMIC"),
    ("XDG_SESSION_DESKTOP", "ikigai"),
    ("XDG_SESSION_TYPE", "wayland"),
    ("QT_QPA_PLATFORM", "wayland;xcb"),
    ("QT_QPA_PLATFORMTHEME", "gtk3"),
    ("QT_AUTO_SCREEN_SCALE_FACTOR", "1"),
    ("QT_ENABLE_HIGHDPI_SCALING", "1"),
    ("GDK_BACKEND", "wayland,x11"),
    ("MOZ_ENABLE_WAYLAND", "1"),
    ("_JAVA_AWT_WM_NONREPARENTING", "1"),
    ("DCONF_PROFILE", "cosmic"),
];
const SYSTEMD_ENV: &[&str] = &[
    "XDG_CURRENT_DESKTOP",
    "XDG_SESSION_DESKTOP",
    "XDG_SESSION_TYPE",
    "QT_QPA_PLATFORMTHEME",
    "DCONF_PROFILE",
];

#[derive(Deserialize)]
#[serde(rename_all = "snake_case", tag = "message")]
enum CompositorMessage {
    SetEnv { variables: HashMap<String, String> },
}

struct Log {
    file: File,
    started: Instant,
}

impl Log {
    fn open(path: &Path) -> io::Result<Self> {
        Ok(Self { file: File::create(path)?, started: Instant::now() })
    }

    fn line(&mut self, msg: impl AsRef<str>) {
        let t = self.started.elapsed().as_secs_f32();
        let _ = writeln!(self.file, "[{t:7.3}] {}", msg.as_ref());
    }
}

fn main() -> ExitCode {
    let runtime_dir = match std::env::var_os("XDG_RUNTIME_DIR") {
        Some(dir) => PathBuf::from(dir),
        None => {
            eprintln!("ikigai-session: XDG_RUNTIME_DIR is not set");
            return ExitCode::FAILURE;
        }
    };
    let mut log = match Log::open(&runtime_dir.join("ikigai-session.log")) {
        Ok(log) => log,
        Err(err) => {
            eprintln!("ikigai-session: cannot open log: {err}");
            return ExitCode::FAILURE;
        }
    };
    match run(&runtime_dir, &mut log) {
        Ok(()) => ExitCode::SUCCESS,
        Err(err) => {
            log.line(format!("fatal: {err}"));
            ExitCode::FAILURE
        }
    }
}

fn run(runtime_dir: &Path, log: &mut Log) -> io::Result<()> {
    log.line("ikigai-session start");
    let terminate = Arc::new(AtomicBool::new(false));
    for sig in [SIGTERM, SIGINT, SIGHUP] {
        signal_hook::flag::register(sig, terminate.clone())?;
    }

    let pairs: Vec<String> = SYSTEMD_ENV.iter().map(|k| format!("{k}={}", session_var(k))).collect();
    systemctl(log, &with_args(&["set-environment"], &pairs));
    systemctl(log, &["reset-failed"]);

    let (mut session_end, comp_end) = UnixStream::pair()?;
    let comp_fd = OwnedFd::from(comp_end);
    inheritable(&comp_fd)?;
    let comp_log = File::create(runtime_dir.join("cosmic-comp.log"))?;
    let mut comp = Command::new("cosmic-comp")
        .envs(SESSION_ENV.iter().copied())
        .env("COSMIC_SESSION_SOCK", comp_fd.as_raw_fd().to_string())
        .stdin(Stdio::null())
        .stdout(comp_log.try_clone()?)
        .stderr(comp_log)
        .spawn()?;
    drop(comp_fd);
    log.line(format!("cosmic-comp started, pid {}", comp.id()));

    let env = match read_env(&mut session_end) {
        Ok(env) => env,
        Err(err) => {
            log.line("no environment from cosmic-comp, terminating it");
            send_term(&comp);
            wait_for(&mut comp, &terminate)?;
            return Err(err);
        }
    };
    let mut env = env;
    let session = session_path();
    if let Some(path) = &session {
        env.insert(SESSION_PATH_VAR.to_owned(), path.clone());
    }
    let pairs: Vec<String> = env.iter().map(|(k, v)| format!("{k}={v}")).collect();
    log.line(format!("compositor up: {}", pairs.join(" ")));
    systemctl(log, &with_args(&["set-environment"], &pairs));
    systemctl(log, &["start", "--no-block", TARGET]);

    let display = env.get("WAYLAND_DISPLAY").cloned().unwrap_or_default();
    let lock_log = OpenOptions::new().append(true).open(runtime_dir.join("ikigai-session.log"))?;
    let mut lock_watcher = match watch_lock(display, session, lock_log) {
        Ok(watcher) => Some(watcher),
        Err(err) => {
            log.line(format!("lock watcher not started: {err}"));
            None
        }
    };

    let status = wait_for(&mut comp, &terminate)?;
    log.line(format!("cosmic-comp exited: {status}"));
    if let Some((monitor, relay)) = lock_watcher.take() {
        let mut monitor = monitor;
        let _ = monitor.kill();
        let _ = monitor.wait();
        let _ = relay.join();
    }
    systemctl(log, &["stop", TARGET]);
    let keys: Vec<String> = env.into_keys().collect();
    systemctl(log, &with_args(&["unset-environment"], &keys));
    Ok(())
}

fn session_var(key: &str) -> &'static str {
    SESSION_ENV.iter().find(|(k, _)| *k == key).map(|(_, v)| *v).unwrap_or_default()
}

fn with_args<'a>(head: &[&'a str], tail: &'a [String]) -> Vec<&'a str> {
    head.iter().copied().chain(tail.iter().map(String::as_str)).collect()
}

fn systemctl(log: &mut Log, args: &[&str]) {
    let result = Command::new("systemctl").arg("--user").args(args).stdin(Stdio::null()).status();
    match result {
        Ok(status) if status.success() => {}
        Ok(status) => log.line(format!("systemctl --user {}: {status}", args.join(" "))),
        Err(err) => log.line(format!("systemctl --user {}: {err}", args.join(" "))),
    }
}

fn inheritable(fd: &OwnedFd) -> io::Result<()> {
    let flags = rustix::io::fcntl_getfd(fd)?;
    rustix::io::fcntl_setfd(fd, flags - FdFlags::CLOEXEC)?;
    Ok(())
}

fn read_env(sock: &mut UnixStream) -> io::Result<HashMap<String, String>> {
    sock.set_read_timeout(Some(HANDSHAKE_TIMEOUT))?;
    let mut len = [0u8; 2];
    sock.read_exact(&mut len)?;
    let mut body = vec![0u8; u16::from_ne_bytes(len) as usize];
    sock.read_exact(&mut body)?;
    match serde_json::from_slice(&body)? {
        CompositorMessage::SetEnv { variables } => Ok(variables),
    }
}

/// logind's object path for this session, so another session's lock is ignored.
fn session_path() -> Option<String> {
    let id = std::env::var("XDG_SESSION_ID").ok()?;
    let out = Command::new("busctl")
        .args(["--system", "call", "org.freedesktop.login1", "/org/freedesktop/login1"])
        .args(["org.freedesktop.login1.Manager", "GetSession", "s", &id])
        .stdin(Stdio::null())
        .output()
        .ok()?;
    String::from_utf8_lossy(&out.stdout).split('"').nth(1).map(str::to_owned)
}

/// Lock and unlock requests arrive as logind signals: cosmic-idle, Super+L and
/// `loginctl lock-session` all end there. gdbus subscribes as an ordinary client
/// (monitoring the system bus needs privileges); each matching line becomes an IPC
/// call into the shell, which owns the lock surface.
fn watch_lock(display: String, session: Option<String>, log: File) -> io::Result<(Child, JoinHandle<()>)> {
    let mut monitor = Command::new("gdbus")
        .args(["monitor", "--system", "--dest", "org.freedesktop.login1"])
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()?;
    let stdout = monitor.stdout.take().expect("stdout is piped");
    let mut relay = LockRelay { display, session, log, inhibitor: None };
    relay.hold_sleep();
    let thread = std::thread::spawn(move || {
        for line in BufReader::new(stdout).lines().map_while(Result::ok) {
            relay.handle(&line);
        }
        relay.release_sleep();
    });
    Ok((monitor, thread))
}

#[derive(Debug, PartialEq)]
enum LockEvent {
    Lock,
    Unlock,
    Sleep,
    Wake,
}

/// logind emits PrepareForSleep(true) and then suspends at once unless a delay
/// inhibitor asks it to wait (up to InhibitDelayMaxSec, 5 s by default). The inhibitor
/// is an fd on the caller's bus connection, which a one-shot CLI call would drop, so
/// `systemd-inhibit` holds it for as long as its `sleep infinity` child lives: killed
/// once the shell confirms the lock, started again after resume.
struct LockRelay {
    display: String,
    session: Option<String>,
    log: File,
    inhibitor: Option<Child>,
}

impl LockRelay {
    fn handle(&mut self, line: &str) {
        let Some(event) = lock_event(line, self.session.as_deref()) else { return };
        self.log(format!("{} -> {event:?}", line.trim_end()));
        match event {
            LockEvent::Lock => { self.shell("lock"); }
            LockEvent::Unlock => { self.shell("unlock"); }
            LockEvent::Sleep => {
                self.shell("lock");
                if !self.wait_locked() {
                    self.log("lock not confirmed before sleep");
                }
                self.release_sleep();
            }
            LockEvent::Wake => self.hold_sleep(),
        }
    }

    fn wait_locked(&mut self) -> bool {
        let deadline = Instant::now() + LOCK_CONFIRM_TIMEOUT;
        while Instant::now() < deadline {
            if self.shell("locked").is_some_and(|out| out.trim() == "true") {
                return true;
            }
            std::thread::sleep(LOCK_POLL);
        }
        false
    }

    fn shell(&mut self, call: &str) -> Option<String> {
        let result = Command::new(SHELL_IPC)
            .args(["session", call])
            .env("WAYLAND_DISPLAY", &self.display)
            .stdin(Stdio::null())
            .stderr(Stdio::null())
            .output();
        match result {
            Ok(out) if out.status.success() => Some(String::from_utf8_lossy(&out.stdout).into_owned()),
            Ok(out) => { self.log(format!("{SHELL_IPC} session {call}: {}", out.status)); None }
            Err(err) => { self.log(format!("{SHELL_IPC}: {err}")); None }
        }
    }

    fn hold_sleep(&mut self) {
        if self.inhibitor.is_some() {
            return;
        }
        let result = Command::new("systemd-inhibit")
            .args(["--what=sleep", "--mode=delay", "--who=ikigai-session", "--why=lock before sleep"])
            .args(["sleep", "infinity"])
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn();
        match result {
            Ok(child) => self.inhibitor = Some(child),
            Err(err) => self.log(format!("systemd-inhibit: {err}")),
        }
    }

    fn release_sleep(&mut self) {
        if let Some(mut child) = self.inhibitor.take() {
            let _ = child.kill();
            let _ = child.wait();
        }
    }

    fn log(&mut self, msg: impl AsRef<str>) {
        let _ = writeln!(self.log, "[lock] {}", msg.as_ref());
    }
}

/// Signals from other sessions are ignored. When ours is unknown, Lock is honoured
/// from any (locking twice is harmless) and Unlock from none.
fn lock_event(line: &str, session: Option<&str>) -> Option<LockEvent> {
    let (path, signal) = line.split_once(": ")?;
    let signal = signal.trim_end();
    if path == "/org/freedesktop/login1" {
        let sleep = signal.strip_prefix("org.freedesktop.login1.Manager.PrepareForSleep (")?;
        return match sleep.split(',').next()? {
            "true" => Some(LockEvent::Sleep),
            "false" => Some(LockEvent::Wake),
            _ => None,
        };
    }
    match signal {
        "org.freedesktop.login1.Session.Lock ()" if session.is_none_or(|ours| ours == path) => Some(LockEvent::Lock),
        "org.freedesktop.login1.Session.Unlock ()" if session == Some(path) => Some(LockEvent::Unlock),
        _ => None,
    }
}

fn send_term(comp: &Child) {
    let _ = kill_process(Pid::from_child(comp), Signal::TERM);
}

fn wait_for(comp: &mut Child, terminate: &AtomicBool) -> io::Result<std::process::ExitStatus> {
    let mut forwarded = false;
    loop {
        if let Some(status) = comp.try_wait()? {
            return Ok(status);
        }
        if terminate.load(Ordering::Relaxed) && !forwarded {
            send_term(comp);
            forwarded = true;
        }
        std::thread::sleep(Duration::from_millis(100));
    }
}

#[cfg(test)]
mod tests {
    use super::{LockEvent, lock_event};

    const OURS: &str = "/org/freedesktop/login1/session/_39";
    const OTHER: &str = "/org/freedesktop/login1/session/_354";

    #[test]
    fn lock_and_unlock_for_our_session() {
        assert_eq!(lock_event(&format!("{OURS}: org.freedesktop.login1.Session.Lock ()"), Some(OURS)), Some(LockEvent::Lock));
        assert_eq!(lock_event(&format!("{OURS}: org.freedesktop.login1.Session.Unlock ()\n"), Some(OURS)), Some(LockEvent::Unlock));
    }

    #[test]
    fn other_sessions_and_signals_are_ignored() {
        assert_eq!(lock_event(&format!("{OTHER}: org.freedesktop.login1.Session.Lock ()"), Some(OURS)), None);
        assert_eq!(lock_event(&format!("{OTHER}: org.freedesktop.login1.Session.Unlock ()"), Some(OURS)), None);
        assert_eq!(lock_event(&format!("{OURS}: org.freedesktop.login1.Session.PauseDevice (...)"), Some(OURS)), None);
        assert_eq!(lock_event("The name org.freedesktop.login1 is owned by :1.4", Some(OURS)), None);
    }

    #[test]
    fn sleep_and_wake() {
        assert_eq!(lock_event("/org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (true,)", Some(OURS)), Some(LockEvent::Sleep));
        assert_eq!(lock_event("/org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (false,)", Some(OURS)), Some(LockEvent::Wake));
    }

    #[test]
    fn unknown_session_locks_from_any_and_unlocks_from_none() {
        assert_eq!(lock_event(&format!("{OTHER}: org.freedesktop.login1.Session.Lock ()"), None), Some(LockEvent::Lock));
        assert_eq!(lock_event(&format!("{OTHER}: org.freedesktop.login1.Session.Unlock ()"), None), None);
    }
}
