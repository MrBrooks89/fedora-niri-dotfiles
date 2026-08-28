# Fedora 44 Minimal + niri / Noctalia Workstation

This repository is a reproducible Fedora workstation build based on **Fedora Everything 44 → Minimal Install**.

Primary desktop stack:

```text
Fedora 44 Minimal
        │
        ▼
      greetd
        │
        ▼
Noctalia Greeter
        │
        ▼
      niri
        │
        ▼
    Noctalia
```

## Repository layout

Expected layout:

```text
fedora-niri-dotfiles/
├── btop/
├── codex/
│   └── skills/fedora-niri/
├── chatgpt/
│   ├── RPM-GPG-KEY-chatgpt
│   ├── chatgpt.desktop
│   └── chatgpt.repo
├── kitty/
├── niri/
│   ├── config.kdl
│   └── screenshot.sh
├── nvim/
├── noctalia/
│   ├── config.toml
│   └── plugins/command-center/
├── noctalia-greeter/
│   └── greeter.toml
├── satty/
├── .zshrc
├── starship.toml
├── .gitignore
├── README.md
├── install-noctalia-greeter.sh
├── configure-noctalia-greeter.sh
└── bootstrap-fedora44-niri-v3.sh
```

The bootstrap script creates symlinks:

```text
repo/.zshrc            → ~/.zshrc
repo/starship.toml     → copied to ~/.config/starship.toml
repo/kitty             → ~/.config/kitty
repo/niri              → ~/.config/niri
repo/nvim              → ~/.config/nvim
repo/btop              → ~/.config/btop
repo/noctalia          → ~/.config/noctalia
repo/satty             → ~/.config/satty
repo/codex/skills/fedora-niri
                       → ~/.codex/skills/fedora-niri
repo/chatgpt/chatgpt.desktop
                       → ~/.local/share/applications/chatgpt.desktop
```

Existing configs are backed up before links are created.

Starship is the exception to the symlink model: its tracked file is an
installation seed. The bootstrap copies it to `~/.config/starship.toml` so
Noctalia can rewrite the live wallpaper-derived palette without modifying the
Git checkout.

The bootstrap discovers the invoking non-root account, UID, and home directory
from the local system. Tracked configuration uses `$HOME` or XDG paths, and the
greeter configuration is rendered with that account at install time. The repo
can therefore be cloned to any location and used with a username chosen during
Fedora installation; it does not rewrite tracked files with that username.

Some settings remain intentionally machine- or preference-specific, including
monitor layout, weather location, static networking, and the personal package
selection. Review those before installing the setup for someone else. Names
such as `mrbrooks/command-center` are stable Noctalia plugin identifiers, not
Linux usernames or home-directory assumptions.

Noctalia-generated Niri, Kitty, and btop theme outputs are intentionally ignored
by Git. On a fresh clone, the bootstrap creates valid fallback files before it
links the configurations. Noctalia replaces those fallbacks after it starts and
applies the configured templates.

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
It must be run as the intended desktop user, not with `sudo`; privileged steps
prompt through `sudo` individually.

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
btop/
noctalia/
satty/
codex/skills/fedora-niri/
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
Joplin
ChatGPT
PipeWire
WirePlumber
polkit
xdg-user-dirs
xdg-desktop-portal
xdg-desktop-portal-gtk
xdg-desktop-portal-kde
```

Joplin is installed by default from the `taw/joplin` COPR repository. The
bootstrap installs the COPR support plugin, enables that repository, and then
installs the `joplin` package:

```bash
sudo dnf -y install dnf-plugins-core
sudo dnf -y copr enable taw/joplin
sudo dnf -y install joplin
```

ChatGPT is installed by default from OpenAI's signed Linux RPM repository. The
bootstrap installs the tracked `Codex Linux Repository` public key and repository
definition before installing the latest available `chatgpt` package. The RPM
repository remains enabled so normal Fedora updates can update ChatGPT.

Login stack:

```text
greetd
Noctalia Greeter (pinned source build)
```

### Noctalia Greeter

The bootstrap builds the official Noctalia Greeter revision pinned in
`install-noctalia-greeter.sh`, installs its binaries under `/usr/local`, and
configures greetd to launch Niri. Stable appearance, authentication, and
session defaults live in `noctalia-greeter/greeter.toml`; the login user is
discovered and inserted into the installed copy. Noctalia's
`greeter-sync` command owns mutable theme, wallpaper, and output state in
`/var/lib/noctalia-greeter/sync.toml`.

To reinstall or update the pinned build:

```bash
./install-noctalia-greeter.sh
noctalia msg greeter-sync
systemctl is-enabled greetd
systemctl status display-manager --no-pager
```

greetd and Noctalia Greeter are the sole login stack. GDM, GNOME Shell, GNOME
Session, Control Center, and the remaining GNOME desktop services were removed
after login and Niri startup passed a real reboot test. GNOME-named runtime
libraries, settings schemas, keyring, and PAM integration may remain when other
applications depend on them; they are not a GNOME desktop fallback.

If login recovery is needed, switch to a TTY and inspect greetd before changing
its configuration:

```bash
systemctl status greetd --no-pager
journalctl -b -u greetd --no-pager
./install-noctalia-greeter.sh
sudo systemctl enable greetd
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

This is a runtime copy of the repository's `starship.toml` seed. Noctalia's
built-in Starship template updates its palette as wallpapers change; those
generated color changes are intentionally not tracked by Git.

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
Mod+P { spawn-sh "noctalia msg panel-toggle session"; }
```

### Command center

`Mod+Space` opens the custom native Noctalia panel at
`noctalia/plugins/command-center/`. Its root contains six categories and its
search covers installed desktop applications plus leaf actions. The remaining
launcher shortcuts open Noctalia's focused utility providers directly:

- `Mod+D` opens the calculator (`/calc`).
- `Mod+Shift+D` opens the emoji picker (`/emo`).
- `Mod+G` launches ChatGPT using native Wayland.

Keyboard controls:

| Key | Action |
| --- | --- |
| Type | Search applications and actions |
| `Up` / `Down` | Move the highlighted selection and follow it through the list |
| `Right` / `Enter` | Open the selected category or action |
| `Alt+Left` | Return to the category root |
| `Escape` | Close the panel |

The plugin keeps UI code in `panel.luau`, exact-string command dispatch in
`dispatch-action.sh`, and capture operations in `capture-tools.sh`. Manifest
changes such as `capture_keys` are loaded only when the plugin starts; reload it
with:

```bash
noctalia msg plugins disable mrbrooks/command-center
noctalia msg plugins enable mrbrooks/command-center
```

For ordinary Noctalia configuration changes, use
`noctalia msg config-reload` instead.

Validate niri config:

```bash
niri validate
```

### ChatGPT desktop

The bootstrap installs the official OpenAI `chatgpt` RPM and links the tracked
desktop entry to `~/.local/share/applications/chatgpt.desktop`. Both that menu
entry and the `Mod+G` Niri shortcut launch:

```bash
chatgpt --ozone-platform=wayland
```

This keeps ChatGPT native to Wayland while leaving the RPM-owned desktop entry
under `/usr/share/applications` untouched. The user entry takes precedence and
is not overwritten by package updates. If ChatGPT was installed after the
command center had already indexed applications, reload that plugin once:

```bash
noctalia msg plugins disable mrbrooks/command-center
noctalia msg plugins enable mrbrooks/command-center
```

---

## GTK / libadwaita dark mode

Persistent dark-mode preference:

```bash
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
```

Verify:

```bash
gsettings get org.gnome.desktop.interface color-scheme
gsettings get org.gnome.desktop.interface gtk-theme
```

Qt applications such as Dolphin use Fedora's Qt GTK integration through Niri's
`QT_QPA_PLATFORMTHEME=gtk3` environment setting. The GTK 3 platform theme does
not consume libadwaita's `color-scheme` preference, so Niri also exports
`GTK_THEME=Adwaita:dark`. This keeps Dolphin dark without requiring `qt6ct` or
Kvantum.

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

The custom command center's Capture category provides:

- Region, focused-window, focused-output, and all-output screenshots
- Region annotation with Satty
- Noctalia screen recording
- Color picking and clipboard copy
- OCR of a selected region to the clipboard
- Direct access to the screenshots folder

Normal screenshot actions save directly under:

```text
~/Pictures/Screenshots
```

The capture implementation uses Niri for the focused window/output and
Grim/Slurp for regions or all outputs. Satty handles annotation, `wl-copy`
handles clipboard output, and Tesseract handles OCR.

`Mod+S` remains a lightweight region-to-Satty shortcut implemented by
`niri/screenshot.sh`. The underlying stack is:

```text
slurp → grim → Satty
```

Satty is provided through the `mineiro/satty` COPR rather than Fedora's default
repositories. Enable that optional source and install Satty with:

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

## OpenAI Codex + usage widget

Install the Codex CLI and the CodexBar usage helper:

```bash
./bootstrap-fedora44-niri-v3.sh --with-codex
```

Then run `codex` once and sign in. `Mod+A` opens Codex in Kitty, starting in
`~/Work`. You can inspect usage manually with:

```bash
codexbar usage --format json --json-only
```

The tracked `noctalia/config.toml` declares the community plugin source,
enables CodexBar Meter, and places it on the right side of the bar. After the
bootstrap links that configuration, Noctalia should fetch and activate it.
If the plugin has not yet been materialized, finish it from the UI:

1. Open **Noctalia Settings → Plugins** and install/enable **CodexBar Meter**.
2. Open **Bar**, choose the desired section, and add
   `salemsayed/codexbar-meter:bar`.

The widget opens its usage panel on left-click and refreshes on right-click.
Its default refresh interval is 60 seconds.

### Codex desktop guidance

The repository includes two instruction layers for Codex:

- `AGENTS.md` describes repository conventions and validation commands.
- `codex/skills/fedora-niri/SKILL.md` provides reusable Fedora/Niri/Noctalia
  desktop guidance.

The bootstrap links the skill to `~/.codex/skills/fedora-niri`. Restart Codex
after the first installation so it discovers the new skill. Authentication and
session data remain in `~/.codex` and are intentionally not tracked.

### Automated workstation diagnostics

The optional diagnostic timer checks every 15 minutes for failed systemd units,
relevant high-priority journal messages, and recent coredumps. Reports are
bounded, sanitized locally, deduplicated, and submitted as GitHub issues titled
`[workstation-diagnostic] ...`. A six-hour cooldown prevents repeated failures
from flooding the repository.

After opening an issue, the runner starts `codex exec` locally under the current
user's existing ChatGPT login. Codex receives the sanitized report and works in
an isolated temporary Git worktree with workspace-write sandboxing. If it finds
a supported repository fix, the wrapper commits and pushes a dedicated branch
and opens a PR. Otherwise, it comments its diagnosis on the issue. It never
merges, runs the bootstrap, or modifies the live workstation.

No OpenAI API key or GitHub Actions secret is required. Local setup requires a
ChatGPT-authenticated Codex CLI and a valid GitHub CLI login:

```bash
codex login
gh auth login --hostname github.com
./diagnostics/install.sh
```

The diagnostic scripts derive their GitHub target from the checkout's `origin`.
That repository must be owned by the account reported by `gh`; a friend using
this setup should fork the repository, set `origin` to their fork, and then run
the installer. This prevents automated reports and branches from targeting the
original repository without its owner's credentials.

For a fresh bootstrap, use:

```bash
./bootstrap-fedora44-niri-v3.sh \
    --with-codex \
    --configure-github \
    --with-auto-diagnostics
```

This integration is deliberately opt-in and is not enabled by `--all`.

Test collection without uploading anything:

```bash
diagnose-workstation --dry-run --force
```

Inspect or disable the timer:

```bash
systemctl --user status fedora-niri-diagnostics.timer
systemctl --user disable --now fedora-niri-diagnostics.timer
```

The local agent logs are available with:

```bash
journalctl --user -u fedora-niri-diagnostics.service
```

The collector deliberately avoids environment dumps, command history,
clipboard contents, arbitrary home-directory files, and full coredump memory.

Interactive Zsh sessions also provide an opt-in, click-to-diagnose path. After
a command exits unsuccessfully, a desktop notification offers **Diagnose with
AI**. Nothing is sent to Codex until that action is clicked. The helper records
only the failed command, exit status, working directory, and—for npm failures—a
recent bounded npm debug-log tail; it sanitizes the report before saving it.

The click action opens a local Kitty window and runs Codex in an isolated
dotfiles worktree. Command mistakes and machine-local failures produce advice
only. If Codex instead finds a durable defect in tracked Fedora Niri
configuration, the wrapper may push the isolated change and open a PR for
review; it never merges or applies that change to the live workstation.

Open a new terminal after installation to load the Zsh hook. A simple local
notification test is:

```bash
false
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
Noctalia Greeter
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
