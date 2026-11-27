#!/bin/bash
# All checks. Run before every commit; CI runs the same file.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -m py_compile providers/*.py tests/*.py
for t in tests/test_*.py; do python3 "$t"; done
python3 -c "import json; json.load(open('config/accounts.example.json'))"
bash -n scripts/build.sh scripts/install.sh scripts/verify.sh
if command -v swiftc >/dev/null; then swiftc -typecheck app/main.swift; else echo "swiftc not found: skipping the Swift typecheck"; fi
# The repo must stay generic: no personal paths, names, hosts or keys.
pattern='/Users/[a-z]|sk-[A-Za-z0-9]{20}|ghp_[A-Za-z0-9]{20}|BEGIN (RSA|OPENSSH|PRIVATE)'
# Extra private deny-words (names of your own machines, companies, clients) live OUTSIDE the repo, one regex per line.
deny="${HEADROOM_DENYLIST:-$HOME/.config/headroom-dev/denylist}"
if [ -f "$deny" ]; then pattern="$pattern|$(grep -v '^[[:space:]]*$' "$deny" | paste -sd'|' -)"; fi
if git ls-files -z | grep -zv '^scripts/verify.sh$' | xargs -0 grep -I -n -E "$pattern"; then
  echo "verify: personal or secret-looking text found above"; exit 1
fi
[ -s VERSION ] && grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' VERSION || { echo "VERSION must be x.y.z"; exit 1; }
grep -q "^## \[$(tr -d '[:space:]' < VERSION)\]" CHANGELOG.md || { echo "CHANGELOG.md has no entry for $(tr -d '[:space:]' < VERSION)"; exit 1; }
echo "headroom verify: ok"
