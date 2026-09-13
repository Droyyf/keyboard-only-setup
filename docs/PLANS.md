# Plans

Plan entries follow the format below. Continue plan-ID numbering from the highest existing ID.

```
## Plan: <short title>
**Date:** YYYY-MM-DD
**Status:** pending | in_progress | finished
**ID:** PLAN-NNN

### Goal
### Steps
### Progress notes
- <date>: <what was done / deviations / test results / codex tokens used>
```

--- Codex plan output (gpt-5.6-sol, read-only, 147,875 tokens) ---

## Plan: Re-own native macOS keyboard shortcuts

**Date:** 2026-09-13  
**Status:** pending  
**ID:** PLAN-001

### Goal

Move every shortcut whose complete behavior is supported by Raycast, Loop, or macOS to that native owner; retain Hammerspoon/skhd only for the Hyper-held HUD, one-handed modal behavior, yabai/BSP/advanced-Space behavior, and workflow-specific semantics no available owner can reproduce.

### Approach

- Reserve **Caps Lock → Hyper** exclusively for Hammerspoon’s registry-driven HUD and remaining custom direct actions. Raycast continues to perform the Caps Lock remap, but no Raycast or Loop command receives a four-modifier Hyper chord.
- Use **Raycast** for Root Search, Clipboard History, menu-bar search, system appearance, and global hidden-file toggling. Raycast supports global hotkeys for commands and reports conflicts in its Shortcuts UI. [Raycast hotkeys](https://manual.raycast.com/command-aliases-and-hotkeys), [system commands](https://manual.raycast.com/system-commands).
- Use **Loop** for deterministic floating-window geometry: halves, quarters, maximize, center, edge growth, and next-display movement. Loop supports a multi-key trigger, key-bound actions, screen switching, edge growth, initial-frame restoration, and URL-driven invocation. [Loop action and trigger model](https://github.com/MrKai77/Loop).
- Use **macOS** for application/window cycling, numbered Desktop focus, adjacent-Space navigation, volume/mute keys, Mission Control, Hide, Minimize, and ordinary editing/browser commands. macOS directly supports `Control+Left/Right` for Spaces and `Control+Up` for Mission Control. [Apple Spaces guide](https://support.apple.com/guide/mac-help/work-in-multiple-spaces-mh14112/mac).
- Hammerspoon may remain the **HUD router** for a Raycast, Loop, or macOS action, but must delegate to that owner instead of implementing the action itself. Ownership in the tables means the action engine, not necessarily the HUD surface.
- Do not add shortcuts for Raycast Calculator, Snippets, Quicklinks, or other commands that have no current workflow equivalent. They remain available through Root Search; adding new bindings would expand scope.
- Keep Raycast Window Management hotkeys unassigned. Loop is the chosen native geometry owner; Raycast must not become a second competing window manager.
- Keep both LH and 2H HUDs. Standardize direct Loop geometry on one LH-friendly map because Loop has one global trigger/preset namespace. This consciously reduces the separate direct 2H Vim geometry map, while the 2H HJKL/UIOP map remains available through the HUD.

### Target namespaces

| Owner | Reserved namespace | Purpose |
| :--- | :--- | :--- |
| Hammerspoon | Hyper = `⌘⌥⌃⇧` | HUD entry, HUD leaves, custom workflow semantics |
| Raycast | `⌥Space`; otherwise `⌃⌥⌘` with `V`, `5`, `B`, `.` | Search, clipboard, menu search, appearance, hidden files |
| Loop | Trigger `⌃⌥⌘`; action keys `WASD`, `QEZC`, `F`, `R`, `G`, `1–4` | Floating-window geometry and displays |
| macOS | Existing native chords plus `⌥1`–`⌥9` | Apps, Spaces, media, Mission Control, editing/navigation |
| skhd/yabai | Existing `⌥`, `⌥⇧`, and HUD-dispatched yabai actions not migrated below | BSP-aware and advanced-Space behavior |

### Migration table — direct Hyper bindings

| Current shortcut | Current action | Target owner and concrete binding | Reason |
| :--- | :--- | :--- | :--- |
| Hyper+A | Toggle Arc: launch, focus, or minimize | **KEEP Hammerspoon: Hyper+A** | Raycast can launch/focus an app but does not reproduce the frontmost-window minimize branch or window-follow authorization. |
| Hyper+C | Toggle ChatGPT | **KEEP Hammerspoon: Hyper+C** | Same three-state semantic requirement. |
| Hyper+F | Toggle Finder | **KEEP Hammerspoon: Hyper+F** | Same three-state semantic requirement. |
| Hyper+T | Toggle kitty | **KEEP Hammerspoon: Hyper+T** | Same three-state semantic requirement. |
| Hyper+Space | Open Raycast | **Raycast: Option+Space** | Raycast should own its own launcher; keep this chord outside Hyper so holding Caps Lock cannot trigger it from a HUD. |
| Hyper+R | Running-app switcher | **KEEP Hammerspoon: Hyper+R** | The custom held-Hyper switcher and window-follow authorization are not equivalent to ordinary app launching. `Command+Tab` remains the parallel native path. |
| Hyper+V | Clipboard History | **Raycast: Control+Option+Command+V** | Clipboard History is a built-in Raycast command with native global-hotkey support. |
| Hyper+E | Window hints on pointer display | **KEEP Hammerspoon: Hyper+E** | Raycast, Loop, and macOS do not provide pointer-display-scoped hint selection integrated with window-follow. |
| Hyper+G | Keyboard mouse grid | **KEEP Hammerspoon: Hyper+G** | No available owner provides this grid, fine-mode, and click workflow. |
| Hyper+5 | Search menu-bar commands | **Raycast: Control+Option+Command+5** | Raycast already owns the command; remove the Hammerspoon global wrapper. |
| LH Hyper+4 / 2H Hyper+N | Next window of current app | **macOS: Command+backtick** | This is a native macOS behavior. Remove the mode-specific aliases. |
| LH Hyper+Q / 2H Hyper+Up | Volume up | **macOS: Volume Up/F12 media key** | Native hardware behavior. Use `Fn+F12` only when “Use F1, F2, etc. as standard function keys” is enabled. |
| LH Hyper+Z / 2H Hyper+Down | Volume down | **macOS: Volume Down/F11 media key** | Native hardware behavior; same function-row qualification. |
| Hyper+M | Mute | **macOS: Mute/F10 media key** | Native hardware behavior. |
| Hyper+B | Toggle light/dark appearance | **Raycast: Control+Option+Command+B** | Raycast’s built-in Toggle System Appearance command exactly covers the action. |
| Hyper+S | Save current multi-window layout | **KEEP Hammerspoon: Hyper+S** | Loop’s Initial Frame is per-window, and Raycast’s Save Current Layout opens a persistent-layout editor; neither equals an immediate transient snapshot. |
| Hyper+D | Restore last transient layout | **KEEP Hammerspoon: Hyper+D** | Must remain paired with the exact Hammerspoon snapshot format and failure behavior. |
| Hyper+W | Open kitty at Finder folder or focus kitty | **KEEP Hammerspoon: Hyper+W** | This combines Finder-path inspection, terminal launch arguments, and focus fallback. |
| Hyper+Tab | Switch LH/2H mode | **KEEP Hammerspoon: Hyper+Tab** | Changes the Hammerspoon registry and active skhd profile transactionally. |
| Hyper+Escape | Reload Hammerspoon and skhd | **KEEP Hammerspoon: Hyper+Escape** | Multi-service workflow orchestration. |
| 2H Hyper+0 | Reload Hammerspoon and skhd | **KEEP only if still registry-generated; normalize to Hyper+Escape in both modes** | Prefer one documented reload binding; remove the 2H alias if it is only accidental auto-promotion. |
| Hyper+X | Open Snap & System HUD | **KEEP Hammerspoon: Hyper+X** | Approved held-Hyper HUD entry. |
| Hyper+3 | Open Navigation HUD | **KEEP Hammerspoon: Hyper+3** | Mode-aware modal navigation is outside native-owner scope. |
| Hyper+/ | Open Action Hub | **KEEP Hammerspoon: Hyper+/** | Primary registry-driven executable HUD. |
| Hyper+backtick | Complete shortcut reference | **KEEP Hammerspoon: Hyper+backtick** | Registry-generated reference and Hyper-held lifecycle. |
| Hyper+Y | Shift+Tab auto-promotion | **macOS/application native: Shift+Tab** | Remove automatic Hyper promotion; the native chord already provides the action. |
| LH Hyper+N | New browser tab auto-promotion | **application native: Command+T** | Remove automatic Hyper promotion; the native chord is left-hand reachable. |
| 2H Hyper+H | Left half | **Loop: Control+Option+Command+A** | Use one mode-independent, LH-friendly Loop geometry map. |
| 2H Hyper+J | Bottom half | **Loop: Control+Option+Command+S** | Same Loop map. |
| 2H Hyper+K | Top half | **Loop: Control+Option+Command+W** | Same Loop map. |
| 2H Hyper+L | Right half | **Loop: Control+Option+Command+D** | Same Loop map. |
| 2H Hyper+U | Top-left quarter | **Loop: Control+Option+Command+Q** | Same Loop map. |
| 2H Hyper+I | Top-right quarter | **Loop: Control+Option+Command+E** | Same Loop map. |
| 2H Hyper+O | Bottom-left quarter | **Loop: Control+Option+Command+Z** | Same Loop map. |
| 2H Hyper+P | Bottom-right quarter | **Loop: Control+Option+Command+C** | Same Loop map. |
| 2H Hyper+semicolon | Maximize | **Loop: Control+Option+Command+F** | Loop owns floating-window maximize. |
| 2H Hyper+apostrophe | Center | **Loop: Control+Option+Command+R** | Loop owns floating-window centering. |

Remove registry-wide automatic promotion after the explicit retained direct map is defined. Otherwise deleting a migrated Hyper binding could silently allow the same registry key to be promoted back into Hammerspoon ownership.

### Migration table — direct scrolling

| Current shortcuts | Target | Reason |
| :--- | :--- | :--- |
| LH `Control+Option+W/S/A/D` | **KEEP Hammerspoon unchanged** | Provides continuous vertical and horizontal one-hand scrolling; native Page Up/Down is not equivalent and does not cover horizontal scroll. |
| 2H `Control+Option+Up/Down/Left/Right` | **KEEP Hammerspoon unchanged** | Same continuous scroll behavior. |
| System HUD `WASD` or `HJKL` scrolling | **KEEP Hammerspoon** | The held-Hyper mode-aware scroll layer itself is out of scope for Raycast, Loop, and macOS. |

### Migration table — HUD layer keys

#### Action Hub

| Current HUD path | Target |
| :--- | :--- |
| Hyper+/ → `A` Apps | **KEEP Hammerspoon HUD route** |
| Hyper+/ → `S` Windows | **KEEP Hammerspoon HUD route** |
| Hyper+/ → `W` Spaces | **KEEP Hammerspoon HUD route** |
| Hyper+/ → `D` System | **KEEP Hammerspoon HUD route** |
| Hyper+/ → `F` Navigation | **KEEP Hammerspoon HUD route** |
| Hyper+/ → `R` Utilities | **KEEP Hammerspoon HUD route** |
| Hyper+/ → backtick Reference | **KEEP Hammerspoon HUD route** |

These are discovery, routing, selection, paging, and Hyper-release lifecycle behaviors—not the underlying actions.

#### Apps HUD

| Keys | Actions | Target |
| :--- | :--- | :--- |
| `A/C/F/T` | Arc, ChatGPT, Finder, kitty toggle | **KEEP Hammerspoon** for launch-or-focus-or-minimize semantics. |
| `R` | Running-app switcher | **KEEP Hammerspoon** for the custom switcher and window-follow intent. |
| `Space` | Raycast | **Raycast**; HUD invokes Raycast’s official command/deeplink, while direct access is `Option+Space`. |
| `V` | Clipboard History | **Raycast**; HUD invokes the command deeplink copied from Raycast’s Action Panel; direct binding is `⌃⌥⌘V`. |
| `5` | Menu-bar search | **Raycast**; same delegation model; direct binding is `⌃⌥⌘5`. |
| LH `4` / 2H `N` | Next window of current app | **macOS**; HUD emits `Command+backtick`, direct use is the same native chord. |
| `E` | Window hints | **KEEP Hammerspoon**. |
| `G` | Mouse grid | **KEEP Hammerspoon**. |
| `Q` | Shortcat | **KEEP Hammerspoon** as HUD glue because no selected native owner supplies semantic UI-element search. |

#### Windows HUD

| Keys | Actions | Target |
| :--- | :--- | :--- |
| LH `W/A/S/D`; 2H `K/H/J/L` | Focus, stateful move/swap, or resize | **KEEP Hammerspoon + skhd/yabai**; the same key changes behavior with HUD `M/E` state and current yabai float/BSP state. |
| `M/E` | Toggle HUD move/resize mode | **KEEP Hammerspoon**. |
| `Q` | Next current-app window | **macOS: Command+backtick** through the HUD. |
| `F` | Maximize/zoom | **Loop: Maximize**, invoked through Loop’s action URL; direct binding `⌃⌥⌘F`. |
| `R` | Toggle yabai float | **KEEP skhd/yabai**. |
| LH `4` / 2H `N` | Move window to next display | **Loop: Next Screen**, invoked through `loop://screen/next`; direct binding `⌃⌥⌘G`. |
| `Z/V` | Next/previous Space | **macOS: Control+Right / Control+Left** through the HUD. |
| `C` | Move current Space to another display | **KEEP skhd/yabai**; neither Loop nor macOS exposes equivalent keyboard automation. |
| `T` | Toggle float/BSP layout | **KEEP skhd/yabai**. |
| `B` | Enter Snap & System HUD | **KEEP Hammerspoon**. |

#### Spaces HUD

| Keys | Actions | Target |
| :--- | :--- | :--- |
| `1/2/3/4/5/Q/W/E/R` in focus mode | Focus Spaces 1–9 | **macOS**; HUD invokes the configured `Option+1` through `Option+9` Desktop shortcuts. |
| `S` | Toggle focus vs. send-and-follow state | **KEEP Hammerspoon**. |
| `1/2/3/4/5/Q/W/E/R` in send mode | Send window to Space 1–9 and follow | **KEEP Hammerspoon + yabai**; macOS and Loop do not supply the combined numbered move-and-follow transaction. |

#### System HUD

| Keys | Actions | Target |
| :--- | :--- | :--- |
| `Q/Z/M` | Volume up/down/mute | **macOS media actions**; Hammerspoon retains only the HUD route. |
| LH `W/A/S/D`; 2H `K/H/J/L` | Continuous scrolling | **KEEP Hammerspoon**. |
| `B` | Toggle system appearance | **Raycast Toggle System Appearance**; invoke the deeplink copied from the installed command; direct binding `⌃⌥⌘B`. |

#### Navigation HUD

| Keys | Actions | Target |
| :--- | :--- | :--- |
| LH `W/A/S/D`; 2H `K/H/J/L` | Arrow movement, optionally selecting | **KEEP Hammerspoon** because the one-hand modal remap and selection state are the feature, even though macOS receives ordinary arrow events. |
| `T` | Toggle selection mode | **KEEP Hammerspoon**. |
| `Q/F/E/R/Y/Z/C` | Backspace, forward delete, Return, Tab, Shift+Tab, Page Up, Page Down | **KEEP Hammerspoon HUD aliases**; direct native forms remain available. |
| `G/4/B/V/N/5/1/2` | Address bar, Find, previous/next/new/close tab, browser back/forward | **KEEP Hammerspoon HUD aliases**; mode-local one-hand access is outside app-native shortcut ownership. |

#### Utilities HUD

| Keys | Actions | Target |
| :--- | :--- | :--- |
| `S/D` | Save/restore transient window layout | **KEEP Hammerspoon**. |
| `W` | kitty at Finder folder/focus | **KEEP Hammerspoon**. |
| `B` | Toggle window-follow | **KEEP Hammerspoon**. |
| `Tab` | Switch LH/2H | **KEEP Hammerspoon + mode helper**. |
| `R` | Reload Hammerspoon/skhd | **KEEP Hammerspoon**. |
| backtick | Complete reference | **KEEP Hammerspoon**. |

#### Snap & System HUD

| Keys | Actions | Target |
| :--- | :--- | :--- |
| LH `A/S/W/D/Q/E/Z/C` | Halves and quarters | **Loop** through its direction/action URLs; matching direct Loop map uses `⌃⌥⌘` plus the same LH keys. |
| 2H `H/J/K/L/U/I/O/P` | Halves and quarters | **Loop** through the HUD. The direct 2H aliases are consciously reduced to the universal LH Loop map. |
| 2H `;/'`; both `F/R` | Maximize and center | **Loop**, direct `⌃⌥⌘F/R`. |
| LH `4` / 2H `N` | Next display | **Loop**, direct `⌃⌥⌘G`. |
| `T` | Enter Spaces HUD | **KEEP Hammerspoon route**. |
| `B` | Window-follow | **KEEP Hammerspoon**. |
| `V` | Hide current app | **macOS: Command+H** through the HUD. |
| `G` | Minimize focused window | **macOS: Command+M** through the HUD. |
| `1` | Mission Control | **macOS: Control+Up** through the HUD. |
| `2` | Toggle Finder hidden files globally | **Raycast Toggle Hidden Files**, direct `⌃⌥⌘.`; this removes the current launch-Finder/delayed-keystroke implementation. |

#### Mouse grid and Shortcat

| Keys/path | Target |
| :--- | :--- |
| Mouse grid LH `W/A/S/D`, 2H `K/H/J/L`, `G`, `C`, LH `F` / 2H `D`, `X` | **KEEP Hammerspoon**; no available owner provides the grid, fine mode, pointer movement, and click variants. |
| Hyper+/ → `A` → `Q` Shortcat | **KEEP Hammerspoon HUD route**; Shortcat remains the action endpoint. |

### Migration table — skhd Option/Fn bindings

| Current bindings | Target owner and concrete binding | Decision |
| :--- | :--- | :--- |
| LH `Option+W/A/S/D`; 2H `Option+K/H/J/L` | **KEEP skhd/yabai unchanged** | Directional focus across windows is not confirmed as a stable Loop action and must work in both float and BSP layouts. |
| LH `Option+Q`; 2H `Option+Tab` | **KEEP skhd/yabai unchanged** | Cycles yabai’s window ordering across the current Space; `Command+backtick` is current-app-only and is not equivalent. |
| LH `Option+Shift+W/A/S/D`; 2H `Option+Shift+K/H/J/L` | **KEEP skhd/yabai unchanged** | Moves a floating window but swaps a tiled window; Loop cannot reproduce the state-dependent BSP branch. |
| LH `Fn+A/S/W/D`; 2H `Fn+H/J/K/L` | **Loop: `⌃⌥⌘1/2/3/4` = Grow Left/Bottom/Top/Right** | Move direct edge-growth to Loop using one mode-independent map. The Windows HUD retains its modal resize path. |
| LH `Option+1`–`Option+5`; 2H `Option+1`–`Option+9` | **macOS: configure Switch to Desktop 1–9 as `Option+1`–`Option+9`** | Same final chords, native owner. Both modes may use all nine after migration. |
| LH/2H `Option+Shift+1`–`Option+Shift+9` where present | **KEEP skhd/yabai unchanged** | Numbered send-and-follow is outside native ownership. |
| LH `Option+Z` next / `Option+X` previous; 2H `Option+Z` next / `Option+V` previous | **macOS: Control+Right / Control+Left** | Standardize Space cycling on native, mode-independent chords. |
| LH `Option+E`; 2H `Option+F` | **Loop: Maximize on `⌃⌥⌘F`** | Current yabai zoom-fullscreen is geometrically closer to Loop Maximize than to macOS full-screen Space creation. |
| LH `Option+R`; 2H `Option+S` | **KEEP skhd/yabai unchanged** | Toggling participation in yabai tiling is outside Loop/macOS/Raycast. |
| LH `Option+F`; 2H `Option+X` | **KEEP skhd/yabai unchanged** | Moves the entire current Space to the other display; Loop moves windows, not Spaces. |
| LH `Option+G`; 2H `Option+Right` | **Loop: Next Screen on `⌃⌥⌘G`** | Exact native Loop scope; remove `cycle-window-display.sh` after HUD and direct callers migrate. |
| LH/2H `Option+T` | **KEEP one skhd/yabai declaration** | Global float/BSP layout switching remains custom. |
| LH first `Option+X` declaration | **macOS: Control+Left** | This attempted to mean previous Space but is currently shadowed by a later `Option+X` declaration. |
| LH later `Option+X` declaration | **Remove redundant alias; KEEP Space transfer on LH `Option+F`** | Prevent one chord from carrying two actions and retain the left-hand Space-transfer path. |
| Duplicate LH `Option+T` declaration | **Remove duplicate; KEEP one `Option+T` binding** | Same-owner duplication is invalid even though the present audit overlooks it. |

### What must stay in Hammerspoon/skhd

- Registry-driven Action Hub, layer HUDs, complete reference, selection/paging, and close-on-Hyper-release eventtap behavior.
- Caps Lock Hyper handling and the guard that prevents direct Hammerspoon callbacks from firing while a HUD owns input.
- LH/2H mode switching and transactional activation of the matching skhd profile.
- Window hints restricted to the pointer display.
- Keyboard mouse grid, fine grid, and click actions.
- App launch-or-focus-or-minimize behavior for Arc, ChatGPT, Finder, and kitty.
- Custom running-app switcher.
- Intent-gated window-follow for app toggles, switcher selection, `Command+Tab`, and selected window hints.
- Transient multi-window layout save/restore.
- “kitty at Finder folder” path discovery and launch/focus fallback.
- Navigation HUD, selection mode, scrolling HUD, and direct continuous scrolling.
- Window HUD focus/move/resize mode state.
- yabai directional focus and BSP-aware move-or-swap.
- yabai float toggle and float/BSP global layout toggle.
- Numbered send-window-to-Space-and-follow.
- Moving an entire Space to another display.
- Shortcat HUD invocation and configuration reload orchestration.

Loop’s Initial Frame/Undo must not replace Hammerspoon’s multi-window snapshot, and Raycast app hotkeys must not replace app toggles unless the user explicitly accepts losing minimize and window-follow semantics.

### Window-management split

- **Loop owns:** floating-window halves, quarters, maximize, center, edge growth from direct shortcuts, and focused-window movement to the next display.
- **yabai owns:** BSP layout, float state, directional window focus, BSP swap, HUD state-aware movement/resizing, numbered send-and-follow, current-Space display movement, and Space/layout state.
- **Raycast Window Management owns nothing:** leave all its window-management global hotkeys unassigned.
- **macOS owns:** Desktop focus/cycling and Mission Control.
- Loop geometry is authoritative only while the affected window is floating. In BSP mode, use the retained skhd focus/swap/resize paths; do not use Loop geometry to fight yabai’s tiler.
- Do not make Caps Lock Loop’s trigger. Loop’s trigger is `Control+Option+Command`; Raycast remains the sole Caps-Lock-to-Hyper remapper.

### Conflict and collision strategy

- Extend `audit_shortcuts.py` from three implicit owners to explicit **Hammerspoon, skhd/yabai, Raycast, Loop, and macOS** records.
- Give every binding a scope: `always`, `left`, `dual`, or `hud`. Identical chords in mutually exclusive LH/2H profiles are allowed; duplicates within one profile are failures.
- Fail on:

  - The same chord assigned to different owners in overlapping scopes.
  - The same chord assigned to different actions within one owner/profile.
  - Any Raycast or Loop chord using the full Hyper modifier set.
  - Shift-only typing-hostile global shortcuts.
  - Any Loop chord also present in Raycast Window Management.
  - Missing action names, owners, scopes, or manual-verification dates in owner manifests.
  - A migrated action appearing again in `bindDirect()` or automatic direct promotion.

- Keep exact-modifier matching: `⌃⌥⌘` external bindings are distinct from Caps-generated `⌃⌥⌘⇧`.
- Do not whitelist cross-owner collisions on the assumption that Hammerspoon’s eventtap will swallow them. The static map must remain collision-free even if eventtap ordering changes.
- Continue treating private Raycast/Loop settings as UI-owned. The repository stores only a sanitized declared assignment map and verification date, not app databases or private configuration.
- Update `raycast-live-shortcuts.json` with the five declared Raycast bindings.
- Add `loop-live-shortcuts.json` and `macos-live-shortcuts.json` with the concrete maps above.
- Correct the LH `Option+X` and duplicated `Option+T` errors before relying on the new audit as a clean baseline.

### Steps

#### 1. Freeze the current behavior and acceptance contract

**Files:**

- `managed/hammerspoon/keyboard.lua`
- `managed/skhd/skhdrc-left`
- `managed/skhd/skhdrc-dual`
- `tests/test_keyboard.lua`
- `tests/test_profile_contract.py`

**Work:**

- Record the current direct, HUD, scroll, and skhd maps as test fixtures.
- Add a profile-level duplicate-chord test that fails on both LH `Option+X` meanings and the duplicated LH `Option+T`.
- Add tests distinguishing current-app cycling from yabai window cycling and multi-window snapshot restore from Loop Initial Frame.
- Establish the success invariant: every old action is either reachable from its target owner or intentionally retained, and every active chord has one owner.

**Verify:** focused Python profile tests and mocked Lua baseline pass except for the deliberately exposed duplicate-profile test.

#### 2. Stage native owners before removing custom bindings

**Files:**

- `raycast-live-shortcuts.json`
- New `loop-live-shortcuts.json`
- New `macos-live-shortcuts.json`
- `CHEATSHEET.md`

**Work:**

- In Raycast, configure `⌥Space`, `⌃⌥⌘V`, `⌃⌥⌘5`, `⌃⌥⌘B`, and `⌃⌥⌘.`.
- Copy and test the official command deeplinks for Clipboard History, menu-bar search, Toggle System Appearance, and Toggle Hidden Files from each command’s Action Panel. Raycast documents Copy Deeplink as a native action. [Raycast Action Panel](https://manual.raycast.com/action-panel).
- In Loop, configure trigger `⌃⌥⌘` and the universal map:

  - `W/A/S/D`: top/left/bottom/right half.
  - `Q/E/Z/C`: top-left/top-right/bottom-left/bottom-right quarter.
  - `F`: maximize.
  - `R`: center.
  - `G`: next screen.
  - `1/2/3/4`: grow left/bottom/top/right.

- Leave Loop’s Caps Lock trigger disabled and leave Raycast Window Management hotkeys unassigned.
- In System Settings, first stage Desktop 1–9 on temporary noncolliding chords such as `Control+Shift+1`–`Control+Shift+9`; do not assign final `Option+1`–`Option+9` while skhd still owns them.
- Verify all staged commands manually while old custom shortcuts remain functional.
- Populate manifests only with bindings that were actually observed working, including the installed app/version where visible and `verified_at`.

**Verify:** old custom path and new native path both work; no old path has been removed.

#### 3. Expand the ownership audit

**Files:**

- `audit_shortcuts.py`
- `raycast-live-shortcuts.json`
- `loop-live-shortcuts.json`
- `macos-live-shortcuts.json`
- `tests/test_shortcut_audit.py`
- `tests/test_profile_contract.py`

**Work:**

- Generalize external-owner parsing without reading private application state.
- Model mode scopes and reject same-owner/profile duplicates.
- Preserve the existing Raycast typing-hostility rule.
- Add collision fixtures for Hammerspoon↔Raycast, Hammerspoon↔Loop, skhd↔macOS, Raycast↔Loop, and same-profile skhd duplicates.
- Add an explicit rule reserving full Hyper chords for Hammerspoon.
- Make the expected manifests the source for audit claims; label them “declared/manual,” not automatically live.
- Ensure equivalent LH/2H bindings in mutually exclusive profiles do not produce false positives.

**Verify:** `python3 -m unittest tests.test_shortcut_audit tests.test_profile_contract -v` and `python3 audit_shortcuts.py`.

#### 4. Transfer direct and HUD action engines

**Files:**

- `managed/hammerspoon/keyboard.lua`
- `tests/test_keyboard.lua`

**Work:**

- Remove migrated global Hyper bindings.
- Replace blanket “unique registry key becomes direct Hyper binding” promotion with an explicit allowlist of retained custom direct actions.
- Keep the registry-driven HUD and eventtap unchanged in lifecycle.
- Change HUD leaves to delegate:

  - Raycast actions through their verified deeplinks.
  - Loop placement through verified `loop://` action URLs.
  - Desktop focus and adjacent-Space movement through configured macOS shortcuts.
  - Media, Hide, Minimize, and Mission Control through native macOS actions.

- Remove Hammerspoon geometry helpers and constants only after no direct or HUD caller remains.
- Retain window-target capture around Snap HUD entry so the selected Loop action is applied to the window captured when the layer opened; verify Loop’s URL action respects that focus timing. If Loop necessarily acts on the then-current focused window, keep the HUD open without stealing focus.
- Preserve all custom behaviors listed in “What must stay.”

**Verify:** mocked Lua tests prove both modes load, every HUD route executes, migrated global Hyper bindings are absent, retained actions remain present, Hyper release closes all HUDs, and one HUD selection causes exactly one delegated action.

#### 5. Prune skhd and retired helpers

**Files:**

- `managed/skhd/skhdrc-left`
- `managed/skhd/skhdrc-dual`
- `managed/skhd/win-dir.sh`
- Remove `managed/skhd/cycle-window-display.sh`
- `tests/test_profile_contract.py`
- `tests/test_window_helper.py`
- Remove `tests/test_cycle_display.py`

**Work:**

- Remove direct Fn resize, numbered Space-focus, Space-cycle, zoom-fullscreen, and focused-window display bindings.
- Retain directional focus, yabai window cycle, BSP-aware move/swap, send-and-follow, float toggle, Space-display movement, and layout toggle.
- Remove the shadowed LH previous-Space `Option+X`, redundant LH Space-display `Option+X`, and duplicate LH `Option+T`; retain LH Space-display on `Option+F`.
- Keep `win-dir.sh resize` because the Windows HUD still uses stateful resize mode.
- Delete `cycle-window-display.sh` only after Hammerspoon and both skhd profiles no longer reference it.
- Replace baseline-equality tests with explicit retained/migrated ownership contracts; the old baseline must not force retired bindings back.

**Verify:** profile tests show no duplicate chord, no migrated direct action, complete LH key reachability for retained shortcuts, and parity of retained semantics across both modes.

#### 6. Update installer, verifier, and rollback metadata

**Files:**

- `scripts/workflow_install.py`
- `verify.sh`
- `tests/test_installer.py`
- `tests/test_repository_contract.py`
- `docs/superpowers/specs/2026-09-09-reproducible-macos-keyboard-workflow-design.md`
- `README.md`
- `METHODOLOGY.md`

**Work:**

- Add Loop to the Homebrew dependency command without introducing a new paid dependency.
- Remove `cycle-window-display.sh` from managed/executable destinations.
- Treat the previously installed helper as a retired managed file: back it up before removal and restore it during uninstall when the selected backup says it previously existed.
- Preserve backup-first atomic installation and unrelated `init.lua` content.
- Replace “leave all Raycast window-management shortcuts unassigned” with the narrower rule: Raycast Window Management remains unassigned, while the named Raycast System/Search commands receive the manifest bindings.
- Print the precise Raycast, Loop, and System Settings manual checklist after installation.
- Make verification check:

  - Required application bundles are installed.
  - Managed custom files match the repository.
  - Retired helper is no longer referenced.
  - All owner manifests parse and pass the audit.
  - Active mode/profile matches.
  - GUI-owned hotkeys remain explicitly reported as **manual verification required**, never “verified live.”

- Update the design spec’s managed destinations, dependency list, ownership model, manual actions, non-goals, and rollback contract.

**Verify:** installer unit tests cover fresh install, upgrade with the retired helper, restoration from backup, dry-run dependencies, copy failure, and honest manual-verification output.

#### 7. Switch the final macOS Desktop bindings without a dead zone

**Files:** no repository file beyond updating the already prepared manual-verification date.

**Work:**

- Install the migrated repository state and reload Hammerspoon/skhd.
- Confirm the retained send-and-follow bindings still operate.
- Replace temporary `Control+Shift+1`–`Control+Shift+9` System Settings bindings with final `Option+1`–`Option+9`.
- Test every numbered Desktop before clearing the temporary chords.
- Confirm `Control+Left/Right` Space cycling and `Control+Up` Mission Control.
- Update the macOS manifest date only after all final chords work.

**Verify:** there is never a point where numbered Desktop focus has neither an old skhd chord nor a working native chord.

#### 8. Rewrite the user-facing map

**Files:**

- `CHEATSHEET.md`
- `README.md`
- `METHODOLOGY.md`

**Work:**

- Make `CHEATSHEET.md` owner-first:

  - Native macOS shortcuts.
  - Raycast shortcuts.
  - Universal Loop geometry.
  - Retained direct Hyper shortcuts.
  - Retained LH/2H skhd shortcuts.
  - HUD routes with each leaf’s actual action owner.
  - Explicit “Loop in float mode; yabai controls BSP” warning.
  - Manual owner-verification date.

- Mark the 2H direct geometry reduction clearly: Vim-style geometry stays in the HUD; direct Loop geometry uses the common LH-friendly map.
- Remove all retired chords and eliminate the current misleading LH `Option+X` previous-Space entry.
- Keep direct-chord and executable-HUD parity for retained custom operations.

**Verify:** documentation tables are compared programmatically against the retained Hammerspoon registry, skhd profiles, and external-owner manifests.

### Migration ordering and no-dead-zone rule

1. Back up/export Raycast settings and record Loop/System Settings assignments.
2. Run the current `./verify.sh`; do not migrate from a failing baseline.
3. Configure new Raycast and Loop bindings on their non-Hyper chords.
4. Configure temporary native Desktop chords.
5. Manually prove every new native action while every old custom shortcut still works.
6. Add owner manifests and make the expanded audit pass.
7. Remove migrated Hammerspoon/skhd ownership and install the new managed files.
8. Reload and verify retained custom behavior.
9. Change macOS Desktop bindings from temporary chords to final `Option+1`–`Option+9`.
10. Run all automated and manual verification.
11. Remove retired helper files only after all callers and bindings are gone.
12. Rewrite the cheat sheet from the verified final maps.

A migrated custom binding must not be removed merely because the target app advertises the capability; it is removed only after the exact command fires on this machine with the proposed chord.

### Rollback

- Use the installer’s timestamped backup as the authoritative custom-layer rollback.
- Restore Hammerspoon/skhd first, reload both services, and prove the former shortcut works before clearing its Raycast, Loop, or macOS replacement.
- Restore the retired `cycle-window-display.sh` from the backup manifest if rolling back to a version that references it.
- Restore the previous Raycast export, or manually clear only the five newly assigned bindings.
- Clear Loop’s `⌃⌥⌘` bindings and restore its previous trigger; never change the Raycast Caps Lock Hyper setting during rollback.
- Restore prior Mission Control/Desktop shortcuts in System Settings.
- Run the old-version `./verify.sh`, compare installed managed files with that checkout, then manually test Caps Hyper, both hand modes, Space focus/send, BSP swap, window-follow, and display movement.
- Do not delete any backup until the restored workflow has survived a Hammerspoon reload, skhd reload, mode switch, and login/restart check.

### Verification

#### Automated

- `python3 -m unittest discover -s tests -p 'test_*.py' -v`
- `hs -c 'dofile("<repository>/tests/test_keyboard.lua")'`
- `python3 audit_shortcuts.py`
- `python3 audit_shortcuts.py --live`
- `./verify.sh`
- `git diff --check`
- Search all managed files, tests, and documentation for:

  - Retired Hyper bindings.
  - Removed skhd chords.
  - `cycle-window-display.sh`.
  - Duplicate LH `Option+X` or `Option+T`.
  - Any Raycast/Loop full-Hyper chord.
  - Any Raycast Window Management assignment.

`--live` may verify installed Hammerspoon/skhd files, but Raycast, Loop, and System Settings assignments remain manifest-backed manual claims unless a supported public API becomes available.

#### `tests/test_keyboard.lua`

- Load and render every registry layer in LH and 2H modes.
- Assert retained custom direct bindings exist.
- Assert migrated Hyper bindings do not exist.
- Assert external-owned registry keys are never automatically promoted.
- Assert Raycast, Loop, and macOS HUD adapters dispatch exactly once.
- Assert Caps Lock hold/release and HUD switching remain unchanged.
- Assert 2H HJKL/UIOP HUD geometry still reaches Loop.
- Assert app toggles retain launch/focus/minimize behavior.
- Assert window-follow remains limited to approved selection intents.
- Assert save/restore layout remains multi-window and independent of Loop.
- Assert Window HUD focus/move/resize state still selects the correct yabai helper operation.

#### Manual — Raycast

- Confirm Caps Lock Hyper remains enabled and still emits `Command+Option+Control+Shift`.
- Confirm Raycast launcher on `Option+Space`.
- Confirm Clipboard History on `Control+Option+Command+V`.
- Confirm menu-bar search on `Control+Option+Command+5`.
- Confirm Toggle System Appearance on `Control+Option+Command+B`.
- Confirm Toggle Hidden Files on `Control+Option+Command+.`.
- Filter Settings → Shortcuts by “Hotkey Set” and compare every assignment with `raycast-live-shortcuts.json`.
- Confirm every Raycast Window Management command remains unassigned.
- Hold Caps Lock and traverse every HUD; no Raycast command may fire merely because a HUD key was pressed.

#### Manual — Loop

- Confirm trigger is exactly `Control+Option+Command`, not Caps Lock or Right Control.
- Compare all Loop keybinds with `loop-live-shortcuts.json`.
- Test halves, quarters, maximize, center, all four edge-growth actions, and next-screen wrap.
- Test on every connected display and with representative native, Electron, and browser windows.
- In yabai float mode, confirm Loop geometry persists.
- In yabai BSP mode, confirm retained skhd focus/swap/resize works and document that Loop geometry is not the BSP control path.
- Confirm repeated/cycle behavior is disabled unless explicitly part of the chosen action.
- Confirm Loop does not react to any Hyper-held HUD chord.

#### Manual — System Settings/macOS

- Under Keyboard → Keyboard Shortcuts → Mission Control, confirm Switch to Desktop 1–9 uses `Option+1`–`Option+9`.
- Confirm every required Desktop exists; macOS may not expose numbered entries for Desktops that have not been created.
- Confirm `Control+Left/Right` cycles Spaces and `Control+Up` opens Mission Control.
- Confirm `Command+Tab`, `Command+backtick`, media volume/mute keys, `Command+H`, and `Command+M`.
- Confirm keyboard navigation/Full Keyboard Access remains at the user’s intended setting.
- Test numbered Desktop focus independently on each display configuration.
- These GUI checks are mandatory and cannot be claimed from repository tests.

#### Manual — integrated workflow

- Test all retained direct Hyper shortcuts with no HUD open.
- Open every HUD in LH and 2H modes and execute at least one action from each owner.
- Switch LH→2H→LH and confirm active skhd profile, HUD labels, navigation keys, and retained direct bindings update correctly.
- Test send-and-follow to Spaces 1–9, current-Space display movement, float toggle, BSP toggle, BSP swap, and window-follow.
- Confirm no duplicate action occurs when a HUD delegates to Raycast, Loop, or macOS.
- Log out/in or restart the relevant applications, then repeat Caps Hyper, one Raycast action, one Loop action, one native Desktop action, and one retained skhd action.

### Progress notes

- 2026-09-13: Read the plan format, Hammerspoon registry/eventtap, both skhd profiles, cheat sheet, shortcut audit, declared Raycast map, installer/verifier/tests, and workflow design. Identified the existing LH `Option+X` collision and duplicated `Option+T`.
- 2026-09-13: Confirmed from first-party documentation that Raycast supports global command hotkeys and the required system commands; Loop supports the selected geometry/display actions and a multi-key trigger; macOS supports the selected Spaces, Mission Control, application, media, and editing behaviors.
- 2026-09-13: No files changed and no implementation tests run; this entry is plan text only.

Routing: Sol/High (ownership design and repository integration) → Luna/Medium (first-party owner-capability research) → Sol/High (feasibility review). Verified from turn metadata.


--- Codex plan output for PLAN-002 (gpt-5.6-sol, read-only, 152,495 tokens) ---

## Plan: Native handoff cherry-pick on the existing keyboard backbone

**Date:** 2026-09-13  
**Status:** pending  
**ID:** PLAN-002

### Goal

Keep the Hammerspoon registry, Caps-Lock Hyper-held HUD/eventtap, skhd/yabai profiles, window-follow semantics, and reproducible backup-first installer as the permanent architecture; make only the five approved native handoffs, repair/lock the LH skhd chord contracts, and extend verification without migrating snapping, Spaces, geometry, or app-toggle ownership.

### Scope guard

- Hammerspoon remains the registry, HUD, complete-reference, mode, app-toggle, hint, mouse-grid, layout-snapshot, and window-follow owner.
- skhd/yabai remains the directional focus, float/BSP, move/swap/resize, Space, and display-workflow owner.
- Loop receives no new ownership, bindings, installer work, or configuration.
- Do not add paid applications or daemons.
- Never alter, disable, re-record, or migrate Raycast’s **Caps Lock → Hyper** remap.
- Preserve Hyper+V clipboard history, Hyper+5 menu-bar search, all snapping/geometry bindings, Space bindings, app toggles, scrolling, hints, Shortcat, and every other binding not listed below.
- Repository files remain the single source of truth; Raycast’s private settings/database must not be read or written. GUI-owned state remains explicitly manual.

### Exact binding map

| Existing path | Final path | HUD decision | Delete |
| :--- | :--- | :--- | :--- |
| LH `Hyper+Q` → Hammerspoon volume `+5` | Physical macOS **Volume Up** media key/F12 | **KEEP** System HUD `Q`; emit one native `SOUND_UP` key-down/key-up pair with no Hyper modifiers | Delete LH direct `Hyper+Q` and percentage-based `hs.audiodevice` mutation |
| 2H `Hyper+Up` → Hammerspoon volume `+5` | Physical macOS **Volume Up** media key/F12 | Same System HUD `Q` delegate | Delete 2H direct `Hyper+Up` |
| LH `Hyper+Z` → Hammerspoon volume `-5` | Physical macOS **Volume Down** media key/F11 | **KEEP** System HUD `Z`; emit one native `SOUND_DOWN` key-down/key-up pair | Delete LH direct `Hyper+Z` and direct audio-device mutation |
| 2H `Hyper+Down` → Hammerspoon volume `-5` | Physical macOS **Volume Down** media key/F11 | Same System HUD `Z` delegate | Delete 2H direct `Hyper+Down` |
| Both `Hyper+M` → Hammerspoon mute toggle | Physical macOS **Mute** media key/F10 | **KEEP** System HUD `M`; emit one native `MUTE` key-down/key-up pair | Delete direct `Hyper+M` and `toggleMute()` |
| LH `Hyper+4` / 2H `Hyper+N` → custom Hammerspoon current-app window enumeration | Native `Command+\`` | **KEEP** Apps HUD LH `4` / 2H `N` and Windows HUD `Q`; each emits exactly one `Command+\`` | Delete both direct Hyper bindings and `cycleCurrentAppWindow()` |
| Both `Hyper+B` → AppleScript dark-mode toggle | Raycast **Toggle System Appearance** on `Control+Option+Command+B` | **KEEP** System HUD `B`; invoke the exact deeplink copied from Raycast | Delete direct `Hyper+B`, AppleScript toggle, and its failure alert |
| Snap HUD `2` → focus Finder, wait 0.15 seconds, send `Command+Shift+.` | Raycast **Toggle Hidden Files** on `Control+Option+Command+.` | **KEEP** Snap HUD `2`; invoke the exact copied Raycast deeplink | Delete Finder launch/focus, delayed timer, and synthetic `Command+Shift+.` hack |
| Raycast opened by direct `Hyper+Space` and Apps HUD `Space` | Raycast launcher’s primary chord becomes `Option+Space` | **KEEP** direct `Hyper+Space` as a secondary compatibility delegate and Apps HUD `Space` as the displayed HUD delegate | Delete nothing from the Hyper alias; do not make `Option+Space` a Hammerspoon binding |
| All other Hammerspoon, skhd/yabai, snapping, Space, display, app-toggle, hint, and navigation paths | Unchanged | Unchanged | Nothing |

Native HUD media delegation should use Hammerspoon’s documented system-key event API; it supports `SOUND_UP`, `SOUND_DOWN`, and `MUTE` events. [Hammerspoon `newSystemKeyEvent`](https://www.hammerspoon.org/docs/hs.eventtap.event.html#newSystemKeyEvent)

`Command+\`` is macOS’s documented command for cycling the front application’s windows. [Apple window-switching guide](https://support.apple.com/en-gb/guide/mac-help/mchlb7beb9af/mac)

### Ordered steps

#### 1. Freeze the narrow ownership contract with failing tests

**Files:**

- `tests/test_keyboard.lua`
- `tests/test_profile_contract.py`
- `tests/test_shortcut_audit.py`
- `raycast-live-shortcuts.json`

**Work:**

- Extend the Hammerspoon fake with native system-key events that record the key name, key-down/key-up state, flags, and post count.
- Replace tests expecting direct Hyper volume/mute with assertions that:

  - LH `Hyper+Q/Z` and 2H `Hyper+Up/Down` are absent.
  - `Hyper+M` is absent in both modes.
  - System HUD `Q/Z/M` remains present and posts exactly one native down/up pair for `SOUND_UP`, `SOUND_DOWN`, and `MUTE`.
  - Posted media events carry no inherited Hyper modifiers.

- Add assertions that LH `Hyper+4` and 2H `Hyper+N` are absent, while Apps HUD `4/N` and Windows HUD `Q` each emit exactly one `Command+\``.
- Add assertions that direct `Hyper+B` is absent and System HUD `B` executes the copied Raycast appearance deeplink exactly once.
- Replace the hidden-file hack test with assertions that Snap HUD `2` executes the copied Raycast hidden-files deeplink exactly once, never launches Finder, never schedules the old 0.15-second keystroke, and never emits `Command+Shift+.`.
- Assert `Option+Space` is not registered by Hammerspoon; direct `Hyper+Space` and Apps HUD `Space` both remain functional Raycast delegates.
- Assert migrated direct keys do not appear in `debugStatus().automaticDirectKeys`; preserve the existing automatic-promotion architecture for unrelated unique registry actions.
- Add explicit LH profile assertions for one `Option+X` previous-Space binding, one `Option+F` Space-to-other-display binding, and one `Option+T` layout binding.
- Run focused tests and confirm the new native-handoff assertions fail before implementation.

**Verify:**

```sh
python3 -m unittest tests.test_profile_contract tests.test_shortcut_audit -v
hs -c 'dofile("tests/test_keyboard.lua")'
```

#### 2. Stage and verify Raycast GUI ownership before removing old paths

**Files:**

- `raycast-live-shortcuts.json`
- `managed/hammerspoon/keyboard.lua` only after the deeplinks are copied and exercised

**Work:**

- Record the current Raycast assignments or export Raycast settings for manual rollback.
- Set Raycast launcher to `Option+Space`.
- Assign **Toggle System Appearance** to `Control+Option+Command+B`.
- Assign **Toggle Hidden Files** to `Control+Option+Command+.`.
- From each command’s Raycast Action Panel, use **Copy Deeplink**; do not infer or hand-compose command slugs. Raycast documents global command hotkeys and the Copy Deeplink action. [Raycast hotkeys](https://manual.raycast.com/command-aliases-and-hotkeys), [Raycast deeplinks](https://developers.raycast.com/information/lifecycle/deeplinks)
- Exercise both commands by hotkey and copied deeplink, accepting Raycast’s command confirmation if it appears.
- Update the sanitized manifest to exactly these GUI-owned assignments:

  - `Raycast Launcher` → `alt+space`
  - `Toggle System Appearance` → `ctrl+alt+cmd+b`
  - `Toggle Hidden Files` → `ctrl+alt+cmd+.`

- Update `verified_at` only after all three are observed working.
- Do not add the rejected PLAN-001 clipboard, menu-bar, Loop, macOS Desktop, or geometry migrations to the manifest.
- Do not claim the JSON file proves live GUI state; retain a note that it is a manually verified, privacy-safe declaration.

**Verify:** all three Raycast bindings work while the old Hammerspoon direct paths still exist, avoiding a dead zone.

#### 3. Implement the minimal Hammerspoon delegates

**Files:**

- `managed/hammerspoon/keyboard.lua`
- `tests/test_keyboard.lua`

**Work:**

- Add one small native-media helper that posts a system key-down followed by its matching key-up.
- Repoint System HUD `Q/Z/M` to `SOUND_UP`, `SOUND_DOWN`, and `MUTE`.
- Repoint Apps HUD LH `4` / 2H `N` and Windows HUD `Q` to `Command+\``.
- Repoint System HUD `B` and Snap HUD `2` to the two exact, GUI-verified Raycast deeplinks.
- Retain Raycast launch delegation for direct `Hyper+Space` and Apps HUD `Space`; `Option+Space` remains exclusively Raycast-owned.
- Delete only these direct registrations:

  - LH volume `Hyper+Q/Z`
  - 2H volume `Hyper+Up/Down`
  - mute `Hyper+M`
  - LH next-window `Hyper+4`
  - 2H next-window `Hyper+N`
  - appearance `Hyper+B`

- Delete `changeVolume()`, `toggleMute()`, `cycleCurrentAppWindow()`, and `toggleDarkMode()` after confirming no callers remain.
- Delete only the Snap HUD hidden-file Finder/timer/keystroke body.
- Preserve the registry, HUD layout, HUD switch actions, automatic promotion, complete reference, eventtap lifecycle, direct-action guard, 15-second safety timeout, screen/appearance watchers, and Caps-Lock handling.
- Preserve the intent-gated window-follow code unchanged.
- Update static `HUDKEYS` comments only if the executable HUD key set actually changes; retained aliases mean `Q/Z/M/B/2/4/N` should remain represented.

**Verify:** affected mocked Lua tests pass in LH and 2H; each retained HUD alias dispatches once and no removed direct binding is registered.

#### 4. Repair and permanently guard the skhd defects

**Files:**

- `managed/skhd/skhdrc-left`
- `managed/skhd/skhdrc-dual`
- `managed/skhd/win-dir.sh`
- `tests/test_profile_contract.py`

**Final LH contract:**

| Chord | Final action | Defect resolution |
| :--- | :--- | :--- |
| `Option+X` | Previous Space | Keep exactly one declaration; delete any second `Option+X` that attempts Space-to-other-display |
| `Option+F` | Move current Space to the other display | Keep as the sole LH Space-transfer chord |
| `Option+T` | Toggle float/BSP layout | Keep exactly one declaration; delete an identical duplicate if present |

**Work:**

- Normalize `skhdrc-left` to that exact map.
- The currently inspected checkout already has the target `X/F/T` map, so do not manufacture a no-op rewrite; make the profile tests and audit the durable defect fix, and remove duplicate lines only if the execution baseline or installed managed file still contains them.
- Leave `skhdrc-dual` unchanged: `Option+X` remains its Space-transfer chord and `Option+T` remains layout toggle.
- Leave `win-dir.sh` unchanged; focus, state-aware move/swap, and resize remain skhd/yabai-owned.
- Keep all Space, display, resize, float, BSP, focus, and send-and-follow behavior unchanged.

**Verify:** both profiles have no within-profile duplicate chord, and the LH explicit `Option+X/F/T` contract passes.

#### 5. Extend shortcut auditing to catch same-owner duplicates

**Files:**

- `audit_shortcuts.py`
- `tests/test_shortcut_audit.py`

**Specification:**

- Preserve normalized chord, owner, action, source/profile, and source line for every parsed binding.
- Assign mutually exclusive scopes to `skhdrc-left` and `skhdrc-dual`; the same chord appearing once in each profile is allowed.
- Detect duplicates by normalized `(owner, scope, chord)`, not merely by chord.
- Fail when a chord appears more than once within the same owner and simultaneously active scope:

  - Different commands on one chord fail as a shadowing defect.
  - Repeated identical commands also fail as redundant configuration.

- Emit actionable output containing owner, normalized chord, profile/source, line numbers, and both actions, for example: `same-owner duplicate skhd/yabai alt+x in skhdrc-left: ...`.
- Preserve the current cross-owner-collision and typing-hostile Raycast rules.
- Do not treat Hammerspoon direct bindings and mode-local HUD labels as duplicate registrations; keep their scopes distinct.
- Add tests for:

  - Same skhd profile, same chord, different actions → fail.
  - Same skhd profile, same chord, identical actions → fail.
  - Same chord once in LH and once in 2H → pass.
  - Duplicate Raycast manifest chord in the same global scope → fail.
  - Existing cross-owner collision behavior → unchanged.
  - Current repository map → pass.

**Verify:**

```sh
python3 -m unittest tests.test_shortcut_audit tests.test_profile_contract -v
python3 audit_shortcuts.py
```

#### 6. Harden installation and verification without automating Raycast settings

**Files:**

- `scripts/workflow_install.py`
- `tests/test_installer.py`
- `verify.sh`

**Work:**

- Keep `MANAGED_FILES`, dependencies, daemons, atomic copy behavior, mode activation, and legacy-window-follow migration structurally unchanged.
- Do not install or edit Raycast databases/preferences.
- Extend installer completion output with the three-item Raycast manual checklist and an explicit warning: **Caps Lock → Hyper is pre-existing and must never be touched**.
- Make `verify()` report:

  - Missing managed files.
  - Installed managed-file content differing from its repository source.
  - Invalid/missing selected mode.
  - Active `.config/skhd/skhdrc` differing from the selected managed profile.
  - Missing executable permission on managed helper scripts.

- Treat differences as reproducibility failures with precise paths; verification remains read-only and must not overwrite drift.
- Add `python3 audit_shortcuts.py --live` to `verify.sh` after the repository audit. Its output must distinguish live installed Hammerspoon/skhd inspection from the manifest-backed Raycast declaration.
- Keep Raycast GUI status as **manual verification required**; never turn the sanitized manifest into a false live-state claim.
- Add installer tests for content drift, wrong active profile, helper execute-bit loss, clean verified installation, and presence of the exact post-install GUI checklist.
- Preserve existing tests for backup/restore, personal `init.lua` content, exact legacy-block migration, selected mode, and pinned yabai source.

**Verify:**

```sh
python3 -m unittest tests.test_installer -v
python3 scripts/workflow_install.py verify
./verify.sh
```

#### 7. Update the user-facing reference and add a targeted drift contract

**Files:**

- `CHEATSHEET.md`
- `tests/test_profile_contract.py`
- `tests/test_shortcut_audit.py`
- `raycast-live-shortcuts.json`

**Work:**

- Add a short native/Raycast section containing:

  - macOS Volume Up/Down/Mute media keys.
  - macOS `Command+\`` current-app window cycle.
  - Raycast launcher `Option+Space`.
  - Raycast appearance `Control+Option+Command+B`.
  - Raycast hidden files `Control+Option+Command+.`.

- Remove direct-reference rows for LH `Hyper+Q/Z/4`, 2H `Hyper+Up/Down/N`, `Hyper+M`, and `Hyper+B`.
- Retain `Hyper+Space`, clearly labeled **secondary Raycast delegate; primary is Option+Space**.
- Retain System HUD `Q/Z/M/B`, Apps HUD `4/N`, Windows HUD `Q`, and Snap HUD `2`; label their actual owners as macOS or Raycast.
- Keep every unaffected Hammerspoon, skhd/yabai, snapping, Space, display, navigation, scrolling, app-toggle, hint, and Shortcat entry unchanged.
- Ensure the LH skhd table shows only:

  - `Option+X` previous Space
  - `Option+F` Space to other display
  - one `Option+T` layout toggle

- Add targeted contract assertions for the five final handoffs and retired direct rows; do not build a brittle parser for all prose.
- Compare the three Raycast chords in the cheat sheet with the sanitized assignment manifest.

**Verify:** documentation contains all final paths, contains none of the deleted direct paths, and does not imply Raycast/Loop ownership of any geometry or Space behavior.

### Enhancements

#### MUST — migrated-key direct-ownership regression contract

- **Problem:** Removing a `bindDirect()` line is insufficient protection if registry contents later make that key eligible for automatic promotion.
- **Fix:** Preserve the existing promotion mechanism but test that every migrated key remains absent from direct bindings and `automaticDirectKeys`; keep retained `Hyper+Space` explicitly present.
- **Files:** `managed/hammerspoon/keyboard.lua`, `tests/test_keyboard.lua`.
- **Risk:** Low; test-led and limited to approved handoffs.
- **Why it earns its place:** Prevents the exact deleted Hyper ownership from silently returning without redesigning the registry.

#### MUST — same-owner, same-scope duplicate audit

- **Problem:** The present audit reports only cross-owner collisions, so shadowed or redundant declarations within one skhd profile are invisible.
- **Fix:** Add profile-aware same-owner grouping with path, line, and action diagnostics.
- **Files:** `audit_shortcuts.py`, `tests/test_shortcut_audit.py`, `tests/test_profile_contract.py`.
- **Risk:** Low if LH and 2H are modeled as mutually exclusive scopes.
- **Why it earns its place:** Directly prevents both reported skhd defects and future silent shadowing.

#### MUST — installed-content and active-profile verification

- **Problem:** Current installer verification proves files exist but not that the installed runtime matches the repository or selected profile.
- **Fix:** Compare content and active profile read-only; report drift precisely; audit installed Hammerspoon/skhd files.
- **Files:** `scripts/workflow_install.py`, `verify.sh`, `tests/test_installer.py`.
- **Risk:** Low to moderate because intentional edits to repository-owned installed files will now be reported.
- **Why it earns its place:** Enforces the approved repository-as-single-source-of-truth contract and makes rollback/deployment claims meaningful.

#### SHOULD — centralize only the verified Raycast delegates

- **Problem:** Repeated shell-quoted deeplinks can drift or dispatch inconsistently.
- **Fix:** Keep the exact copied appearance/hidden-files URIs as named constants and use one small invocation helper; do not generalize unrelated app launching.
- **Files:** `managed/hammerspoon/keyboard.lua`, `tests/test_keyboard.lua`.
- **Risk:** Low.
- **Why it earns its place:** Two GUI-owned command boundaries receive one testable dispatch path without creating a new abstraction layer.

#### SHOULD — strengthen existing Hyper-release safety tests

- **Problem:** The implementation already handles partial/lost modifier state and a 15-second safety timeout, but those edge cases are less explicitly protected than the main release path.
- **Fix:** Capture timer callbacks in the fake and test repeated `flagsChanged`, partial modifier loss, timeout closure, key-up consumption, and direct-hotkey recovery; change production eventtap code only if a test exposes a defect.
- **Files:** `tests/test_keyboard.lua`; `managed/hammerspoon/keyboard.lua` only if required.
- **Risk:** Low.
- **Why it earns its place:** Protects the defining held-Hyper interaction with tests rather than an unnecessary eventtap rewrite.

#### SHOULD — targeted documentation/manifest drift checks

- **Problem:** The cheat sheet and manually declared Raycast map can diverge.
- **Fix:** Assert only the three Raycast chords and the deleted/retained handoff markers.
- **Files:** `CHEATSHEET.md`, `raycast-live-shortcuts.json`, `tests/test_shortcut_audit.py`.
- **Risk:** Low; keep assertions semantic and narrow.
- **Why it earns its place:** Guards the user-visible contract without parsing the entire document.

#### SKIP — HUD renderer reuse or performance refactor

- **Problem:** `refreshLayer()` currently recreates the canvas, but no measured lag or rendering defect is established.
- **Fix:** None in PLAN-002.
- **Files:** None.
- **Risk if attempted:** Medium; touches stable visual lifecycle code.
- **Why skipped:** Speculative optimization does not justify expanding this cherry-pick.

#### SKIP — window-follow behavior changes

- **Problem:** No new defect is established; current tests already cover ordinary activation rejection, single-use intents, launch TTL, switcher, `Command+Tab`, hints, expiry, and termination.
- **Fix:** Preserve and rerun the existing suite.
- **Files:** No production change.
- **Risk if attempted:** High because broad activation watching previously caused disruptive window movement.
- **Why skipped:** The current conservative allowlist is approved and already regression-tested.

#### SKIP — app-toggle, hint, mouse-grid, or mode-switch redesign

- **Problem:** No failing behavior in this scope.
- **Fix:** Preserve existing launch/focus/minimize semantics, pointer-display hints, grid lifecycle, and transactional LH/2H switch.
- **Files:** No production change.
- **Risk if attempted:** Medium.
- **Why skipped:** These are established workflow features, not native-handoff candidates.

#### SKIP — Loop, snapping, Spaces, geometry, new daemons, or paid tools

- **Problem:** None; these were part of rejected PLAN-001 ownership expansion.
- **Fix:** None.
- **Files:** None.
- **Risk if attempted:** High architectural churn and overlapping ownership.
- **Why skipped:** Explicitly outside the approved scope.

### Full verification

#### Automated

```sh
python3 -m unittest tests.test_keyboard tests.test_profile_contract tests.test_shortcut_audit tests.test_installer -v
python3 -m unittest discover -s tests -p 'test_*.py' -v
hs -c 'dofile("tests/test_keyboard.lua")'
python3 audit_shortcuts.py
python3 audit_shortcuts.py --live
python3 scripts/workflow_install.py verify
./verify.sh
git diff --check
```

Search for retired implementations and direct ownership:

```sh
rg -n 'changeVolume|toggleMute|cycleCurrentAppWindow|toggleDarkMode|launchOrFocus\\(\"Finder\"\\)|cmd.*shift.*\"\\.\"' managed/hammerspoon/keyboard.lua tests CHEATSHEET.md
rg -n 'bindDirect\\((currentMode.*\"q\"|currentMode.*\"z\"|\"m\"|\"b\")' managed/hammerspoon/keyboard.lua
rg -n '^alt - (x|f|t)\\s*:' managed/skhd/skhdrc-left
```

Expected results:

- No retired helper/hack references.
- No deleted direct Hyper registrations.
- Exactly one LH `Option+X`, one LH `Option+F`, and one LH `Option+T`.
- All Python, mocked Lua, repository audit, live installed-file audit, installer verification, and full verifier checks pass.
- Existing snapping, Spaces, display, BSP, app-toggle, hint, mouse-grid, window-follow, scrolling, and mode-switch tests remain green.

#### Manual — Raycast and integrated behavior

- Before changing Raycast, record/export the existing shortcut state.
- In Raycast Settings, set launcher to `Option+Space`.
- Set **Toggle System Appearance** to `Control+Option+Command+B`.
- Set **Toggle Hidden Files** to `Control+Option+Command+.`.
- Copy both command deeplinks from their Action Panels and exercise them directly.
- Filter Raycast Shortcuts by **Hotkey Set** and confirm the new chords do not overwrite unrelated assignments.
- Confirm `Option+Space` opens Raycast.
- Confirm direct `Hyper+Space` still opens Raycast as the secondary alias.
- From Apps HUD, confirm `Space` opens Raycast.
- Confirm direct LH `Hyper+Q/Z/4`, 2H `Hyper+Up/Down/N`, `Hyper+M`, and `Hyper+B` do nothing.
- Confirm physical Volume Up/Down/Mute keys work.
- Confirm System HUD `Q/Z/M` produces the normal macOS media behavior once per press.
- Confirm native `Command+\`` cycles the current application’s windows.
- Confirm Apps HUD `4/N` and Windows HUD `Q` each perform the same native window cycle once.
- Confirm `Control+Option+Command+B` and System HUD `B` both toggle appearance.
- Confirm `Control+Option+Command+.` and Snap HUD `2` both toggle hidden files without bringing Finder forward.
- Switch LH → 2H → LH; recheck the mode-local Apps HUD next-window alias and active skhd profile.
- Recheck one app toggle, one snap action, one Space send-and-follow, one BSP move/swap, one window hint, and one intent-gated window-follow action.
- Reload Hammerspoon/skhd and repeat one macOS, Raycast, HUD, and retained custom action.
- Log out/in or restart the relevant applications and repeat the smoke test.
- At every stage, verify Raycast **Caps Lock → Hyper** remains unchanged. Never open its recorder or replace that mapping.

### Rollback

- Before installation, retain the timestamped backup path printed by `workflow_install.py`; do not delete that backup.
- Restore repository-owned runtime files with:

```sh
python3 scripts/workflow_install.py uninstall ~/.keyboard-only-setup/backups/<timestamp>
```

- Reactivate the restored LH/2H profile, reload skhd, and reload Hammerspoon.
- Confirm the restored direct volume, mute, next-window, appearance, and hidden-file behavior before removing their Raycast replacements.
- In Raycast, remove only:

  - `Option+Space` launcher assignment if it was newly introduced.
  - `Control+Option+Command+B`.
  - `Control+Option+Command+.`.

- Restore the recorded prior Raycast launcher chord if one existed.
- Never modify the Caps-Lock Hyper remap during rollback.
- Run the restored checkout’s `./verify.sh`, then test Hyper HUD release, both modes, app toggles, snapping, Space focus/send, BSP swap, display movement, and window-follow.
- Keep the installer backup until the restored workflow survives Hammerspoon/skhd reload, mode switching, and a login/restart.

### Progress notes

- 2026-09-13: Read the plan format and rejected PLAN-001, the full Hammerspoon registry/eventtap and affected tests, both skhd profiles, `win-dir.sh`, cheat sheet, audit, Raycast manifest, installer, verifier, and installer/profile/audit tests.
- 2026-09-13: Confirmed the current checked-in LH profile already has the desired one-each `Option+X/F/T` map; PLAN-002 treats this as a contract to enforce and removes duplicate declarations only where they still exist in an execution or installed baseline.
- 2026-09-13: Confirmed from first-party documentation that macOS owns `Command+\``, Hammerspoon can emit native media system-key events, and Raycast supports global command hotkeys and copied command deeplinks.
- 2026-09-13: No files changed and no implementation tests run; this is a read-only plan.
- 2026-09-13: Routing: Sol/High (scope, decisions, and final plan) → Luna/Low (read-only repository trace) → Sol/High (integration and review). Verified from turn metadata.

