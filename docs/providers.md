# Providers

A provider is a script. Headroom runs `python3 <provider>.py '<account as JSON>'` and reads one JSON object from stdout.
The account is one entry from `accounts.json`. Headroom looks in `~/.config/headroom/providers/` first, then the built-ins
inside the app. The name is the file name (letters, digits, `-`, `_` only).

## Output

```json
{
  "status": "ok",
  "plan": "Max",
  "meters": [
    {"name": "5h",   "pct": 62, "reset": "2026-11-16T07:40:00+00:00"},
    {"name": "Week", "pct": 40, "reset": "2026-12-01T19:00:00+00:00"},
    {"name": "Memory", "text": "36G"}
  ]
}
```

| Field | Meaning |
|---|---|
| `status` | `ok`, `off` (source not running or signed out, a normal state) or `error` (something broke; put the reason in `error`) |
| `error` | why it is off or failing; shown in the dropdown |
| `plan` | optional; read it from the source, never hard-code it |
| `title` | optional extra header text (for example a loaded model name) |
| `hide` | optional; `true` hides the item while it holds |
| `stale` | optional; `true` when the reading is cached because the source refused. Headroom marks the bar with `~` and says so in the dropdown |
| `icon` | optional `{"path": "...", "style": "template" or "shape"}` |
| `actions` | optional dropdown items `{"title", "command", "checked"}`; Headroom runs the shell command and shows its output if it fails |
| `meters` | any number, in display order. `pct` is percent **remaining**; `reset` is an ISO time; or plain `text` |

The bar shows the first two meters as two small rows; the dropdown shows all of them.

## Rules

- Report, don't draw. Return meters; Headroom formats them.
- Never write a plan or model name in code. Read it from the source.
- Never print or store a secret. Read it at run time (Keychain, environment).
- Answer in a few seconds (Headroom stops a provider after 20 s) and cache if the source rate-limits.
- Use `status: "off"` only when the source is genuinely not there. If it is there but unreadable, use `error`.
- Environment you get: `HEADROOM_FORCE=1` on **Refresh Now** (skip your cache), `HEADROOM_CACHE_DIR` (where to cache,
  default `~/.cache/headroom`), and `PYTHONPATH` set so `from _common import account_arg, emit, read_cache, write_cache` works.

Start from [`providers/_template.py`](../providers/_template.py). Test by hand:
`python3 providers/<name>.py '{"label": "X"}'`.

## Built-in providers

**claude**: any Claude Code login (Pro, Max, Team, Enterprise). `"login"` is the Claude Code config folder
(`~/.claude` by default, for example `~/.claude-second` for another). The token comes from the Keychain entry
`Claude Code-credentials` (other logins add a suffix of the folder's hash), read under your account name first because a
stray same-named entry can exist. Calls `https://api.anthropic.com/api/oauth/usage` at most every 5 minutes and serves the
last good reading for up to an hour when refused. The 5-hour row never shows more than the weekly window has left.
**Undocumented API.**

**antigravity**: the signed-in Antigravity user, from its local language server. Models sharing one quota show as one pool.
Finds the server's port and token from the running process. **Undocumented**, see
[antigravity-quota-rpc.md](antigravity-quota-rpc.md). Shows `off` when Antigravity isn't running and `error` when it is
running but can't be read.

**local**: whatever a local model server has loaded. Fields: `url` (default `http://localhost:8080`), `hide_when_off`,
and optional `stop_command` / `start_command` for a ticked "Local AI" dropdown item that runs them.
