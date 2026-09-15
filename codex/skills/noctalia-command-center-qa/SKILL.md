---
name: noctalia-command-center-qa
description: Review and test the native Noctalia v5 command-center and capture workflows in this Fedora Niri dotfiles repository. Use for command-center behavior, keyboard navigation, application launching, capture actions, or plugin regressions.
---

# Noctalia Command Center QA

Assess `noctalia/plugins/command-center/` against the repository's required
behavior. Read `AGENTS.md` and the relevant plugin files before choosing static
or live checks. Default to review and diagnosis; modify files only when the user
explicitly asks for a fix.

## Required invariants

- The idle root has six categories, supports nested browsing, and searches both
  applications and leaf actions from the root.
- Typing searches; Up/Down moves the highlighted row; Right/Enter activates it;
  Alt+Left returns; Escape closes the panel.
- Keyboard selection remains visible in the scroll viewport, mouse-wheel
  scrolling still works, and the selected row is visually distinct.
- Application launch data is treated as untrusted input and launched safely.
- Screenshot, Satty annotation, color picker, OCR, copy/save/open, and recording
  entry points remain consolidated in the command center and Capture menu.
- Normal screenshots save under `~/Pictures/Screenshots`; Annotate opens Satty.

Run shell syntax checks for changed helpers and `noctalia plugins lint` when
available. Inspect exact-string dispatch whenever actions or labels change.
Manifest-field changes require disabling and re-enabling the plugin for live
testing; a configuration reload alone is insufficient. Do not mutate live
plugin state unless the user asked for a live test.

Report verified behavior, regressions with file-level evidence, unavailable or
deferred live checks, and whether a plugin reload is required.
