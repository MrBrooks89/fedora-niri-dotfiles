---
name: fedora-niri
description: Manage and troubleshoot this user's Fedora workstation configuration using Niri, Noctalia v5, Kitty, and the fedora-niri-dotfiles bootstrap. Use for desktop layout, displays, keybindings, bar widgets, themes, Wayland application behavior, and related dotfile changes. Do not use for Omarchy or Hyprland systems.
---

# Fedora Niri Workstation

Customize the Fedora 44 Niri/Noctalia desktop through the tracked repository at
`~/Documents/fedora-niri-dotfiles`.

## Source of truth

Prefer edits in the repository because the bootstrap links them into the home
configuration:

| Area | Tracked source | Live destination |
| --- | --- | --- |
| Niri | `niri/` | `~/.config/niri/` |
| Noctalia | `noctalia/` | `~/.config/noctalia/` |
| Kitty | `kitty/` | `~/.config/kitty/` |
| Neovim | `nvim/` | `~/.config/nvim/` |
| Shell | `.zshrc`, `starship.toml` | `~/.zshrc`, `~/.config/starship.toml` |

Read the repository's `AGENTS.md` before changing it. Inspect Git status first
and preserve unrelated work. Do not edit `/usr/share/omarchy`; Omarchy is useful
only as a read-only design reference when the user explicitly asks to reproduce
one of its behaviors.

## Platform rules

- Keep applications native Wayland unless the user explicitly chooses an
  XWayland workaround.
- Use current Niri KDL and Noctalia v5 TOML. Treat old Noctalia Shell v4 QML,
  JSON, and Home Manager options as migration inputs, not valid v5 settings.
- Check `~/.local/state/noctalia/settings.toml` when a tracked Noctalia setting
  appears ignored; GUI-managed state has higher precedence.
- Keep authentication and secrets out of the repository. Codex credentials stay
  under `~/.codex` and must never be copied into dotfiles.
- Do not run the complete bootstrap without explicit authorization. It changes
  installed packages, services, the login shell, and linked configuration.

## Working method

Read the smallest relevant configuration and current live state before editing.
For monitor issues, identify connectors and logical layout from Niri before
writing output rules. For Noctalia plugins, verify the current v5 plugin ID,
entry ID, dependency, and source; declare bar placement under `[bar.<name>]` and
widget type under `[widget.<name>]`.

Validate only what changed:

```bash
bash -n ~/Documents/fedora-niri-dotfiles/bootstrap-fedora44-niri-v3.sh
niri validate -c ~/Documents/fedora-niri-dotfiles/niri/config.kdl
noctalia config validate ~/Documents/fedora-niri-dotfiles/noctalia/config.toml
git -C ~/Documents/fedora-niri-dotfiles diff --check
```

If a command is unavailable, do not install it solely for validation; run the
remaining checks and state the limitation.

