import importlib
import os
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class InstallerTest(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.home = Path(self.temporary_directory.name) / "home"
        self.home.mkdir()
        self.backups = self.home / ".keyboard-only-setup/backups"

    def tearDown(self):
        self.temporary_directory.cleanup()

    def test_install_backs_up_existing_managed_file_and_replaces_it(self):
        workflow_install = importlib.import_module("scripts.workflow_install")
        (self.home / ".hammerspoon").mkdir()
        destination = self.home / ".hammerspoon/keyboard.lua"
        destination.write_text("old configuration")

        backup = workflow_install.install_managed_files(ROOT, self.home, self.backups)

        self.assertEqual(
            destination.read_text(),
            (ROOT / "managed/hammerspoon/keyboard.lua").read_text(),
        )
        self.assertEqual(
            (backup / "files/.hammerspoon/keyboard.lua").read_text(),
            "old configuration",
        )

    def test_install_preserves_valid_existing_mode(self):
        workflow_install = importlib.import_module("scripts.workflow_install")
        (self.home / ".config").mkdir()
        (self.home / ".config/keyboard-mode").write_text("dual\n")
        workflow_install.install_managed_files(ROOT, self.home, self.backups)

        selected_mode = workflow_install.activate_mode(self.home, None)

        self.assertEqual(selected_mode, "dual")
        self.assertEqual((self.home / ".config/keyboard-mode").read_text(), "dual\n")

    def test_install_initializes_left_mode_when_mode_is_absent(self):
        workflow_install = importlib.import_module("scripts.workflow_install")
        workflow_install.install_managed_files(ROOT, self.home, self.backups)

        selected_mode = workflow_install.activate_mode(self.home, None)

        self.assertEqual(selected_mode, "left")
        self.assertEqual((self.home / ".config/keyboard-mode").read_text(), "left\n")

    def test_install_command_plan_pins_yabai_source_and_commit(self):
        workflow_install = importlib.import_module("scripts.workflow_install")

        commands = workflow_install.install_commands(ROOT, self.home)

        command_text = "\n".join(commands)
        self.assertIn("https://github.com/Droyyf/yabai-macos27.git", command_text)
        self.assertIn("a42af64b9ba0e6e01d9745c11d486311e04ec0ab", command_text)
        self.assertIn("open -gja Hammerspoon", command_text)
        self.assertIn("skhd --start-service", command_text)
        self.assertIn("brew install skhd jq", command_text)

    def test_restore_removes_only_file_created_by_installer(self):
        workflow_install = importlib.import_module("scripts.workflow_install")
        backup = workflow_install.install_managed_files(ROOT, self.home, self.backups)

        workflow_install.restore_backup(backup, self.home)

        self.assertFalse((self.home / ".hammerspoon/keyboard.lua").exists())

    def test_activate_mode_is_defined_before_cli_entry(self):
        source = (ROOT / "scripts/workflow_install.py").read_text()
        self.assertLess(source.index("def activate_mode"), source.index('if __name__'))

    def test_install_copies_yabai_wrapper_and_marks_it_executable(self):
        workflow_install = importlib.import_module("scripts.workflow_install")
        workflow_install.install_managed_files(ROOT, self.home, self.backups)
        wrapper = self.home / ".config/skhd/yabai-run.sh"
        self.assertTrue(wrapper.is_file())
        self.assertTrue(os.access(wrapper, os.X_OK))

    def test_install_adds_keyboard_require_without_replacing_personal_init(self):
        workflow_install = importlib.import_module("scripts.workflow_install")
        hammerspoon = self.home / ".hammerspoon"
        hammerspoon.mkdir()
        init = hammerspoon / "init.lua"
        init.write_text("hs.alert.show('personal automation')\n")

        workflow_install.install_managed_files(ROOT, self.home, self.backups)

        self.assertIn("hs.alert.show('personal automation')", init.read_text())
        self.assertIn('require("keyboard")', init.read_text())

    def test_install_migrates_only_the_known_legacy_window_follow_block(self):
        workflow_install = importlib.import_module("scripts.workflow_install")
        hammerspoon = self.home / ".hammerspoon"
        hammerspoon.mkdir()
        init = hammerspoon / "init.lua"
        original = (
            "hs.alert.show('before')\n"
            + workflow_install.LEGACY_WINDOW_FOLLOW_BLOCK
            + "require(\"keyboard\")\n"
            + "hs.alert.show('after')\n"
        )
        init.write_text(original)

        backup = workflow_install.install_managed_files(ROOT, self.home, self.backups)

        migrated = init.read_text()
        self.assertIn("hs.alert.show('before')", migrated)
        self.assertIn("hs.alert.show('after')", migrated)
        self.assertNotIn("AppWatcher = hs.application.watcher.new", migrated)
        self.assertEqual(migrated.count('require("keyboard")'), 1)
        self.assertEqual((backup / "files/.hammerspoon/init.lua").read_text(), original)

    def test_legacy_migration_does_not_remove_a_nearby_unrecognized_block(self):
        workflow_install = importlib.import_module("scripts.workflow_install")
        altered = workflow_install.LEGACY_WINDOW_FOLLOW_BLOCK.replace(
            'hs.alert.show(followEnabled and "Window-follow: ON" or "Window-follow: OFF")',
            'hs.alert.show("custom follow")',
        )
        self.assertEqual(workflow_install._migrate_legacy_window_follow(altered), altered)


if __name__ == "__main__":
    unittest.main()
