from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
MANAGED = ROOT / "managed" / "skhd"
BASELINE = ROOT / "backups/20260908-195649/skhd/skhdrc-dual"


def bindings(path: Path) -> list[tuple[str, str]]:
    result = []
    for line in path.read_text().splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or ":" not in stripped:
            continue
        shortcut, command = stripped.split(":", 1)
        result.append((shortcut.strip(), command.strip()))
    return result


def chords(path: Path) -> set[str]:
    return {shortcut for shortcut, _ in bindings(path)}


def normalized_commands(path: Path) -> set[str]:
    commands = set()
    for _, command in bindings(path):
        command = re.sub(r"(?:\$HOME|/Users/[^/ ]+)/.config/skhd/yabai-run\.sh(?: --script \S+)?", "YABAI", command)
        command = re.sub(r"/bin/bash /Users/[^/ ]+/dev/yabai-macos27/scripts/\S+", "YABAI", command)
        command = re.sub(r"/Users/[^/ ]+/dev/yabai-macos27/bin/yabai", "YABAI", command)
        command = re.sub(r"(?:\$HOME|/Users/[^/ ]+)/.config/skhd/win-dir\.sh", "WIN", command)
        commands.add(command)
    return commands


class ProfileContractTest(unittest.TestCase):
    def test_two_hand_profile_preserves_existing_chords(self):
        self.assertEqual(chords(MANAGED / "skhdrc-dual"), chords(BASELINE))

    def test_left_profile_never_requires_a_right_side_key(self):
        allowed = set("12345qwertasdfgzxcvb") | {"tab", "escape", "space"}
        for shortcut, _ in bindings(MANAGED / "skhdrc-left"):
            key = shortcut.split("-", 1)[1].strip()
            self.assertIn(key, allowed, shortcut)

    def test_left_preserves_non_space_window_actions(self):
        expected = {
            command
            for command in normalized_commands(MANAGED / "skhdrc-dual")
            if not any(f"--focus {n} " in command or f"--space {n} " in command for n in range(6, 10))
        }
        self.assertTrue(expected <= normalized_commands(MANAGED / "skhdrc-left"), "a window/display action was dropped")


if __name__ == "__main__":
    unittest.main()
