# This file is sourced by the tracked .zshrc. Resolve its physical location once
# so another clone or Git worktree cannot inherit this checkout's session route.
typeset -g _fedora_niri_dotfiles_root=${${(%):-%N}:A:h:h}

function herdr() {
  emulate -L zsh

  if (( $# != 0 )); then
    command herdr "$@"
    return
  fi

  if [[ ${HERDR_ENV:-} == 1 ]]; then
    print -u2 -- "Already inside Herdr; detach before attaching to the dotfiles session."
    return 2
  fi

  local git_root=''
  git_root=$(command git -C "$PWD" rev-parse --show-toplevel 2>/dev/null) || git_root=''
  if [[ -n $git_root && ${git_root:A} == ${_fedora_niri_dotfiles_root:A} ]]; then
    "$_fedora_niri_dotfiles_root/herdr/dispatch.sh"
  else
    command herdr
  fi
}
