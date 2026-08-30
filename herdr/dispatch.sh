#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 0 ]]; then
    echo "dispatch.sh accepts no arguments" >&2
    exit 2
fi
if [[ "${HERDR_ENV:-}" == 1 ]]; then
    echo "Already inside Herdr; detach before attaching to the dotfiles session." >&2
    exit 2
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)" || {
    echo "Unable to resolve the dotfiles repository." >&2
    exit 1
}
CALLER_ROOT="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"

if [[ -z "$CALLER_ROOT" || "$(realpath -e -- "$CALLER_ROOT")" != "$(realpath -e -- "$REPO_ROOT")" ]]; then
    echo "The dotfiles Herdr session can only be launched from its canonical checkout." >&2
    exit 1
fi

HERDR_SESSION=fedora-niri-dotfiles exec herdr
