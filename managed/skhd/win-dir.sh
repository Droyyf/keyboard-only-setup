#!/bin/bash
# Directional window helper for skhd.
# Works in BOTH yabai layouts (float and bsp):
#   focus  <dir>   -> focus nearest window in direction
#   move   <dir>   -> translate floating window, or swap with neighbour in bsp
#   resize <dir>   -> resize by a step in direction
#
# Edge cases handled:
#   - yabai not running → silent exit
#   - no focused window → silent exit
#   - fullscreen window → move/resize silently skipped
#   - missing/invalid arguments → silent exit
#   - all yabai stderr suppressed → no log noise

if [ -z "${YABAI:-}" ]; then
  for candidate in \
    "${YABAI_ROOT:+$YABAI_ROOT/bin/yabai}" \
    "$HOME/.local/src/yabai-macos27/bin/yabai" \
    "$HOME/dev/yabai-macos27/bin/yabai"
  do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
      YABAI="$candidate"
      break
    fi
  done
fi
[ -n "${YABAI:-}" ] || exit 0

if [ -z "${JQ:-}" ] || [ ! -x "${JQ:-}" ]; then
  JQ=""
  for candidate in /opt/homebrew/bin/jq /usr/local/bin/jq; do
    if [ -x "$candidate" ]; then
      JQ="$candidate"
      break
    fi
  done
  if [ -z "$JQ" ]; then
    JQ="$(command -v jq 2>/dev/null || true)"
  fi
fi

json_flag() {
  local key="$1"
  if [ -n "${JQ:-}" ] && [ -x "$JQ" ]; then
    printf '%s' "$win_info" | "$JQ" -r --arg key "$key" '.[$key] // false'
  else
    printf '%s' "$win_info" | python3 -c 'import json,sys
w=json.load(sys.stdin)
key=sys.argv[1]
print("true" if w.get(key) else "false")
' "$key"
  fi
}

op="$1"
dir="$2"

# --- guard: missing arguments ---
[ -z "$op" ] || [ -z "$dir" ] && exit 0

# --- guard: invalid operation ---
case "$op" in
  focus|move|resize) ;;
  *) exit 0 ;;
esac

# --- guard: invalid direction ---
case "$dir" in
  west|east|north|south) ;;
  *) exit 0 ;;
esac

# --- guard: yabai not running ---
"$YABAI" -m query --windows --window &>/dev/null || exit 0

# --- guard: no focused window or fullscreen (skip move/resize on fullscreen) ---
win_info=$("$YABAI" -m query --windows --window 2>/dev/null)
[ -z "$win_info" ] && exit 0
is_fullscreen=$(json_flag is-fullscreen)
is_floating=$(json_flag is-floating)

case "$op" in
  focus)
    "$YABAI" -m window --focus "$dir" &>/dev/null || true
    ;;
  move)
    [ "$is_fullscreen" = "true" ] && exit 0
    case "$dir" in
      west)  dx=-60; dy=0   ;;
      east)  dx=60;  dy=0   ;;
      north) dx=0;   dy=-60 ;;
      south) dx=0;   dy=60  ;;
    esac
    if [ "$is_floating" = "true" ]; then
      "$YABAI" -m window --move "rel:$dx:$dy" &>/dev/null || true
    else
      "$YABAI" -m window --swap "$dir" &>/dev/null || true
    fi
    ;;
  resize)
    [ "$is_fullscreen" = "true" ] && exit 0
    case "$dir" in
      west)  h="left";   dx=-60; dy=0   ;;
      east)  h="right";  dx=60;  dy=0   ;;
      north) h="top";    dx=0;   dy=-40 ;;
      south) h="bottom"; dx=0;   dy=40  ;;
    esac
    "$YABAI" -m window --resize "$h:$dx:$dy" &>/dev/null || true
    ;;
esac
