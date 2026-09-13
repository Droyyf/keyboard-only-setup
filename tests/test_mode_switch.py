import importlib.util
from pathlib import Path
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[1] / 'managed/skhd/set-keyboard-mode.py'

class ModeSwitchTest(unittest.TestCase):
    def setUp(self):
        self.assertTrue(SOURCE.exists(), 'transactional mode switch is missing')
        spec = importlib.util.spec_from_file_location('switch', SOURCE)
        self.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.module)
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.config = self.root / 'skhd'
        self.config.mkdir()
        self.mode = self.root / 'keyboard-mode'
        self.active = self.config / 'skhdrc'
        self.active.write_text('alt - h : /usr/bin/true\n')
        (self.config / 'skhdrc-dual').write_bytes(self.active.read_bytes())
        (self.config / 'skhdrc-left').write_text('alt - a : /usr/bin/true\n')
        self.mode.write_text('dual\n')

    def switch(self, mode, reload=lambda: None):
        self.module.apply_mode(mode, self.config, self.mode, reload)

    def test_success_commits_consistent_pair(self):
        observed = []
        self.switch('left', lambda: observed.append(self.mode.read_text().strip()))
        self.assertEqual(observed, ['dual'])
        self.assertEqual(self.active.read_bytes(), (self.config/'skhdrc-left').read_bytes())
        self.assertEqual(self.mode.read_text(), 'left\n')

    def test_reload_failure_rolls_back_both_files(self):
        old = self.active.read_bytes()
        def fail():
            raise RuntimeError('reload failed')
        with self.assertRaises(RuntimeError):
            self.switch('left', fail)
        self.assertEqual(self.active.read_bytes(), old)
        self.assertEqual(self.mode.read_text(), 'dual\n')

    def test_missing_profile_does_not_change_state(self):
        (self.config/'skhdrc-left').unlink()
        with self.assertRaises(FileNotFoundError):
            self.switch('left')
        self.assertEqual(self.mode.read_text(), 'dual\n')
        self.assertEqual(self.active.read_bytes(), (self.config/'skhdrc-dual').read_bytes())

    def test_duplicate_shortcuts_rejected_before_reload(self):
        (self.config/'skhdrc-left').write_text('alt - a : /usr/bin/true\nalt - a : /usr/bin/false\n')
        with self.assertRaises(ValueError):
            self.switch('left', lambda: self.fail('must not reload invalid profile'))
        self.assertEqual(self.mode.read_text(), 'dual\n')

    def test_intentionally_empty_profile_is_valid(self):
        (self.config/'skhdrc-left').write_text('# LEFT-HAND MODE\n# direct-bindings: none\n')
        self.switch('left')
        self.assertEqual(self.mode.read_text(), 'left\n')
        self.assertEqual(self.active.read_text(), '# LEFT-HAND MODE\n# direct-bindings: none\n')

    def test_unmarked_empty_profile_is_rejected(self):
        (self.config/'skhdrc-left').write_text('# accidentally emptied\n')
        with self.assertRaisesRegex(ValueError, 'Empty shortcut profile'):
            self.switch('left')
        self.assertEqual(self.mode.read_text(), 'dual\n')

    def test_invalid_mode_rejected(self):
        with self.assertRaises(ValueError):
            self.switch('../other')

    def test_first_switch_failure_keeps_mode_absent(self):
        self.mode.unlink()
        def fail(): raise RuntimeError('reload failed')
        with self.assertRaises(RuntimeError): self.switch('left', fail)
        self.assertFalse(self.mode.exists())

    def test_round_trip_restores_original_config(self):
        original = self.active.read_bytes()
        self.switch('left')
        self.switch('dual')
        self.assertEqual(self.active.read_bytes(), original)
        self.assertEqual(self.mode.read_text(), 'dual\n')

if __name__ == '__main__': unittest.main()
