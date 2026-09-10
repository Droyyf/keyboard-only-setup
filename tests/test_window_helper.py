from pathlib import Path
import json
import os
import subprocess
import tempfile
import unittest


class WindowHelperTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.log = root / "calls.jsonl"
        yabai = root / "yabai"
        yabai.write_text(
            """#!/usr/bin/python3
import json, os, sys
if 'query' in sys.argv:
 print(os.environ['TEST_WINDOW'])
else:
 with open(os.environ['TEST_CALLS'], 'a') as f: f.write(json.dumps(sys.argv[1:])+'\\n')
"""
        )
        yabai.chmod(0o755)
        self.helper = root / "win-dir.sh"
        source = (Path(__file__).resolve().parents[1] / "managed/skhd/win-dir.sh").read_text()
        self.helper.write_text(source)
        self.helper.chmod(0o755)
        self.env = dict(os.environ, TEST_CALLS=str(self.log), YABAI=str(yabai), JQ="")

    def run_helper(self, op, direction, floating=True, fullscreen=False):
        self.env["TEST_WINDOW"] = json.dumps({"is-floating": floating, "is-fullscreen": fullscreen})
        subprocess.run(["/bin/bash", str(self.helper), op, direction], env=self.env, check=True)
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def test_float_moves_use_relative_coordinate_syntax(self):
        self.assertEqual(self.run_helper("move", "west"), [["-m", "window", "--move", "rel:-60:0"]])

    def test_tiled_move_swaps_instead(self):
        self.assertEqual(self.run_helper("move", "east", floating=False), [["-m", "window", "--swap", "east"]])

    def test_fullscreen_move_is_ignored(self):
        self.assertEqual(self.run_helper("move", "west", fullscreen=True), [])

    def test_invalid_input_is_ignored(self):
        self.assertEqual(self.run_helper("move", "invalid"), [])

    def test_resize_uses_yabai_edge_syntax(self):
        self.assertEqual(self.run_helper("resize", "north"), [["-m", "window", "--resize", "top:0:-40"]])


if __name__ == "__main__":
    unittest.main()
