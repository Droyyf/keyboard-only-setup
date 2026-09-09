# Reproducible macOS Keyboard Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a public repository that installs, verifies, and restores the keyboard-only macOS workflow from a single command.

**Architecture:** Managed configuration lives under `managed/`, while shell entrypoints remain at the repository root. A single standard-library Python installer module performs file backup, atomic replacement, mode activation, and command orchestration. Thin shell scripts invoke it. The installer preserves unowned Hammerspoon startup code and delegates all external side effects through explicitly injected commands for testability.

**Tech Stack:** Bash, Python 3 standard library, Lua/Hammerspoon, Homebrew, Git, GitHub CLI.

**Spec:** `docs/superpowers/specs/2026-09-09-reproducible-macos-keyboard-workflow-design.md`

## Global Constraints

- Target macOS 27.0 and the pinned yabai commit `a42af64b9ba0e6e01d9745c11d486311e04ec0ab`.
- Never modify SIP, approve privacy prompts, modify Raycast private settings, or overwrite `~/.hammerspoon/init.lua`.
- Back up every managed destination before replacement under `~/.keyboard-only-setup/backups/`.
- `install.sh`, `verify.sh`, and `uninstall.sh` must be idempotent and fail closed.
- Use only Python standard library and shell tools available on a default macOS developer installation.

---

### Task 1: Package the current managed workflow and establish repository hygiene

**Files:**
- Create: `.gitignore`
- Create: `managed/hammerspoon/keyboard.lua`
- Create: `managed/skhd/skhdrc-dual`
- Create: `managed/skhd/skhdrc-left`
- Create: `managed/skhd/set-keyboard-mode.py`
- Create: `managed/skhd/win-dir.sh`
- Modify: `tests/test_keyboard.lua`
- Modify: `tests/test_mode_switch.py`
- Modify: `tests/test_profile_contract.py`
- Modify: `tests/test_shortcut_audit.py`
- Modify: `tests/test_window_helper.py`
- Modify: `audit_shortcuts.py`

**Interfaces:**
- Consumes: current verified live configuration at `~/.hammerspoon` and `~/.config/skhd`.
- Produces: repository-local source of truth for all workflow-managed files.

- [ ] **Step 1: Write the failing packaging contract test**

```python
def test_repository_contains_every_managed_install_source():
    for relative_path in (
        "managed/hammerspoon/keyboard.lua",
        "managed/skhd/skhdrc-dual",
        "managed/skhd/skhdrc-left",
        "managed/skhd/set-keyboard-mode.py",
        "managed/skhd/win-dir.sh",
    ):
        assert (ROOT / relative_path).is_file()
```

- [ ] **Step 2: Run the packaging contract test to verify it fails**

Run: `python3 -m unittest tests.test_repository_contract.RepositoryContractTest.test_repository_contains_every_managed_install_source -v`

Expected: FAIL because the `managed/` copies do not exist.

- [ ] **Step 3: Copy the verified live managed files into the repository and add ignore rules**

```text
managed/hammerspoon/keyboard.lua
managed/skhd/skhdrc-dual
managed/skhd/skhdrc-left
managed/skhd/set-keyboard-mode.py
managed/skhd/win-dir.sh
```

Ignore Python bytecode, installer backups, and local environment files.

- [ ] **Step 4: Run all inherited workflow tests and the repository contract test**

Run: `python3 -m unittest discover -s tests -p 'test_*.py' -v && hs -c 'dofile("tests/test_keyboard.lua")' && python3 audit_shortcuts.py`

Expected: all tests and the audit pass.

- [ ] **Step 5: Commit**

```bash
git add .gitignore managed tests audit_shortcuts.py
git commit -m "feat: package managed keyboard workflow"
```

### Task 2: Implement and test backup-safe managed file installation

**Files:**
- Create: `scripts/workflow_install.py`
- Create: `tests/test_installer.py`

**Interfaces:**
- Produces: `install_managed_files(repo_root: Path, target_home: Path, backup_root: Path) -> Path`
- Produces: `activate_mode(target_home: Path, mode: str | None) -> str`
- Produces: `read_manifest(backup_dir: Path) -> dict[str, dict[str, str]]`

- [ ] **Step 1: Write failing tests for backup, restore metadata, and mode handling**

```python
def test_install_backs_up_existing_managed_file_and_replaces_it(self):
    (self.home / ".hammerspoon").mkdir()
    destination = self.home / ".hammerspoon/keyboard.lua"
    destination.write_text("old configuration")
    backup = workflow_install.install_managed_files(ROOT, self.home, self.backups)
    self.assertEqual(destination.read_text(), source_text("managed/hammerspoon/keyboard.lua"))
    self.assertEqual((backup / "files/.hammerspoon/keyboard.lua").read_text(), "old configuration")

def test_install_preserves_valid_existing_mode(self):
    (self.home / ".config").mkdir()
    (self.home / ".config/keyboard-mode").write_text("dual\n")
    workflow_install.activate_mode(self.home, None)
    self.assertEqual((self.home / ".config/keyboard-mode").read_text(), "dual\n")
```

- [ ] **Step 2: Run installer tests to verify they fail**

Run: `python3 -m unittest tests.test_installer -v`

Expected: FAIL with `ModuleNotFoundError: No module named 'scripts.workflow_install'`.

- [ ] **Step 3: Implement the minimal standard-library installer module**

```python
MANAGED_FILES = {
    "managed/hammerspoon/keyboard.lua": ".hammerspoon/keyboard.lua",
    "managed/skhd/skhdrc-dual": ".config/skhd/skhdrc-dual",
    "managed/skhd/skhdrc-left": ".config/skhd/skhdrc-left",
    "managed/skhd/set-keyboard-mode.py": ".config/skhd/set-keyboard-mode.py",
    "managed/skhd/win-dir.sh": ".config/skhd/win-dir.sh",
}

def install_managed_files(repo_root, target_home, backup_root):
    # Create one timestamped backup and atomically replace each listed target.
    ...
```

The implementation writes a JSON manifest recording `present` or `absent` for
each destination and sets executable permissions on the two installed helper
scripts.

- [ ] **Step 4: Run installer tests to verify they pass**

Run: `python3 -m unittest tests.test_installer -v`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/workflow_install.py tests/test_installer.py
git commit -m "feat: add backup-safe workflow installer core"
```

### Task 3: Add installation, verification, and uninstall entrypoints

**Files:**
- Create: `install.sh`
- Create: `verify.sh`
- Create: `uninstall.sh`
- Modify: `scripts/workflow_install.py`
- Modify: `tests/test_installer.py`

**Interfaces:**
- `./install.sh [--dry-run] [--mode dual|left]`
- `./verify.sh [--home PATH]`
- `./uninstall.sh BACKUP_DIRECTORY [--home PATH]`

- [ ] **Step 1: Write failing command-construction and uninstaller tests**

```python
def test_install_command_plan_pins_yabai_source_and_commit(self):
    commands = workflow_install.install_commands(ROOT, self.home)
    self.assertIn("https://github.com/Droyyf/yabai-macos27.git", "\n".join(commands))
    self.assertIn("a42af64b9ba0e6e01d9745c11d486311e04ec0ab", "\n".join(commands))

def test_restore_removes_only_file_created_by_installer(self):
    backup = workflow_install.install_managed_files(ROOT, self.home, self.backups)
    workflow_install.restore_backup(backup, self.home)
    self.assertFalse((self.home / ".hammerspoon/keyboard.lua").exists())
```

- [ ] **Step 2: Run the new tests to verify they fail**

Run: `python3 -m unittest tests.test_installer -v`

Expected: FAIL because `install_commands` and `restore_backup` do not exist.

- [ ] **Step 3: Implement shell entrypoints and the missing installer functions**

```bash
#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")" && pwd)"
exec python3 "$repo_root/scripts/workflow_install.py" install "$@"
```

The install command checks prerequisites, installs Homebrew packages, clones
the pinned source, builds yabai, installs managed files, reloads services, and
runs the verifier. Dry-run emits commands without executing them. The uninstaller
requires an explicit backup directory and validates that it is inside the
workflow backup root before restoration.

- [ ] **Step 4: Run focused entrypoint and installer tests**

Run: `python3 -m unittest tests.test_installer -v && ./install.sh --dry-run --mode left && ./verify.sh --home "$(mktemp -d)"`

Expected: tests pass, dry-run has no side effects, and empty-home verification
reports actionable missing-prerequisite failures.

- [ ] **Step 5: Commit**

```bash
git add install.sh verify.sh uninstall.sh scripts/workflow_install.py tests/test_installer.py
git commit -m "feat: add reproducible install verify and restore commands"
```

### Task 4: Document the public installation and manual authorization boundaries

**Files:**
- Create: `README.md`
- Modify: `METHODOLOGY.md`
- Modify: `RAYCAST_SETUP.md`
- Modify: `CHEATSHEET.md`

**Interfaces:**
- Documents `git clone`, `./install.sh`, `./verify.sh`, and `./uninstall.sh`.
- Documents exact manual settings and the backup recovery contract.

- [ ] **Step 1: Write a failing documentation contract test**

```python
def test_readme_documents_install_verify_restore_and_manual_permissions():
    text = (ROOT / "README.md").read_text()
    for fragment in ("./install.sh", "./verify.sh", "./uninstall.sh", "Accessibility", "Raycast"):
        self.assertIn(fragment, text)
```

- [ ] **Step 2: Run the documentation contract test to verify it fails**

Run: `python3 -m unittest tests.test_repository_contract.RepositoryContractTest.test_readme_documents_install_verify_restore_and_manual_permissions -v`

Expected: FAIL because `README.md` is missing.

- [ ] **Step 3: Write the concise user-facing documentation**

Include prerequisites, clone/install commands, exactly what the installer does,
manual macOS permissions, SIP decision boundary, Raycast settings, verification,
restoration, and customization guidance.

- [ ] **Step 4: Run the complete repository suite**

Run: `python3 -m unittest discover -s tests -p 'test_*.py' -v && hs -c 'dofile("tests/test_keyboard.lua")' && python3 audit_shortcuts.py && ./install.sh --dry-run --mode left`

Expected: all tests pass, Hammerspoon behavior tests pass, audit passes, and
the dry-run makes no machine changes.

- [ ] **Step 5: Commit**

```bash
git add README.md METHODOLOGY.md RAYCAST_SETUP.md CHEATSHEET.md tests/test_repository_contract.py
git commit -m "docs: document reproducible keyboard workflow"
```

### Task 5: Publish and verify the GitHub repository

**Files:**
- Modify: all committed repository files as needed after final verification.

**Interfaces:**
- Produces: public GitHub repository `Droyyf/keyboard-only-setup`.

- [ ] **Step 1: Inspect the staged repository state**

Run: `git status --short && git log --oneline --decorate -5`

Expected: clean working tree with the implementation commits present.

- [ ] **Step 2: Create the public remote and push main**

Run: `gh repo create Droyyf/keyboard-only-setup --public --source=. --remote=origin --push`

Expected: GitHub reports the repository URL and `main` is pushed.

- [ ] **Step 3: Verify public remote contents**

Run: `gh repo view Droyyf/keyboard-only-setup --json url,visibility,defaultBranchRef && git ls-remote --heads origin main`

Expected: public visibility, a `main` default branch, and the pushed main ref.

- [ ] **Step 4: Commit any final verification-only documentation correction**

```bash
git add README.md
git commit -m "docs: finalize installation verification"
git push
```
