# Changelog

Format: [Keep a Changelog](https://keepachangelog.com), versions follow [Semantic Versioning](https://semver.org).

## [0.1.1] - 2026-11-27
- A reading served from cache because the source refused is now marked with `~` on the bar, not only in the dropdown.
- Providers refresh side by side, so one slow source no longer delays the others.
- A broken `accounts.json` shows `bad config` and says why, instead of looking like an empty one.
- The Claude provider deletes the cached readings of earlier versions of itself.
- Tests for the Antigravity pool and token rules.
- README: `python3` is a runtime requirement; the cask uses the current `depends_on macos:` form and quits the app on uninstall.

## [0.1.0] - 2026-11-27
First public release.
- Menu bar item per account, two compact rows each (percent remaining and reset time).
- Providers: Claude Code (any login), Antigravity, local model servers (llama.cpp, Ollama, LM Studio, MLX).
- Config lives in `~/.config/headroom/`; providers you add there load without a rebuild.
- "Refresh Now" always reads live. The Claude reading is cached 5 minutes otherwise.
- The 5-hour row never shows more than the weekly limit has left.
