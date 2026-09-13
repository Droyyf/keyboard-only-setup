#!/usr/bin/env python3
"""Backup-safe installation helpers for the macOS keyboard workflow."""

from __future__ import annotations

from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
from typing import Final


MANAGED_FILES: Final[dict[str, str]] = {
    "managed/hammerspoon/keyboard.lua": ".hammerspoon/keyboard.lua",
    "managed/skhd/skhdrc-dual": ".config/skhd/skhdrc-dual",
    "managed/skhd/skhdrc-left": ".config/skhd/skhdrc-left",
    "managed/skhd/set-keyboard-mode.py": ".config/skhd/set-keyboard-mode.py",
    "managed/skhd/cycle-window-display.sh": ".config/skhd/cycle-window-display.sh",
    "managed/skhd/win-dir.sh": ".config/skhd/win-dir.sh",
    "managed/skhd/yabai-run.sh": ".config/skhd/yabai-run.sh",
}
EXECUTABLE_DESTINATIONS: Final[set[str]] = {
    ".config/skhd/set-keyboard-mode.py",
    ".config/skhd/cycle-window-display.sh",
    ".config/skhd/win-dir.sh",
    ".config/skhd/yabai-run.sh",
}
VALID_MODES: Final[set[str]] = {"dual", "left"}
YABAI_REPOSITORY: Final[str] = "https://github.com/Droyyf/yabai-macos27.git"
YABAI_COMMIT: Final[str] = "a42af64b9ba0e6e01d9745c11d486311e04ec0ab"
LEGACY_WINDOW_FOLLOW_BLOCK: Final[str] = '''local excludedApps = {
    -- ["Slack"] = true,
}

local followEnabled = true
local lastCloseTime = 0
local CLOSE_GRACE_PERIOD = 0.5
local pullTimer = nil

-- Globals required to prevent Lua Garbage Collection
AppWatcher = nil
CloseWatcher = nil

CloseWatcher = hs.window.filter.new()
CloseWatcher:subscribe(hs.window.filter.windowDestroyed, function()
    lastCloseTime = hs.timer.secondsSinceEpoch()
end)

local function pullWindowToCurrentScreen()
    if hs.timer.secondsSinceEpoch() - lastCloseTime < CLOSE_GRACE_PERIOD then return end

    local app = hs.application.frontmostApplication()
    if not app then return end

    local appName = app:title()
    if excludedApps[appName] then return end

    local win = app:focusedWindow() or app:mainWindow()
    if not win then return end
    if not win:isStandard() then return end
    if win:isFullScreen() then return end

    local currentScreen = hs.mouse.getCurrentScreen()
    if currentScreen and win:screen() ~= currentScreen then
        -- Temporarily unsubscribe to prevent moveToScreen from triggering windowDestroyed
        CloseWatcher:unsubscribe(hs.window.filter.windowDestroyed)
        win:moveToScreen(currentScreen)
        hs.timer.doAfter(0.1, function()
            CloseWatcher:subscribe(hs.window.filter.windowDestroyed, function()
                lastCloseTime = hs.timer.secondsSinceEpoch()
            end)
        end)
    end
end

AppWatcher = hs.application.watcher.new(function(appName, eventType, appObject)
    if not followEnabled then return end

    if eventType == hs.application.watcher.terminated then
        lastCloseTime = hs.timer.secondsSinceEpoch()
        return
    end

    if eventType == hs.application.watcher.activated then
        if pullTimer then
            pullTimer:stop()
            pullTimer = nil
        end

        pullTimer = hs.timer.doAfter(0.15, function()
            local ok, err = pcall(pullWindowToCurrentScreen)

            if not ok then print("window-follow error: " .. tostring(err)) end
        end)
    end
end)
AppWatcher:start()

local hyper = {"cmd", "alt", "ctrl", "shift"}
hs.hotkey.bind(hyper, "end", function()
    followEnabled = not followEnabled
    hs.alert.show(followEnabled and "Window-follow: ON" or "Window-follow: OFF")
end)

'''


def _backup_directory(backup_root: Path) -> Path:
    backup_root.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    directory = backup_root / timestamp
    directory.mkdir()
    return directory


def _atomic_copy(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_name(destination.name + ".keyboard-only-setup.tmp")
    shutil.copy2(source, temporary)
    os.replace(temporary, destination)


def _atomic_write_text(destination: Path, content: str) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_name(destination.name + ".keyboard-only-setup.tmp")
    temporary.write_text(content)
    os.replace(temporary, destination)


def _migrate_legacy_window_follow(init_text: str) -> str:
    """Remove only the unconditional watcher block from the prior workflow."""
    return init_text.replace(LEGACY_WINDOW_FOLLOW_BLOCK, "", 1)


def install_managed_files(repo_root: Path, target_home: Path, backup_root: Path) -> Path:
    """Back up and atomically replace every repository-owned configuration file."""
    missing_sources = [source for source in MANAGED_FILES if not (repo_root / source).is_file()]
    if missing_sources:
        raise FileNotFoundError("missing managed source: " + ", ".join(missing_sources))

    backup = _backup_directory(backup_root)
    manifest: dict[str, dict[str, str]] = {}
    for source_relative, destination_relative in MANAGED_FILES.items():
        source = repo_root / source_relative
        destination = target_home / destination_relative
        backup_file = backup / "files" / destination_relative
        if destination.exists():
            backup_file.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(destination, backup_file)
            manifest[destination_relative] = {"state": "present"}
        else:
            manifest[destination_relative] = {"state": "absent"}
        _atomic_copy(source, destination)
        if destination_relative in EXECUTABLE_DESTINATIONS:
            destination.chmod(destination.stat().st_mode | stat.S_IXUSR)

    init_relative = ".hammerspoon/init.lua"
    init_file = target_home / init_relative
    init_text = init_file.read_text() if init_file.exists() else ""
    updated_init_text = _migrate_legacy_window_follow(init_text)
    if 'require("keyboard")' not in updated_init_text and "require('keyboard')" not in updated_init_text:
        suffix = "" if not updated_init_text or updated_init_text.endswith("\n") else "\n"
        updated_init_text += suffix + 'require("keyboard")\n'
    if updated_init_text != init_text:
        if init_file.exists():
            backup_file = backup / "files" / init_relative
            backup_file.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(init_file, backup_file)
            manifest[init_relative] = {"state": "present"}
        else:
            manifest[init_relative] = {"state": "absent"}
        _atomic_write_text(init_file, updated_init_text)

    (backup / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    return backup


def read_manifest(backup_directory: Path) -> dict[str, dict[str, str]]:
    return json.loads((backup_directory / "manifest.json").read_text())


def restore_backup(backup_directory: Path, target_home: Path) -> None:
    """Restore managed files from one installer-created backup manifest."""
    manifest = read_manifest(backup_directory)
    for destination_relative, metadata in manifest.items():
        destination = target_home / destination_relative
        if metadata["state"] == "present":
            _atomic_copy(backup_directory / "files" / destination_relative, destination)
        elif metadata["state"] == "absent" and destination.exists():
            destination.unlink()


def _yabai_source(target_home: Path) -> Path:
    return target_home / ".local/src/yabai-macos27"


def dependency_commands(repo_root: Path, target_home: Path) -> list[str]:
    yabai_source = _yabai_source(target_home)
    clone_or_fetch = (
        f"git -C {yabai_source} fetch --all --tags"
        if yabai_source.exists()
        else f"git clone {YABAI_REPOSITORY} {yabai_source}"
    )
    return [
        "brew install --cask hammerspoon raycast shortcat",
        "brew install skhd jq",
        clone_or_fetch,
        f"git -C {yabai_source} checkout --detach {YABAI_COMMIT}",
        f"make -C {yabai_source}",
    ]


def service_commands(repo_root: Path, target_home: Path) -> list[str]:
    yabai_source = _yabai_source(target_home)
    return [
        f"{yabai_source}/bin/yabai --start-service",
        "skhd --start-service",
        "open -gja Hammerspoon",
    ]


def install_commands(repo_root: Path, target_home: Path) -> list[str]:
    """Return the externally visible commands used for a non-dry installation."""
    return dependency_commands(repo_root, target_home) + service_commands(repo_root, target_home)


def _run(command: str) -> None:
    subprocess.run(command, shell=True, check=True)


def _print_and_run(commands: list[str], dry_run: bool) -> None:
    for command in commands:
        print("+", command)
        if not dry_run:
            _run(command)


def activate_mode(target_home: Path, requested_mode: str | None) -> str:
    """Keep a valid selected mode or select left mode, then derive skhdrc."""
    mode_file = target_home / ".config/keyboard-mode"
    existing_mode = mode_file.read_text().strip() if mode_file.exists() else None
    selected_mode = requested_mode or (existing_mode if existing_mode in VALID_MODES else "left")
    if selected_mode not in VALID_MODES:
        raise ValueError("mode must be one of: dual, left")

    profile = target_home / f".config/skhd/skhdrc-{selected_mode}"
    if not profile.is_file():
        raise FileNotFoundError(f"missing skhd profile: {profile}")
    _atomic_copy(profile, target_home / ".config/skhd/skhdrc")
    mode_file.parent.mkdir(parents=True, exist_ok=True)
    mode_file.write_text(selected_mode + "\n")
    return selected_mode


def _reload_skhd() -> None:
    skhd = shutil.which("skhd")
    if skhd is None:
        for candidate in ("/opt/homebrew/bin/skhd", "/usr/local/bin/skhd"):
            if Path(candidate).is_file():
                skhd = candidate
                break
    if skhd is None:
        return
    subprocess.run([skhd, "--reload"], capture_output=True, text=True, timeout=3, check=False)


def verify(repo_root: Path, target_home: Path) -> list[str]:
    """Return human-readable verification failures without mutating the machine."""
    failures: list[str] = []
    for source_relative, destination_relative in MANAGED_FILES.items():
        source = repo_root / source_relative
        destination = target_home / destination_relative
        if not destination.is_file():
            failures.append(f"missing managed file: {destination}")
            continue
        if source.read_bytes() != destination.read_bytes():
            failures.append(f"managed file differs from repository: {destination}")
        if destination_relative in EXECUTABLE_DESTINATIONS and not os.access(destination, os.X_OK):
            failures.append(f"managed helper is not executable: {destination}")
    mode_file = target_home / ".config/keyboard-mode"
    mode = mode_file.read_text().strip() if mode_file.exists() else None
    if mode not in VALID_MODES:
        failures.append("keyboard mode is missing or invalid")
    elif not (target_home / f".config/skhd/skhdrc-{mode}").is_file():
        failures.append(f"missing profile for mode: {mode}")
    elif (target_home / ".config/skhd/skhdrc").read_bytes() != (
        target_home / f".config/skhd/skhdrc-{mode}"
    ).read_bytes():
        failures.append(f"active skhd profile differs from selected mode: {mode}")
    return failures


def _cli(argv: list[str]) -> int:
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("install", "verify", "uninstall"))
    parser.add_argument("backup", nargs="?")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--mode", choices=sorted(VALID_MODES))
    parser.add_argument("--home", type=Path, default=Path.home())
    args = parser.parse_args(argv)
    repo_root = Path(__file__).resolve().parents[1]
    target_home = args.home.expanduser().resolve()

    if args.command == "verify":
        failures = verify(repo_root, target_home)
        if failures:
            print("Verification failed:", *failures, sep="\n- ", file=sys.stderr)
            return 1
        print("Verification passed")
        return 0
    if args.command == "uninstall":
        if not args.backup:
            parser.error("uninstall requires a backup directory")
        backup = Path(args.backup).expanduser().resolve()
        backup_root = (target_home / ".keyboard-only-setup/backups").resolve()
        if backup_root not in backup.parents or not (backup / "manifest.json").is_file():
            parser.error("backup must be an installer-created directory below ~/.keyboard-only-setup/backups")
        restore_backup(backup, target_home)
        print(f"Restored {backup}")
        return 0

    if shutil.which("brew") is None:
        raise RuntimeError(
            "Homebrew is required. Install it from https://brew.sh, then rerun this script."
        )

    planned = install_commands(repo_root, target_home)
    if args.dry_run:
        for command in planned:
            print("+", command)
        return 0

    _print_and_run(dependency_commands(repo_root, target_home), dry_run=False)
    backup = install_managed_files(repo_root, target_home, target_home / ".keyboard-only-setup/backups")
    mode = activate_mode(target_home, args.mode)
    _print_and_run(service_commands(repo_root, target_home), dry_run=False)
    _reload_skhd()
    print(f"Installed mode: {mode}")
    print(f"Backup: {backup}")
    print("Grant Accessibility to Hammerspoon, skhd, yabai, Raycast, and Shortcat.")
    print("Enable Raycast Caps Lock Hyper Key and leave Raycast Window Management hotkeys unassigned.")
    return 0


if __name__ == "__main__":
    raise SystemExit(_cli(sys.argv[1:]))
