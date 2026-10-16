# DylanOS interactive Bash defaults (installed as /etc/skel/.bashrc).
case $- in
  *i*) ;;
  *) return ;;
esac

[ -r /etc/bash.bashrc ] && . /etc/bash.bashrc

export EDITOR="${EDITOR:-nano}"
export PAGER="${PAGER:-less}"

if [ -n "${TERM:-}" ] && [ "$TERM" != dumb ]; then
  PS1='\[\e[38;5;39m\]\u@\h\[\e[0m\]:\[\e[38;5;141m\]\w\[\e[0m\]\$ '
fi

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
