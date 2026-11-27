# Contributing

Small PRs welcome, especially new providers.

1. Fork, branch, change.
2. `scripts/verify.sh` must pass (CI runs it too).
3. User-visible change: add a line under a new or unreleased version in `CHANGELOG.md` and bump `VERSION` (semver:
   fix = patch, new provider or feature = minor).
4. A new provider needs: the script, a section in `docs/providers.md`, a row in the README table, and a test if it has rules worth pinning.

Provider rules: [docs/providers.md](docs/providers.md). Keep the repo generic: no personal paths, hostnames, accounts or
keys (`verify.sh` checks for the obvious ones).
