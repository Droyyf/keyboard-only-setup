from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
MANAGED = ROOT / "managed" / "skhd"


def bindings(path: Path) -> list[tuple[str, str]]:
    result = []
    for line in path.read_text().splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or ":" not in stripped:
            continue
        shortcut, command = stripped.split(":", 1)
        result.append((shortcut.strip(), command.strip()))
    return result


class ProfileContractTest(unittest.TestCase):
    def test_skhd_profiles_expose_no_direct_shortcuts(self):
        for mode in ("left", "dual"):
            self.assertEqual(bindings(MANAGED / f"skhdrc-{mode}"), [])

    def test_left_profile_never_requires_a_right_side_key(self):
        allowed = set("12345qwertasdfgzxcvb") | {"tab", "escape", "space"}
        for shortcut, _ in bindings(MANAGED / "skhdrc-left"):
            key = shortcut.split("-", 1)[1].strip()
            self.assertIn(key, allowed, shortcut)

if __name__ == "__main__":
    unittest.main()
