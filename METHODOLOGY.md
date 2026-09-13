# Keyboard mode setup

This setup offers two modes across skhd and Hammerspoon while retaining Raycast's Caps Lock → Hyper remap.

See **[CHEATSHEET.md](CHEATSHEET.md)** for the complete map and **[RAYCAST_SETUP.md](RAYCAST_SETUP.md)** for the Raycast ownership boundary.

## Architecture

- **Raycast:** Caps Lock → Hyper and searchable commands. Its Window Management commands have no global hotkeys.
- **skhd:** low-latency window focus, move, resize, Space and display commands; one selected profile at a time.
- **yabai:** executes window, Space, and display operations. Helpers resolve `$HOME/.local/src/yabai-macos27` first, then `$HOME/dev/yabai-macos27`.
- **Hammerspoon:** mode switch and indicator; apps, hints, grid, scrolling, media, snapshots, window-follow; direct two-hand snapping; snapping and navigation layers; a Hyper-held HUD and reference generated from the active shortcut registry.
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
| `~/.config/skhd/cycle-window-display.sh` | Queries the display ring and wraps window movement |
| `~/.config/skhd/win-dir.sh` | Focus / float move / BSP swap / resize helper |
| `~/.config/skhd/yabai-run.sh` | Resolves the yabai binary and layout scripts |

Use the mode switch rather than editing the generated active `skhdrc`: edit the corresponding profile when changing shortcuts. Keep both profiles' actions in sync, then update the cheat sheet.

## Switching and recovery

**Hyper+Tab** switches mode; the menu bar shows **2H** or **LH**. Hold Hyper for **/** to open the executable Action Hub, then press the plain key displayed by its layer or select an entry with arrows/Tab and run it with Return; releasing Hyper closes every Hammerspoon HUD. **Hyper+backtick** displays the complete active map, with arrows, Tab, **Hyper+[**, and **Hyper+]** paging it. Both surfaces are rendered from the same active registry as the bindings. **Hyper+Escape** reloads the configuration. Two-hand mode also binds **Hyper+0** to reload. A missing mode file is treated as **LH**, matching the installer.

Direct Hammerspoon shortcuts are generated from the same registry. Explicit
app, system, launcher, HUD, and 2H snap bindings are registered first. A layer
action is then promoted automatically only when its key occurs once across the
active mode and no explicit direct action owns it. The complete direct map is
maintained in [CHEATSHEET.md](CHEATSHEET.md).

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

Shortcut and renderer callbacks are guarded at the shared dispatch boundary.
An individual failure is logged, counted in `debugStatus()`, and shown as a
short alert without escaping through the global hotkey or eventtap callback.
HUD rendering uses a simplified fallback element set; if both attempts fail,
the empty canvas is hidden and the failure is exposed through `renderErrors`.

- Hammerspoon owns every global snap chord and window-follow. The installer removes the exact legacy unconditional `AppWatcher`/`CloseWatcher` and Hyper+End block from `~/.hammerspoon/init.lua`, preserving unrelated automation; `keyboard.lua` also stops those legacy globals defensively during an upgrade.
- Window-follow is intent-gated: it pulls only once after an app toggle, a running-app switcher selection, macOS **Command+Tab**, or a selected **Hyper+E** hint. Ordinary activation from the Dock, a file, a notification, or another app never authorizes a pull.
- Raycast Window Management remains enabled for searchable commands, with its global hotkey fields unassigned.
- Snapping is intended for floating windows. yabai BSP may retile snapped windows; ⌥T changes the layout deliberately.
- Space numbers reference existing macOS Spaces; no extra Spaces are created by these bindings.
- Search fields still need text entry. The navigation layer supplies arrows, Tab, Return, browser and editing controls without remapping the alphabet.
- Third-party applications can have their own shortcuts. This setup supplies left-hand alternatives for the actions in this map; it does not rewrite every application's shortcut database.
- Secure Input, unavailable Accessibility permissions, and applications that reject synthetic key events can prevent shortcuts from working.
