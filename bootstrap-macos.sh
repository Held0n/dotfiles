#!/usr/bin/env bash
# bootstrap-macos.sh — one-shot installer for a fresh macOS box.
# Idempotent: re-running should not break anything.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_ROOT"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m  %s\n' "$*" >&2; }
die()  { printf '\033[1;31mXX\033[0m %s\n' "$*" >&2; exit 1; }

# --- 1. Homebrew ----------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
    log "Installing Homebrew…"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for the rest of this script (Apple Silicon path).
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    log "Homebrew already installed."
fi

# --- 2. brew bundle -------------------------------------------------------
log "Running brew bundle…"
brew bundle --file="$REPO_ROOT/Brewfile"

# --- 3. stow packages -----------------------------------------------------
# Always-stow: configs that should exist on every macOS box.
ALWAYS=(zsh-macos p10k-macos git ssh-config)
# Optional: stow only if the package directory contains files.
OPTIONAL=(tmux nvim vim)

stow_pkgs=("${ALWAYS[@]}")
for pkg in "${OPTIONAL[@]}"; do
    if [[ -d "$REPO_ROOT/$pkg" ]] && [[ -n "$(ls -A "$REPO_ROOT/$pkg" 2>/dev/null)" ]]; then
        stow_pkgs+=("$pkg")
    fi
done

log "Stowing: ${stow_pkgs[*]}"
# stow refuses to overwrite existing non-symlink files — by design.
stow -v -t "$HOME" -d "$REPO_ROOT" "${stow_pkgs[@]}"

# --- 4. iTerm2 PrefsCustomFolder -----------------------------------------
log "Configuring iTerm2 to load prefs from $REPO_ROOT/iterm2"
defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$REPO_ROOT/iterm2"
defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true

# --- 5. Decrypt SSH keys --------------------------------------------------
if compgen -G "$REPO_ROOT/secrets/ssh/*.age" > /dev/null; then
    log "Decrypting SSH keys (passphrase prompts coming)…"
    "$REPO_ROOT/scripts/decrypt-ssh.sh"
else
    warn "No secrets/ssh/*.age files; skipping SSH key decryption."
fi

# --- 6. Post-install hints ------------------------------------------------
log "Bootstrap complete."
cat <<'EOF'

Manual follow-ups:
  1. chsh -s /opt/homebrew/bin/zsh    (set Homebrew zsh as login shell)
  2. Open iTerm2 once to load prefs from the repo (font should render as Maple Mono NF).
  3. Test: ssh -T git@github.com
  4. If REDpass is needed, install it; it will write its own ~/.ssh/config block.

EOF
