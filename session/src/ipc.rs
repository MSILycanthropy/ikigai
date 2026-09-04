//! Wire format between `ikigai-bridge` and its clients: one JSON object per line.

use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Debug)]
#[serde(rename_all = "snake_case")]
pub enum State {
    Activated,
    Maximized,
    Minimized,
    Fullscreen,
    Sticky,
}

#[derive(Serialize, Deserialize, Clone, PartialEq, Eq, Debug)]
pub struct Toplevel {
    pub id: String,
    pub app_id: String,
    pub title: String,
    pub states: Vec<State>,
    pub outputs: Vec<String>,
    pub workspaces: Vec<String>,
    /// Bumped each time the window becomes activated, so the highest is the most recent; 0 is never.
    pub last_active: u64,
}

#[derive(Serialize, Deserialize, Clone, PartialEq, Eq, Debug)]
pub struct Workspace {
    pub id: String,
    pub name: String,
    pub active: bool,
    pub outputs: Vec<String>,
}

/// Where a window sits on one output, in that output's logical coordinates.
#[derive(Serialize, Deserialize, Clone, PartialEq, Eq, Debug)]
pub struct Geometry {
    pub id: String,
    pub output: String,
    pub x: i32,
    pub y: i32,
    pub width: i32,
    pub height: i32,
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(rename_all = "snake_case", tag = "event")]
pub enum Event {
    Snapshot { toplevels: Vec<Toplevel>, workspaces: Vec<Workspace> },
    Toplevel { toplevel: Toplevel },
    Workspaces { workspaces: Vec<Workspace> },
    Closed { id: String },
    /// A fresh preview of a window, replacing any earlier file for it.
    Thumbnail { id: String, path: String, width: u32, height: u32 },
    /// Every window's place on every output it touches, answering a `geometry` request.
    Geometry { windows: Vec<Geometry> },
    Error { message: String },
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(rename_all = "snake_case", tag = "request")]
pub enum Request {
    Activate { id: String },
    Close { id: String },
    Minimize { id: String },
    Unminimize { id: String },
    Maximize { id: String },
    Unmaximize { id: String },
    MoveToWorkspace { id: String, workspace: String },
    ActivateWorkspace { workspace: String },
    /// Capture these windows; each answers with a `thumbnail` event, or nothing if it can't be drawn.
    Capture { ids: Vec<String> },
    /// Ask once where the windows are; geometry is not streamed (it changes on every move).
    Geometry,
}

impl Request {
    /// The toplevel a request targets, if it targets one.
    pub fn id(&self) -> Option<&str> {
        match self {
            Request::Activate { id }
            | Request::Close { id }
            | Request::Minimize { id }
            | Request::Unminimize { id }
            | Request::Maximize { id }
            | Request::Unmaximize { id }
            | Request::MoveToWorkspace { id, .. } => Some(id),
            Request::ActivateWorkspace { .. } | Request::Capture { .. } | Request::Geometry => None,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn events_are_tagged_objects() {
        let event = Event::Toplevel {
            toplevel: Toplevel {
                id: "abc".into(),
                app_id: "ghostty".into(),
                title: "~".into(),
                states: vec![State::Activated],
                outputs: vec!["Virtual-1".into()],
                workspaces: vec!["ws1".into()],
                last_active: 3,
            },
        };
        assert_eq!(
            serde_json::to_string(&event).unwrap(),
            r#"{"event":"toplevel","toplevel":{"id":"abc","app_id":"ghostty","title":"~","states":["activated"],"outputs":["Virtual-1"],"workspaces":["ws1"],"last_active":3}}"#
        );
        assert_eq!(
            serde_json::to_string(&Event::Closed { id: "abc".into() }).unwrap(),
            r#"{"event":"closed","id":"abc"}"#
        );
    }

    #[test]
    fn requests_parse() {
        let request: Request = serde_json::from_str(r#"{"request":"activate","id":"abc"}"#).unwrap();
        assert!(matches!(request, Request::Activate { id } if id == "abc"));
        let request: Request =
            serde_json::from_str(r#"{"request":"move_to_workspace","id":"abc","workspace":"ws1"}"#).unwrap();
        assert!(matches!(request, Request::MoveToWorkspace { id, workspace } if id == "abc" && workspace == "ws1"));
        let request: Request = serde_json::from_str(r#"{"request":"capture","ids":["abc"]}"#).unwrap();
        assert!(matches!(request, Request::Capture { ids } if ids == ["abc"]));
    }
}
