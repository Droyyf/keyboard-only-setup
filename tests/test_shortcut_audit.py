import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class ShortcutAuditTest(unittest.TestCase):
    def test_live_map_has_no_cross_owner_or_typing_hostile_shortcuts(self):
        result = subprocess.run(
            [sys.executable, ROOT / "audit_shortcuts.py"],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_audit_reports_a_cross_owner_collision(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / "raycast.json"
            fixture.write_text(json.dumps({"assignments": [
                {"action": "Conflicting action", "chord": "cmd+alt+ctrl+shift+h"}
            ]}))
            result = subprocess.run(
                [sys.executable, ROOT / "audit_shortcuts.py", "--raycast", fixture],
                capture_output=True,
                text=True,
            )
        self.assertEqual(result.returncode, 1)
        self.assertIn("cross-owner collision cmd+alt+ctrl+shift+h", result.stdout)

    def test_removed_skhd_direct_shortcut_does_not_collide(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / "raycast.json"
            fixture.write_text(json.dumps({"assignments": [
                {"action": "Conflicting action", "chord": "alt+h"}
            ]}))
            result = subprocess.run(
                [sys.executable, ROOT / "audit_shortcuts.py", "--raycast", fixture],
                capture_output=True,
                text=True,
            )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
