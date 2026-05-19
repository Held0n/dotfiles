# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal dotfiles. No build system, no tests, no package manifest — just shell config, terminal config, and helper scripts that get installed into `$HOME` via two small bash scripts.

## Layout and install model

- `init.sh` — bootstraps an Ubuntu host (`apt-get install fzf, exa, subversion`). macOS bootstrap is not scripted; install equivalents via Homebrew manually.
- `link.sh` — symlinks `./script` to `~/.config/script`, backing up any existing target to `~/.config/script.bak`. Run from the repo root (uses `$PWD`).
- `macos/zsh/zshrc` and `ubuntu/zsh/zshrc` — per-OS zsh configs. **Not symlinked by `link.sh`** — copy or symlink the appropriate one to `~/.zshrc` manually.
- `macos/kitty/` — kitty terminal config (`kitty.conf`, `session.conf`). Belongs at `~/.config/kitty/`.
- `ubuntu/zsh/p10k.zsh` — powerlevel10k config. Belongs at `~/.p10k.zsh`.
- `script/*.zsh` — shared zsh helper functions sourced by both `zshrc`s via `~/.config/script/...`. Edits here affect both OSes after `link.sh` has run.

## Conventions to preserve when editing

- Both `zshrc` files use [zinit](https://github.com/zdharma-continuum/zinit) for plugin management with powerlevel10k as the prompt. Keep the zinit installer block intact at the top — it self-installs on a fresh machine.
- `zshrc` sources `~/.config/script/git_functions.zsh` and `~/.config/script/clickhouse_functions.zsh`. New shared functions go in `script/` and must be sourced from both `zshrc`s to stay cross-OS.
- The macOS and Ubuntu `zshrc`s have drifted (different `PATH` exports, aliases, env detection). When fixing a bug in one, check whether the other has the same bug — they are not generated from a shared template.
- `script/clickhouse_functions.zsh` and the SSH aliases in `macos/zsh/zshrc` reference user-specific paths, hosts, and keys (e.g. `/Users/heldon/...`, internal jumpservers, `.pem` paths). Treat these as the owner's environment, not something to generalize.
