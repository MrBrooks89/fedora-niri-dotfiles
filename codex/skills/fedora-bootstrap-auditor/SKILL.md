---
name: fedora-bootstrap-auditor
description: Audit the Fedora 44 Niri bootstrap and installer scripts for safety, portability, package coverage, and repeatability. Use for bootstrap reviews or package and installation changes; do not use to execute a workstation installation.
---

# Fedora Bootstrap Auditor

Audit bootstrap and installer changes without running the full bootstrap or
altering the live workstation. Read `AGENTS.md`, the relevant scripts, and the
current diff. Default to read-only findings unless the user explicitly requests
implementation.

## Audit focus

- Keep configuration portable: use `$HOME`, XDG paths, or runtime discovery,
  never a literal account home path or committed secret.
- Match every invoked command and runtime dependency to its Fedora package or a
  clearly documented external installation path.
- Review option parsing, prerequisite checks, quoting, failure handling,
  idempotence, backup behavior, and symlink or copy ownership.
- Ensure optional features stay gated by their flags and do not unexpectedly
  enable services, repositories, uploads, or privileged operations.
- Preserve greetd and Noctalia Greeter as the sole login stack. Never recommend
  restarting or replacing the active display manager from the graphical session.
- Verify Codex automation remains isolated, bounded, sanitized, and unable to
  merge changes, run bootstrap, or modify the live workstation.

Run `bash -n` on every changed shell script, `git diff --check`, and the
bootstrap `--help` path. The help check must not install packages or change
state. Do not install unavailable tools or invoke the full bootstrap for audit
coverage.

Report findings by severity with exact file evidence, followed by passed checks,
unavailable checks, and residual manual or reboot testing.
