#!/usr/bin/env python3
"""Antigravity pool rules and token lookup. Run by scripts/verify.sh."""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "providers"))
import antigravity

def model(label, frac, reset):
    q = {"resetTime": reset}
    if frac is not None:
        q["remainingFraction"] = frac
    return {"label": label, "quotaInfo": q}

# Families with the same amount left and the same reset minute are one shared pool.
pools = antigravity.pools([
    model("Claude Sonnet", 1.0, "2026-12-03T22:57:54Z"),
    model("GPT-OSS 120B", 1.0, "2026-12-03T22:57:54Z"),
    model("Gemini 3 Pro", 0.08, "2026-12-03T16:24:00Z"),
])
assert [(p["name"], p["pct"]) for p in pools] == [("Claude & GPT-OSS", 100), ("Gemini", 8)] or \
       [(p["name"], p["pct"]) for p in pools] == [("Gemini", 8), ("Claude & GPT-OSS", 100)], pools
# A model with no fraction is an untouched pool (100%); no reset time means no evidence of sharing.
pools = antigravity.pools([model("Alpha x", None, None), model("Beta y", None, None)])
assert sorted(p["name"] for p in pools) == ["Alpha", "Beta"] and all(p["pct"] == 100 for p in pools), pools
# The lowest remaining amount in a family wins.
pools = antigravity.pools([model("Gemini a", 0.5, "2026-12-01T00:00:00Z"), model("Gemini b", 0.2, "2026-12-01T00:00:00Z")])
assert pools[0]["pct"] == 20, pools
# Token: newer builds keep it in the environment, older ones on the command line.
class R:  # fake subprocess.run result
    def __init__(self, out): self.stdout = out
antigravity.subprocess.run = lambda *a, **k: R("/bin/language_server --x ANTIGRAVITY_SERVER_CSRF_TOKEN=abc-123 HOME=/h")
assert antigravity.env_token("1") == "abc-123"
antigravity.subprocess.run = lambda *a, **k: R("/bin/language_server --x HOME=/h")
assert antigravity.env_token("1") is None
print("antigravity rules: ok")
