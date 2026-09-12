# Two-hand and left-hand shortcuts

**Hyper = hold Caps Lock** (Raycast supplies ⌘⌥⌃⇧).

- **Caps Lock + Tab:** switch between **2H** (two hands) and **LH** (left hand).
- **Caps Lock + /:** open the interactive **Action Hub** in either mode.
- **Caps Lock + `:** show the complete shortcut reference.
- **2H / LH in the menu bar:** see the current mode or select one with the mouse.
- **Caps Lock + Escape:** reload the configuration.

## Hyper-held HUD

Every visual menu — the Action Hub, each layer, the complete reference, and the
mouse grid — is **visible only while Caps Lock is held**. You never release
Caps Lock and never add Shift, Fn, or anything else:

1. Hold **Caps Lock**.
2. Press **/** (or X for snapping, 3 for navigation, ` for the reference).
3. Keep holding Caps Lock and press a displayed shortcut directly, or use the
   arrow keys/Tab to select an entry and Return to run it.
4. Release Caps Lock — the menu closes itself.

While any HUD is open, **/**, **X**, **3**, and **`** immediately switch to
the Action Hub, Snap, Navigation, or complete reference without releasing Caps Lock.

Menus also auto-dismiss after 15 s of inactivity, and any key pressed without
the Hyper modifiers closes them (so a stuck modifier can never trap typing).
The HUD is flat and opaque: AMOLED black in system dark mode and warm creamy
white in system light mode, with the system accent colour used for key labels.

The complete reference is paged so it stays readable on any display. Hold
Caps Lock and use arrows, Tab, **[**, or **]** to change page; its entries are generated from
the active shortcut registry.

Window hints follow the same held-Hyper rule: press **E**, then their hint
letter before releasing Caps Lock. Shortcat is different: it opens Shortcat's
own search surface after the workflow shortcut has been executed.

## Action Hub

Press **Hyper+/**, hold, then choose an area. Every action in this workflow is
available from one of these HUD routes while its direct shortcut remains
available as the faster path. The same six entry keys work in **LH** and
**2H** mode.

| Key | Route | Includes |
|---|---|---|
| A | Apps | App toggles, Raycast, clipboard, hints, mouse grid, Shortcat |
| S | Windows | Focus, move, resize, fullscreen, float, displays, layouts |
| W | Spaces | Focus, or send the focused window |
| D | System | Volume, mute, scrolling, appearance |
| F | Navigation | Arrows, selection, editing, browser tabs |
| R | Utilities | Layout snapshots, kitty folder, window-follow, mode switch, reload |
| ` | Reference | The complete read-only shortcut reference |

## Everyday actions

| Action | Two hands | Left hand |
|---|---|---|
| Arc / ChatGPT / Finder / kitty | Hyper+A / C / F / T | Same |
| Running-app switcher | Hyper+R, then a displayed app key while held | Same |
| Raycast | Hyper+Space | Same |
| Clipboard history | Hyper+V | Same |
| Menu search | Hyper+5 | Same |
| Window hints (pointer display only) | Hyper+E, then its hint letter while held | Same |
| Next window of current app | Hyper+N | Hyper+4 |
| Mouse grid | Hyper+G | Same; controls below |
| Save / restore window layout | Hyper+S / D | Same |
| Dark mode | Hyper+B | Same |
| Volume up / down / mute | Hyper+↑ / ↓ / M | Hyper+Q / Z / M |
| kitty at Finder folder when closed; focus kitty when open | Hyper+W | Same |
| Shortcat (⌘⇧Space) | Inside the Apps layer, Q | Same |
| Interactive Action Hub / complete reference | Hyper+/ / Hyper+` | Same |
| Reload | Hyper+0 or Hyper+Escape | Hyper+Escape |

The application shortcuts work as toggles in both modes: launch the
application when closed, restore and focus its existing window when it is in
the background, and minimize its window when it is already focused. Hyper+W
follows the same rule for kitty; the Finder folder is used only when kitty
needs to be launched.

## Windows layer (S from the hub)

Arrows are plain mode arrows (2H: H/J/K/L, LH: W/A/S/D) and repeat while held.
The layer has three arrow modes, switched with plain keys — the HUD always
shows the active one:

| Key | Action |
|---|---|
| Arrows | Focus neighbouring window (default mode) |
| M | Toggle **move/swap** mode for the arrows |
| E | Toggle **resize** mode for the arrows |
| Q | Next window of current app |
| F / R | Toggle fullscreen / float |
| N | **Move window to next display — one key that loops** back to the first |
| Z / V | Next / previous Space |
| X | Move Space to the other display |
| T | Float ↔ BSP layout |
| B | Snap & system layer |

## Displays — one looping shortcut

There is a single "move window to next display" action everywhere: **N** in
the Windows and Snap layers, ⌥G (LH) or ⌥→ (2H) outside the HUD. It always
advances to the next display in ring order and wraps from the last display
back to the first. There is no separate previous-display shortcut.

## Spaces layer (W from the hub)

| Key | Action |
|---|---|
| 1–5 (Q/W/E/R for 6–9) | Focus that Space |
| S | Toggle **send & follow** — numbers then move the focused window |
| Escape / release Caps Lock | Close |

## System layer (D from the hub)

| Key | Action |
|---|---|
| Q / Z | Volume up / down |
| M | Mute |
| Arrows | Scroll (repeat) — 2H: H/J/K/L, LH: W/A/S/D |
| B | Toggle dark appearance |

There are **no brightness shortcuts**; use the keyboard's brightness keys.
Direct scrolling outside the HUD: ⌃⌥arrows (2H) / ⌃⌥W/A/S/D (LH).

## Navigation layer (Hyper+3)

Plain keys only; arrows repeat while held:

| Key | Action |
|---|---|
| Arrows (2H: H/J/K/L, LH: W/A/S/D) | Caret movement |
| T | Toggle **select** mode — arrows extend the selection |
| Q / F | Backspace / forward delete |
| E | Return / confirm |
| R / Y | Tab / Shift+Tab |
| Z / C | Page up / page down |
| G / 4 | Browser address bar / find |
| B / V | Previous / next browser tab |
| N / 5 | New / close browser tab |
| 1 / 2 | Browser back / forward |

## Snap & system layer (Hyper+X)

LH: A/S/W/D halves, Q/E/Z/C quarters. 2H: H/J/K/L halves, U/I/O/P quarters.
Both modes: F maximize, R center, **N move window to next display (loops)**,
T Spaces, B window-follow, V hide app, G minimize, 1 Mission Control, 2 toggle
hidden Finder files. Two-hand mode also keeps direct Hyper+H/J/K/L/U/I/O/P/;'
snapping.

## Mouse grid (Hyper+G)

A keyboard way to move and click the pointer — useful when reaching for the
mouse is awkward. Hold Caps Lock, press G, then:

| Key | Action |
|---|---|
| Arrows (2H: H/J/K/L, LH: W/A/S/D) | Move the selected cell |
| G | Toggle the fine grid inside the cell |
| C | Left click |
| D / F (2H / LH) | Double click |
| X | Right click |

Release Caps Lock to dismiss. The grid opens on the display the pointer is on.

## Shortcat (Apps layer, Q)

Shortcat is a companion app (installed with the workflow) that overlays the
current window with searchable, clickable UI elements: press Hyper, A, then Q
(sends ⌘⇧Space), release Caps Lock, type a search term or a hint letter, and
Return clicks the element.

## Hammerspoon and yabai split

Hammerspoon owns snapping in both modes: two-hand mode uses Hyper+H/J/K/L for
halves, U/I/O/P for quarters, semicolon for maximize, and apostrophe for
center. Left-hand mode uses the Hyper+X layer. Raycast Window Management
remains available through Raycast search but has no global hotkeys. Snapping
works best in float layout; BSP can retile a window afterward.
