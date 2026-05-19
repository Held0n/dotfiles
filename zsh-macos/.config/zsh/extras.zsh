# Aliases, focus reporting reset, bun, extra PATH entries.

alias ls='exa'
alias clear="clear && printf '\e[3J'"
alias jump="ssh -i ~/.ssh/zhanghongtai-jumpserver.pem zhanghongtai@jumpserver.devops.xiaohongshu.com"
alias sr-dev='ssh -t -i ~/.ssh/starrocks-dev root@10.4.65.79 "tmux new-session -A -s main"'

export PATH="$HOME/.local/bin:$PATH"
export PATH="/opt/homebrew/opt/mysql-client/bin:$PATH"

# Reset focus reporting to prevent leaking 1004l after broken SSH sessions.
_reset_focus_reporting() {
    printf '\033[?1004l'
}
trap '_reset_focus_reporting' EXIT

# bun
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
