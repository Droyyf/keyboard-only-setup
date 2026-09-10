#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")" && pwd)"

python3 -m unittest discover -s "$repo_root/tests" -p 'test_*.py' -v

if command -v hs >/dev/null 2>&1; then
  hs -c "dofile(\"$repo_root/tests/test_keyboard.lua\")"
else
  echo "skipping Hammerspoon Lua tests: hs CLI not found"
fi

python3 "$repo_root/audit_shortcuts.py"

exec python3 "$repo_root/scripts/workflow_install.py" verify "$@"
