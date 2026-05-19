### Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Annexes — shallow clone to save ~100MB of .git history per annex.
zinit depth"1" light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

# Turbo-loaded plugins. Ordering inside this block matters:
#   1. zicompinit must run before fzf-tab (fzf-tab wraps completion widgets).
#   2. fzf-tab must come before fast-syntax-highlighting / autosuggestions
#      (those wrap widgets fzf-tab needs to inspect first).
#   3. _zsh_autosuggest_start re-binds widgets after turbo load.
zinit wait lucid for \
    atinit"zicompinit; zicdreplay" \
        Aloxaf/fzf-tab \
    zdharma-continuum/fast-syntax-highlighting \
    atload"_zsh_autosuggest_start" \
        zsh-users/zsh-autosuggestions \
    blockf \
        zsh-users/zsh-completions \
    hlissner/zsh-autopair \
    agkozak/zsh-z

# OMZ libs and plugins (turbo, no SVN dependency).
zinit wait lucid for \
    OMZ::lib/clipboard.zsh \
    OMZ::lib/git.zsh \
    OMZ::lib/completion.zsh \
    OMZ::lib/directories.zsh \
    OMZ::lib/key-bindings.zsh \
    OMZ::plugins/sudo/sudo.plugin.zsh \
    OMZ::plugins/urltools/urltools.plugin.zsh \
    OMZ::plugins/git/git.plugin.zsh \
    OMZ::plugins/extract/extract.plugin.zsh

# Powerlevel10k — must stay synchronous; it owns the prompt.
zinit ice depth"1"
zinit light romkatv/powerlevel10k

# Completion zstyles
zstyle ':completion:*:git-checkout:*' sort false
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls -1 --color=always $realpath'
zstyle ':fzf-tab:*' switch-group ',' '.'
