import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class CycleDisplayTest(unittest.TestCase):
    def test_cycles_forward_and_wraps_to_the_first_display(self) -> None:
        with tempfile.TemporaryDirectory() as raw_directory:
            directory = Path(raw_directory)
            helper = directory / "cycle-window-display.sh"
            shutil.copy2(ROOT / "managed/skhd/cycle-window-display.sh", helper)
            helper.chmod(0o755)
            log = directory / "move.log"
            yabai = directory / "yabai-run.sh"
            yabai.write_text(
                "#!/bin/bash\n"
                "if [[ \"$*\" == *\"query --displays\"* ]]; then\n"
                "  printf '%s\\n' '[{\"index\":1},{\"index\":3}]'\n"
                "elif [[ \"$*\" == *\"query --windows --window\"* ]]; then\n"
                "  printf '{\"display\":%s}\\n' \"$CURRENT_DISPLAY\"\n"
                "else\n"
                "  printf '%s\\n' \"$*\" >> \"$MOVE_LOG\"\n"
                "fi\n"
            )
            yabai.chmod(0o755)

            environment = os.environ | {"MOVE_LOG": str(log)}
            subprocess.run([helper], env=environment | {"CURRENT_DISPLAY": "1"}, check=True)
            subprocess.run([helper], env=environment | {"CURRENT_DISPLAY": "3"}, check=True)

            self.assertEqual(
                log.read_text().splitlines(),
                ["-m window --display 3", "-m window --display 1"],
            )


if __name__ == "__main__":
    unittest.main()
