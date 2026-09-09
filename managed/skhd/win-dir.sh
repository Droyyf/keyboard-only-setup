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
YABAI="/Users/droy-/dev/yabai-macos27/bin/yabai"
JQ="/opt/homebrew/bin/jq"

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
is_fullscreen=$(echo "$win_info" | "$JQ" -r '."is-fullscreen" // false')
is_floating=$(echo "$win_info" | "$JQ" -r '."is-floating" // false')

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
