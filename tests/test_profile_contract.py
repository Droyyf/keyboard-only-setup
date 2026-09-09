from pathlib import Path
import unittest

ROOT = Path.home()/'.config/skhd'
BASELINE = Path(__file__).resolve().parents[1]/'backups/20260908-195649/skhd/skhdrc-dual'

class ProfileContractTest(unittest.TestCase):
    def test_two_hand_profile_preserves_existing_shortcuts(self):
        self.assertEqual((ROOT/'skhdrc-dual').read_bytes(), BASELINE.read_bytes())

    def test_left_profile_never_requires_a_right_side_key(self):
        allowed = set('12345qwertasdfgzxcvb') | {'tab','escape','space'}
        for line in (ROOT/'skhdrc-left').read_text().splitlines():
            if not line.strip() or line.startswith('#'): continue
            shortcut = line.split(':',1)[0]
            key = shortcut.split('-',1)[1].strip()
            self.assertIn(key, allowed, shortcut)

    def test_left_preserves_non_space_window_actions(self):
        def commands(path):
            return {line.split(':',1)[1].strip() for line in path.read_text().splitlines() if line.strip() and not line.startswith('#')}
        # Spaces 6-9 are provided in the Hammerspoon sequence layer.
        expected = {c for c in commands(ROOT/'skhdrc-dual') if not any(f'--focus {n} ' in c or f'--space {n} ' in c for n in range(6,10))}
        self.assertTrue(expected <= commands(ROOT/'skhdrc-left'), 'a window/display action was dropped')

if __name__ == '__main__': unittest.main()
