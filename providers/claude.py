#!/usr/bin/env python3
"""
Claude subscription usage for Headroom. Works for any plan (Pro, Max, Team, Enterprise):
it shows whichever usage windows the account reports, in the order the API gives them.

Account fields (accounts.json):
    "login": Claude Code config folder, e.g. "~/.claude-second". Omit or "~/.claude" for the default login.

Reads that Claude Code login from the macOS Keychain. Zero LLM tokens used.
The token is never printed or written anywhere.
"""

import getpass
import hashlib
import json
import os
import subprocess
import time
import urllib.error
import urllib.request

from _common import FORCE, account_arg, emit, read_cache, write_cache

USAGE_URL = "https://api.anthropic.com/api/oauth/usage"
ICON = {"path": "/Applications/Claude.app/Contents/Resources/TrayIconTemplate@2x.png", "style": "template"}

# The usage endpoint rate-limits (HTTP 429), so hit it at most every MIN_INTERVAL seconds
# and keep serving the last good reading (up to MAX_STALE seconds) when it refuses.
MIN_INTERVAL = 300
MAX_STALE = 3600

# Short names for window keys the API is known to send; any other key is shown with its words tidied up.
SHORT = {"five_hour": "5h", "seven_day": "Week"}
FIRST = ["five_hour", "seven_day"]


def config_dir(login):
    """None for the default ~/.claude login, else the absolute folder path."""
    if not login:
        return None
    path = os.path.abspath(os.path.expanduser(login))
    return None if path == os.path.expanduser("~/.claude") else path


def keychain_service(cfg):
    # Claude Code names the Keychain entry after the config folder: the default login uses the bare name,
    # others add the first 8 hex of sha256(CLAUDE_CONFIG_DIR).
    if cfg is None:
        return "Claude Code-credentials"
    return "Claude Code-credentials-" + hashlib.sha256(cfg.encode()).hexdigest()[:8]


def meter_name(key):
    if key in SHORT:
        return SHORT[key]
    words = key.replace("seven_day", "week").replace("five_hour", "5h").split("_")
    return " ".join(w.capitalize() if not w[0].isdigit() else w for w in words if w)


def meters(data):
    """Every usage window in the response (anything with a utilization number), known ones first.
    A known window the account has but isn't in right now (e.g. no 5h window open) keeps its row as "–",
    so the top and bottom rows mean the same thing every refresh."""
    keys = [k for k, v in data.items()
            if (isinstance(v, dict) and v.get("utilization") is not None) or (k in FIRST and k in data)]
    keys.sort(key=lambda k: (FIRST.index(k) if k in FIRST else len(FIRST), list(data).index(k)))
    out = []
    for k in keys:
        w = data[k] if isinstance(data[k], dict) else {}
        if w.get("utilization") is None:
            out.append({"name": meter_name(k), "text": "–"})
        else:
            out.append({"name": meter_name(k),
                        "pct": max(0, min(100, 100 - int(round(w["utilization"])))),
                        "reset": w.get("resets_at")})
    return cap_by_week(out)


def cap_by_week(out):
    """A short window can't have more left than the week: at 0% for the week you are locked out whatever the
    5h row says, so show the lower number (and the week's reset) on any window that has a longer one above it."""
    week = next((m for m in out if m["name"] == "Week" and "pct" in m), None)
    if week:
        for m in out:
            if m is not week and "pct" in m and m["name"] == "5h" and week["pct"] < m["pct"]:
                m["pct"], m["reset"] = week["pct"], week["reset"]
    return out


def read_oauth(service):
    """The login's OAuth block from the Keychain. Several entries can share one service name (a stray one made
    under account "unknown" holds only MCP data), and `security -s` alone picks any of them at random. So ask for
    the entry under your own account name first, then fall back to any entry that actually has the token."""
    for account in (getpass.getuser(), None):
        cmd = ["security", "find-generic-password", "-s", service] + (["-a", account] if account else []) + ["-w"]
        try:
            oauth = json.loads(subprocess.check_output(cmd, stderr=subprocess.DEVNULL)).get("claudeAiOauth")
        except (subprocess.CalledProcessError, ValueError):
            continue
        if oauth:
            return oauth
    raise subprocess.CalledProcessError(44, "security")   # not found: reported as "login not found"


def fetch_live(service):
    try:
        oauth = read_oauth(service)
        req = urllib.request.Request(USAGE_URL, headers={
            "Authorization": f"Bearer {oauth['accessToken']}",
            "anthropic-beta": "oauth-2025-04-20",
        })
        with urllib.request.urlopen(req, timeout=8) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        plan = oauth.get("subscriptionType")
        result = {"status": "ok", "meters": meters(data)}
        if plan:
            result["plan"] = str(plan).capitalize()
        return result
    except subprocess.CalledProcessError:
        return {"status": "error", "error": "Claude Code login not found in Keychain"}
    except urllib.error.HTTPError as e:
        hint = (" (rate limited, will retry)" if e.code == 429
                else " (login expired? open Claude Code once)" if e.code in (401, 403) else "")
        return {"status": "error", "error": f"usage API HTTP {e.code}{hint}"}
    except Exception as e:
        return {"status": "error", "error": str(e)}


def get(account):
    service = keychain_service(config_dir(account.get("login")))
    # The cache name carries a hash of this file, so any code change (a new rule, a fixed bug) drops old
    # readings instead of serving what the previous version computed (stale-cache bug, 27 Nov 2026).
    with open(__file__, "rb") as f:
        code = hashlib.sha256(f.read()).hexdigest()[:6]
    cache = "claude-" + hashlib.sha256(service.encode()).hexdigest()[:8] + "-" + code + ".json"
    fetched_at, cached = read_cache(cache)
    now = time.time()
    force = FORCE
    if cached and not force and now - fetched_at < MIN_INTERVAL:
        result = cached
    else:
        result = fetch_live(service)
        if result.get("status") == "ok":
            write_cache(cache, result)
        elif cached and now - fetched_at < MAX_STALE:
            result = {**cached, "stale": True}
    return {**result, "icon": ICON}


if __name__ == "__main__":
    emit(get(account_arg()))
