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


# Added by Antigravity CLI installer
export PATH="/home/mrbrooks/.local/bin:$PATH"

