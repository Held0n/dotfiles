# dotfile

Personal macOS dotfiles managed with [GNU stow](https://www.gnu.org/software/stow/) + Homebrew `brew bundle` + age-encrypted SSH keys.

## What's in the box

| Package | Symlinks to | Purpose |
|---|---|---|
| `zsh-macos/` | `~/.zshrc` + `~/.config/zsh/*.zsh` | zsh entry + 5 ordered fragments (env, zinit, prompt, functions, extras) |
| `p10k-macos/` | `~/.p10k.zsh` | powerlevel10k config |
| `git/` | `~/.gitconfig` | git global config |
| `ssh-config/` | `~/.ssh/my-ssh.config` | Tracked clean SSH config. `~/.ssh/config` itself is a local stub written by bootstrap that just `Include`s this — see "stow + self-writing tools" below |
| `tmux/` | `~/.tmux.conf` | tmux config |
| `nvim/` | `~/.config/nvim/` | neovim config |
| `zsh-ubuntu/`, `p10k-ubuntu/` | (Ubuntu only) | Kept for the day Ubuntu is reorganized to mirror the macOS layout |
| `iterm2/` | (not stowed) | iTerm2 reads its plist from this directory directly |
| `secrets/ssh/` | (not stowed) | age-encrypted SSH private keys; `decrypt-ssh.sh` lands them in `~/.ssh/` |

## New-mac install

```sh
# 0. Manual prerequisites
xcode-select --install
git clone <repo-url> <path of your choosing>
cd <that path>

# 1. One command
./bootstrap-macos.sh
```

`bootstrap-macos.sh` does, in order:

1. Install Homebrew if missing.
2. `brew bundle --file=Brewfile` (formulas, casks, fonts, mas).
3. `stow` the always-on packages (`zsh-macos p10k-macos git ssh-config`), plus any of `tmux nvim vim` whose directory is non-empty.
4. Set iTerm2 `PrefsCustomFolder` to `<repo>/iterm2`.
5. Run `scripts/decrypt-ssh.sh` (prompts for the age passphrase).

`stow` will REFUSE to overwrite any existing non-symlink files; if you see a conflict, delete or rename the offending file in `$HOME`, then re-run.

### After bootstrap

- `chsh -s /opt/homebrew/bin/zsh` (set Homebrew zsh as login shell).
- Open iTerm2 once so it loads prefs from the repo (font should be **Maple Mono NF**).
- `ssh -T git@github.com` to verify GitHub key works.
- Install REDpass if needed — it will write its own block into `~/.ssh/config`.

## Day-to-day maintenance

| Change | What to do |
|---|---|
| Installed a new brew/cask | `brew bundle dump --file=Brewfile --force --describe`, review, commit |
| iTerm2 setting change | Already auto-written into `iterm2/com.googlecode.iterm2.plist`; `git status` + commit |
| zsh tweak | Edit the file in the repo (it's already a symlink target); reload with `exec zsh` |
| New SSH key on this mac | `./scripts/encrypt-ssh.sh ~/.ssh/<newkey>` then commit `secrets/ssh/<newkey>.age` |

## SSH key encryption

Private keys are encrypted with [age](https://age-encryption.org/) in passphrase mode. The passphrase is **memorized**, not stored anywhere — losing it means losing every key in `secrets/ssh/`.

```sh
# Encrypt one or more keys (called interactively or with explicit paths)
./scripts/encrypt-ssh.sh ~/.ssh/id_rsa ~/.ssh/id_rsa.pub

# Decrypt every secrets/ssh/*.age back to ~/.ssh/, chmod 600 (called by bootstrap)
./scripts/decrypt-ssh.sh
```

`decrypt-ssh.sh` is **non-overwriting**: if a target exists in `~/.ssh/`, it is left alone. To replace a key, delete it from `~/.ssh/` first.

Recommended passphrase: 6+ diceware words (or equivalent ~80 bits of entropy). age uses scrypt; weak passphrases can be brute-forced offline if the repo is exposed.

## stow + self-writing tools

`~/.ssh/config` is **not** a symlink. Bootstrap writes it as a local stub whose only content is:

```
Include ~/.ssh/my-ssh.config
```

The tracked clean config lives in `ssh-config/.ssh/my-ssh.config` and is symlinked into `~/.ssh/my-ssh.config`. Tools like **REDpass**, **OrbStack**, and the **Coral** dev-sandbox toolchain auto-append blocks to `~/.ssh/config` — those writes land in the local stub, NOT the repo, so machine-specific UUIDs and ephemeral Pod IPs never enter version control. Per OpenSSH rules, options from earlier matches win, so the `Include` (read first) takes precedence over anything appended below it.

`.gitignore` also blocks `ssh-config/.ssh/config` as defense-in-depth: if a future misconfiguration ever re-creates that path inside the repo, git will refuse to stage it.

## Troubleshooting

- **Nerd Font icons not rendering**: iTerm2 → Profiles → Text → confirm font is **Maple Mono NF**. If not in the picker, `brew install --cask font-maple-mono-nf` and restart iTerm2.
- **p10k complains about font**: same as above.
- **`stow` reports conflict on `.zshrc`**: an oh-my-zsh or default install left a `~/.zshrc`. `mv ~/.zshrc ~/.zshrc.preexisting && ./bootstrap-macos.sh` again.
- **`ssh -T git@github.com` → permission denied**: `ls -la ~/.ssh/id_rsa_myself` — file should be present, perms 600. If missing, `./scripts/decrypt-ssh.sh`.
