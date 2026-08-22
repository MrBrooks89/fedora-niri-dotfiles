# Fedora 44 Minimal + niri / Noctalia Workstation

This repository is a reproducible Fedora workstation build based on **Fedora Everything 44 → Minimal Install**.

Primary desktop stack:

```text
Fedora 44 Minimal
        │
        ▼
       GDM
        │
        ├──────────────┐
        ▼              ▼
      niri           GNOME
        │           fallback /
        ▼           settings
    Noctalia
```

GNOME is kept as a fallback session for graphical GNOME/GTK settings. niri + Noctalia is the normal desktop.

## Repository layout

Expected layout:

```text
fedora-niri-dotfiles/
├── kitty/
├── niri/
│   ├── config.kdl
│   └── screenshot.sh
├── nvim/
├── noctalia/              # optional
├── satty/                 # optional
├── .zshrc
├── starship.toml
├── .gitignore
├── README.md
└── bootstrap-fedora44-niri-v3.sh
```

The bootstrap script creates symlinks:

```text
repo/.zshrc            → ~/.zshrc
repo/starship.toml     → ~/.config/starship.toml
repo/kitty             → ~/.config/kitty
repo/niri              → ~/.config/niri
repo/nvim              → ~/.config/nvim
repo/noctalia          → ~/.config/noctalia
repo/satty             → ~/.config/satty
```

Existing configs are backed up before links are created.

---

## Fresh install using this repository

### 1. Install Fedora

Use:

```text
Fedora Everything 44
Network Install
x86_64
```

Choose **Minimal Install**.

### 2. Update and install Git

```bash
sudo dnf upgrade --refresh
sudo dnf install git
```

### 3. Clone this repository

SSH:

```bash
git clone git@github.com:MrBrooks89/fedora-niri-dotfiles.git ~/.dotfiles
```

HTTPS is easier on a brand-new machine if your GitHub SSH key is not installed yet:

```bash
git clone https://github.com/MrBrooks89/fedora-niri-dotfiles.git ~/.dotfiles
```

Then:

```bash
cd ~/.dotfiles
chmod +x bootstrap-fedora44-niri-v3.sh
```

### 4. Run the bootstrap

Because the script lives inside this repo, **no dotfiles option is required**:

```bash
./bootstrap-fedora44-niri-v3.sh
```

The script automatically uses its own directory as the dotfiles source.

A fuller install:

```bash
./bootstrap-fedora44-niri-v3.sh \
    --with-nerd-font \
    --with-satty-copr \
    --with-docker \
    --with-containerlab
```

To also configure the static network profile interactively:

```bash
./bootstrap-fedora44-niri-v3.sh --all
```

Then reboot:

```bash
sudo reboot
```

---

## Using a different dotfiles repository

The same bootstrap can use another dotfiles repository instead of the repo containing the script.

Example:

```bash
./bootstrap-fedora44-niri-v3.sh \
    --dotfiles-repo https://github.com/anotheruser/dotfiles.git
```

The alternate repo is cloned to:

```text
~/.dotfiles-external
```

You can choose another destination:

```bash
./bootstrap-fedora44-niri-v3.sh \
    --dotfiles-repo https://github.com/anotheruser/dotfiles.git \
    --dotfiles-dir ~/.my-dotfiles
```

Use a specific branch:

```bash
./bootstrap-fedora44-niri-v3.sh \
    --dotfiles-repo https://github.com/anotheruser/dotfiles.git \
    --dotfiles-branch main
```

The alternate repo should follow the same layout:

```text
.zshrc
starship.toml
kitty/
niri/
nvim/
noctalia/      # optional
satty/         # optional
```

---

## Core packages

The bootstrap installs common CLI and development tools including:

```text
zsh
neovim
eza
starship
git
curl
wget
tmux
btop
ripgrep
fd
jq
python3
gcc/g++
make
pciutils
usbutils
rfkill
```

Desktop stack:

```text
niri
Noctalia
Kitty
Firefox
PipeWire
WirePlumber
polkit
xdg-user-dirs
xdg-desktop-portal
xdg-desktop-portal-gtk
xdg-desktop-portal-kde
```

GNOME fallback/settings environment:

```text
gdm
gnome-shell
gnome-session
gnome-control-center
```

---

## Wi-Fi support

Fedora Minimal may not include all wireless firmware/packages that a full desktop edition normally pulls in.

The bootstrap now installs:

```text
NetworkManager-wifi
wpa_supplicant
wireless-regdb
linux-firmware
iwlwifi-mvm-firmware
```

`iwlwifi-mvm-firmware` was required for an Intel Wireless-AC 9260. Without it, the kernel could see the card and load `iwlwifi`, but failed with messages like:

```text
Direct firmware load for iwlwifi-9260-th-b0-jf-b0-46.ucode failed
no suitable firmware found!
```

Useful checks:

```bash
nmcli device status
rfkill list
lspci -nnk | grep -A5 -Ei 'network|wireless'
```

Kernel/firmware troubleshooting:

```bash
sudo journalctl -k -b | grep -iE 'iwl|wifi|firmware'
```

---

## Network configuration

Current static LAN example:

```text
Address: 192.168.4.112/24
Gateway: 192.168.4.1
DNS:     192.168.4.1
```

Run the interactive network setup with:

```bash
./bootstrap-fedora44-niri-v3.sh --configure-network
```

Manual example:

```bash
nmcli connection show
```

```bash
sudo nmcli connection modify "Wired connection 1" \
    ipv4.method manual \
    ipv4.addresses 192.168.4.112/24 \
    ipv4.gateway 192.168.4.1 \
    ipv4.dns 192.168.4.1
```

---

## Zsh + Starship

Zsh is configured as the login shell.

Starship is installed to:

```text
~/.local/bin/starship
```

The repo `.zshrc` should include:

```bash
eval "$(starship init zsh)"
```

Starship config:

```text
~/.config/starship.toml
```

---

## Fonts

The Fedora JetBrains Mono package is installed by default.

For prompt icons and Nerd Font glyphs:

```bash
./bootstrap-fedora44-niri-v3.sh --with-nerd-font
```

Verify:

```bash
fc-match "JetBrainsMono Nerd Font"
```

---

## niri + Noctalia

niri config:

```text
~/.config/niri/config.kdl
```

Noctalia startup:

```kdl
spawn-at-startup "noctalia"
```

Noctalia v5 IPC syntax:

```bash
noctalia msg <command>
```

Power/session menu example:

```kdl
Mod+P { spawn-sh "noctalia msg session-toggle"; }
```

Validate niri config:

```bash
niri validate
```

---

## GTK / libadwaita dark mode

Persistent dark-mode preference:

```bash
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
```

Verify:

```bash
gsettings get org.gnome.desktop.interface color-scheme
```

Useful discovery commands:

```bash
gsettings list-schemas
gsettings list-recursively org.gnome.desktop.interface
gsettings describe org.gnome.desktop.interface color-scheme
gsettings range org.gnome.desktop.interface color-scheme
```

---

## XDG desktop portals

The KDE file chooser portal is preferred for niri.

Config:

```text
~/.config/xdg-desktop-portal/niri-portals.conf
```

```ini
[preferred]
default=gtk;
org.freedesktop.impl.portal.FileChooser=kde;
```

This is important for Firefox file/attachment dialogs.

Check:

```bash
systemctl --user status xdg-desktop-portal
```

---

## Screenshots

Screenshot stack:

```text
slurp → grim → Satty
```

Example helper:

```bash
#!/usr/bin/env bash
set -euo pipefail

geometry="$(slurp)"
[[ -n "$geometry" ]] || exit 0
grim -g "$geometry" - | satty --no-window-decoration -f -
```

Install Satty with:

```bash
./bootstrap-fedora44-niri-v3.sh --with-satty-copr
```

---

## Steam

Steam:
Enables the rpmfusion Nonfree repository and installs steam

```bash
./bootstrap-fedora44-niri-v3.sh --with-steam
```

## Docker + containerlab

Docker:

```bash
./bootstrap-fedora44-niri-v3.sh --with-docker
```

Containerlab:

```bash
./bootstrap-fedora44-niri-v3.sh --with-containerlab
```

Containerlab tooling may require membership in:

```text
docker
clab_admins
```

Verify:

```bash
id
docker ps
containerlab version
```

After group changes, fully log out and back in.

---

## Updating dotfiles

Because the live configs are symlinked to the Git checkout, editing the normal config path edits the repository directly.

Example:

```bash
nvim ~/.config/niri/config.kdl
```

Commit changes:

```bash
cd ~/.dotfiles
git status
git add .
git commit -m "Update desktop configuration"
git push
```

---

## Quick rebuild

```bash
sudo dnf install git

git clone https://github.com/MrBrooks89/fedora-niri-dotfiles.git ~/.dotfiles
cd ~/.dotfiles
chmod +x bootstrap-fedora44-niri-v3.sh

./bootstrap-fedora44-niri-v3.sh \
    --with-nerd-font \
    --with-satty-copr \
    --with-docker \
    --with-containerlab

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
Git-backed dotfiles
```

The repository is the source of truth for the workstation configuration.
