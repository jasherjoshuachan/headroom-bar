# Changelog

Format: [Keep a Changelog](https://keepachangelog.com), versions follow [Semantic Versioning](https://semver.org).

## [0.1.0] - 2026-11-27
First public release.
- Menu bar item per account, two compact rows each (percent remaining and reset time).
- Providers: Claude Code (any login), Antigravity, local model servers (llama.cpp, Ollama, LM Studio, MLX).
- Config lives in `~/.config/headroom/`; providers you add there load without a rebuild.
- "Refresh Now" always reads live. The Claude reading is cached 5 minutes otherwise.
- The 5-hour row never shows more than the weekly limit has left.
