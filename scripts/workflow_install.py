#!/usr/bin/env python3
"""Backup-safe installation helpers for the macOS keyboard workflow."""

from __future__ import annotations

from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import stat
from typing import Final


MANAGED_FILES: Final[dict[str, str]] = {
    "managed/hammerspoon/keyboard.lua": ".hammerspoon/keyboard.lua",
    "managed/skhd/skhdrc-dual": ".config/skhd/skhdrc-dual",
    "managed/skhd/skhdrc-left": ".config/skhd/skhdrc-left",
    "managed/skhd/set-keyboard-mode.py": ".config/skhd/set-keyboard-mode.py",
    "managed/skhd/win-dir.sh": ".config/skhd/win-dir.sh",
}
EXECUTABLE_DESTINATIONS: Final[set[str]] = {
    ".config/skhd/set-keyboard-mode.py",
    ".config/skhd/win-dir.sh",
}
VALID_MODES: Final[set[str]] = {"dual", "left"}


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

    (backup / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    return backup


def read_manifest(backup_directory: Path) -> dict[str, dict[str, str]]:
    return json.loads((backup_directory / "manifest.json").read_text())


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
