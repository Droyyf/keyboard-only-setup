from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class RepositoryContractTest(unittest.TestCase):
    def test_repository_contains_every_managed_install_source(self):
        for relative_path in (
            "managed/hammerspoon/keyboard.lua",
            "managed/skhd/skhdrc-dual",
            "managed/skhd/skhdrc-left",
            "managed/skhd/set-keyboard-mode.py",
            "managed/skhd/win-dir.sh",
        ):
            self.assertTrue((ROOT / relative_path).is_file(), relative_path)


if __name__ == "__main__":
    unittest.main()
