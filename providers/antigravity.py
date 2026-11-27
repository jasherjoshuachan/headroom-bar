#!/usr/bin/env python3
"""
Antigravity quota for Headroom, read from the local Antigravity language server. Zero LLM tokens used.

No model names are written here. Each model the server lists is grouped by its family (the first word of
its label, e.g. "Gemini"), and families that share one quota (same remaining amount and same reset time)
are shown as one pool, e.g. "Claude & GPT". New or renamed models show up on their own.
How the RPC works: docs/antigravity-quota-rpc.md.
"""

import json
import re
import ssl
import subprocess
import time
import urllib.request

from _common import account_arg, emit

ICON = {"path": "/Applications/Antigravity.app/Contents/Resources/icon.icns", "style": "shape"}


def env_token(pid):
    out = subprocess.run(["ps", "eww", "-p", pid, "-o", "command="], capture_output=True, text=True).stdout
    m = re.search(r"ANTIGRAVITY_SERVER_CSRF_TOKEN=(\S+)", out)
    return m.group(1) if m else None


def user_status():
    ps = subprocess.check_output(["ps", "-axo", "pid=,command="]).decode("utf-8", errors="ignore")
    pid = csrf = None
    for line in ps.splitlines():
        if "bin/language_server" not in line:
            continue
        m = re.match(r"\s*(\d+)\s", line)
        if not m:
            continue
        pid = m.group(1)
        # Older builds put the token on the command line; Antigravity 2.35+ passes it in the environment.
        t = re.search(r"--csrf_token\s+(\S+)", line)
        csrf = t.group(1) if t else env_token(pid)
        break
    if not pid:
        return None, "Antigravity isn't running"
    if not csrf:
        return None, "couldn't read the language server's CSRF token"

    lsof = subprocess.run(["lsof", "-Pan", "-p", pid, "-i"], capture_output=True, text=True).stdout
    ports = re.findall(r":(\d+)\s+\(LISTEN\)", lsof)
    if not ports:
        return None, "no listening port for the language server"

    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    for port in ports:
        req = urllib.request.Request(
            f"https://127.0.0.1:{port}/exa.language_server_pb.LanguageServerService/GetUserStatus",
            data=b"{}",
            headers={"Content-Type": "application/json", "X-Codeium-Csrf-Token": csrf,
                     "Connect-Protocol-Version": "1"})
        try:
            with urllib.request.urlopen(req, context=ctx, timeout=2) as resp:
                return json.loads(resp.read().decode("utf-8")).get("userStatus", {}), None
        except Exception:
            continue
    return None, "GetUserStatus RPC didn't answer"


def pools(configs):
    families = {}   # family -> [remaining pct, earliest reset]; dict keeps first-seen order
    for m in configs:
        label = (m.get("label") or "").strip()
        if not label:
            continue
        family = label.split()[0]
        quota = m.get("quotaInfo") or {}
        rem = quota.get("remainingFraction")
        pct = 100 if rem is None else int(round(rem * 100))   # no fraction = untouched pool
        reset = quota.get("resetTime")
        f = families.setdefault(family, [pct, reset])
        f[0] = min(f[0], pct)
        if reset and (not f[1] or reset < f[1]):
            f[1] = reset

    # Same amount left and same reset minute = one shared pool. Without a reset time there's no evidence
    # two families share a pool, so those stay separate.
    merged = {}     # key -> (pct, [families])
    for family, (pct, reset) in families.items():
        key = (pct, reset[:16]) if reset else ("alone", family)
        merged.setdefault(key, (pct, []))[1].append((family, reset))
    return [{"name": " & ".join(f for f, _ in members), "pct": pct,
             "reset": min((r for _, r in members if r), default=None)}
            for pct, members in merged.values()]


def get():
    try:
        # ps/lsof sometimes come back empty while the server is busy; a quick retry beats a false "off".
        for attempt in range(3):
            status, why = user_status()
            if status is not None or why == "Antigravity isn't running":
                break
            time.sleep(0.7)
    except Exception as e:
        return {"status": "error", "error": str(e), "icon": ICON}
    if status is None:
        # Only "not running" is a normal off. A running server we can't read is a break: show err with the reason.
        return {"status": "off" if why == "Antigravity isn't running" else "error", "error": why, "icon": ICON}
    configs = status.get("cascadeModelConfigData", {}).get("clientModelConfigs", [])
    result = {"status": "ok", "meters": pools(configs), "icon": ICON}
    plan = (status.get("userTier") or {}).get("name")
    if plan:
        result["plan"] = plan
    return result


if __name__ == "__main__":
    account_arg()  # Antigravity has one signed-in user; the account entry only sets the label.
    emit(get())
