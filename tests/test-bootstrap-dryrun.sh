#!/usr/bin/env bash
# Verify stow can lay down the always-stow packages into a fresh fake $HOME.

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAKE_HOME="$(mktemp -d)"
trap 'rm -rf "$FAKE_HOME"' EXIT

cd "$REPO_ROOT"

# Mirror bootstrap-macos.sh: pre-create dirs we don't want stow to fold.
# .ssh must be a real 700-mode dir, .config must be real, .config/nvim too.
mkdir -p "$FAKE_HOME/.ssh" && chmod 700 "$FAKE_HOME/.ssh"
mkdir -p "$FAKE_HOME/.config"

# Mirror the ALWAYS list from bootstrap-macos.sh
ALWAYS=(zsh-macos p10k-macos git ssh-config)

stow -v -t "$FAKE_HOME" -d "$REPO_ROOT" "${ALWAYS[@]}" 2>&1

# Verify each expected path resolves to its repo source. stow may fold (turn a
# whole subdir into one symlink) or unfold (symlink each leaf file), so checking
# `-L` on the leaf is too strict; what we care about is functional equivalence.
# Format: "<fake-home-relative-path>|<repo-relative-source-path>"
# bash 3.2 has no associative arrays, so use parallel strings split on '|'.
EXPECTED=(
    ".zshrc|zsh-macos/.zshrc"
    ".config/zsh/env.zsh|zsh-macos/.config/zsh/env.zsh"
    ".config/zsh/zinit.zsh|zsh-macos/.config/zsh/zinit.zsh"
    ".config/zsh/prompt.zsh|zsh-macos/.config/zsh/prompt.zsh"
    ".config/zsh/functions.zsh|zsh-macos/.config/zsh/functions.zsh"
    ".config/zsh/extras.zsh|zsh-macos/.config/zsh/extras.zsh"
    ".p10k.zsh|p10k-macos/.p10k.zsh"
    ".gitconfig|git/.gitconfig"
    ".ssh/config|ssh-config/.ssh/config"
)
for pair in "${EXPECTED[@]}"; do
    path="$FAKE_HOME/${pair%%|*}"
    want="$REPO_ROOT/${pair#*|}"
    got="$(realpath "$path" 2>/dev/null || true)"
    if [[ "$got" != "$want" ]]; then
        echo "FAIL: $path -> $got (expected $want)"
        exit 1
    fi
done

# .ssh must remain a real directory (NOT a symlink), so decrypt-ssh.sh writes
# plaintext keys here locally instead of into ssh-config/.ssh/ in the repo.
if [[ -L "$FAKE_HOME/.ssh" ]]; then
    echo "FAIL: ~/.ssh is a symlink; decrypt-ssh.sh would write plaintext keys into the repo"
    exit 1
fi

# Conflict scenario: stow must refuse when target exists as a real file
CONFLICT_HOME="$(mktemp -d)"
trap 'rm -rf "$FAKE_HOME" "$CONFLICT_HOME"' EXIT
echo "preexisting" > "$CONFLICT_HOME/.zshrc"
if stow -v -t "$CONFLICT_HOME" -d "$REPO_ROOT" zsh-macos 2>/dev/null; then
    echo "FAIL: stow did not refuse to overwrite preexisting .zshrc"
    exit 1
fi

echo "PASS: stow lays down all expected symlinks; refuses conflicts"
