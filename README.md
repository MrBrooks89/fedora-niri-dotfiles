# Fedora 44 Minimal → niri + Noctalia Workstation

This documents the Fedora build assembled from a **Fedora Everything 44 Network Install ISO** using the **Minimal Install** base environment.

The target design is:

```text
Fedora 44 Minimal
├── GDM graphical login
│   ├── niri             ← primary session
│   │   └── Noctalia     ← shell
│   └── GNOME            ← fallback/settings session
├── Zsh
├── Kitty
├── Firefox
├── PipeWire/WirePlumber
├── XDG desktop portals
├── grim + slurp + Satty screenshots
├── Docker/containerlab (optional)
└── user dotfiles under ~/.config
```

The point is to keep the base system small while retaining GNOME as a maintenance/settings environment when a GTK/GNOME setting is easier to manage graphically.

## 1. Base OS installation

Use:

- Fedora Everything 44
- Network Install ISO
- Intel/AMD `x86_64`
- Software Selection: **Minimal Install**

The Everything installer is graphical (Anaconda), but the installed Minimal system initially boots to a CLI.

After first login:

```bash
sudo dnf upgrade --refresh
```

## 2. XDG configuration directory

A Minimal install may not have `~/.config` yet. That is normal.

```bash
mkdir -p ~/.config
```

Existing configuration can be restored under it normally, for example:

```text
~/.config/niri/
~/.config/kitty/
~/.config/noctalia/
~/.config/satty/
```

Avoid using `sudo` for files in your home directory. If ownership gets changed accidentally:

```bash
sudo chown -R "$USER:$USER" ~/.config
```

## 3. Zsh

Install and make it the default shell:

```bash
sudo dnf install zsh
chsh -s "$(command -v zsh)"
```

Log out and back in, then verify:

```bash
echo "$SHELL"
getent passwd "$USER"
```

Expected shell:

```text
/usr/bin/zsh
```

Originally niri was launched from `.zshrc` after a TTY login. Once GDM was added, that autostart block was no longer necessary and should be removed.

## 4. Static IPv4 configuration

Desired address:

```text
IP:      192.168.4.112/24
Gateway: 192.168.4.1
DNS:     192.168.4.1
```

Find the NetworkManager connection:

```bash
nmcli connection show
```

Then modify the correct connection name:

```bash
sudo nmcli connection modify "Wired connection 1" \
    ipv4.method manual \
    ipv4.addresses 192.168.4.112/24 \
    ipv4.gateway 192.168.4.1 \
    ipv4.dns 192.168.4.1
```

Apply it:

```bash
sudo nmcli connection up "Wired connection 1"
```

Be careful doing this over SSH because changing the active connection can interrupt the session.

## 5. niri + Noctalia

On Fedora 44, Noctalia v5 is available from Fedora's default repositories. The Noctalia documentation recommends compositor autostart for niri.

Install:

```bash
sudo dnf install niri noctalia
```

In:

```text
~/.config/niri/config.kdl
```

start Noctalia with:

```kdl
spawn-at-startup "noctalia"
```

Noctalia v5 changed its IPC/keybinding syntax compared with older releases.

For the power/session menu:

```kdl
Mod+P { spawn-sh "noctalia msg session-toggle"; }
```

The current CLI can be explored with:

```bash
noctalia msg --help
```

## 6. GDM + GNOME fallback

The final design uses GDM rather than auto-launching niri from a TTY.

Install only the core GNOME pieces needed for a fallback desktop and graphical settings:

```bash
sudo dnf install \
    gdm \
    gnome-shell \
    gnome-session \
    gnome-control-center
```

Enable graphical boot:

```bash
sudo systemctl set-default graphical.target
sudo systemctl enable gdm
```

Then reboot:

```bash
sudo reboot
```

GDM should offer both **niri** and **GNOME** sessions. Use niri normally and GNOME when you want an easy GUI for GNOME/GTK-oriented settings.

If you previously put this in `~/.zshrc`, remove it once GDM is being used:

```zsh
if [[ -z "$WAYLAND_DISPLAY" && "$XDG_VTNR" == "1" ]]; then
    exec /usr/bin/niri-session
fi
```

## 7. GTK/libadwaita dark mode

Satty initially opened with a light interface. The setting that fixed it was:

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

This persists; it does not need to be placed in `.zshrc`.

Useful discovery commands for future GTK/GNOME settings:

```bash
gsettings list-schemas
gsettings list-recursively org.gnome.desktop.interface
gsettings list-keys org.gnome.desktop.interface
gsettings describe org.gnome.desktop.interface color-scheme
gsettings range org.gnome.desktop.interface color-scheme
```

## 8. Cursor settings

The GTK cursor setting can be inspected with:

```bash
gsettings get org.gnome.desktop.interface cursor-theme
gsettings get org.gnome.desktop.interface cursor-size
```

After installing a Rose Pine cursor theme, use its **exact installed theme directory name**:

```bash
gsettings set org.gnome.desktop.interface cursor-theme 'THEME_DIRECTORY_NAME'
gsettings set org.gnome.desktop.interface cursor-size 24
```

For niri, the equivalent compositor-side configuration is:

```kdl
cursor {
    xcursor-theme "THEME_DIRECTORY_NAME"
    xcursor-size 24
}
```

Find installed cursor themes with:

```bash
find ~/.local/share/icons ~/.icons /usr/share/icons \
    -name index.theme -exec grep -H '^Name=' {} \; 2>/dev/null
```

## 9. Firefox file picker / XDG portals

On the Minimal build, clicking Firefox's attachment control initially did nothing because the desktop portal/file chooser stack was not fully present.

Install:

```bash
sudo dnf install \
    xdg-desktop-portal \
    xdg-desktop-portal-gtk \
    xdg-desktop-portal-kde
```

Create:

```text
~/.config/xdg-desktop-portal/niri-portals.conf
```

with:

```ini
[preferred]
default=gtk;
org.freedesktop.impl.portal.FileChooser=kde;
```

Restart the portal or log out/in:

```bash
systemctl --user restart xdg-desktop-portal
```

Check:

```bash
systemctl --user status xdg-desktop-portal
```

Firefox can be forced to use the portal through `about:config` using its XDG desktop portal file-picker preference if necessary.

## 10. Screenshot stack: grim + slurp + Satty

The screenshot script uses:

- `slurp` — select a Wayland region
- `grim` — capture it
- `satty` — annotate/edit it

Install the Fedora packages:

```bash
sudo dnf install grim slurp wl-clipboard
```

Satty was installed through COPR because it was not available from the enabled Fedora repos at the time of this build:

```bash
sudo dnf install dnf-plugins-core
sudo dnf copr enable mineiro/satty
sudo dnf install satty
```

Screenshot script:

```text
~/.config/niri/screenshot.sh
```

```bash
#!/usr/bin/env bash
set -euo pipefail

geometry="$(slurp)"
[[ -n "$geometry" ]] || exit 0
grim -g "$geometry" - | satty --no-window-decoration -f -
```

Make it executable:

```bash
chmod +x ~/.config/niri/screenshot.sh
```

Satty looks for:

```text
~/.config/satty/config.toml
```

The GTK dark preference described above is what made the Satty UI dark.

## 11. Desktop plumbing worth installing on Minimal

A full Fedora desktop normally supplies these automatically. On a custom Minimal/niri build they should be deliberate:

```bash
sudo dnf install \
    pipewire \
    wireplumber \
    polkit \
    xdg-user-dirs \
    xdg-desktop-portal \
    xdg-desktop-portal-gtk \
    xdg-desktop-portal-kde \
    wl-clipboard
```

These cover audio/session routing, privilege prompts, standard user directories, file pickers/screen sharing integration, and Wayland clipboard utilities.

## 12. Docker and containerlab

Docker CE can be installed from Docker's Fedora repository.

```bash
sudo dnf install dnf-plugins-core

sudo dnf config-manager addrepo \
    --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo

sudo dnf install \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
```

Containerlab:

```bash
bash -c "$(curl -sL https://get.containerlab.dev)"
```

For the VS Code/VSCodium containerlab extension, the user needed membership in both `docker` and `clab_admins`:

```bash
sudo groupadd -f clab_admins
sudo usermod -aG docker,clab_admins "$USER"
```

Completely log out and back in afterward so the session inherits the new groups.

Verify:

```bash
id
docker ps
containerlab version
```

## 13. Current configuration philosophy

The resulting system is intentionally layered:

```text
Fedora Minimal
      │
      ├── system services
      │
      ├── GDM
      │     ├── GNOME fallback/settings
      │     └── niri
      │          └── Noctalia
      │
      ├── XDG portals
      ├── PipeWire/WirePlumber
      ├── GTK/libadwaita settings via gsettings
      └── user applications/config
```

The useful part of this approach is not only lower RAM usage; it is knowing which component owns each desktop function.

When something does not work after a Minimal install, identify the subsystem:

```text
Dark theme / cursor       → GTK/libadwaita + gsettings
File chooser/screen share → xdg-desktop-portal
Audio                     → PipeWire + WirePlumber
Privilege dialogs         → polkit
Wayland screenshot        → grim/slurp/Satty
Session startup           → GDM/niri
Shell                     → Zsh
Containers                → Docker/containerlab
```

## 14. Bootstrap script

Use the accompanying:

```text
bootstrap-fedora44-niri.sh
```

Normal desktop setup:

```bash
chmod +x bootstrap-fedora44-niri.sh
./bootstrap-fedora44-niri.sh
```

Add Satty:

```bash
./bootstrap-fedora44-niri.sh --with-satty-copr
```

Add Docker/containerlab:

```bash
./bootstrap-fedora44-niri.sh \
    --with-docker \
    --with-containerlab
```

Configure the static IP interactively:

```bash
./bootstrap-fedora44-niri.sh --configure-network
```

Everything:

```bash
./bootstrap-fedora44-niri.sh --all
```

The script intentionally **does not overwrite existing user configuration files**. For a truly repeatable rebuild, the next improvement is to keep your niri, Noctalia, Kitty, Satty, Zsh, and other dotfiles in a Git repository and have the bootstrap script clone/symlink them after package installation.
