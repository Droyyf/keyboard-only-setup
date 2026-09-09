# Two-hand and left-hand shortcuts

**Hyper = hold Caps Lock** (Raycast supplies ⌘⌥⌃⇧).

- **Caps Lock + Tab:** switch between **2H** (two hands) and **LH** (left hand).
- **Caps Lock + `:** show the shortcut sheet in either mode. The backtick key is above Tab on a US keyboard.
- **2H / LH in the menu bar:** see the current mode or select one with the mouse.
- **Caps Lock + Escape:** reload the configuration.

Normal letters keep typing normally. The extra left-hand controls below become active only after you deliberately open their layer. Release Caps Lock before pressing a layer selection. Escape cancels; layers also time out after inactivity.

## Everyday actions

| Action | Two hands | Left hand |
|---|---|---|
| Arc / ChatGPT / Finder / kitty | Hyper+A / C / F / T | Same |
| Running-app switcher | Hyper+R | Same; Ctrl+W/S selects, Ctrl+E opens |
| Raycast | Hyper+Space | Same |
| Clipboard history | Hyper+V | Same |
| Menu search | Hyper+M | Hyper+5 |
| Window hints | Hyper+E | Same; hint letters use the left side |
| Next window of current app | Hyper+N | Hyper+4 |
| Mouse grid | Hyper+G | Same; controls below |
| Save / restore window layout | Hyper+S / D | Same |
| Dark mode | Hyper+B | Same |
| kitty at Finder folder when closed; focus kitty when open | Hyper+W | Same |
| Shortcat | ⌘⇧Space | Same |
| Cheat sheet | Hyper+/ or Hyper+` | Hyper+` |
| Reload | Hyper+0 or Hyper+Escape | Hyper+Escape |

The application shortcuts work as toggles in both modes: launch the application
when closed, restore and focus its existing window when it is in the background,
and minimize its window when it is already focused. They never request another
window for a running application. Hyper+W follows the same rule for kitty; the
Finder folder is used only when kitty needs to be launched.

## Windows and Spaces

| Action | Two hands | Left hand |
|---|---|---|
| Focus left / down / up / right | ⌥H / J / K / L | ⌥A / S / W / D |
| Move or swap in those directions | Add Shift | Add Shift |
| Resize in those directions | Fn+H / J / K / L | Fn+A / S / W / D |
| Next window | ⌥Tab | ⌥Q |
| Fullscreen zoom | ⌥F | ⌥E |
| Toggle window floating | ⌥S | ⌥R |
| Next / previous Space | ⌥Z / V | ⌥Z / X |
| Go to Space | ⌥1–9 | ⌥1–5; use Space layer for all nine |
| Send window to Space and follow | ⌥⇧1–9 | ⌥⇧1–5; use Space layer for all nine |
| Window to previous / next display | ⌥← / → | ⌥⇧G / ⌥G |
| Space to other display | ⌥X | ⌥F |
| Toggle float / BSP layout | ⌥T | Same |

Spaces are existing macOS Space indexes; these shortcuts do not create missing Spaces.

## Left-hand snapping and Space layer

Press **Hyper+X**, release, then choose. The guide is a centered, Escape-dismissible
reference card that explains the active layer before it captures any plain keys.

| Key | Action |
|---|---|
| A / S / W / D | Left / bottom / top / right half |
| Q / E | Top-left / top-right quarter |
| Z / C | Bottom-left / bottom-right quarter |
| F / R | Maximize / center |
| T | Open Space selections below |
| B | Toggle the existing window-follow behavior |
| V / G | Hide app / minimize window |
| 1 | Mission Control |
| 2 | Toggle hidden files in Finder |
| Escape | Cancel |

After **Hyper+X, T**, select a Space:

| Key | 1 | 2 | 3 | 4 | 5 | Q | W | E | R |
|---|---|---|---|---|---|---|---|---|---|
| Space | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |

Hold **Shift** with that selection to send the focused window there and follow it.

## Two-hand snapping and Space layer

Two-hand mode retains its direct Hyper snap map. It also has the same discoverable
layer: press **Hyper+X**, release, then choose:

| Key | Action |
|---|---|
| H / J / K / L | Left / bottom / top / right half |
| U / I / O / P | Top-left / top-right / bottom-left / bottom-right quarter |
| ; / ' | Maximize / center |
| T | Open Space selections below |
| B / V / G | Toggle window-follow / hide app / minimize window |
| 1 / 2 | Mission Control / toggle hidden Finder files |
| Escape | Cancel |

The Space selection keys and Shift behavior are the same as the left-hand Space layer.

Hammerspoon owns snapping in both modes: two-hand mode uses Hyper+H/J/K/L for halves, U/I/O/P for quarters, semicolon for maximize, and apostrophe for center. Left-hand mode uses the Hyper+X layer above. Raycast Window Management remains available through Raycast search but has no global hotkeys, so it cannot collide with this map. Snapping works best in float layout; BSP can retile a window afterward.

## Left-hand navigation layer

Press **Hyper+3**, release, then use these keys inside apps, choosers, menus, and browser pages:

| Key | Action |
|---|---|
| W / A / S / D | Up / left / down / right arrow |
| Shift + W / A / S / D | Select text in that direction |
| Ctrl + W / A / S / D | Option+arrow navigation (words/paragraphs) |
| Cmd + W / A / S / D | Command+arrow navigation (line/document edges) |
| Add Shift to either of the above | Extend the selection |
| Q / F | Backspace / forward delete |
| E | Return / confirm, then leave the layer |
| R / Shift+R | Tab / Shift+Tab |
| Z / C | Page up / page down |
| B / V | Previous / next browser tab |
| T / X | New / close browser tab |
| 1 / 2 | Browser back / forward |
| G | Browser address bar |
| 4 | Find |
| Escape or Hyper+3 | Leave navigation layer |

Exit the navigation layer before normal typing. This provides left-hand **controls and shortcuts**, not a remapped one-hand alphabet. App-specific commands and search text still use the app's normal text input. Vimium's F link hints remain available outside the navigation layer.

## Mouse grid

Open with **Hyper+G**. Move the selected cell, optionally zoom, then click.

| Action | Two hands | Left hand |
|---|---|---|
| Move left / down / up / right | H / J / K / L | A / S / W / D |
| Toggle fine grid | G | G |
| Left click | C | C |
| Double click | D | F |
| Right click | X | X |
| Cancel | Escape | Escape |

## System

| Action | Two hands | Left hand |
|---|---|---|
| Volume up / down | Hyper+↑ / ↓ | Hyper+Q / Z |
| Brightness down / up | Hyper+← / → | Hyper+1 / 2 |
| Scroll left / down / up / right | ⌃⌥← / ↓ / ↑ / → | ⌃⌥A / S / W / D |

Brightness depends on display support. Scrolling supports key repeat.
