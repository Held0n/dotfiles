# Refers to the number of commands that are stored in the zsh history file
export HISTFILE=${ZDOTDIR:-$HOME}/.zsh_history
# Refers to the number of commands that are stored in the zsh history file
export HISTSIZE=100000
# Refers to the number of commands that are loaded into memory from the history file
export SAVEHIST=100000

setopt INC_APPEND_HISTORY
setopt EXTENDED_HISTORY
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_ALL_DUPS

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

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

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

### End of Zinit's installer chunk
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
    OMZ::plugins/urltools/urltools.plugin.zsh \

zinit ice lucid wait='0'
zinit snippet OMZ::plugins/git/git.plugin.zsh
zinit ice svn
zinit svn for \
    OMZ::plugins/extract
zinit ice depth=1
zinit light romkatv/powerlevel10k

# disable sort when completing `git checkout`
zstyle ':completion:*:git-checkout:*' sort false
# set descriptions format to enable group support
zstyle ':completion:*:descriptions' format '[%d]'
# set list-colors to enable filename colorizing
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# preview directory's content with exa when completing cd
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls -1 --color=always $realpath'
# switch group using `,` and `.`
zstyle ':fzf-tab:*' switch-group ',' '.'

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

#### env ####
if [[ -d '/root/directory/zulu8.62.0.19-ca-jdk8.0.332-linux_x64' ]]; then
    export JAVA_HOME='/root/directory/zulu8.62.0.19-ca-jdk8.0.332-linux_x64'
    export PATH="$JAVA_HOME/bin:$PATH"
fi

if [[ -d '/root/directory/apache-maven-3.8.6' ]]; then
    export MVN_HOME='/root/directory/apache-maven-3.8.6'
    export PATH="$MVN_HOME/bin:$PATH"
fi

if [[ -d '/root/project/redck/build/programs' ]]; then
    export CK_DEV_HOME='/root/project/redck/build/programs'
    export PATH="$CK_DEV_HOME:$PATH"
fi

if [[ -d '/root/directory/cmake-3.20.6-linux-x86_64' ]]; then
    export CMAKE_HOME='/root/directory/cmake-3.20.6-linux-x86_64'
    export PATH="$CMAKE_HOME/bin:$PATH"
fi

if [[ -d '/root/directory/cmake-3.20.6-linux-x86_64' ]]; then
    export CMAKE_HOME='/root/directory/cmake-3.20.6-linux-x86_64'
    export PATH="$CMAKE_HOME/bin:$PATH"
fi

if [[ -d '/usr/lib/llvm-11/bin' ]]; then
    export LLVM11_HOME='/usr/lib/llvm-11';
    export PATH="$LLVM11_HOME/bin:$PATH"
fi

export LESSCHARSET=utf-8

#### script ####

source $HOME/.config/script/clickhouse_functions.zsh
source $HOME/.config/script/git_functions.zsh

#### alias ####

alias ls='ls --color=auto'
alias clickhouse-yandex-client='/root/project/ClickHouse/build/programs/clickhouse-client --port 9100'

j() {
    [ $# -gt 0 ] && zshz "$*" && return
    cd "$(zshz -l 2>&1 | fzf --height 40% --nth 2.. --reverse --inline-info +s --tac --query "${*##-* }" | sed 's/^[0-9,.]* *//')"
}

