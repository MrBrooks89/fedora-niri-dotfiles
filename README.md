# Fedora 44 Minimal + Niri Workstation

A reproducible Fedora workstation built from **Fedora 44 Minimal** with **niri + Noctalia** as the primary desktop environment.

The goal is to start with a minimal Fedora installation and explicitly install only the desktop components, applications, development tools, and services I actually use.

GNOME is installed only as a fallback desktop and for managing GTK/GNOME settings.

## Desktop Stack

```text
Fedora 44 Minimal
        │
        ▼
       GDM
        │
        ├───────────────┐
        ▼               ▼
      niri            GNOME
        │            fallback /
        │            settings
        ▼
    Noctalia
```

Primary desktop:

- niri
- Noctalia Shell
- Kitty
- Zsh
- Starship
- JetBrains Mono / JetBrainsMono Nerd Font
- Firefox
- PipeWire
- WirePlumber

Fallback desktop:

- GDM
- GNOME Shell
- GNOME Session
- GNOME Control Center

## Repository Structure

The repository is designed to be cloned directly to:

```text
~/.dotfiles
```

Current structure:

```text
~/.dotfiles/
├── kitty/
│   └── ...
│
├── niri/
│   ├── config.kdl
│   ├── screenshot.sh
│   └── ...
│
├── nvim/
│   └── ...
│
├── .gitignore
├── .zshrc
├── starship.toml
├── bootstrap-fedora44-niri-v2.sh
└── FEDORA44_NIRI_BUILD.md
```

The bootstrap script can symlink these files into their normal locations:

```text
~/.dotfiles/.zshrc
    → ~/.zshrc

~/.dotfiles/starship.toml
    → ~/.config/starship.toml

~/.dotfiles/kitty/
    → ~/.config/kitty/

~/.dotfiles/niri/
    → ~/.config/niri/

~/.dotfiles/nvim/
    → ~/.config/nvim/
```

This keeps the Git repository as the source of truth.

Editing:

```bash
nvim ~/.config/niri/config.kdl
```

therefore modifies the configuration stored in the dotfiles repository.

---

# Fresh Fedora Installation

## 1. Install Fedora

Download:

```text
Fedora Everything 44
Network Install
x86_64
```

During installation select:

```text
Minimal Install
```

The installer itself is graphical, but the installed system initially contains only the minimal CLI environment.

Boot the new system and log in.

## 2. Update Fedora

```bash
sudo dnf upgrade --refresh
```

## 3. Install Git

Git is needed to retrieve this repository.

```bash
sudo dnf install git
```

## 4. Clone the Dotfiles

Clone the repository directly into `~/.dotfiles`:

```bash
git clone git@github.com:MrBrooks89/fedora-niri-dotfiles.git ~/.dotfiles
```

Then:

```bash
cd ~/.dotfiles
```

Make the bootstrap script executable:

```bash
chmod +x bootstrap-fedora44-niri-v2.sh
```

## 5. Run the Bootstrap Script

Basic installation:

```bash
./bootstrap-fedora44-niri-v2.sh
```

Optional components can also be installed.

For example:

```bash
./bootstrap-fedora44-niri-v2.sh \
    --with-nerd-font \
    --with-satty-copr \
    --with-docker \
    --with-containerlab
```

To include the static network configuration:

```bash
./bootstrap-fedora44-niri-v2.sh --all
```

The network portion is intentionally interactive so the script does not accidentally modify the wrong NetworkManager connection.

---

# Core Applications and Utilities

The workstation includes tools such as:

```text
zsh
git
curl
wget
vim
neovim
tmux
btop
eza
ripgrep
fd
jq
python
gcc
make
kitty
firefox
starship
```

## Zsh

Zsh is configured as the login shell:

```bash
chsh -s /usr/bin/zsh
```

Configuration:

```text
~/.zshrc
```

is managed from:

```text
~/.dotfiles/.zshrc
```

## Starship

Starship provides the shell prompt.

Configuration:

```text
~/.config/starship.toml
```

Repository source:

```text
~/.dotfiles/starship.toml
```

Zsh should contain:

```bash
eval "$(starship init zsh)"
```

---

# Fonts

The system uses **JetBrains Mono**.

The normal Fedora JetBrains Mono font package is installed.

For terminal icons and Starship glyphs, the **JetBrainsMono Nerd Font** can additionally be installed by running the bootstrap script with:

```bash
--with-nerd-font
```

The Nerd Font is installed under:

```text
~/.local/share/fonts/
```

Verify:

```bash
fc-list | grep -i jetbrains
```

or:

```bash
fc-match "JetBrainsMono Nerd Font"
```

---

# Niri

niri is the primary Wayland compositor.

Configuration:

```text
~/.config/niri/config.kdl
```

Repository source:

```text
~/.dotfiles/niri/config.kdl
```

Noctalia is launched by niri using:

```kdl
spawn-at-startup "noctalia"
```

---

# Noctalia

Noctalia provides the desktop shell.

It handles components such as:

- panel
- launcher
- session menu
- desktop controls
- wallpaper management

Noctalia v5 changed its IPC syntax from older releases.

Current commands use:

```bash
noctalia msg <command>
```

Available commands can be discovered with:

```bash
noctalia msg --help
```

For example, the niri power/session menu binding is:

```kdl
Mod+P { spawn-sh "noctalia msg session-toggle"; }
```

---

# GDM + GNOME Fallback

GDM provides the graphical login screen.

The following GNOME components are installed:

```text
gdm
gnome-shell
gnome-session
gnome-control-center
```

The full Fedora Workstation package set is not required.

GDM provides two useful sessions:

```text
GDM
 │
 ├── niri
 │     └── primary desktop
 │
 └── GNOME
       └── fallback / settings
```

GNOME is useful when a GTK/GNOME setting is easier to manage graphically.

Graphical boot is enabled with:

```bash
sudo systemctl set-default graphical.target
sudo systemctl enable gdm
```

---

# GTK / libadwaita Dark Mode

GTK applications initially used the light color scheme.

The persistent dark-mode preference is:

```bash
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
```

Verify:

```bash
gsettings get org.gnome.desktop.interface color-scheme
```

Expected:

```text
'prefer-dark'
```

Useful commands for discovering GTK/GNOME settings:

```bash
gsettings list-schemas
```

Search for a schema:

```bash
gsettings list-schemas | grep -i interface
```

Inspect all settings:

```bash
gsettings list-recursively org.gnome.desktop.interface
```

Describe a setting:

```bash
gsettings describe org.gnome.desktop.interface color-scheme
```

Display valid values:

```bash
gsettings range org.gnome.desktop.interface color-scheme
```

---

# Cursor Theme

GTK cursor configuration can be inspected with:

```bash
gsettings get org.gnome.desktop.interface cursor-theme
gsettings get org.gnome.desktop.interface cursor-size
```

Example:

```text
org.gnome.desktop.interface cursor-size 24
org.gnome.desktop.interface cursor-theme 'Adwaita'
```

After installing a custom cursor theme:

```bash
gsettings set org.gnome.desktop.interface cursor-theme 'THEME_NAME'
```

For niri:

```kdl
cursor {
    xcursor-theme "THEME_NAME"
    xcursor-size 24
}
```

---

# XDG Desktop Portals

A minimal Fedora installation does not automatically include all the desktop integration normally provided by Workstation.

The system uses:

```text
xdg-desktop-portal
xdg-desktop-portal-gtk
xdg-desktop-portal-kde
```

These are important for functionality such as:

- Firefox file selection
- attachment dialogs
- screen sharing
- desktop integration

The KDE portal is used for the file chooser.

Configuration:

```text
~/.config/xdg-desktop-portal/niri-portals.conf
```

Example:

```ini
[preferred]
default=gtk;
org.freedesktop.impl.portal.FileChooser=kde;
```

Check portal status:

```bash
systemctl --user status xdg-desktop-portal
```

---

# Audio

Audio is provided by:

```text
PipeWire
WirePlumber
```

These provide the audio infrastructure normally installed automatically by Fedora desktop editions.

---

# Screenshots

The Wayland screenshot stack consists of:

```text
slurp
  ↓
select region

grim
  ↓
capture image

satty
  ↓
annotate/edit
```

Screenshot script:

```text
~/.config/niri/screenshot.sh
```

Example:

```bash
#!/usr/bin/env bash

geometry="$(slurp)"
[[ -n "$geometry" ]] || exit 0

grim -g "$geometry" - | satty --no-window-decoration -f -
```

Satty is installed using COPR:

```bash
sudo dnf copr enable mineiro/satty
sudo dnf install satty
```

Satty uses the GTK/libadwaita color preference, so dark mode is controlled by:

```bash
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
```

---

# Neovim

Neovim configuration is stored in:

```text
~/.dotfiles/nvim/
```

and linked to:

```text
~/.config/nvim/
```

Verify:

```bash
nvim --version
```

Because the complete Neovim configuration is stored in Git, plugins and editor behavior can be reconstructed automatically after reinstalling Fedora.

---

# Docker

Docker support is optional.

Install through the bootstrap script with:

```bash
--with-docker
```

The current user is added to:

```text
docker
```

After installation, completely log out and back in before testing:

```bash
docker ps
```

---

# Containerlab

Containerlab support is optional:

```bash
--with-containerlab
```

The workstation uses the groups:

```text
docker
clab_admins
```

Verify:

```bash
id
```

The VS Code/VSCodium Containerlab extension requires the appropriate group permissions.

After changing group membership, completely log out and back in.

---

# Network Configuration

Current static LAN configuration:

```text
Address: 192.168.4.112/24
Gateway: 192.168.4.1
DNS:     192.168.4.1
```

Find the NetworkManager connection:

```bash
nmcli connection show
```

Example configuration:

```bash
sudo nmcli connection modify "Wired connection 1" \
    ipv4.method manual \
    ipv4.addresses 192.168.4.112/24 \
    ipv4.gateway 192.168.4.1 \
    ipv4.dns 192.168.4.1
```

Activate:

```bash
sudo nmcli connection up "Wired connection 1"
```

The bootstrap script can configure this interactively with:

```bash
--configure-network
```

---

# Updating Dotfiles

Because the live configuration is linked to this repository, configuration changes can be committed directly.

Check:

```bash
cd ~/.dotfiles
git status
```

Commit changes:

```bash
git add .
git commit -m "Update desktop configuration"
git push
```

Examples:

```bash
git commit -m "Update niri keybindings"
```

```bash
git commit -m "Update Neovim config"
```

```bash
git commit -m "Update Kitty theme"
```

---

# Fresh Install Recovery

The eventual goal is for a fresh Fedora installation to require approximately:

```bash
sudo dnf install git
```

Then:

```bash
git clone git@github.com:MrBrooks89/fedora-niri-dotfiles.git ~/.dotfiles
```

Then:

```bash
cd ~/.dotfiles
chmod +x bootstrap-fedora44-niri-v2.sh
./bootstrap-fedora44-niri-v2.sh \
    --with-nerd-font \
    --with-satty-copr \
    --with-docker \
    --with-containerlab
```

Finally:

```bash
sudo reboot
```

After reboot:

```text
GDM
 ↓
niri
 ↓
Noctalia
 ↓
Kitty / Zsh / Starship
 ↓
existing dotfiles restored
```

The repository serves as the **single source of truth for the workstation configuration**.

---

# Useful Verification Commands

Check desktop components:

```bash
command -v niri
command -v noctalia
command -v kitty
```

Check development tools:

```bash
command -v nvim
command -v eza
command -v starship
```

Check fonts:

```bash
fc-match "JetBrainsMono Nerd Font"
```

Check GTK theme:

```bash
gsettings get org.gnome.desktop.interface color-scheme
```

Check portal:

```bash
systemctl --user status xdg-desktop-portal
```

Check groups:

```bash
id
```

Check Docker:

```bash
docker ps
```

Check memory:

```bash
free -h
```

or:

```bash
btop
```

## Philosophy

Instead of starting with a complete desktop environment and removing unwanted components, this build starts with Fedora Minimal and adds each required layer deliberately:

```text
Fedora
  ↓
system services
  ↓
GDM
  ↓
niri
  ↓
Noctalia
  ↓
desktop plumbing
  ↓
applications
  ↓
dotfiles
```

This keeps the workstation relatively lightweight while making it clear which component is responsible for each part of the desktop.