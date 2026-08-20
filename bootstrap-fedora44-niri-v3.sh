#!/usr/bin/env bash
set -Eeuo pipefail

# Fedora 44 Minimal -> niri + Noctalia workstation bootstrap
#
# Run as your normal user, NOT root.
#
# Default behavior:
#   - Uses the directory containing this script as the dotfiles source.
#   - This is ideal when the repo itself contains this bootstrap script.
#
# Alternate dotfiles:
#   --dotfiles-repo URL
#       Clone/update another repo and use its dotfiles instead.
#
# Expected dotfiles layout:
#
#   repo/
#   ├── .zshrc
#   ├── starship.toml          # optional
#   ├── kitty/
#   ├── niri/
#   ├── nvim/
#   ├── noctalia/              # optional
#   └── satty/                 # optional
#
# Symlink targets:
#   ~/.zshrc
#   ~/.config/starship.toml
#   ~/.config/kitty
#   ~/.config/niri
#   ~/.config/nvim
#   ~/.config/noctalia
#   ~/.config/satty
#
# Existing configs are backed up before symlinks are created.

FEDORA_MAJOR="44"

STATIC_IP="192.168.4.112/24"
STATIC_GW="192.168.4.1"
STATIC_DNS="192.168.4.1"

WITH_DOCKER=0
WITH_CONTAINERLAB=0
WITH_SATTY_COPR=0
WITH_NERD_FONT=0
CONFIGURE_NETWORK=0

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_REPO=""
DOTFILES_BRANCH=""
DOTFILES_DIR="$SCRIPT_DIR"
EXTERNAL_DOTFILES_DIR="$HOME/.dotfiles-external"

usage() {
    cat <<'EOF'
Usage: bootstrap-fedora44-niri-v3.sh [options]

Options:
  --dotfiles-repo URL      Clone/update an alternate dotfiles Git repository
  --dotfiles-branch NAME   Optional branch for the alternate repo
  --dotfiles-dir PATH      Destination for alternate repo
                           (default: ~/.dotfiles-external)
  --with-nerd-font         Install JetBrainsMono Nerd Font
  --with-satty-copr        Enable mineiro/satty COPR and install Satty
  --with-docker            Install Docker CE and add current user to docker
  --with-containerlab      Install containerlab and add current user to clab_admins
  --configure-network      Configure 192.168.4.112/24, gateway/DNS 192.168.4.1
  --all                    Enable all optional software
  -h, --help               Show this help

Default dotfiles behavior:
  If no --dotfiles-repo is supplied, the script uses the directory that
  contains this script as the dotfiles source.

Alternate repo example:
  ./bootstrap-fedora44-niri-v3.sh \
      --dotfiles-repo https://github.com/someuser/dotfiles.git \
      --with-nerd-font
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dotfiles-repo)
            [[ $# -ge 2 ]] || { echo "--dotfiles-repo requires a URL" >&2; exit 2; }
            DOTFILES_REPO="$2"
            shift
            ;;
        --dotfiles-branch)
            [[ $# -ge 2 ]] || { echo "--dotfiles-branch requires a branch name" >&2; exit 2; }
            DOTFILES_BRANCH="$2"
            shift
            ;;
        --dotfiles-dir)
            [[ $# -ge 2 ]] || { echo "--dotfiles-dir requires a path" >&2; exit 2; }
            EXTERNAL_DOTFILES_DIR="$2"
            shift
            ;;
        --with-docker)       WITH_DOCKER=1 ;;
        --with-containerlab) WITH_CONTAINERLAB=1 ;;
        --with-satty-copr)   WITH_SATTY_COPR=1 ;;
        --with-nerd-font)    WITH_NERD_FONT=1 ;;
        --configure-network) CONFIGURE_NETWORK=1 ;;
        --all)
            WITH_DOCKER=1
            WITH_CONTAINERLAB=1
            WITH_SATTY_COPR=1
            WITH_NERD_FONT=1
            CONFIGURE_NETWORK=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 2
            ;;
    esac
    shift
done

if [[ $EUID -eq 0 ]]; then
    echo "Run this script as your normal user, not root." >&2
    exit 1
fi

if [[ ! -r /etc/fedora-release ]]; then
    echo "This script is intended for Fedora." >&2
    exit 1
fi

CURRENT_MAJOR="$(rpm -E %fedora)"
if [[ "$CURRENT_MAJOR" != "$FEDORA_MAJOR" ]]; then
    echo "WARNING: written for Fedora $FEDORA_MAJOR; detected Fedora $CURRENT_MAJOR."
    read -r -p "Continue anyway? [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] || exit 1
fi

timestamp="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$HOME/.dotfiles-backup-$timestamp"

backup_and_link() {
    local source="$1"
    local target="$2"

    [[ -e "$source" || -L "$source" ]] || return 0

    mkdir -p "$(dirname "$target")"

    if [[ -L "$target" ]]; then
        local current desired
        current="$(readlink -f "$target" 2>/dev/null || true)"
        desired="$(readlink -f "$source" 2>/dev/null || true)"

        if [[ "$current" == "$desired" ]]; then
            echo "    already linked: $target"
            return 0
        fi
    fi

    if [[ -e "$target" || -L "$target" ]]; then
        local relative="${target#$HOME/}"
        mkdir -p "$BACKUP_DIR/$(dirname "$relative")"
        mv "$target" "$BACKUP_DIR/$relative"
        echo "    backed up: $target -> $BACKUP_DIR/$relative"
    fi

    ln -s "$source" "$target"
    echo "    linked: $target -> $source"
}

echo "==> Updating Fedora"
sudo dnf -y upgrade --refresh

echo "==> Installing base CLI/development/networking utilities"
sudo dnf -y install \
    zsh git curl wget vim-enhanced nano tmux btop \
    neovim eza \
    python3 python3-pip gcc gcc-c++ make \
    unzip tar rsync jq ripgrep fd-find \
    pciutils usbutils rfkill \
    NetworkManager \
    NetworkManager-wifi \
    wpa_supplicant \
    wireless-regdb \
    linux-firmware \
    iwlwifi-mvm-firmware \
    jetbrains-mono-fonts

echo "==> Enabling NetworkManager"
sudo systemctl enable --now NetworkManager

echo "==> Loading/reloading Intel iwlwifi driver if Intel wireless hardware is present"
if command -v lspci >/dev/null 2>&1 && \
   lspci -nn | grep -qiE 'Intel Corporation.*(Network controller|Wireless|Wi-Fi)'; then

    # Reload after firmware install so Wi-Fi can become available immediately
    # without requiring the first reboot.
    sudo modprobe -r iwlwifi 2>/dev/null || true
    sudo modprobe iwlwifi
    sleep 2

    nmcli radio wifi on 2>/dev/null || true

    echo "    Intel wireless status:"
    nmcli device status || true
fi

echo "==> Installing niri/Noctalia desktop components"
sudo dnf -y install \
    niri noctalia kitty firefox dolphin \
    pipewire wireplumber \
    xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-kde \
    xdg-user-dirs \
    polkit \
    grim slurp wl-clipboard

echo "==> Installing GDM + minimal GNOME fallback/settings desktop"
sudo dnf -y install \
    gdm gnome-shell gnome-session gnome-control-center

echo "==> Installing Starship"
mkdir -p "$HOME/.local/bin"

if ! command -v starship >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/starship" ]]; then
    curl -sS https://starship.rs/install.sh | \
        sh -s -- -y -b "$HOME/.local/bin"
fi

if [[ ! -f "$HOME/.zprofile" ]]; then
    cat > "$HOME/.zprofile" <<'EOF'
export PATH="$HOME/.local/bin:$PATH"
EOF
elif ! grep -Fq '$HOME/.local/bin' "$HOME/.zprofile"; then
    cat >> "$HOME/.zprofile" <<'EOF'

# User-local binaries
export PATH="$HOME/.local/bin:$PATH"
EOF
fi

export PATH="$HOME/.local/bin:$PATH"

if [[ "$WITH_NERD_FONT" -eq 1 ]]; then
    echo "==> Installing JetBrainsMono Nerd Font"

    FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerd"
    mkdir -p "$FONT_DIR"

    tmp_font="$(mktemp --suffix=.tar.xz)"

    curl -fL \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz" \
        -o "$tmp_font"

    tar -xJf "$tmp_font" -C "$FONT_DIR"
    rm -f "$tmp_font"

    fc-cache -f "$FONT_DIR"
else
    echo "NOTE: Fedora JetBrains Mono is installed."
    echo "      Use --with-nerd-font if your prompt/icons need Nerd Font glyphs."
fi

echo "==> Setting Zsh as login shell"
ZSH_PATH="$(command -v zsh)"

if [[ "${SHELL:-}" != "$ZSH_PATH" ]]; then
    chsh -s "$ZSH_PATH"
fi

echo "==> Creating base XDG directories"
mkdir -p \
    "$HOME/.config" \
    "$HOME/.config/xdg-desktop-portal" \
    "$HOME/Pictures/Screenshots"

# ----------------------------------------------------------------------
# Select dotfiles source
# ----------------------------------------------------------------------
if [[ -n "$DOTFILES_REPO" ]]; then
    DOTFILES_DIR="$EXTERNAL_DOTFILES_DIR"

    echo "==> Using alternate dotfiles repository"
    echo "    repo: $DOTFILES_REPO"
    echo "    dir:  $DOTFILES_DIR"

    if [[ -d "$DOTFILES_DIR/.git" ]]; then
        git -C "$DOTFILES_DIR" fetch --all --prune

        if [[ -n "$DOTFILES_BRANCH" ]]; then
            git -C "$DOTFILES_DIR" checkout "$DOTFILES_BRANCH"
            git -C "$DOTFILES_DIR" pull --ff-only origin "$DOTFILES_BRANCH"
        else
            git -C "$DOTFILES_DIR" pull --ff-only
        fi

    elif [[ -e "$DOTFILES_DIR" ]]; then
        echo "ERROR: $DOTFILES_DIR exists but is not a Git repository." >&2
        exit 1

    else
        if [[ -n "$DOTFILES_BRANCH" ]]; then
            git clone --branch "$DOTFILES_BRANCH" "$DOTFILES_REPO" "$DOTFILES_DIR"
        else
            git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
        fi
    fi
else
    echo "==> Using dotfiles from this repository"
    echo "    $DOTFILES_DIR"
fi

# ----------------------------------------------------------------------
# Restore/symlink dotfiles
# ----------------------------------------------------------------------
echo "==> Linking dotfiles"

backup_and_link "$DOTFILES_DIR/.zshrc"        "$HOME/.zshrc"
backup_and_link "$DOTFILES_DIR/starship.toml" "$HOME/.config/starship.toml"
backup_and_link "$DOTFILES_DIR/kitty"         "$HOME/.config/kitty"
backup_and_link "$DOTFILES_DIR/niri"          "$HOME/.config/niri"
backup_and_link "$DOTFILES_DIR/nvim"          "$HOME/.config/nvim"
backup_and_link "$DOTFILES_DIR/noctalia"      "$HOME/.config/noctalia"
backup_and_link "$DOTFILES_DIR/satty"         "$HOME/.config/satty"

if [[ -d "$BACKUP_DIR" ]]; then
    echo "    previous configs saved under: $BACKUP_DIR"
fi

# ----------------------------------------------------------------------
# Fallback configs only when selected dotfiles repo did not provide them
# ----------------------------------------------------------------------
NIRI_DIR="$HOME/.config/niri"
NIRI_CONFIG="$NIRI_DIR/config.kdl"

if [[ ! -e "$NIRI_CONFIG" ]]; then
    mkdir -p "$NIRI_DIR"

    cat > "$NIRI_CONFIG" <<'EOF'
// Minimal fallback niri config.
// Normally restore your real config from your dotfiles repository.

spawn-at-startup "noctalia"

binds {
    Mod+P { spawn-sh "noctalia msg session-toggle"; }
}
EOF
fi

SCREENSHOT="$HOME/.config/niri/screenshot.sh"

if [[ ! -e "$SCREENSHOT" ]]; then
    cat > "$SCREENSHOT" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

geometry="$(slurp)"
[[ -n "$geometry" ]] || exit 0

grim -g "$geometry" - | satty --no-window-decoration -f -
EOF

    chmod +x "$SCREENSHOT"
fi

if [[ ! -e "$HOME/.zshrc" ]]; then
    cat > "$HOME/.zshrc" <<'EOF'
eval "$(starship init zsh)"
EOF
elif ! grep -Fq 'starship init zsh' "$HOME/.zshrc"; then
    echo 'NOTE: ~/.zshrc does not contain: eval "$(starship init zsh)"'
fi

echo "==> Setting GTK/libadwaita preference to dark"
if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || true
fi

echo "==> Configuring preferred KDE file chooser portal for niri"
PORTAL_CONFIG="$HOME/.config/xdg-desktop-portal/niri-portals.conf"

if [[ ! -e "$PORTAL_CONFIG" ]]; then
    cat > "$PORTAL_CONFIG" <<'EOF'
[preferred]
default=gtk;
org.freedesktop.impl.portal.FileChooser=kde;
EOF
fi

if [[ "$WITH_SATTY_COPR" -eq 1 ]]; then
    echo "==> Installing Satty from COPR"

    sudo dnf -y install dnf-plugins-core
    sudo dnf -y copr enable mineiro/satty
    sudo dnf -y install satty
else
    echo "NOTE: Satty not installed. Use --with-satty-copr if needed."
fi

if [[ "$WITH_DOCKER" -eq 1 ]]; then
    echo "==> Installing Docker CE"

    sudo dnf -y install dnf-plugins-core

    if ! sudo dnf repolist --all | grep -q 'docker-ce-stable'; then
        sudo dnf config-manager addrepo \
            --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo
    fi

    sudo dnf -y install \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    sudo systemctl enable --now docker
    sudo usermod -aG docker "$USER"
fi

if [[ "$WITH_CONTAINERLAB" -eq 1 ]]; then
    echo "==> Installing containerlab"

    bash -c "$(curl -sL https://get.containerlab.dev)"

    if ! getent group clab_admins >/dev/null; then
        sudo groupadd clab_admins
    fi

    sudo usermod -aG clab_admins "$USER"

    if getent group docker >/dev/null; then
        sudo usermod -aG docker "$USER"
    fi
fi

if [[ "$CONFIGURE_NETWORK" -eq 1 ]]; then
    echo
    echo "==> Static network configuration"
    echo "Target: $STATIC_IP  gateway: $STATIC_GW  DNS: $STATIC_DNS"
    echo

    nmcli -f NAME,TYPE,DEVICE connection show --active

    echo
    read -r -p "Enter the NetworkManager connection NAME to modify: " NM_CONN

    if [[ -n "$NM_CONN" ]]; then
        echo "WARNING: this can interrupt your network/SSH session."
        read -r -p "Apply static settings to '$NM_CONN'? [y/N] " answer

        if [[ "$answer" =~ ^[Yy]$ ]]; then
            sudo nmcli connection modify "$NM_CONN" \
                ipv4.method manual \
                ipv4.addresses "$STATIC_IP" \
                ipv4.gateway "$STATIC_GW" \
                ipv4.dns "$STATIC_DNS"

            echo "Settings written. Activate with:"
            echo "  sudo nmcli connection up \"$NM_CONN\""
        fi
    fi
fi

echo "==> Enabling GDM and graphical boot"
sudo systemctl set-default graphical.target
sudo systemctl enable gdm

echo
echo "============================================================"
echo "Bootstrap complete."
echo
echo "Dotfiles source:"
echo "  $DOTFILES_DIR"
echo
echo "Installed/handled:"
echo "  niri + Noctalia"
echo "  Kitty + Firefox + Dolphin"
echo "  Neovim + eza + Starship"
echo "  JetBrains Mono"
echo "  NetworkManager Wi-Fi support"
echo "  Intel iwlwifi firmware (iwlwifi-mvm-firmware)"
echo "  Intel iwlwifi driver reload when Intel wireless is detected"
echo "  GDM + minimal GNOME fallback"
echo "  PipeWire/WirePlumber + XDG portals"
echo
echo "Important:"
echo "  If Docker/containerlab groups were changed, completely log out/in."
echo "  Reboot when ready:"
echo "      sudo reboot"
echo
echo "Verification:"
echo "  ls -l ~/.config/niri ~/.config/kitty ~/.config/nvim ~/.zshrc"
echo "  niri validate"
echo "  nmcli device status"
echo "  command -v niri noctalia kitty dolphin nvim eza starship"
echo "  fc-match 'JetBrains Mono'"
echo "  gsettings get org.gnome.desktop.interface color-scheme"
echo "  id"
echo "============================================================"
