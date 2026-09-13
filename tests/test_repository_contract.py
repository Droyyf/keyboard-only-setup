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
            "managed/skhd/yabai-run.sh",
        ):
            self.assertTrue((ROOT / relative_path).is_file(), relative_path)

    def test_readme_documents_install_verify_restore_and_manual_permissions(self):
        text = (ROOT / "README.md").read_text()
        for fragment in (
            "./install.sh",
            "./verify.sh",
            "./uninstall.sh",
            "Accessibility",
            "Raycast",
        ):
            self.assertIn(fragment, text)

    def test_refresh_verifies_source_then_waits_and_checks_live_install(self):
        text = (ROOT / "refresh.sh").read_text()
        self.assertIn('"$repo_root/verify.sh" --source-only', text)
        self.assertGreaterEqual(text.count('"$repo_root/verify.sh"'), 2)
        self.assertIn("Hammerspoon did not restore its CLI message port", text)


if __name__ == "__main__":
    unittest.main()
