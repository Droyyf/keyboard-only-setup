# Keyboard-only macOS workflow

This repository installs and documents a keyboard-first macOS workflow with two
maps: **2H** for normal two-hand use and **LH** for left-hand shortcut access.

It combines Raycast Hyper Key, Hammerspoon, skhd, a macOS 27-compatible yabai
build, and Shortcat. Hammerspoon owns app toggles, snapping, navigation layers,
a Hyper-held Action Hub and generated shortcut reference, and mode selection. skhd invokes yabai for focus, movement,
resizing, native Spaces, and displays.

Display movement uses one looping action: **4** inside LH window HUDs and
**N** inside 2H window HUDs. The shared helper queries yabai's connected-display
ring and wraps from the final display back to the first.

Read [CHEATSHEET.md](CHEATSHEET.md) for the complete map and
[METHODOLOGY.md](METHODOLOGY.md) for the ownership and recovery model.

## Install

Clone the repository, then run:

```sh
./install.sh
```

To inspect every external command first, use:

```sh
./install.sh --dry-run --mode left
```

Use `--mode dual` to make 2H the initial active map. If no mode is provided,
the installer preserves a valid existing choice or starts a new setup in LH.

The installer requires Homebrew. If Homebrew is not present, it stops before
changing configuration and tells you to install Homebrew from
<https://brew.sh>, then rerun `./install.sh`.

On a compatible Mac it installs Hammerspoon, Raycast, Shortcat, and skhd with
Homebrew. It clones `Droyyf/yabai-macos27` to `~/.local/src/yabai-macos27`,
checks out the pinned verified commit, builds yabai, and starts its service.
Then it installs the repository-owned Hammerspoon and skhd files.

## What the installer preserves

Before changing each managed file, the installer writes a timestamped backup to:

```text
~/.keyboard-only-setup/backups/<timestamp>/
```

Each backup has a manifest recording whether every target file existed before
the installer changed it. The installer does not overwrite
`~/.hammerspoon/init.lua`, because it can contain unrelated personal automation.
It appends the following line only when it is absent, so Hammerspoon loads the
workflow while retaining the rest of the file:

```lua
require("keyboard")
```

## Required manual macOS settings

macOS permissions and security choices belong to you. The installer never
attempts to bypass or grant them automatically.

1. Grant **Accessibility** permission to Hammerspoon, skhd, yabai, Raycast,
   and Shortcat in **System Settings → Privacy & Security → Accessibility**.
2. In **Raycast → Settings → Keyboard → Hyper Key**, set **Caps Lock** as the
   Hyper Key. This setup expects Hyper to produce Command + Option + Control +
   Shift.
3. Leave Raycast Window Management global hotkeys unassigned. Hammerspoon owns
   every global snap chord in this map.
4. Decide whether to keep System Integrity Protection disabled. The advanced
   native-Space operations provided by yabai can require it; the installer does
   not modify SIP.

## Verify

`./verify.sh` runs the Python tests, the Hammerspoon Lua tests when the `hs` CLI is available, the shortcut audit against `managed/`, and the installed-machine file checks.

```sh
./verify.sh
```

Audit an already-installed map with:

```sh
python3 audit_shortcuts.py --live
```

## Refresh after editing

For a quick live reload without changing files, press **Hyper+Escape**.

After editing the repository sources, run the following from this repository:

```sh
./refresh.sh
```

It runs the verification suite, makes a timestamped backup, atomically installs
only the repository-owned Hammerspoon and skhd files, preserves the selected
LH/2H mode, then reloads skhd and Hammerspoon. It does not rerun Homebrew or
reinstall applications.

## Restore or uninstall

List the available backups, choose one timestamped directory, then restore it:

```sh
./uninstall.sh "$HOME/.keyboard-only-setup/backups/<timestamp>"
```

`uninstall.sh` only accepts installer-created backup directories below that
backup root. It restores files that existed beforehand and removes only managed
files that the installer originally created.

## Updating the workflow

Edit the sources under `managed/`, update the tests and cheat sheet, run the
verification suite, then run `./install.sh` again. Do not edit the generated
active `~/.config/skhd/skhdrc` directly: the selected `skhdrc-left` or
`skhdrc-dual` profile generates it.
