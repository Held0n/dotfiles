# zinit installer + plugin loading + completion zstyles. Identical to the original block.

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

# Annexes
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

### Plugins
zinit light Aloxaf/fzf-tab
zinit light-mode for \
    zdharma-continuum/fast-syntax-highlighting \
    zsh-users/zsh-autosuggestions \
    zsh-users/zsh-completions \
    hlissner/zsh-autopair
zinit wait="1" lucid light-mode for \
    agkozak/zsh-z
zinit wait="1" lucid for \
    OMZ::lib/clipboard.zsh \
    OMZ::lib/git.zsh \
    OMZ::lib/completion.zsh \
    OMZ::lib/directories.zsh \
    OMZ::lib/key-bindings.zsh \
    OMZ::plugins/sudo/sudo.plugin.zsh \
    OMZ::plugins/urltools/urltools.plugin.zsh

zinit ice lucid wait='0'
zinit snippet OMZ::plugins/git/git.plugin.zsh
zinit ice svn
zinit svn for \
    OMZ::plugins/extract
zinit ice depth=1
zinit light romkatv/powerlevel10k

# Completion zstyles
zstyle ':completion:*:git-checkout:*' sort false
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls -1 --color=always $realpath'
zstyle ':fzf-tab:*' switch-group ',' '.'
