"""
Shared helpers for Headroom provider plug-ins.

A provider is `providers/<name>.py`. Headroom runs it as
    python3 providers/<name>.py '<account as JSON>'
where the account is one entry from accounts.json, and reads one JSON object from stdout:

    {
      "status": "ok" | "off" | "error",
      "error":  "why it is off or failing",          # optional, shown in the dropdown
      "plan":   "Max" | "Team" | ...,                # optional, read from the account, never configured
      "title":  "my-model-q8_0",                  # optional, extra header text (e.g. a loaded model)
      "hide":   true,                                # optional, hide the item while this is true
      "icon":   {"path": "/Applications/X.app/...", "style": "template" | "shape"},   # optional
      "stale":  true,                                # optional, reading is cached because the source refused
      "actions": [{"title": "Local AI", "command": "stop-server", "checked": true}],   # optional dropdown items; the app
                                                     # runs the shell command and shows its output if it fails.
                                                     # "checked" (optional) draws a tick: true = on, false = off
      "meters": [                                    # any number, in display order
        {"name": "5h", "pct": 62, "reset": "2026-11-16T07:40:00+00:00"},   # pct = percent REMAINING
        {"name": "Memory", "text": "36G"}                                    # or plain text
      ]
    }

The menu bar shows the first two meters as two small stacked rows; the dropdown shows all of them.
Providers report, the app only draws: no provider, plan or model name is written in main.swift.
"""

import json
import os
import sys
import time

CACHE_DIR = os.environ.get("HEADROOM_CACHE_DIR") or os.path.expanduser("~/.cache/headroom")
FORCE = bool(os.environ.get("HEADROOM_FORCE"))   # set by "Refresh Now": skip your cache and read live


def account_arg():
    """The account entry Headroom passed in (an empty dict when run by hand with no argument)."""
    if len(sys.argv) > 1:
        try:
            return json.loads(sys.argv[1])
        except ValueError:
            return {"label": sys.argv[1]}
    return {}


def emit(result):
    print(json.dumps(result, indent=2))


def read_cache(name):
    try:
        with open(os.path.join(CACHE_DIR, name)) as f:
            c = json.load(f)
        return c["fetched_at"], c["result"]
    except Exception:
        return None, None


def write_cache(name, result):
    try:
        os.makedirs(CACHE_DIR, exist_ok=True)
        with open(os.path.join(CACHE_DIR, name), "w") as f:
            json.dump({"fetched_at": time.time(), "result": result}, f)
    except Exception:
        pass
