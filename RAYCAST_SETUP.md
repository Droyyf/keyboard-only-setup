# Raycast ownership boundary

Raycast supplies the Caps Lock → Hyper remap and remains available for
searchable commands. Its **Window Management commands have no global hotkeys**.
Hammerspoon owns the complete mode-aware snap map, which prevents Raycast from
competing with Hammerspoon or yabai/skhd for the same chord.

Both modes expose only left half, maximize, and right half as direct window
placements. Every other window action is reached through the Hammerspoon HUD.
See [CHEATSHEET.md](CHEATSHEET.md).

## Hammerspoon's direct placement map

| Action | Shortcut | What it does |
|---|---|---|
| Left Half | LH `hyper+q`; 2H `hyper+h` | window → left half of screen |
| Maximize | LH `hyper+w`; 2H `hyper+;` | window → fill screen |
| Right Half | LH `hyper+e`; 2H `hyper+l` | window → right half |

(`hyper` = Caps Lock, which Raycast's remap turns into cmd+alt+ctrl+shift.)

> **Tip:** these only matter in **float** layout. In BSP layout yabai
> re-tiles automatically after a snap.

## Why Raycast is unassigned

- **One owner per global chord** — mode switching cannot leave a second
  Raycast action on the same key.
- **Small global surface** — less frequent actions stay in the generated HUD.
- **Raycast remains useful** — Window Management commands can still be found
  and run from Raycast search.

## Troubleshooting

- **Snap does nothing:** Hammerspoon must be running. Reload it from
  **Action Hub → Utilities → Reload configuration**.
- **A Raycast hotkey reappears:** clear it in **Raycast → Settings →
  Shortcuts**. Run `python3 audit_shortcuts.py` after updating
  `raycast-live-shortcuts.json` from the live UI.
