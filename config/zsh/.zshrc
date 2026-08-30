# Ikigai zsh — seeded once by the installer; yours from here on.

export PATH="$HOME/.local/share/ikigai/bin:$HOME/.local/bin:$PATH"
export EDITOR="zed --wait"
export VISUAL="$EDITOR"

HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000
setopt HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE SHARE_HISTORY
setopt AUTO_CD INTERACTIVE_COMMENTS

autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

bindkey -e
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^[[3~' delete-char

git_current_branch() {
  local ref
  ref=$(git symbolic-ref --quiet HEAD 2>/dev/null) || ref=$(git rev-parse --short HEAD 2>/dev/null) || return
  echo "${ref#refs/heads/}"
}
source "$HOME/.config/zsh/git-aliases.zsh"

alias ls="eza --icons --group-directories-first"
alias ll="eza -l --icons --group-directories-first --git"
alias la="eza -la --icons --group-directories-first --git"
alias tree="eza --tree --icons"
alias cat="bat --paging=never"
alias du="dust"
alias grep="rg"
alias lg="lazygit"
alias ld="lazydocker"
alias c="clear"
alias zj="zellij attach --create main"

y() {
  local tmp; tmp="$(mktemp -t yazi-cwd.XXXXXX)"
  yazi "$@" --cwd-file="$tmp"
  local cwd; cwd="$(<"$tmp")"; rm -f "$tmp"
  [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && cd -- "$cwd"
}

source /usr/share/fzf/key-bindings.zsh
source /usr/share/fzf/completion.zsh
source "$HOME/.config/fzf/theme.sh"
export FZF_DEFAULT_COMMAND="fd --type f --hidden --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

eval "$(mise activate zsh)"
eval "$(starship init zsh)"

source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

[ -f "$HOME/.config/secrets.zsh" ] && source "$HOME/.config/secrets.zsh"
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
