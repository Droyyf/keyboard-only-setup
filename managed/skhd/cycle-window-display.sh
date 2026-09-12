#!/bin/bash
set -euo pipefail

config_dir="$(cd "$(dirname "$0")" && pwd)"
yabai_run="$config_dir/yabai-run.sh"

displays="$($yabai_run -m query --displays)"
window="$($yabai_run -m query --windows --window)"
target="$(jq -nr --argjson displays "$displays" --argjson window "$window" '
  ($displays | map(.index)) as $ids
  | ($window.display) as $current
  | ($ids | index($current)) as $position
  | if ($ids | length) < 2 or $position == null then empty
    else $ids[(($position + 1) % ($ids | length))]
    end
')"

[ -n "$target" ] || exit 0
exec "$yabai_run" -m window --display "$target"
