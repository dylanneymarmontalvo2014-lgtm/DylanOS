# DylanOS interactive Zsh defaults (installed as /etc/skel/.zshrc).
autoload -Uz compinit && compinit

export EDITOR="${EDITOR:-nano}"
export PAGER="${PAGER:-less}"

setopt autocd
setopt hist_ignore_dups
setopt hist_ignore_space
HISTFILE="$HOME/.zsh_history"
HISTSIZE=5000
SAVEHIST=5000

PROMPT='%F{cyan}%n@%m%f:%F{magenta}%~%f%# '
[[ -o interactive ]] && alias ll='ls -alF'
