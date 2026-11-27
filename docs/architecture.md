# Architecture

```
accounts.json ──► Headroom.app (Swift, AppKit) ──runs──► provider.py ──prints──► JSON ──► two-row menu bar item
   (your config)     one NSStatusItem per account          (any language that     (shared
                                                            prints the JSON)        format)
```

| Path | Role |
|---|---|
| `app/main.swift` | The whole app: reads `accounts.json`, runs providers off the main thread, draws items and menus. Names no provider, plan or model. |
| `providers/` | Built-in providers, copied into `Headroom.app/Contents/Resources/providers`. `_common.py` is the shared helper and format doc; `_template.py` is the starting point. |
| `~/.config/headroom/` | Your config: `accounts.json` and optional `providers/` (override built-ins). Never in the repo. |
| `~/.cache/headroom/` | Provider caches. The Claude cache name carries a hash of `claude.py`, so a code change never serves old readings. |
| `config/accounts.example.json` | Examples, shipped in the app. |
| `tests/` | Provider rules, run by `scripts/verify.sh`. |
| `scripts/` | `build.sh` (app and release zip), `install.sh`, `verify.sh`. |

Design rules: providers report and the app draws; a provider failure shows as `err` with a reason, never as a wrong
number; one slow provider can't freeze the others (20 s limit); provider names are file names and are validated.

## Releases

Version lives in `VERSION` and `CHANGELOG.md` (checked by `verify.sh`). Tagging `vX.Y.Z` runs
`.github/workflows/release.yml`: build, zip, checksum, publish a GitHub Release with the changelog entry.
