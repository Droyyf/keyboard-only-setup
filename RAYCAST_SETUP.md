# Raycast ownership boundary

Raycast supplies the Caps Lock → Hyper remap and remains available for
searchable commands. Its **Window Management commands have no global hotkeys**.
Hammerspoon owns the complete mode-aware snap map, which prevents Raycast from
competing with Hammerspoon or yabai/skhd for the same chord.

In **two-hand mode**, use the direct Hyper shortcuts below. In **left-hand
mode**, use **Hyper+X**, release, then a left-hand selection. See
[CHEATSHEET.md](CHEATSHEET.md).

## Hammerspoon's two-hand snap map

| Action | Shortcut | What it does |
|---|---|---|
| Left Half | `hyper+h` | window → left half of screen |
| Right Half | `hyper+l` | window → right half |
| Top Half | `hyper+k` | window → top half |
| Bottom Half | `hyper+j` | window → bottom half |
| Top Left Quarter | `hyper+u` | window → top-left quarter |
| Top Right Quarter | `hyper+i` | window → top-right quarter |
| Bottom Left Quarter | `hyper+o` | window → bottom-left quarter |
| Bottom Right Quarter | `hyper+p` | window → bottom-right quarter |
| Maximize | `hyper+;` | window → fill screen |
| Center | `hyper+'` | window → centered large |

(`hyper` = Caps Lock, which Raycast's remap turns into cmd+alt+ctrl+shift.)

> **Tip:** these only matter in **float** layout. In BSP layout yabai
> re-tiles automatically after a snap.

## Why Raycast is unassigned

- **One owner per global chord** — mode switching cannot leave a second
  Raycast action on the same key.
- **Existing habits stay intact** — the two-hand keys are unchanged; only
  their owner moved to Hammerspoon.
- **Raycast remains useful** — Window Management commands can still be found
  and run from Raycast search.

## Troubleshooting

- **Snap does nothing:** Hammerspoon must be running. Reload it with
  **Hyper+Escape**.
- **A Raycast hotkey reappears:** clear it in **Raycast → Settings →
  Shortcuts**. Run `python3 audit_shortcuts.py` after updating
  `raycast-live-shortcuts.json` from the live UI.
