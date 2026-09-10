# Reproducible macOS Keyboard Workflow Design

## Purpose

Create a public GitHub repository that can reproduce this keyboard-only macOS
workflow from a fresh compatible Mac with one installer command while preserving
any configuration it replaces.

## Scope

The repository contains the managed Hammerspoon and skhd configuration files,
the current keyboard-mode helper and window helper, the existing shortcut audit
and tests, a backup-first installer, a verifier, and an uninstaller.

The installer requires Homebrew already present, then installs Hammerspoon,
Raycast, Shortcat, skhd, and jq through Homebrew. It clones the user's macOS
27-compatible yabai fork at commit
`a42af64b9ba0e6e01d9745c11d486311e04ec0ab`, builds it, and installs its launch
service. It copies only repository-owned configuration files into their final
locations, starts or reloads services, and reports the selected keyboard mode.

## Managed destinations

| Repository path | Installed destination |
| --- | --- |
| `managed/hammerspoon/keyboard.lua` | `~/.hammerspoon/keyboard.lua` |
| `managed/skhd/skhdrc-dual` | `~/.config/skhd/skhdrc-dual` |
| `managed/skhd/skhdrc-left` | `~/.config/skhd/skhdrc-left` |
| `managed/skhd/set-keyboard-mode.py` | `~/.config/skhd/set-keyboard-mode.py` |
| `managed/skhd/win-dir.sh` | `~/.config/skhd/win-dir.sh` |
| `managed/skhd/yabai-run.sh` | `~/.config/skhd/yabai-run.sh` |

The installer creates `~/.config/keyboard-mode` with `left` only when it is
absent. It copies the matching profile onto the active `skhdrc` after managed
files are in place, then starts services.

The user's pre-existing `~/.hammerspoon/init.lua` is not overwritten because
it can contain unrelated personal automation. The installer appends
`require("keyboard")` when that line is missing.

## Safety and recovery

Before replacing a managed destination, the installer stores the prior version
in one timestamped directory under `~/.keyboard-only-setup/backups/`. It writes
a manifest that distinguishes files that existed before installation from files
created by the installer. A failed copy aborts before service activation. The
uninstaller restores the selected backup and never recursively deletes an
unresolved home-directory path.

The installer must be idempotent: re-running it creates a new backup and leaves
the managed files, mode helper, executable bits, and service configuration in a
known good state.

## Installation flow

1. Verify Homebrew is present; if it is missing, print https://brew.sh and stop.
2. Install the casks/formulae that do not need user interaction: Hammerspoon,
   Raycast, Shortcat, skhd, and jq.
3. Clone or update the pinned yabai source into
   `~/.local/src/yabai-macos27`, check out the exact commit, and build it.
4. Backup and install managed configuration files, then activate the skhd profile.
5. Ensure the current user's mode is preserved when valid; otherwise initialize
   it to `left`.
6. Start yabai and skhd, open Hammerspoon, reload skhd, and run the verifier.
7. Print the manual authorization checklist.

## Manual actions

The installer never grants Accessibility permission, changes System Integrity
Protection, or writes Raycast's private settings. It opens the appropriate
System Settings pages and prints the required actions:

- grant Accessibility to Hammerspoon, skhd, yabai, Raycast, and Shortcat;
- enable Raycast's Caps Lock Hyper Key;
- leave Raycast Window Management global hotkeys unassigned;
- decide whether the advanced yabai native-Space features justify the current
  SIP-disabled configuration.

## Verification

`./verify.sh` must run Python tests, Hammerspoon's mocked Lua tests when the
`hs` CLI is installed, the shortcut audit, process checks, mode/profile
consistency checks, and a source-pin check for yabai. It exits nonzero with
specific remediation text for a failed check.

Tests use a temporary home directory and stub external executables. They prove
that the installer copies only managed files, preserves an existing mode,
initializes a missing mode, writes a backup manifest, and avoids activating
services after a copy failure.

## Non-goals

- No automatic SIP modification.
- No automated approval of macOS privacy prompts.
- No overwrite of `~/.hammerspoon/init.lua`.
- No automatic configuration of Raycast's Hyper Key.
- No migration to AeroSpace or removal of skhd in this release.
