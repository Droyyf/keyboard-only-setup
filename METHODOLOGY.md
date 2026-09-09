# Keyboard mode setup

This setup offers two modes across skhd and Hammerspoon while retaining Raycast's Caps Lock → Hyper remap.

See **[CHEATSHEET.md](CHEATSHEET.md)** for the complete map and **[RAYCAST_SETUP.md](RAYCAST_SETUP.md)** for the Raycast ownership boundary.

## Architecture

- **Raycast:** Caps Lock → Hyper and searchable commands. Its Window Management commands have no global hotkeys.
- **skhd:** low-latency window focus, move, resize, Space and display commands; one selected profile at a time.
- **yabai:** executes window, Space, and display operations. The verified active binary is `/Users/droy-/dev/yabai-macos27/bin/yabai`.
- **Hammerspoon:** mode switch and indicator; apps, hints, grid, scrolling, media, snapshots; direct two-hand snapping; left-hand snapping and navigation layers; mode-aware help.
- **Shortcat:** existing ⌘⇧Space activation for accessibility-based UI search.

The left-hand map uses W/A/S/D for direction. Short, explicitly entered layers make the less frequent actions available without stretching or losing actions such as Spaces 6–9. Outside those layers, normal typing remains unchanged. This is a shortcut/control map, not a one-hand text-entry layout.

## Live configuration

| File | Purpose |
|---|---|
| `~/.hammerspoon/keyboard.lua` | Hammerspoon action implementations and mode-aware bindings |
| `~/.hammerspoon/init.lua` | Existing startup and window-follow behavior |
| `~/.config/keyboard-mode` | Saved selection: `dual` or `left` |
| `~/.config/skhd/skhdrc-dual` | Full two-hand window shortcuts |
| `~/.config/skhd/skhdrc-left` | Left-hand window shortcuts |
| `~/.config/skhd/skhdrc` | Active skhd configuration |
| `~/.config/skhd/set-keyboard-mode.py` | Validated, locked profile switch with failure rollback |
| `~/.config/skhd/win-dir.sh` | Focus / float move / BSP swap / resize helper |

Use the mode switch rather than editing the generated active `skhdrc`: edit the corresponding profile when changing shortcuts. Keep both profiles' actions in sync, then update the cheat sheet.

## Switching and recovery

**Hyper+Tab** switches mode; the menu bar shows **2H** or **LH**. **Hyper+backtick** displays the active map. **Hyper+Escape** reloads the configuration.

The switching helper validates the target profile, serializes concurrent requests, atomically replaces the active skhd file, requests skhd reload, and only then records the selected mode. Reported reload or write failures restore the previous files and request another reload. skhd's reload command signals the daemon; live input testing is still needed to establish that the daemon has actually adopted every binding.

Terminal fallback:

```sh
~/.config/skhd/set-keyboard-mode.py dual
hs -c 'hs.reload()'
```

Choose `left` instead to activate the left-hand profile.

Pre-change backup: `backups/20260908-195649/`. It includes the original Hammerspoon files, the complete skhd directory, and project guides. The mode file did not exist before this change (the former setup defaulted to two hands).

To restore the old setup, restore the backed-up Hammerspoon files and original skhd directory, remove the newly introduced mode file, and reload both engines. Preserve any later changes before doing that.

## Behavioral boundaries

- Hammerspoon owns every global snap chord. Raycast Window Management remains enabled for searchable commands, with its global hotkey fields unassigned.
- Snapping is intended for floating windows. yabai BSP may retile snapped windows; ⌥T changes the layout deliberately.
- Space numbers reference existing macOS Spaces; no extra Spaces are created by these bindings.
- Search fields still need text entry. The navigation layer supplies arrows, Tab, Return, browser and editing controls without remapping the alphabet.
- Third-party applications can have their own shortcuts. This setup supplies left-hand alternatives for the actions in this map; it does not rewrite every application's shortcut database.
- Secure Input, unavailable Accessibility permissions, and applications that reject synthetic key events can prevent shortcuts from working.
