# macOS env / PATH / brew completions.
export TERM=xterm-256color
export LLVM11_HOME=/opt/homebrew/opt/llvm@11
export LLVM13_HOME=/opt/homebrew/opt/llvm@13
export JAVA_HOME="/Library/Java/JavaVirtualMachines/zulu-8.jdk/Contents/Home"
export CLASSPATH=".:$JAVA_HOME/lib:$JRE_HOME/lib:$CLASSPATH"

export PATH="$PATH:$LLVM13_HOME/bin"
export PATH="$PATH:$LLVM11_HOME/bin"
export PATH="$PATH:$JAVA_HOME"

unsetopt LIST_BEEP

if type brew &>/dev/null; then
    FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
    autoload -Uz compinit
    compinit
fi
