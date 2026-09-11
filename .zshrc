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

# Route plain `herdr` from this canonical checkout to its dedicated persistent
# session. All arguments and all other directories retain upstream behavior.
typeset _fedora_niri_zshrc_source=${${(%):-%N}:A}
unset _fedora_niri_zshrc_source

# opencode
export PATH="$HOME/.opencode/bin:$PATH"

# bun completions
[ -s "/home/mrbrooks/.bun/_bun" ] && source "/home/mrbrooks/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
