---
name: fedora-niri
description: Manage and troubleshoot this user's Fedora workstation configuration using Niri, Noctalia v5, Rofi, Kitty, and the tracked Fedora dotfiles bootstrap. Use for desktop layout, displays, keybindings, command-center and capture workflows, bar widgets, coordinated themes, Wayland application behavior, and related dotfile changes. Do not use for Omarchy or Hyprland systems.
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
| Rofi command center | `rofi/` | `~/.config/rofi/` |
| btop | `btop/` | `~/.config/btop/` |
| Shell | `.zshrc`, `starship.toml` | `~/.zshrc`, `~/.config/starship.toml` |

Read the repository's `AGENTS.md` before changing it. Inspect Git status first
and preserve unrelated work. Do not edit `/usr/share/omarchy`; Omarchy is useful
only as a read-only design reference when the user explicitly asks to reproduce
one of its behaviors.

## Platform rules

- Keep applications native Wayland unless the user explicitly chooses an
  XWayland workaround.
- Fedora 44's `rofi` 2.x package is Wayland-native and replaces the old
  `rofi-wayland` package name.
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
- `Mod+Space` runs `rofi/unified-command-center.sh`. Its combined provider order
  is categories, desktop applications, then actions. Keep the idle root at six
  visible category rows while allowing typed searches to match applications and
  leaf actions.
- The Rofi category and action providers are separate scripts. Category
  selection calls `command-center.sh`; actions may execute directly through the
  same dispatcher. Do not collapse them into one provider, which exposes every
  application or action in the unfiltered root.
- Keep Rofi's mode-next, mode-previous, row-left, row-right, and plain-arrow
  cursor bindings disabled in the unified launcher. Otherwise Left/Right cycles
  into the application provider. Text cursor movement uses `Ctrl+B`/`Ctrl+F`.
- `rofi/capture-tools.sh` owns screenshots, Satty annotation, color picking,
  OCR, save/copy/open actions, and the screenshots folder. Niri captures the
  focused window/output; Grim and Slurp capture regions or all outputs.
- Noctalia owns clipboard history, idle locking/suspend, OSD-backed hardware
  controls, screen recording, and coordinated palette resolution.

## Coordinated theming

Noctalia v5 renders built-in templates for Niri, Kitty, btop, and GTK, plus
tracked user templates for Neovim and Rofi. Edit template sources under
`noctalia/templates/`, not generated outputs such as `rofi/theme.rasi` or
`niri/noctalia.kdl`. After template changes, run:

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
bash -n ~/Documents/.dotfiles/rofi/command-center.sh
bash -n ~/Documents/.dotfiles/rofi/unified-command-center.sh
bash -n ~/Documents/.dotfiles/rofi/command-center-categories-mode.sh
bash -n ~/Documents/.dotfiles/rofi/command-center-mode.sh
bash -n ~/Documents/.dotfiles/rofi/capture-tools.sh
git -C ~/Documents/.dotfiles diff --check
```

If a command is unavailable, do not install it solely for validation; run the
remaining checks and state the limitation.
