use serde::Deserialize;
use std::collections::HashMap;
use std::fs::File;
use std::io::{self, Read, Write};
use std::os::fd::{AsRawFd, OwnedFd};
use std::os::unix::net::UnixStream;
use std::path::{Path, PathBuf};
use std::process::{Child, Command, ExitCode, Stdio};
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::{Duration, Instant};

use rustix::io::FdFlags;
use rustix::process::{Pid, Signal, kill_process};
use signal_hook::consts::{SIGHUP, SIGINT, SIGTERM};

const TARGET: &str = "ikigai-session.target";
const HANDSHAKE_TIMEOUT: Duration = Duration::from_secs(10);

// Same values cosmic-session's start-cosmic exports, minus what we don't ship.
const SESSION_ENV: &[(&str, &str)] = &[
    ("XDG_CURRENT_DESKTOP", "COSMIC"),
    ("XDG_SESSION_DESKTOP", "ikigai"),
    ("XDG_SESSION_TYPE", "wayland"),
    ("QT_QPA_PLATFORM", "wayland;xcb"),
    ("QT_QPA_PLATFORMTHEME", "cosmic"),
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
    let pairs: Vec<String> = env.iter().map(|(k, v)| format!("{k}={v}")).collect();
    log.line(format!("compositor up: {}", pairs.join(" ")));
    systemctl(log, &with_args(&["set-environment"], &pairs));
    systemctl(log, &["start", "--no-block", TARGET]);

    let status = wait_for(&mut comp, &terminate)?;
    log.line(format!("cosmic-comp exited: {status}"));
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
