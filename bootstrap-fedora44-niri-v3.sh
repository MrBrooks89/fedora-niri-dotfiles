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
#   ├── btop/
#   ├── chatgpt/
#   ├── noctalia/              # optional
#   ├── noctalia-greeter/
#   ├── install-noctalia-greeter.sh
#   ├── configure-noctalia-greeter.sh
#   ├── codex/skills/fedora-niri/
#   └── satty/                 # optional
#
# Symlink targets:
#   ~/.zshrc
#   ~/.config/starship.toml
#   ~/.config/kitty
#   ~/.config/niri
#   ~/.config/nvim
#   ~/.config/btop
#   ~/.config/noctalia
#   ~/.codex/skills/fedora-niri
#   ~/.config/satty
#   ~/.local/share/applications/chatgpt.desktop
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
WITH_GAMING=0
WITH_CODEX=0
WITH_AUTO_DIAGNOSTICS=0
CONFIGURE_GITHUB=0
CONFIGURE_NETWORK=0
GROUP_MEMBERSHIP_CHANGED=0

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
  --with-gaming            Install Steam, ProtonUp-rs, Heroic, gaming tools,
                           and USB/Bluetooth Xbox controller support
  --with-codex             Install Codex CLI and CodexBar usage helper
  --with-auto-diagnostics  Enable local Codex crash diagnosis and PR proposals
                           (requires --with-codex and --configure-github)
  --configure-github       Configure Git identity and authenticate GitHub CLI
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
        --with-gaming)      WITH_GAMING=1 ;;
        --with-codex)       WITH_CODEX=1 ;;
        --with-auto-diagnostics) WITH_AUTO_DIAGNOSTICS=1 ;;
        --configure-github) CONFIGURE_GITHUB=1 ;;
        --configure-network) CONFIGURE_NETWORK=1 ;;
        --all)
            WITH_DOCKER=1
            WITH_CONTAINERLAB=1
            WITH_SATTY_COPR=1
            WITH_NERD_FONT=1
            WITH_GAMING=1
            WITH_CODEX=1
            CONFIGURE_GITHUB=1
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

if [[ "$WITH_AUTO_DIAGNOSTICS" -eq 1 && "$CONFIGURE_GITHUB" -ne 1 ]]; then
    echo "--with-auto-diagnostics requires --configure-github." >&2
    exit 2
fi
if [[ "$WITH_AUTO_DIAGNOSTICS" -eq 1 && "$WITH_CODEX" -ne 1 ]]; then
    echo "--with-auto-diagnostics requires --with-codex." >&2
    exit 2
fi

if [[ $EUID -eq 0 ]]; then
    echo "Run this script as your normal user, not root." >&2
    exit 1
fi

INSTALL_USER="$(id -un)"
INSTALL_UID="$(id -u)"
INSTALL_HOME="$(getent passwd "$INSTALL_USER" | cut -d: -f6)"

if [[ -z "$INSTALL_HOME" || "$INSTALL_HOME" != "$HOME" ]]; then
    echo "ERROR: Account home from passwd does not match HOME." >&2
    echo "       user=$INSTALL_USER passwd_home=$INSTALL_HOME HOME=$HOME" >&2
    exit 1
fi

echo "==> Installing for $INSTALL_USER (uid $INSTALL_UID, home $INSTALL_HOME)"

ensure_install_user_group() {
    local group_name="$1"

    if ! getent group "$group_name" >/dev/null; then
        sudo groupadd "$group_name"
    fi

    if ! id -nG "$INSTALL_USER" | grep -qw -- "$group_name"; then
        sudo usermod -aG "$group_name" "$INSTALL_USER"
        GROUP_MEMBERSHIP_CHANGED=1
    fi

    if ! id -nG "$INSTALL_USER" | grep -qw -- "$group_name"; then
        echo "ERROR: Failed to add $INSTALL_USER to the $group_name group." >&2
        exit 1
    fi
}

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

backup_and_copy() {
    local source="$1"
    local target="$2"

    [[ -f "$source" ]] || return 0
    mkdir -p "$(dirname "$target")"

    if [[ -e "$target" || -L "$target" ]]; then
        local relative="${target#$HOME/}"
        mkdir -p "$BACKUP_DIR/$(dirname "$relative")"
        mv "$target" "$BACKUP_DIR/$relative"
        echo "    backed up: $target -> $BACKUP_DIR/$relative"
    fi

    install -m 0644 "$source" "$target"
    echo "    copied runtime seed: $target"
}

echo "==> Updating Fedora"
sudo dnf -y upgrade --refresh

echo "==> Installing base CLI/development/networking utilities"
sudo dnf -y install \
    zsh git curl wget vim-enhanced nano tmux btop \
    neovim eza \
    python3 python3-pip gcc gcc-c++ make \
    dnf-plugins-core \
    unzip tar rsync jq ripgrep fd-find \
    pciutils usbutils rfkill \
    NetworkManager \
    NetworkManager-wifi \
    wpa_supplicant \
    wireless-regdb \
    linux-firmware \
    iwlwifi-mvm-firmware \
    jetbrains-mono-fonts \
    zsh-autosuggestions \
    zsh-syntax-highlighting \
    google-noto-color-emoji-fonts \
    unzip \
    golang

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
    grim slurp wl-clipboard tesseract tesseract-langpack-eng ddcutil i2c-tools \
    libreoffice

echo "==> Installing ChatGPT from the official OpenAI RPM repository"
sudo install -m 0644 \
    "$SCRIPT_DIR/chatgpt/RPM-GPG-KEY-chatgpt" \
    /etc/pki/rpm-gpg/RPM-GPG-KEY-chatgpt
sudo rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-chatgpt
sudo install -m 0644 \
    "$SCRIPT_DIR/chatgpt/chatgpt.repo" \
    /etc/yum.repos.d/chatgpt.repo
sudo dnf -y install chatgpt

echo "==> Enabling DDC/CI access for external monitor brightness controls"
echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null
sudo modprobe i2c-dev

echo "==> Installing Teams for Linux from its official repository"
teams_signing_key="$(mktemp --suffix=-teams-for-linux.asc)"
trap 'rm -f "$teams_signing_key"' EXIT

curl -1sSfL \
    -o "$teams_signing_key" \
    https://repo.teamsforlinux.de/teams-for-linux.asc
sudo rpm --import "$teams_signing_key"
sudo curl -1sSfL \
    -o /etc/yum.repos.d/teams-for-linux.repo \
    https://repo.teamsforlinux.de/rpm/teams-for-linux.repo
sudo dnf -y install teams-for-linux

rm -f "$teams_signing_key"
trap - EXIT

echo "==> Installing Joplin from taw/joplin COPR"
sudo dnf -y copr enable taw/joplin
sudo dnf -y install joplin

if [[ "$CONFIGURE_GITHUB" -eq 1 ]]; then
    echo "==> Configuring Git identity and GitHub CLI"

    if [[ ! -t 0 ]]; then
        echo "ERROR: --configure-github requires an interactive terminal." >&2
        exit 1
    fi

    sudo dnf -y install gh

    current_git_name="$(git config --global --get user.name || true)"
    current_git_email="$(git config --global --get user.email || true)"

    read -r -p "Git author name${current_git_name:+ [$current_git_name]}: " git_name
    read -r -p "Git author email${current_git_email:+ [$current_git_email]}: " git_email

    git_name="${git_name:-$current_git_name}"
    git_email="${git_email:-$current_git_email}"

    if [[ -z "$git_name" || -z "$git_email" ]]; then
        echo "ERROR: Git author name and email cannot be empty." >&2
        exit 1
    fi

    git config --global user.name "$git_name"
    git config --global user.email "$git_email"

    if ! gh auth status --hostname github.com >/dev/null 2>&1; then
        gh auth login --hostname github.com --git-protocol ssh --web
    else
        echo "    GitHub CLI is already authenticated."
    fi

    gh auth setup-git
fi

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

if [[ "$WITH_GAMING" -eq 1 ]]; then
    echo "==> Installing ProtonUp-rs"

    case "$(uname -m)" in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64)
            ARCH="arm64"
            ;;
        *)
            echo "ERROR: Unsupported architecture for ProtonUp-rs: $(uname -m)" >&2
            exit 1
            ;;
    esac

    FILE="protonup-rs-linux-$ARCH.tar.gz"
    TMP_DIR="$(mktemp -d)"

    curl -fL \
        --connect-timeout 60 \
        "https://github.com/auyer/Protonup-rs/releases/latest/download/$FILE" \
        -o "$TMP_DIR/$FILE"

    tar -xzf "$TMP_DIR/$FILE" -C "$TMP_DIR"

    mkdir -p "$HOME/.local/bin"

    install -m 755 \
        "$TMP_DIR/protonup-rs" \
        "$HOME/.local/bin/protonup-rs"

    rm -rf "$TMP_DIR"

    echo "    Installed: $HOME/.local/bin/protonup-rs"
else
    echo "NOTE: Gaming software not installed. Use --with-gaming if needed."
fi

if [[ "$WITH_CODEX" -eq 1 ]]; then
    echo "==> Installing OpenAI Codex CLI"
    sudo dnf -y install nodejs npm
    npm install --global --prefix "$HOME/.local" @openai/codex

    echo "==> Installing CodexBar CLI for the Noctalia usage widget"

    case "$(uname -m)" in
        x86_64)  CODEXBAR_ARCH="x86_64" ;;
        aarch64) CODEXBAR_ARCH="aarch64" ;;
        *)
            echo "ERROR: Unsupported architecture for CodexBar: $(uname -m)" >&2
            exit 1
            ;;
    esac

    CODEXBAR_RELEASE_JSON="$(curl -fsSL \
        https://api.github.com/repos/steipete/CodexBar/releases/latest)"
    CODEXBAR_TAG="$(jq -r '.tag_name' <<<"$CODEXBAR_RELEASE_JSON")"
    CODEXBAR_ASSET="CodexBarCLI-${CODEXBAR_TAG}-linux-${CODEXBAR_ARCH}.tar.gz"
    CODEXBAR_URL="$(jq -r --arg name "$CODEXBAR_ASSET" \
        '.assets[] | select(.name == $name) | .browser_download_url' \
        <<<"$CODEXBAR_RELEASE_JSON")"
    CODEXBAR_SHA_URL="$(jq -r --arg name "${CODEXBAR_ASSET}.sha256" \
        '.assets[] | select(.name == $name) | .browser_download_url' \
        <<<"$CODEXBAR_RELEASE_JSON")"

    if [[ -z "$CODEXBAR_URL" || -z "$CODEXBAR_SHA_URL" ]]; then
        echo "ERROR: Could not find the CodexBar Linux release assets." >&2
        exit 1
    fi

    CODEXBAR_TMP="$(mktemp -d)"
    curl -fL "$CODEXBAR_URL" -o "$CODEXBAR_TMP/$CODEXBAR_ASSET"
    curl -fL "$CODEXBAR_SHA_URL" -o "$CODEXBAR_TMP/$CODEXBAR_ASSET.sha256"
    (
        cd "$CODEXBAR_TMP"
        sha256sum -c "$CODEXBAR_ASSET.sha256"
        tar -xzf "$CODEXBAR_ASSET"
    )
    CODEXBAR_BIN="$CODEXBAR_TMP/CodexBarCLI"
    CODEXBAR_BUNDLE="$CODEXBAR_TMP/CodexBar_CodexBarCore.bundle"
    if [[ ! -x "$CODEXBAR_BIN" || ! -d "$CODEXBAR_BUNDLE" ]]; then
        echo "ERROR: CodexBar executable or resource bundle missing from archive." >&2
        exit 1
    fi

    # The Linux release contains a CodexBarCLI executable, a lowercase symlink,
    # and a Swift resource bundle that must remain beside the executable.
    CODEXBAR_INSTALL_DIR="$HOME/.local/lib/codexbar/$CODEXBAR_TAG"
    mkdir -p "$CODEXBAR_INSTALL_DIR" "$HOME/.local/bin"
    install -m 755 "$CODEXBAR_BIN" "$CODEXBAR_INSTALL_DIR/CodexBarCLI"
    cp -a "$CODEXBAR_BUNDLE" "$CODEXBAR_INSTALL_DIR/"
    ln -sfn "$CODEXBAR_INSTALL_DIR/CodexBarCLI" "$HOME/.local/bin/codexbar"
    rm -rf -- "$CODEXBAR_TMP"

    "$HOME/.local/bin/codexbar" config enable --provider codex

    echo "    Codex and CodexBar are installed. Run 'codex' once to sign in."
    echo "    Install CodexBar Meter from Noctalia Settings -> Plugins, then"
    echo "    add 'salemsayed/codexbar-meter:bar' to the desired bar section."
else
    echo "NOTE: Codex tooling not installed. Use --with-codex if wanted."
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

echo "==> Installing Rosé Pine cursor theme"

ROSE_PINE_CURSOR_DIR="$HOME/.local/share/icons/BreezeX-RosePine"
ROSE_PINE_CURSOR_URL="https://github.com/rose-pine/cursors/releases/latest/download/BreezeX-RosePine-Linux.tar.xz"

if [[ ! -d "$ROSE_PINE_CURSOR_DIR" ]]; then
    TMP_CURSOR="$(mktemp --suffix=.tar.xz)"

    mkdir -p "$HOME/.local/share/icons"

    curl -fL \
        --connect-timeout 60 \
        "$ROSE_PINE_CURSOR_URL" \
        -o "$TMP_CURSOR"

    tar -xJf "$TMP_CURSOR" \
        -C "$HOME/.local/share/icons"

    rm -f "$TMP_CURSOR"
else
    echo "    Rosé Pine cursor already installed."
fi

echo "==> Setting Rosé Pine cursor theme"

gsettings set org.gnome.desktop.interface cursor-theme 'BreezeX-RosePine'
gsettings set org.gnome.desktop.interface cursor-size 24

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

echo "==> Seeding generated theme files for first login"
mkdir -p \
    "$DOTFILES_DIR/niri" \
    "$DOTFILES_DIR/kitty/themes" \
    "$DOTFILES_DIR/btop/themes"

if [[ ! -e "$DOTFILES_DIR/niri/noctalia.kdl" ]]; then
    cat > "$DOTFILES_DIR/niri/noctalia.kdl" <<'EOF'
// Bootstrap fallback. Noctalia replaces this file when it applies templates.
EOF
fi

if [[ ! -e "$DOTFILES_DIR/kitty/themes/noctalia.conf" ]]; then
    cat > "$DOTFILES_DIR/kitty/themes/noctalia.conf" <<'EOF'
# Bootstrap fallback. Noctalia replaces this file when it applies templates.
foreground #f8f8f2
background #282a36
EOF
fi

if [[ ! -e "$DOTFILES_DIR/btop/themes/noctalia.theme" ]]; then
    cat > "$DOTFILES_DIR/btop/themes/noctalia.theme" <<'EOF'
# Bootstrap fallback. Noctalia replaces this file when it applies templates.
theme[main_bg]="#282a36"
theme[main_fg]="#f8f8f2"
EOF
fi

echo "==> Linking dotfiles"

backup_and_link "$DOTFILES_DIR/.zshrc"        "$HOME/.zshrc"
backup_and_copy "$DOTFILES_DIR/starship.toml" "$HOME/.config/starship.toml"
backup_and_link "$DOTFILES_DIR/kitty"         "$HOME/.config/kitty"
backup_and_link "$DOTFILES_DIR/niri"          "$HOME/.config/niri"
backup_and_link "$DOTFILES_DIR/nvim"          "$HOME/.config/nvim"
backup_and_link "$DOTFILES_DIR/btop"          "$HOME/.config/btop"
backup_and_link "$DOTFILES_DIR/noctalia"      "$HOME/.config/noctalia"
backup_and_link "$DOTFILES_DIR/satty"         "$HOME/.config/satty"
backup_and_link "$DOTFILES_DIR/codex/skills/fedora-niri" "$HOME/.codex/skills/fedora-niri"
backup_and_link "$DOTFILES_DIR/chatgpt/chatgpt.desktop" "$HOME/.local/share/applications/chatgpt.desktop"

update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

if [[ -d "$BACKUP_DIR" ]]; then
    echo "    previous configs saved under: $BACKUP_DIR"
fi

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

echo "==> Validating linked Niri configuration"
niri validate -c "$NIRI_CONFIG"

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
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' || true
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

if [[ "$WITH_GAMING" -eq 1 ]]; then
    echo "==> Installing Steam and gaming support from RPM Fusion"

    sudo dnf install -y \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
    sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1
    sudo dnf install -y \
        steam \
        steam-devices \
        gamemode \
        gamescope \
        mangohud \
        flatpak \
        bluez \
        bluez-tools \
        joystick-support

    echo "==> Installing Heroic Games Launcher from Flathub"
    flatpak remote-add --user --if-not-exists \
        flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install --user -y flathub com.heroicgameslauncher.hgl

    echo "==> Enabling USB and Bluetooth Xbox controller support"
    sudo systemctl enable --now bluetooth
    printf '%s\n' xpad uhid | sudo tee /etc/modules-load.d/gaming-controllers.conf >/dev/null
    sudo modprobe xpad
    sudo modprobe uhid
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

    ensure_install_user_group docker
    sudo systemctl enable --now docker
fi

if [[ "$WITH_CONTAINERLAB" -eq 1 ]]; then
    echo "==> Installing containerlab"

    bash -c "$(curl -sL https://get.containerlab.dev)"

    ensure_install_user_group clab_admins

    if getent group docker >/dev/null; then
        ensure_install_user_group docker
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

if [[ "$WITH_AUTO_DIAGNOSTICS" -eq 1 ]]; then
    echo "==> Enabling automatic sanitized workstation diagnostics"
    sudo dnf -y install gh
    "$DOTFILES_DIR/diagnostics/install.sh"
else
    echo "NOTE: Automatic diagnostics are disabled."
    echo "      Use --with-auto-diagnostics with --configure-github to enable them."
fi

echo "==> Installing and configuring Noctalia Greeter"
"$DOTFILES_DIR/install-noctalia-greeter.sh"

echo "==> Enabling greetd and graphical boot"
sudo systemctl set-default graphical.target
sudo systemctl disable gdm 2>/dev/null || true
sudo systemctl enable greetd

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
echo "  ChatGPT (native Wayland launcher + Mod+G shortcut)"
echo "  Joplin"
echo "  Neovim + eza + Starship"
echo "  JetBrains Mono"
echo "  NetworkManager Wi-Fi support"
echo "  Intel iwlwifi firmware (iwlwifi-mvm-firmware)"
echo "  Intel iwlwifi driver reload when Intel wireless is detected"
echo "  greetd + Noctalia Greeter"
echo "  PipeWire/WirePlumber + XDG portals"
if [[ "$WITH_AUTO_DIAGNOSTICS" -eq 1 ]]; then
    echo "  Sanitized workstation diagnostics + local Codex PR workflow"
fi
echo
echo "Important:"
if [[ "$GROUP_MEMBERSHIP_CHANGED" -eq 1 ]]; then
    echo "  Docker/containerlab permissions were configured for $INSTALL_USER."
    echo "  Completely log out and back in once to activate the new groups."
fi
echo "  Reboot when ready:"
echo "      sudo reboot"
echo
echo "Verification:"
echo "  ls -l ~/.config/niri ~/.config/kitty ~/.config/nvim ~/.zshrc"
echo "  niri validate"
echo "  nmcli device status"
echo "  command -v niri noctalia kitty dolphin chatgpt teams-for-linux nvim eza starship"
if [[ "$CONFIGURE_GITHUB" -eq 1 ]]; then
    echo "  command -v gh && gh auth status --hostname github.com"
fi
echo "  fc-match 'JetBrains Mono'"
echo "  gsettings get org.gnome.desktop.interface color-scheme"
echo "  id"
echo "============================================================"
