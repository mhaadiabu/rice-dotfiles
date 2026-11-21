#!/usr/bin/env python3
"""Read the small slice of Niri state shown in the top bar."""

import json
import subprocess


def niri_json(command: str):
    result = subprocess.run(
        ["niri", "msg", "--json", command],
        capture_output=True,
        check=True,
        text=True,
    )
    return json.loads(result.stdout)


try:
    focused = niri_json("focused-window") or {}
    workspaces = niri_json("workspaces")
    windows = niri_json("windows")
    active = next((workspace for workspace in workspaces if workspace["is_focused"]), {})
    visible_workspaces = [
        workspace["idx"]
        for workspace in workspaces
        if workspace.get("output") == active.get("output")
    ]
    print(json.dumps({
        "workspace": str(active.get("idx", "–")),
        "workspaces": sorted(visible_workspaces),
        "windowAppIds": [window.get("app_id", "") for window in windows],
        "title": focused.get("title", "Desktop"),
        "appId": focused.get("app_id", ""),
    }))
except (OSError, subprocess.CalledProcessError, json.JSONDecodeError):
    print(json.dumps({"workspace": "–", "workspaces": [], "windowAppIds": [], "title": "Desktop", "appId": ""}))
