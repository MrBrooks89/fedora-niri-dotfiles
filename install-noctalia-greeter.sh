#!/usr/bin/env bash
set -euo pipefail

readonly GREETER_REPOSITORY="https://github.com/noctalia-dev/noctalia-greeter.git"
readonly GREETER_REVISION="5956c6f40249b2837bb260d25ea3953a2631fbdc"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

build_dir="$(mktemp -d --tmpdir noctalia-greeter-build.XXXXXX)"
trap 'rm -rf -- "$build_dir"' EXIT

sudo dnf install -y \
    meson gcc-c++ just greetd dbus \
    wayland-devel wayland-protocols-devel wlroots-devel \
    libEGL-devel mesa-libGLES-devel \
    freetype-devel fontconfig-devel cairo-devel pango-devel harfbuzz-devel \
    libxkbcommon-devel glib2-devel tomlplusplus-devel json-devel \
    stb_image_resize2-devel libwebp-devel librsvg2-devel

git clone "$GREETER_REPOSITORY" "$build_dir/source"
git -C "$build_dir/source" checkout --detach "$GREETER_REVISION"

# The upstream wrapper currently hard-codes /usr/share even when Meson is given
# a /usr/local prefix. Keep the wrapper aligned with this source installation.
sed -i \
    's|/usr/share/noctalia-greeter/print_greetd_config.sh|/usr/local/share/noctalia-greeter/print_greetd_config.sh|' \
    "$build_dir/source/scripts/noctalia-greeter-print-greetd-config"

meson setup "$build_dir/source/build-release" \
    "$build_dir/source" \
    --buildtype=release \
    --prefix=/usr/local
meson compile -C "$build_dir/source/build-release"
sudo meson install -C "$build_dir/source/build-release"
sudo "$SCRIPT_DIR/configure-noctalia-greeter.sh" \
    "$build_dir/source/scripts/setup_greeter_system.sh"

echo
echo "Noctalia Greeter is installed and configured, but display-manager services were not changed."
echo "Preview it inside Niri before switching away from GDM."
