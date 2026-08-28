# Enable Zsh options
autoload -Uz compinit
compinit

# History File
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY

# ~/.zshrc
eval "$(starship init zsh)"

# Session environment variables
export PATH="$HOME/go/bin:$PATH"
export PATH=$PATH:/snap/bin
export DISPLAY=":0"

# Aliases
alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
#alias cat="bat"
alias ll="eza -al --icons"
alias ls="eza -a --icons"
alias lt="eza -a --tree --level=1 --icons"
alias nn="nvim"
alias vim="nvim"
#alias ping="fping -c 25"
#alias ringcentral="ringcentral-embeddable"
alias code="codium"

# Plugins
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Source environment variables from .env
if [ -f "$HOME/.env" ]; then
  while IFS= read -r line; do
    if [[ -n "$line" && "$line" != \#* ]]; then
      export "$line"
    fi
  done < "$HOME/.env"
fi
export PATH="$HOME/.local/bin:$PATH"

# Offer an opt-in AI diagnosis after a failed interactive command. The helper
# sanitizes and bounds evidence before the notification action can invoke Codex.
if [[ -o interactive ]] && [[ -x "$HOME/.local/bin/notify-command-failure" ]]; then
  autoload -Uz add-zsh-hook
  typeset -g _diagnostic_last_command=''

  _capture_command_for_diagnosis() {
    _diagnostic_last_command="$1"
  }

  _notify_failed_command_for_diagnosis() {
    local exit_status=$?
    local failed_command="$_diagnostic_last_command"

    if (( exit_status != 0 && exit_status != 130 )) && [[ -n "$failed_command" ]]; then
      "$HOME/.local/bin/notify-command-failure" \
        --status "$exit_status" \
        --cwd "$PWD" \
        --command "$failed_command" >/dev/null 2>&1 &!
    fi
  }
  add-zsh-hook preexec _capture_command_for_diagnosis
  # This hook must run before prompt and highlighting hooks: each precmd hook
  # updates `$?`, so a later hook would see the previous hook's success instead
  # of the interactive command's failure.
  add-zsh-hook precmd _notify_failed_command_for_diagnosis
  precmd_functions=(
    _notify_failed_command_for_diagnosis
    ${precmd_functions:#_notify_failed_command_for_diagnosis}
  )
fi
