# Fedora Niri Dotfiles

This repository provisions Mr. Brooks' Fedora 44 workstation. Niri and
Noctalia v5 are the primary desktop; GNOME is only a fallback session.

## Configuration ownership

- `niri/` is linked to `~/.config/niri`.
- `noctalia/` is linked to `~/.config/noctalia`.
- `kitty/` and `nvim/` are linked to their matching `~/.config` directories.
- `.zshrc` and `starship.toml` are linked into the home configuration.
- `bootstrap-fedora44-niri-v3.sh` installs packages and creates those links.
- `codex/skills/fedora-niri/` is linked to `~/.codex/skills/fedora-niri`.

Edit the tracked source files, not the linked destinations, unless the user
explicitly asks for a live-only experiment. Preserve unrelated user changes.

## Desktop conventions

- Keep the normal desktop native Wayland. Do not solve application problems by
  forcing XWayland unless the user explicitly requests it.
- Use Niri KDL syntax and Noctalia v5 TOML. Do not copy Hyprland or Noctalia v4
  settings into these files.
- Noctalia's tracked TOML is the declarative base. Remember that
  `~/.local/state/noctalia/settings.toml` contains GUI overrides and wins over it.
- Keep machine secrets and Codex authentication out of Git. Never add
  `~/.codex/auth.json`, `.env` files, API keys, or tokens.
- Do not execute the full bootstrap merely to validate an edit; it performs
  package, service, shell, and desktop changes.

## Validation

Run checks relevant to the files changed:

```bash
bash -n bootstrap-fedora44-niri-v3.sh
niri validate -c niri/config.kdl
noctalia config validate noctalia/config.toml
python3 -c 'import json; json.load(open("noctalia/palettes/DraculaMrBrooks.json"))'
git diff --check
```

If a validator is unavailable, report that clearly and still run the remaining
static checks. For bootstrap changes, also confirm `--help` parses without
performing installation.

