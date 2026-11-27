#!/usr/bin/env python3
"""
Template for a new Headroom provider. Copy to providers/<name>.py, fill in read_usage(), then add
    {"provider": "<name>", "label": "X", ...any fields you need...}
to accounts.json and click "Reload accounts.json" in any Headroom menu. No Swift change, no rebuild.

Rules (full format in _common.py):
- Report, don't draw: return meters, Headroom formats them into two short rows.
- Never name a plan or model in code; read them from the source.
- Never print or store a secret. Read it from the Keychain at run time.
- Answer fast (a few seconds at most) and cache if the source rate-limits (see claude.py).
"""

from _common import account_arg, emit


def read_usage(account):
    # Replace with a real reading. Return status "off" when the source isn't running or signed in.
    return {
        "status": "ok",
        "plan": None,
        "meters": [
            {"name": "Daily", "pct": 80, "reset": "2026-11-17T00:00:00+00:00"},
            {"name": "Monthly", "pct": 55, "reset": "2026-12-01T00:00:00+00:00"},
        ],
        # "icon": {"path": "/Applications/<App>.app/Contents/Resources/<icon>", "style": "template" | "shape"},
    }


if __name__ == "__main__":
    result = read_usage(account_arg())
    emit({k: v for k, v in result.items() if v is not None})
