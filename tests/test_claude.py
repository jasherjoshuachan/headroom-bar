#!/usr/bin/env python3
"""Regression checks for claude.py's meter rules. Run by scripts/verify.sh."""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "providers"))
import claude

def w(u, r="2026-11-28T00:00:00+00:00"):
    return {"utilization": u, "resets_at": r}

# Week used up, 5h window unused (the 27 Nov 2026 Team case): the 5h row must not read 100%.
m = claude.meters({"five_hour": w(0.0, None), "seven_day": w(100.0)})
assert [x["pct"] for x in m] == [0, 0], m
assert m[0]["reset"] == m[1]["reset"], m
# Normal case: 5h lower than week stays as is.
m = claude.meters({"five_hour": w(70.0), "seven_day": w(10.0)})
assert [x["pct"] for x in m] == [30, 90], m
# No 5h window (Max): row stays "-" and the week is reported as is.
m = claude.meters({"five_hour": None, "seven_day": w(58.0)})
assert m[0].get("text") == "\u2013" and m[1]["pct"] == 42, m

# Keychain: a same-named entry without the token must never win over the real one.
import json, subprocess
real = json.dumps({"claudeAiOauth": {"accessToken": "x"}}).encode()
stray = json.dumps({"mcpOAuth": {}}).encode()
def fake(cmd, **kw):
    if "-a" in cmd:
        return real
    return stray
claude.subprocess.check_output = fake
assert claude.read_oauth("svc") == {"accessToken": "x"}
def only_stray(cmd, **kw):
    if "-a" in cmd:
        raise subprocess.CalledProcessError(44, cmd)
    return stray
claude.subprocess.check_output = only_stray
try:
    claude.read_oauth("svc"); raise SystemExit("expected not-found")
except subprocess.CalledProcessError:
    pass
print("claude.py meter rules: ok")
