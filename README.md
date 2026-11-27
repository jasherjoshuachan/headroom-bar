# Headroom

A free, open-source macOS menu bar app that shows how much of your AI plans you have left.

One small item per account, two compact rows each: percent **remaining** and when it resets. Claude Code,
Antigravity (Gemini) and local model servers work out of the box, and a new source is one small Python file.

<!-- screenshot: add docs/images/menubar.png once the UI pass lands -->

- **No telemetry, no Headroom server, no account.** The only network calls go to the sources you configure (for Claude, `api.anthropic.com`). Nothing is sent to the author.
- **Zero LLM tokens.** It reads usage numbers your tools already expose; it never prompts a model.
- **Modular.** The app only draws. Each source is a provider script that prints one JSON shape. Add one without touching Swift.

## Install

Homebrew:

```bash
brew install --cask jasherjoshuachan/tap/headroom-bar
```

Or download `Headroom-<version>.zip` from [Releases](https://github.com/jasherjoshuachan/headroom-bar/releases), unzip, and drag `Headroom.app` to `/Applications`.

Or build from source (needs the Xcode Command Line Tools: `xcode-select --install`):

```bash
git clone https://github.com/jasherjoshuachan/headroom-bar.git
cd headroom-bar
scripts/install.sh --login-item     # builds, installs to /Applications, starts at login
```

**First open:** releases are not yet signed with an Apple Developer ID, so macOS says it can't verify the app.
Right-click `Headroom.app`, choose **Open**, then **Open** again. (Or: System Settings, Privacy & Security, "Open Anyway".)
Building from source avoids the prompt. Start-at-login for a downloaded copy: System Settings, General, Login Items.

Keep Headroom in `/Applications`. On macOS 27, menu bar items from apps outside it get filed under the program path
and menu bar managers (Thaw, Bartender) can lose them.

**Requirements:** macOS 14 or later and `python3` (the providers are Python scripts). `python3` comes with the Xcode Command
Line Tools: if `/usr/bin/python3` isn't there yet, run `xcode-select --install` once.

## Setup

On first run Headroom writes `~/.config/headroom/accounts.json` with your Claude Code login. Click any Headroom item,
**Open Config Folder**, edit, then **Reload accounts.json**. No restart or rebuild.

```json
[
  {"provider": "claude", "label": "P", "login": "~/.claude"},
  {"provider": "claude", "label": "2", "login": "~/.claude-second"},
  {"provider": "antigravity", "label": "A"},
  {"provider": "local", "label": "L", "url": "http://localhost:8080"}
]
```

`label` is the short text next to the icon. Optional on any entry: `"name"` (dropdown title), `"enabled": false`.
More examples: [`config/accounts.example.json`](config/accounts.example.json).

## Providers

| Provider | Shows | Reads from |
|---|---|---|
| `claude` | the 5-hour and weekly windows (any plan) for a Claude Code login | Anthropic's usage endpoint, with the token Claude Code already keeps in your Keychain |
| `antigravity` | each model family's quota, shared pools merged | Antigravity's local language server |
| `local` | the model a local server has loaded, memory held, idle/busy | any OpenAI-style `/v1/models` server (llama.cpp, Ollama, LM Studio, MLX) |

Claude and Antigravity use **undocumented** interfaces. They can change without notice; when one breaks you see `err`
and a reason in the dropdown, not wrong numbers. Details and caveats: [docs/providers.md](docs/providers.md).

## Menu

Click an item for the full readings and plan. **Refresh Now** always reads live (otherwise Claude is cached 5 minutes
because its endpoint rate-limits). **Releases and Updates** opens this repo's releases; Headroom makes no network
call to check for updates.

Bar rows: `62% 3:40p` (resets within 20 h), `62% Wed` (within a week), `62% 22 Nov`. `off` = the source isn't running
or signed out, `err` = it failed (reason in the dropdown), `~` before a number = that reading is old: the source refused the
latest request, so Headroom is showing the last good one (the dropdown says so).

## Add your own provider

Copy [`providers/_template.py`](providers/_template.py) to `~/.config/headroom/providers/<name>.py`, make it print the
JSON in [docs/providers.md](docs/providers.md), add `{"provider": "<name>", "label": "X"}` to `accounts.json`, reload.
A provider in your config folder overrides a built-in of the same name. Built-ins that others would use: open a PR.

## Security

The Claude provider reads a token from your macOS Keychain, sends it only to `api.anthropic.com`, and never prints or
stores it. Providers are plain scripts you can read. Report problems: [SECURITY.md](SECURITY.md).

## Develop

```bash
scripts/verify.sh                    # all checks (also run by CI)
scripts/build.sh                     # build/Headroom.app
HEADROOM_CONFIG_DIR=/tmp/hr HEADROOM_PROVIDERS_DIR=$PWD/providers build/Headroom.app/Contents/MacOS/Headroom
```

Layout: [docs/architecture.md](docs/architecture.md). Contributing: [CONTRIBUTING.md](CONTRIBUTING.md). Version history: [CHANGELOG.md](CHANGELOG.md).

## License

MIT. Not affiliated with Anthropic, Google or any provider named here.
