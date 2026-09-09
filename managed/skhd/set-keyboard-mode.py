#!/usr/bin/python3
"""Apply a keyboard profile with validation, locking, and failure rollback."""
from pathlib import Path
import fcntl
import os
import re
import subprocess
import sys
import tempfile


def atomic_write(path, data):
    path = Path(path)
    permissions = path.stat().st_mode & 0o777 if path.exists() else 0o600
    fd, temporary = tempfile.mkstemp(prefix='.' + path.name + '-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as output:
            output.write(data)
            output.flush()
            os.fsync(output.fileno())
        os.chmod(temporary, permissions)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def validate_profile(data):
    """This setup deliberately uses only simple modifier/key command bindings."""
    seen = set()
    allowed_modifiers = {'alt', 'shift', 'ctrl', 'cmd', 'fn'}
    allowed_keys = set('abcdefghijklmnopqrstuvwxyz0123456789') | {'tab', 'left', 'right', 'up', 'down'}
    for number, line in enumerate(data.decode('utf-8').splitlines(), 1):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        match = re.fullmatch(r'([a-z+ ]+)\s*-\s*([a-z0-9]+)\s*:\s*(.+)', line)
        if not match:
            raise ValueError(f'Unsupported profile syntax on line {number}')
        modifiers, key, command = match.groups()
        mods = [part.strip() for part in modifiers.split('+')]
        if not set(mods) <= allowed_modifiers or len(set(mods)) != len(mods) or key not in allowed_keys:
            raise ValueError(f'Invalid shortcut on line {number}')
        binding = (tuple(sorted(mods)), key)
        if binding in seen:
            raise ValueError(f'Duplicate shortcut on line {number}')
        seen.add(binding)
        check = subprocess.run(['/bin/bash', '-n'], input=command, text=True, capture_output=True)
        if check.returncode:
            raise ValueError(f'Invalid command syntax on line {number}')
    if not seen:
        raise ValueError('Empty shortcut profile')


def apply_mode(mode, config_dir, mode_file, reload_config):
    if mode not in ('dual', 'left'):
        raise ValueError('Mode must be dual or left')
    config_dir, mode_file = Path(config_dir), Path(mode_file)
    with (config_dir / '.keyboard-mode.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        target = (config_dir / ('skhdrc-' + mode)).read_bytes()
        validate_profile(target)
        active = config_dir / 'skhdrc'
        old_config = active.read_bytes()
        old_mode = mode_file.read_bytes() if mode_file.exists() else None
        try:
            atomic_write(active, target)
            reload_config()
            atomic_write(mode_file, (mode + '\n').encode())
        except Exception:
            atomic_write(active, old_config)
            if old_mode is None:
                mode_file.unlink(missing_ok=True)
            else:
                atomic_write(mode_file, old_mode)
            try:
                reload_config()
            except Exception:
                pass
            raise


def reload_skhd():
    # The daemon hotloads files as well; explicit reload avoids relying on that watcher.
    result = subprocess.run(['/opt/homebrew/bin/skhd', '--reload'], capture_output=True, text=True, timeout=3)
    if result.returncode:
        raise RuntimeError('skhd reload failed; check that skhd is running')


if __name__ == '__main__':
    try:
        if len(sys.argv) != 2:
            raise ValueError('Usage: set-keyboard-mode.py dual|left')
        root = Path.home() / '.config'
        apply_mode(sys.argv[1], root / 'skhd', root / 'keyboard-mode', reload_skhd)
        print(sys.argv[1])
    except Exception as exc:
        print('Keyboard mode unchanged: ' + str(exc), file=sys.stderr)
        sys.exit(1)
