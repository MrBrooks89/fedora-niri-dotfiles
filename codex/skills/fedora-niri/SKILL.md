---
name: fedora-niri
description: Manage and troubleshoot this user's Fedora workstation configuration using Niri, Noctalia v5, Kitty, and the tracked Fedora dotfiles bootstrap. Use for desktop layout, displays, keybindings, command-center and capture workflows, bar widgets, coordinated themes, Wayland application behavior, and related dotfile changes. Do not use for Omarchy or Hyprland systems.
---

# Fedora Niri Workstation

Customize the Fedora 44 Niri/Noctalia desktop through the tracked repository at
`~/Documents/.dotfiles`.

## Source of truth

Prefer edits in the repository because the bootstrap links them into the home
configuration:

| Area | Tracked source | Live destination |
| --- | --- | --- |
| Niri | `niri/` | `~/.config/niri/` |
| Noctalia | `noctalia/` | `~/.config/noctalia/` |
| Kitty | `kitty/` | `~/.config/kitty/` |
| Neovim | `nvim/` | `~/.config/nvim/` |
| btop | `btop/` | `~/.config/btop/` |
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

## Desktop architecture

- `Mod+D` opens Noctalia's standard application launcher.
- `Mod+Space` currently opens the experimental native panel
  `mrbrooks/command-center:panel`, tracked under
  `noctalia/plugins/command-center/`. Keep its idle root at six categories,
  nested browsing, and direct root search across applications and leaf actions.
- The command-center plugin's `capture-tools.sh` owns screenshots, Satty annotation, color picking,
  OCR, save/copy/open actions, and the screenshots folder. Niri captures the
  focused window/output; Grim and Slurp capture regions or all outputs.
- Noctalia owns clipboard history, idle locking/suspend, OSD-backed hardware
  controls, screen recording, and coordinated palette resolution.

## Coordinated theming

Noctalia v5 renders built-in templates for Niri, Kitty, btop, and GTK, plus a
tracked user template for Neovim. Edit template sources under
`noctalia/templates/`, not generated outputs such as `niri/noctalia.kdl`.
After template changes, run:

```bash
noctalia msg config-reload
noctalia msg templates-apply
```

Template rendering is asynchronous; poll for the expected generated content
before deciding that generation failed.

## Working method

Read the smallest relevant configuration and current live state before editing.
For monitor issues, identify connectors and logical layout from Niri before
writing output rules. For Noctalia plugins, verify the current v5 plugin ID,
entry ID, dependency, and source; declare bar placement under `[bar.<name>]` and
widget type under `[widget.<name>]`.

When changing the command center or capture tools, preserve direct root search,
category browsing, exact-string dispatch, and safe cancellation. Keep privileged
package operations visible to the user; the bootstrap declares dependencies but
must not be run merely to install one missing package.

Validate only what changed:

```bash
bash -n ~/Documents/.dotfiles/bootstrap-fedora44-niri-v3.sh
niri validate -c ~/Documents/.dotfiles/niri/config.kdl
noctalia config validate ~/Documents/.dotfiles/noctalia/config.toml
bash -n ~/Documents/.dotfiles/noctalia/plugins/command-center/dispatch-action.sh
bash -n ~/Documents/.dotfiles/noctalia/plugins/command-center/capture-tools.sh
bash -n ~/Documents/.dotfiles/noctalia/plugins/command-center/list-applications.sh
noctalia plugins lint ~/Documents/.dotfiles/noctalia/plugins/command-center
git -C ~/Documents/.dotfiles diff --check
```

If a command is unavailable, do not install it solely for validation; run the
remaining checks and state the limitation.
