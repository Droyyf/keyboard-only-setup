#!/bin/bash
# Locate the pinned yabai tree and run its binary or one of its scripts.
set -euo pipefail

resolve_root() {
  local candidate
  for candidate in \
    "${YABAI_ROOT:-}" \
    "$HOME/.local/src/yabai-macos27" \
    "$HOME/dev/yabai-macos27"
  do
    if [ -n "$candidate" ] && [ -x "$candidate/bin/yabai" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

root="$(resolve_root)" || exit 0

if [ "${1:-}" = "--script" ]; then
  shift
  script="${1:-}"
  [ -n "$script" ] || exit 0
  shift || true
  exec /bin/bash "$root/scripts/$script" "$@"
fi

exec "$root/bin/yabai" "$@"
