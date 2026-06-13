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
# Pre-create dirs we don't want stow to fold into single symlinks.
# .ssh MUST be a real 700-mode dir: decrypt-ssh.sh writes plaintext keys here
# and we don't want them landing inside ssh-config/.ssh/ in the repo.
# .config stays a real dir so unrelated tools can add subdirs alongside ours.
# .config/nvim stays a real dir so plugin managers (lazy.nvim etc.) write
# installs and lockfiles locally instead of into the repo.
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
mkdir -p "$HOME/.config"
[[ -d "$REPO_ROOT/nvim/.config/nvim" ]] && mkdir -p "$HOME/.config/nvim"

# Write the ~/.ssh/config stub if absent. ssh-config package ships my-ssh.config
# (the tracked clean config); the stub Include-s it. REDpass / OrbStack /
# coral-mutagen append their own blocks below the Include into this local file,
# which is NOT a symlink into the repo — keeping the repo free of UUIDs/Pod IPs.
if [[ ! -f "$HOME/.ssh/config" ]]; then
    log "Writing ~/.ssh/config Include stub"
    cat > "$HOME/.ssh/config" <<'EOF'
# ~/.ssh/config — bootstrap-managed stub.
# The Include below pulls in the dotfile-tracked clean SSH config first; per
# OpenSSH rules, options from earlier matches win. Anything REDpass / OrbStack /
# coral-mutagen auto-appends below stays local and does NOT enter the repo.
Include ~/.ssh/my-ssh.config
EOF
    chmod 600 "$HOME/.ssh/config"
fi

# Always-stow: configs that should exist on every macOS box.
ALWAYS=(zsh-macos p10k-macos git ssh-config)
# Optional: stow only if the package directory contains files.
OPTIONAL=(tmux nvim vim karabiner)

stow_pkgs=("${ALWAYS[@]}")
for pkg in "${OPTIONAL[@]}"; do
    if [[ -d "$REPO_ROOT/$pkg" ]] && [[ -n "$(ls -A "$REPO_ROOT/$pkg" 2>/dev/null)" ]]; then
        stow_pkgs+=("$pkg")
    fi
done

log "Stowing: ${stow_pkgs[*]}"
# Stow one package at a time. GNU stow aborts the whole operation when any
# package has conflicts; isolating packages lets the rest of the bootstrap land.
for pkg in "${stow_pkgs[@]}"; do
    log "Stowing $pkg"
    if ! stow -v -t "$HOME" -d "$REPO_ROOT" "$pkg"; then
        warn "Skipping $pkg due to stow conflicts. Resolve the target files and re-run bootstrap."
    fi
done

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
