#!/usr/bin/env python3
"""Audit cross-owner global shortcuts without reading private app databases."""

from __future__ import annotations

import argparse
import json
import re
from collections import defaultdict
from pathlib import Path


def normalize_chord(chord: str) -> str:
    aliases = {"control": "ctrl", "command": "cmd", "option": "alt"}
    parts = [aliases.get(part.strip().lower(), part.strip().lower()) for part in chord.split("+")]
    modifier_names = {"cmd", "alt", "ctrl", "shift", "fn"}
    modifiers = [part for part in ("cmd", "alt", "ctrl", "shift", "fn") if part in parts]
    keys = [part for part in parts if part not in modifier_names]
    if len(keys) != 1:
        raise ValueError(f"shortcut must contain exactly one key: {chord!r}")
    return "+".join([*modifiers, keys[0]])


def hammerspoon_hyper_bindings(path: Path) -> list[dict[str, str]]:
    source = path.read_text()
    keys = set(re.findall(r'hs\.hotkey\.bind\(hyper,\s*"([^"]+)"', source))
    keys |= set(re.findall(r'bindDirect\("([^"]+)"', source))
    return [
        {"owner": "Hammerspoon", "action": f"configured Hyper+{key}", "chord": normalize_chord(f"cmd+alt+ctrl+shift+{key}")}
        for key in sorted(keys)
    ]


def raycast_bindings(path: Path) -> list[dict[str, str]]:
    data = json.loads(path.read_text())
    return [
        {"owner": "Raycast", "action": item["action"], "chord": normalize_chord(item["chord"])}
        for item in data["assignments"]
    ]


def skhd_bindings(paths: list[Path]) -> list[dict[str, str]]:
    bindings: list[dict[str, str]] = []
    for path in paths:
        for line in path.read_text().splitlines():
            stripped = line.strip()
            if not stripped or stripped.startswith("#") or ":" not in stripped:
                continue
            shortcut = stripped.split(":", 1)[0].strip()
            modifiers, separator, key = shortcut.rpartition(" - ")
            if not separator:
                raise ValueError(f"unsupported skhd shortcut in {path}: {shortcut!r}")
            chord = "+".join([*(part.strip() for part in modifiers.split("+")), key.strip()])
            bindings.append({
                "owner": "skhd/yabai",
                "action": f"{path.name} binding",
                "chord": normalize_chord(chord),
            })
    return bindings


def audit(bindings: list[dict[str, str]]) -> list[str]:
    findings: list[str] = []
    by_chord: defaultdict[str, list[dict[str, str]]] = defaultdict(list)
    for binding in bindings:
        by_chord[binding["chord"]].append(binding)
        parts = binding["chord"].split("+")
        if binding["owner"] == "Raycast" and len(parts) == 2 and parts[0] == "shift":
            findings.append(
                f"typing-hostile Raycast shortcut {binding['chord']}: {binding['action']}"
            )

    for chord, owners in sorted(by_chord.items()):
        if len({item["owner"] for item in owners}) > 1:
            actions = "; ".join(f"{item['owner']}: {item['action']}" for item in owners)
            findings.append(f"cross-owner collision {chord}: {actions}")
    return findings


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    root = Path(__file__).resolve().parent
    parser.add_argument("--live", action="store_true", help="audit installed files under $HOME")
    parser.add_argument("--raycast", type=Path, default=root / "raycast-live-shortcuts.json")
    parser.add_argument("--hammerspoon", type=Path)
    parser.add_argument("--skhd", type=Path, nargs="*")
    args = parser.parse_args()

    hammerspoon = args.hammerspoon
    skhd = args.skhd
    if args.live:
        hammerspoon = hammerspoon or (Path.home() / ".hammerspoon/keyboard.lua")
        skhd = skhd or [Path.home() / ".config/skhd/skhdrc-dual", Path.home() / ".config/skhd/skhdrc-left"]
    else:
        hammerspoon = hammerspoon or (root / "managed/hammerspoon/keyboard.lua")
        skhd = skhd or [root / "managed/skhd/skhdrc-dual", root / "managed/skhd/skhdrc-left"]

    bindings = raycast_bindings(args.raycast)
    bindings += hammerspoon_hyper_bindings(hammerspoon)
    bindings += skhd_bindings(skhd)
    findings = audit(bindings)
    if findings:
        print("Shortcut audit failed:")
        for finding in findings:
            print(f"- {finding}")
        return 1
    print("Shortcut audit passed: no cross-owner or typing-hostile chords found.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
