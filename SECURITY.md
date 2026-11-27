# Security

Headroom runs provider scripts with your user's permissions and the Claude provider reads a token from your Keychain.
Only run providers you have read.

- The Claude token is sent only to `api.anthropic.com` and is never printed or written to disk.
- Provider names are validated as file names; an `accounts.json` entry can't point at an arbitrary path.
- `stop_command` / `start_command` / `actions` run shell commands from **your** config. Don't paste a config you didn't write.

Found a vulnerability? Use GitHub's private "Report a vulnerability" (Security tab) on this repo rather than a public issue.
