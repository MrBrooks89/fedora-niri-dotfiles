---
name: fedora-dotfiles-validator
description: Validate changes to this Fedora Niri dotfiles repository and report evidence without modifying files. Use for pre-commit, pre-PR, regression, or independent read-only validation; do not use to implement fixes.
---

# Fedora Dotfiles Validator

Validate the repository as a read-only reviewer. Read `AGENTS.md`, inspect the
current diff and status, and select every check relevant to the changed files.
Do not edit files, install missing validators, run the full bootstrap, or change
the live workstation.

## Validation method

- Run `git diff --check` for every change set.
- Run the file-specific commands listed in `AGENTS.md`, including shell syntax,
  Niri, Noctalia, plugin, and JSON checks when their inputs changed.
- For bootstrap changes, also run its `--help` path and confirm that it exits
  without installation or other workstation changes.
- Inspect the diff for credentials, logs, machine-specific paths, generated
  theme outputs, and unrelated edits.
- Treat an unavailable validator as a limitation, not permission to install it.
  Continue with all remaining checks.

Report commands and outcomes as passed, failed, or unavailable. Include concise
failure evidence, any manual checks still required, and an overall readiness
assessment. Do not silently repair failures.
