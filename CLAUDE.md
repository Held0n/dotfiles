# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal dotfiles for macOS, organized as **GNU stow packages**. One command (`./bootstrap-macos.sh`) takes a fresh Mac to a fully-configured working environment: Homebrew formulas/casks, zsh + powerlevel10k, iTerm2 prefs, git config, tmux/nvim configs, and SSH keys (decrypted from `age -p` ciphertext in `secrets/ssh/`).

There is no build system, no tests for the configs themselves, and no package manifest. The "tests" under `tests/` only verify the bootstrap orchestration (encrypt/decrypt round-trip, stow dry-run).

## Layout and install model

Each top-level directory (except `scripts/`, `tests/`, `docs/`, `secrets/`, and `iterm2/`) is a **stow package** whose internal structure mirrors `$HOME`:

- `bootstrap-macos.sh` — orchestrator. Installs Homebrew → runs `brew bundle` → pre-creates `~/.ssh` (700) + `~/.config` → stows packages → wires iTerm2 prefs folder → runs `scripts/decrypt-ssh.sh`.
- `Brewfile` — `brew bundle` input. `age`, `stow`, `fzf`, `jq`, and `font-maple-mono-nf` are required by bootstrap itself.
- `scripts/encrypt-ssh.sh` / `scripts/decrypt-ssh.sh` — `age -p` symmetric encryption of SSH private keys; passphrase memorized, not stored.
- `tests/test-roundtrip.sh` / `tests/test-bootstrap-dryrun.sh` — bash scripts run with `./tests/...`. The dry-run test stows into a `mktemp -d` and asserts each expected file resolves via `realpath` to the repo source.
- `zsh-macos/` — `.zshrc` (entry) + `.config/zsh/{env,zinit,prompt,functions,extras}.zsh` (the entry sources these in order).
- `zsh-ubuntu/` — verbatim copy of the old Ubuntu zshrc; NOT refactored into the 6-file split. Still sources `~/.config/script/*.zsh` paths that no longer exist (placeholder for future Ubuntu work).
- `p10k-macos/` / `p10k-ubuntu/` — powerlevel10k configs, per OS.
- `git/` — `.gitconfig` and (if present) `.gitignore_global`.
- `ssh-config/` — `.ssh/config` only. Private keys live in `secrets/ssh/*.age` and land in `~/.ssh/` via `decrypt-ssh.sh`.
- `tmux/`, `nvim/` — direct copies. Optional packages: bootstrap stows them only if the dir is non-empty.
- `iterm2/` — NOT a stow package. iTerm2 reads its plist from this folder via the `PrefsCustomFolder` default that bootstrap sets.
- `secrets/ssh/*.age` — `age -p` ciphertext of SSH keys. `.gitignore` blocks plaintext (`secrets/ssh/id_*`, `*.pem`) and allow-lists `*.age`.

## Conventions to preserve when editing

- **Bash 3.2 compatibility everywhere.** Stock macOS bash is 3.2.57. Don't use `mapfile`, `declare -A` (associative arrays), or `readlink -f`. Use parallel arrays, `realpath` (provided by `coreutils` brew), and `while IFS= read -r line; do ...; done < <(...)`. When concatenating possibly-empty arrays use `${arr[@]+"${arr[@]}"}` to avoid unbound-variable errors under `set -u`.
- **Don't break the stow folding contract.** `~/.ssh` must be a real 700-mode directory, never a symlink — otherwise `decrypt-ssh.sh` would write plaintext keys into `ssh-config/.ssh/` inside the repo, past `.gitignore`. Bootstrap pre-creates `~/.ssh` and `~/.config` for this reason; the dry-run test asserts `~/.ssh` is not a symlink.
- **Both zshrc files use [zinit](https://github.com/zdharma-continuum/zinit)** with powerlevel10k. The zinit self-installer block at the top of `zsh-macos/.config/zsh/zinit.zsh` must stay intact (it's how a fresh machine gets zinit).
- **macOS uses the 6-file split** (`zsh-macos/.config/zsh/{env,zinit,prompt,functions,extras}.zsh` sourced by `.zshrc` in that order). Ubuntu does not — it remains a single `.zshrc`. They have drifted intentionally; fixing a bug on one side does NOT automatically apply to the other.
- **Personal user-specific content is intentional.** SSH aliases (`jump`, `sr-dev`), hardcoded jumpserver hostnames, `.pem` paths under `~/.ssh/`, the encrypted key list in `secrets/ssh/` — all reference the repo owner's environment. Don't try to parameterize or generalize them.
- **iTerm2 plist is binary.** Edit through the iTerm2 GUI (it writes back to `iterm2/com.googlecode.iterm2.plist` automatically because of the `PrefsCustomFolder` setting), not by hand.
