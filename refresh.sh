#!/usr/bin/env bash
# Verify and deploy the repository-owned keyboard workflow without reinstalling
# Homebrew packages or changing the selected LH/2H mode.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")" && pwd)"

# Validate source first; installed drift is expected and repaired below.
"$repo_root/verify.sh" --source-only

python3 - "$repo_root" <<'PY'
from pathlib import Path
import sys

repo = Path(sys.argv[1])
sys.path.insert(0, str(repo))
from scripts.workflow_install import activate_mode, install_managed_files

home = Path.home()
backup = install_managed_files(repo, home, home / ".keyboard-only-setup/backups")
mode = activate_mode(home, None)
print(f"Installed managed files in {mode} mode")
print(f"Backup: {backup}")
PY

if command -v skhd >/dev/null 2>&1; then
  skhd --reload
fi

if command -v hs >/dev/null 2>&1; then
  # Hammerspoon intentionally drops the CLI message port while reloading.
  # The live app finishes the reload after the CLI process exits.
  hs -c 'hs.reload()' || true
  hammerspoon_ready=false
  for _ in {1..40}; do
    if hs -c 'return true' >/dev/null 2>&1; then
      hammerspoon_ready=true
      break
    fi
    sleep 0.25
  done
  if [[ "$hammerspoon_ready" != true ]]; then
    echo "Hammerspoon did not restore its CLI message port after reload." >&2
    exit 1
  fi
fi

"$repo_root/verify.sh"

echo "Keyboard workflow refreshed."
