#!/usr/bin/env python3
"""
Local model server for Headroom: llama.cpp (llama-server), Ollama, LM Studio, MLX or anything that speaks
the OpenAI-style /v1/models API. No model is named here: every refresh asks the server what is loaded.

Account fields (accounts.json):
    "url":           server address, default "http://localhost:8080"
    "hide_when_off": hide the item while nothing is loaded (default true)
    "stop_command":  shell command that stops the server (run when you click the ticked "Local AI" item)
    "start_command": shell command that starts it (run when you click the unticked "Local AI" item)
    The dropdown shows one "Local AI" item: ticked while the server is up, unticked while it is down.

Bar rows: memory the model holds, then idle / busy / speed. "swap!" replaces the second row while macOS
reports memory pressure, so you know to stop the model.
"""

import json
import os
import re
import subprocess
import urllib.error
import urllib.request
from urllib.parse import urlparse

from _common import account_arg, emit


def get_json(url, timeout=1.5):
    with urllib.request.urlopen(url, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def get_text(url, timeout=1.5):
    with urllib.request.urlopen(url, timeout=timeout) as resp:
        return resp.read().decode("utf-8", errors="ignore")


def gb(n):
    return f"{n / 1e9:.0f}G" if n >= 10e9 else f"{n / 1e9:.1f}G"


def listener_rss(port):
    """Resident memory (bytes) of whatever process listens on the port."""
    try:
        pids = subprocess.run(["lsof", "-nP", f"-iTCP:{port}", "-sTCP:LISTEN", "-t"],
                              capture_output=True, text=True).stdout.split()
        total = 0
        for pid in set(pids):
            rss = subprocess.run(["ps", "-o", "rss=", "-p", pid], capture_output=True, text=True).stdout.strip()
            total += int(rss or 0) * 1024
        return total
    except Exception:
        return 0


def under_pressure():
    """macOS memory pressure: 1 normal, 2 warning, 4 critical."""
    try:
        out = subprocess.run(["sysctl", "-n", "kern.memorystatus_vm_pressure_level"],
                             capture_output=True, text=True).stdout.strip()
        return int(out) >= 2
    except Exception:
        return False


def model_name(raw):
    return re.sub(r"\.gguf$", "", os.path.basename(str(raw).rstrip("/")))


def probe(base):
    """(server kind, model name, memory bytes, state text) or raises if the server is unreachable."""
    port = urlparse(base).port or 80

    # Ollama lists what is actually loaded (its /v1/models lists everything installed instead).
    try:
        ps = get_json(f"{base}/api/ps")
        loaded = ps.get("models") or []
        if not loaded:
            return "Ollama", None, 0, "empty"
        mem = sum(m.get("size_vram") or m.get("size") or 0 for m in loaded)
        return "Ollama", ", ".join(m.get("name", "?") for m in loaded), mem, "on"
    except urllib.error.HTTPError:
        pass  # not Ollama

    models = get_json(f"{base}/v1/models").get("data") or []
    name = model_name(models[0]["id"]) if models else None
    mem = listener_rss(port)

    # llama.cpp extras: model file (its size is a floor for memory, since Metal buffers may not count in RSS),
    # slots (busy or idle) and metrics (speed, only when started with --metrics).
    try:
        props = get_json(f"{base}/props")
    except Exception:
        return "OpenAI-compatible", name, mem, "on"
    path = props.get("model_path") or ""
    if path and os.path.exists(path):
        mem = max(mem, os.path.getsize(path))
        name = name or model_name(path)
    state = "idle"
    try:
        slots = get_json(f"{base}/slots")
        if any(s.get("is_processing") for s in slots if isinstance(s, dict)):
            state = "busy"
            m = re.search(r"^llamacpp:predicted_tokens_seconds\s+([\d.]+)", get_text(f"{base}/metrics"), re.M)
            if m and float(m.group(1)) > 0:
                state = f"{float(m.group(1)):.0f}t/s"
    except Exception:
        pass
    return "llama.cpp", name, mem, state


def action(account, key, checked):
    """The "Local AI" menu item (ticked = on) running the account's command, or nothing when it is not set."""
    cmd = account.get(key)
    return [{"title": "Local AI", "command": cmd, "checked": checked}] if cmd else []


def get(account):
    base = (account.get("url") or "http://localhost:8080").rstrip("/")
    hide = account.get("hide_when_off", True)
    try:
        kind, name, mem, state = probe(base)
    except Exception:
        return {"status": "off", "error": f"no server at {base}", "hide": hide,
                "actions": action(account, "start_command", False)}
    if name is None:
        return {"status": "off", "error": f"{kind} is up at {base}, no model loaded", "hide": hide,
                "actions": action(account, "start_command", False)}

    pressure = under_pressure()
    meters = [{"name": "Memory", "text": gb(mem) if mem else "?"},
              {"name": "State", "text": "swap!" if pressure else state},
              {"name": "Server", "text": f"{kind}, {base}"}]
    if pressure:
        meters.append({"name": "Note", "text": f"macOS memory pressure is high; model is {state}"})
    return {"status": "ok", "title": name, "meters": meters,
            "actions": action(account, "stop_command", True)}


if __name__ == "__main__":
    emit(get(account_arg()))
