# macOS Dotfile Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild this dotfile repo as a stow-managed system that bootstraps a new macOS box end-to-end via one `bootstrap-macos.sh` command — brew bundle, stow packages, iTerm2 prefs from a custom folder, and age+passphrase-encrypted SSH keys.

**Architecture:** Each top-level directory (except `scripts/`, `docs/`, `secrets/`, `iterm2/`) is a GNU stow package whose internal layout mirrors `$HOME`. `bootstrap-macos.sh` orchestrates: install Homebrew → `brew bundle` → `stow` packages → set iTerm2 PrefsCustomFolder → `decrypt-ssh.sh`. SSH private keys live as `*.age` ciphertext in `secrets/ssh/` and are decrypted on the new box with the user's memorized passphrase.

**Tech Stack:** bash 3.2+ (default macOS), GNU stow, age (passphrase mode), Homebrew + `brew bundle`, `expect` (for round-trip tests), `fzf` (for interactive SSH key selection).

**Spec:** `docs/superpowers/specs/2026-05-19-macos-dotfile-sync-design.md`

**Branch:** `feat/macos-dotfile-sync` (already checked out).

---

## File Structure

### New files

| Path | Purpose |
|---|---|
| `.gitignore` | Block plaintext private keys from accidental commits |
| `Brewfile` | `brew bundle` input — formulas, casks, fonts, mas apps |
| `bootstrap-macos.sh` | New-mac entry point; orchestrates 6 install steps |
| `scripts/encrypt-ssh.sh` | Old-mac tool: `~/.ssh/<key>` → `secrets/ssh/<key>.age` |
| `scripts/decrypt-ssh.sh` | New-mac tool: `secrets/ssh/<key>.age` → `~/.ssh/<key>` (chmod 600) |
| `tests/test-roundtrip.sh` | Verifies encrypt/decrypt round-trip integrity using `expect` |
| `tests/test-bootstrap-dryrun.sh` | Smoke-tests bootstrap-macos.sh against a fake `$HOME` |
| `zsh-macos/.zshrc` | Entry; sources the 5 files below in order |
| `zsh-macos/.config/zsh/env.zsh` | macOS env / PATH / brew compinit |
| `zsh-macos/.config/zsh/zinit.zsh` | zinit installer + plugin loading + zstyle |
| `zsh-macos/.config/zsh/prompt.zsh` | Source `~/.p10k.zsh` if exists |
| `zsh-macos/.config/zsh/functions.zsh` | `j()` + `git_branch` + `list_branch_with_description` |
| `zsh-macos/.config/zsh/extras.zsh` | Aliases + focus reporting trap + bun + extra PATH |
| `p10k-macos/.p10k.zsh` | Copy of `~/.p10k.zsh` |
| `git/.gitconfig` | Copy of `~/.gitconfig` |
| `ssh-config/.ssh/config` | Copy of `~/.ssh/config` with REDpass block stripped |
| `iterm2/com.googlecode.iterm2.plist` | Written by iTerm2 after PrefsCustomFolder is set |
| `tmux/.tmux.conf` | Copy of `~/.tmux.conf` |
| `nvim/.config/nvim/init.lua` etc. | Copy of `~/.config/nvim/` tree |
| `secrets/ssh/{id_rsa,id_rsa_myself,coral_ed25519,starrocks-dev}{,.pub}.age` | age ciphertexts of the 4 keypairs |
| `secrets/ssh/zhanghongtai-jumpserver.pem.age` | age ciphertext of the jumpserver pem |
| `README.md` | Install + daily-maintenance docs |
| `zsh-ubuntu/.zshrc` | Verbatim copy of `ubuntu/zsh/zshrc` (Ubuntu side untouched this round) |
| `p10k-ubuntu/.p10k.zsh` | Verbatim copy of `ubuntu/zsh/p10k.zsh` |

### Deleted files

| Path | Reason |
|---|---|
| `init.sh` | Ubuntu apt bootstrap superseded by stow + Brewfile model (Ubuntu out of scope) |
| `link.sh` | Replaced by stow |
| `macos/zsh/zshrc` | Content split into 6 files under `zsh-macos/` |
| `macos/kitty/` | kitty no longer used |
| `ubuntu/zsh/zshrc` | Content moved verbatim into `zsh-ubuntu/.zshrc` |
| `ubuntu/zsh/p10k.zsh` | Content moved verbatim into `p10k-ubuntu/.p10k.zsh` |
| `script/clickhouse_functions.zsh` | ClickHouse work not migrated |
| `script/git_functions.zsh` | Merged into `zsh-macos/.config/zsh/functions.zsh` |
| `script/` (now empty) | Top-level `script/` package eliminated |
| `macos/`, `ubuntu/` (now empty) | After moves complete |

---

## Task 1: Create directory skeleton, .gitignore, empty Brewfile

**Files:**
- Create: `.gitignore`
- Create: `Brewfile` (empty placeholder, populated in Task 11)
- Create: `scripts/.gitkeep`
- Create: `tests/.gitkeep`
- Create: `secrets/ssh/.gitkeep`
- Create: `iterm2/.gitkeep`

- [ ] **Step 1: Create directories**

```bash
cd /Users/heldon/Directory/Project/dotfile
mkdir -p scripts tests secrets/ssh iterm2
touch scripts/.gitkeep tests/.gitkeep secrets/ssh/.gitkeep iterm2/.gitkeep
```

- [ ] **Step 2: Write .gitignore**

Create `.gitignore` with this exact content:

```gitignore
# Plaintext private keys / pems must never enter git, even if encrypt-ssh.sh
# was forgotten. .age ciphertexts are explicitly allow-listed.
secrets/ssh/*
!secrets/ssh/.gitkeep
!secrets/ssh/*.age

# iTerm2 may write a number of cruft files alongside the plist
iterm2/*.xml
iterm2/*Companions*

# OS junk
.DS_Store
```

- [ ] **Step 3: Write empty Brewfile placeholder**

Create `Brewfile` with this exact content (populated for real in Task 11):

```ruby
# Generated initially by `brew bundle dump --describe`, then hand-trimmed.
# Required additions (do not remove unless you also stop using them):
#   - age, stow, fzf, jq  → bootstrap & scripts
#   - font-maple-mono-nf  → iTerm2 + p10k font
```

- [ ] **Step 4: Commit**

```bash
git add .gitignore Brewfile scripts/ tests/ secrets/ iterm2/
git commit -m "feat: create new stow-package skeleton + .gitignore"
```

---

## Task 2: Write scripts/encrypt-ssh.sh

**Files:**
- Create: `scripts/encrypt-ssh.sh`

This script encrypts SSH private keys (and `.pem` files) into `secrets/ssh/<name>.age` using `age -p` (passphrase mode). It supports two modes:
- **Interactive** (no args): scans `$HOME/.ssh/` + `$HOME/zhanghongtai-jumpserver.pem`, uses `fzf` for multi-select.
- **Programmatic** (`--source FILE ...` + optional `--target DIR`): used by tests and for scripted use.

- [ ] **Step 1: Write the script**

Create `scripts/encrypt-ssh.sh` with this exact content:

```bash
#!/usr/bin/env bash
# Encrypt SSH private keys into secrets/ssh/*.age with age -p (passphrase mode).
# Usage:
#   ./scripts/encrypt-ssh.sh                          # interactive: fzf-select from ~/.ssh + ~/zhanghongtai*.pem
#   ./scripts/encrypt-ssh.sh FILE [FILE ...]          # programmatic: encrypt listed files
#   ./scripts/encrypt-ssh.sh --target DIR FILE ...    # write to DIR instead of <repo>/secrets/ssh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_DIR="$REPO_ROOT/secrets/ssh"

# --target DIR
if [[ "${1:-}" == "--target" ]]; then
    TARGET_DIR="$2"
    shift 2
fi
mkdir -p "$TARGET_DIR"

# Build the list of files to encrypt
files=()
if [[ $# -gt 0 ]]; then
    files=("$@")
else
    # Interactive: fzf multi-select
    candidates=()
    while IFS= read -r f; do
        candidates+=("$f")
    done < <(
        find "$HOME/.ssh" -maxdepth 1 -type f \
            \( -name 'id_*' -o -name '*.pem' \) ! -name '*.pub' 2>/dev/null
        find "$HOME" -maxdepth 1 -type f -name '*.pem' 2>/dev/null
    )
    # Add corresponding .pub files (the spec wants public keys encrypted too,
    # for full round-trip recovery).
    pubs=()
    for f in "${candidates[@]}"; do
        [[ -f "$f.pub" ]] && pubs+=("$f.pub")
    done
    candidates+=("${pubs[@]}")
    if [[ ${#candidates[@]} -eq 0 ]]; then
        echo "No candidate keys found in ~/.ssh or ~/." >&2
        exit 1
    fi
    mapfile -t files < <(printf '%s\n' "${candidates[@]}" | fzf --multi --prompt='Select files to encrypt > ')
    if [[ ${#files[@]} -eq 0 ]]; then
        echo "Nothing selected." >&2
        exit 1
    fi
fi

# Single-shot passphrase prompt: read once into a tmp file, age reuses it via tty redirection.
# (age -p prompts on /dev/tty twice per invocation; we accept that and call age once per file.)
echo "About to encrypt ${#files[@]} file(s) into $TARGET_DIR"
for f in "${files[@]}"; do
    if [[ ! -f "$f" ]]; then
        echo "Skip (not found): $f" >&2
        continue
    fi
    out="$TARGET_DIR/$(basename "$f").age"
    echo "→ $f  ⇒  $out"
    age -p -o "$out" "$f"
done

echo
echo "Done. Review and commit:"
echo "  cd $REPO_ROOT && git status secrets/ssh/"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/encrypt-ssh.sh
```

- [ ] **Step 3: Smoke-test the help / no-args path**

```bash
./scripts/encrypt-ssh.sh --target /tmp/never-exists-dir /dev/null 2>&1 || true
```

Expected: script runs, mkdir's the dir, attempts `age -p -o /tmp/.../null.age /dev/null` which will prompt for a passphrase on tty. Since stdin is not a tty here, it will fail with "no tty" — that's fine. We just confirm the script reaches `age` without earlier crashes. Hit Ctrl-C to abort.

- [ ] **Step 4: Commit**

```bash
git add scripts/encrypt-ssh.sh
git commit -m "feat(scripts): add encrypt-ssh.sh with interactive + programmatic modes"
```

---

## Task 3: Write scripts/decrypt-ssh.sh

**Files:**
- Create: `scripts/decrypt-ssh.sh`

Decrypts every `*.age` under `secrets/ssh/` (or `--source DIR`) back to `~/.ssh/` (or `--target DIR`). Never overwrites existing files. Chmods private keys to 600.

- [ ] **Step 1: Write the script**

Create `scripts/decrypt-ssh.sh` with this exact content:

```bash
#!/usr/bin/env bash
# Decrypt secrets/ssh/*.age into ~/.ssh/ with age -d.
# Usage:
#   ./scripts/decrypt-ssh.sh                          # default: <repo>/secrets/ssh → ~/.ssh
#   ./scripts/decrypt-ssh.sh --source DIR --target DIR

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$REPO_ROOT/secrets/ssh"
TARGET_DIR="$HOME/.ssh"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --source) SOURCE_DIR="$2"; shift 2 ;;
        --target) TARGET_DIR="$2"; shift 2 ;;
        *) echo "Unknown flag: $1" >&2; exit 2 ;;
    esac
done

mkdir -p "$TARGET_DIR"
chmod 700 "$TARGET_DIR"

shopt -s nullglob
ciphertexts=("$SOURCE_DIR"/*.age)
shopt -u nullglob
if [[ ${#ciphertexts[@]} -eq 0 ]]; then
    echo "No *.age files in $SOURCE_DIR" >&2
    exit 1
fi

echo "About to decrypt ${#ciphertexts[@]} file(s) into $TARGET_DIR"
echo "(age will prompt for the passphrase once per file)"

for cipher in "${ciphertexts[@]}"; do
    name="$(basename "$cipher" .age)"
    out="$TARGET_DIR/$name"
    if [[ -e "$out" ]]; then
        echo "SKIP (already exists): $out"
        continue
    fi
    echo "→ $cipher  ⇒  $out"
    age -d -o "$out" "$cipher"
    # Private keys: chmod 600. Public keys: chmod 644.
    case "$name" in
        *.pub) chmod 644 "$out" ;;
        *)     chmod 600 "$out" ;;
    esac
done

echo
echo "Done. Verify with: ls -la $TARGET_DIR"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/decrypt-ssh.sh
```

- [ ] **Step 3: Smoke-test the "empty source" path**

```bash
mkdir -p /tmp/empty-secrets
./scripts/decrypt-ssh.sh --source /tmp/empty-secrets --target /tmp/test-ssh-out 2>&1 || true
rm -rf /tmp/empty-secrets /tmp/test-ssh-out
```

Expected: prints `No *.age files in /tmp/empty-secrets` and exits non-zero.

- [ ] **Step 4: Commit**

```bash
git add scripts/decrypt-ssh.sh
git commit -m "feat(scripts): add decrypt-ssh.sh with non-overwrite + chmod 600/644"
```

---

## Task 4: Write the round-trip test using expect

**Files:**
- Create: `tests/test-roundtrip.sh`

This test verifies that `encrypt-ssh.sh` followed by `decrypt-ssh.sh` produces byte-identical output, and that file permissions are correct. `age -p` reads the passphrase from `/dev/tty`, so we drive it with `expect` (macOS ships with `expect` built in).

- [ ] **Step 1: Write the test**

Create `tests/test-roundtrip.sh` with this exact content:

```bash
#!/usr/bin/env bash
# Round-trip test: encrypt a fake key → decrypt → diff plaintext → check perms.
# Requires: age, expect (both pre-installed on macOS or via Brewfile).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

SRC_DIR="$TMP/ssh-src"
SECRETS_DIR="$TMP/secrets/ssh"
DEC_DIR="$TMP/ssh-dec"
mkdir -p "$SRC_DIR" "$SECRETS_DIR" "$DEC_DIR"

# Create a deterministic fake "private key"
printf 'fake-private-key-line-1\nfake-private-key-line-2\n' > "$SRC_DIR/id_test"
chmod 600 "$SRC_DIR/id_test"

PASS='roundtrip-test-passphrase-do-not-ship'

# Encrypt via expect
expect <<EOF
log_user 0
spawn $REPO_ROOT/scripts/encrypt-ssh.sh --target $SECRETS_DIR $SRC_DIR/id_test
expect {
    -re "passphrase.*:" { send "$PASS\r"; exp_continue }
    -re "Confirm.*:"    { send "$PASS\r"; exp_continue }
    eof
}
EOF

[[ -f "$SECRETS_DIR/id_test.age" ]] || { echo "FAIL: ciphertext missing"; exit 1; }

# Decrypt via expect
expect <<EOF
log_user 0
spawn $REPO_ROOT/scripts/decrypt-ssh.sh --source $SECRETS_DIR --target $DEC_DIR
expect {
    -re "passphrase.*:" { send "$PASS\r"; exp_continue }
    eof
}
EOF

[[ -f "$DEC_DIR/id_test" ]] || { echo "FAIL: decrypted file missing"; exit 1; }
diff "$SRC_DIR/id_test" "$DEC_DIR/id_test" || { echo "FAIL: content mismatch"; exit 1; }

perms=$(stat -f "%Lp" "$DEC_DIR/id_test")
[[ "$perms" == "600" ]] || { echo "FAIL: perms=$perms (want 600)"; exit 1; }

# Idempotency: second decrypt must SKIP (not overwrite)
output=$($REPO_ROOT/scripts/decrypt-ssh.sh --source "$SECRETS_DIR" --target "$DEC_DIR" 2>&1 || true)
echo "$output" | grep -q "SKIP" || { echo "FAIL: re-decrypt did not skip; got: $output"; exit 1; }

echo "PASS: encrypt → decrypt round-trip, perms, idempotency"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x tests/test-roundtrip.sh
```

- [ ] **Step 3: Run the test**

```bash
# age must be installed first; on this mac if not present:
brew list age >/dev/null 2>&1 || brew install age
./tests/test-roundtrip.sh
```

Expected output: `PASS: encrypt → decrypt round-trip, perms, idempotency`

If FAIL: inspect the expect output, check that `age` is in PATH, and confirm `/dev/tty` works in the shell where you ran it.

- [ ] **Step 4: Commit**

```bash
git add tests/test-roundtrip.sh
git commit -m "test: round-trip encrypt/decrypt with expect-driven passphrase"
```

---

## Task 5: Encrypt the actual SSH keys (interactive — USER must enter passphrase)

**Files:**
- Create: `secrets/ssh/id_rsa.age`
- Create: `secrets/ssh/id_rsa.pub.age`
- Create: `secrets/ssh/id_rsa_myself.age`
- Create: `secrets/ssh/id_rsa_myself.pub.age`
- Create: `secrets/ssh/coral_ed25519.age`
- Create: `secrets/ssh/coral_ed25519.pub.age`
- Create: `secrets/ssh/starrocks-dev.age`
- Create: `secrets/ssh/starrocks-dev.pub.age`
- Create: `secrets/ssh/zhanghongtai-jumpserver.pem.age`

> **STOP — INTERACTIVE STEP.** The user must type their chosen passphrase. Do NOT auto-run this with a placeholder passphrase. Once the user runs the script and answers the prompts, continue to Step 2.

- [ ] **Step 1: User runs the encryption (passphrase prompted twice per file)**

```bash
./scripts/encrypt-ssh.sh \
    ~/.ssh/id_rsa           ~/.ssh/id_rsa.pub \
    ~/.ssh/id_rsa_myself    ~/.ssh/id_rsa_myself.pub \
    ~/.ssh/coral_ed25519    ~/.ssh/coral_ed25519.pub \
    ~/.ssh/starrocks-dev    ~/.ssh/starrocks-dev.pub \
    ~/zhanghongtai-jumpserver.pem
```

The user must use the **same passphrase** for every file (recommended: 6+ diceware words). Forgetting this passphrase means all 9 files are unrecoverable.

- [ ] **Step 2: Verify all 9 ciphertexts exist**

```bash
ls -la secrets/ssh/*.age
```

Expected: 9 files, none empty.

- [ ] **Step 3: Sanity-check by decrypting ONE file to a tmp dir**

```bash
mkdir -p /tmp/ssh-verify
./scripts/decrypt-ssh.sh --source secrets/ssh --target /tmp/ssh-verify
# User enters same passphrase, then:
diff ~/.ssh/id_rsa /tmp/ssh-verify/id_rsa && echo "OK: id_rsa round-trip matches plaintext"
rm -rf /tmp/ssh-verify
```

Expected: `OK: id_rsa round-trip matches plaintext`. If diff fails, do NOT commit — passphrase was likely mistyped during encrypt.

- [ ] **Step 4: Commit**

```bash
git add secrets/ssh/*.age
git commit -m "secrets: encrypt 4 SSH keypairs + jumpserver.pem with age passphrase"
```

---

## Task 6: Split macos zshrc into 6 files under zsh-macos/

**Files:**
- Read: `macos/zsh/zshrc` (current source)
- Read: `script/git_functions.zsh` (will be merged into functions.zsh)
- Create: `zsh-macos/.zshrc`
- Create: `zsh-macos/.config/zsh/env.zsh`
- Create: `zsh-macos/.config/zsh/zinit.zsh`
- Create: `zsh-macos/.config/zsh/prompt.zsh`
- Create: `zsh-macos/.config/zsh/functions.zsh`
- Create: `zsh-macos/.config/zsh/extras.zsh`

- [ ] **Step 1: Create the directory layout**

```bash
mkdir -p zsh-macos/.config/zsh
```

- [ ] **Step 2: Write `zsh-macos/.zshrc` (entry point)**

```sh
# zsh-macos: entry point. Splits the old monolithic ~/.zshrc into 5 ordered files.
source ~/.config/zsh/env.zsh
source ~/.config/zsh/zinit.zsh
source ~/.config/zsh/prompt.zsh
source ~/.config/zsh/functions.zsh
source ~/.config/zsh/extras.zsh
```

- [ ] **Step 3: Write `zsh-macos/.config/zsh/env.zsh`**

```sh
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
```

Note: the `export CK_HOME=...` and `export PATH="$PATH:$CK_HOME"` lines from the old zshrc are **intentionally not included** (ClickHouse migration is out of scope).

- [ ] **Step 4: Write `zsh-macos/.config/zsh/zinit.zsh`**

```sh
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
```

- [ ] **Step 5: Write `zsh-macos/.config/zsh/prompt.zsh`**

```sh
# Load p10k config if present.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
```

- [ ] **Step 6: Write `zsh-macos/.config/zsh/functions.zsh`**

This file merges `j()` (from old zshrc) with the contents of `script/git_functions.zsh`.

```sh
# Shared shell functions. Merged from old zshrc + script/git_functions.zsh.

# Jump to a frecent directory via zshz + fzf.
j() {
    [ $# -gt 0 ] && zshz "$*" && return
    cd "$(zshz -l 2>&1 | fzf --height 40% --nth 2.. --reverse --inline-info +s --tac --query "${*##-* }" | sed 's/^[0-9,.]* *//')"
}

# --- git branch helpers (from former script/git_functions.zsh) ---
# https://github.com/bahmutov/git-branches/blob/master/branches.sh
list_branch_with_description() {
    branches=$(git branch --list "$1")
    while read -r branch; do
        clean_branch_name=${branch//\*\ /}
        clean_branch_name=$(echo "$clean_branch_name" | tr -d '[:cntrl:]' | sed -E "s/\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g")
        clean_branch_name=$(echo "$clean_branch_name" | sed -E "s/^.+ -> //g")
        description=$(git config "branch.$clean_branch_name.description")
        if [[ "${branch:0:1}" = "*" ]]; then
            printf "%s %s\n" "$branch" "$description"
        else
            printf "  %s %s\n" "$branch" "$description"
        fi
    done <<< "$branches"
}

git_branch() {
    if [[ "$*" = "" ]]; then
        list_branch_with_description "--color"
    elif [[ "$*" =~ "--color" || "$*" =~ "--no-color" ]]; then
        list_branch_with_description "$*"
    else
        branch_operation_result=$(git branch "$@")
        printf "%s\n" "$branch_operation_result"
    fi
}
```

Note: `source ~/.config/script/clickhouse_functions.zsh` from the old zshrc is **intentionally not included** (ClickHouse migration is out of scope).

- [ ] **Step 7: Write `zsh-macos/.config/zsh/extras.zsh`**

```sh
# Aliases, focus reporting reset, bun, extra PATH entries.

alias ls='exa'
alias clear="clear && printf '\e[3J'"
alias jump="ssh -i ~/.ssh/zhanghongtai-jumpserver.pem zhanghongtai@jumpserver.devops.xiaohongshu.com"
alias sr-dev='ssh -t -i ~/.ssh/starrocks-dev root@10.4.65.79 "tmux new-session -A -s main"'

export PATH="$HOME/.local/bin:$PATH"
export PATH="/opt/homebrew/opt/mysql-client/bin:$PATH"

# Reset focus reporting to prevent leaking 1004l after broken SSH sessions.
_reset_focus_reporting() {
    printf '\033[?1004l'
}
trap '_reset_focus_reporting' EXIT

# bun
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
```

The `alias jump` pem path was rewritten from `/Users/heldon/zhanghongtai-jumpserver.pem` to `~/.ssh/zhanghongtai-jumpserver.pem` to align with where `decrypt-ssh.sh` lands the file.

- [ ] **Step 8: Verify it parses**

```bash
zsh -n zsh-macos/.zshrc \
       zsh-macos/.config/zsh/env.zsh \
       zsh-macos/.config/zsh/zinit.zsh \
       zsh-macos/.config/zsh/prompt.zsh \
       zsh-macos/.config/zsh/functions.zsh \
       zsh-macos/.config/zsh/extras.zsh \
    && echo "SYNTAX OK"
```

Expected: `SYNTAX OK`. Any error message means a typo in one of the files — fix before committing.

- [ ] **Step 9: Commit**

```bash
git add zsh-macos/
git commit -m "feat(zsh-macos): split zshrc into 6 files, merge git_functions, drop clickhouse"
```

---

## Task 7: Migrate p10k.zsh into p10k-macos/

**Files:**
- Create: `p10k-macos/.p10k.zsh` (copy of `~/.p10k.zsh`)

- [ ] **Step 1: Copy the file**

```bash
mkdir -p p10k-macos
cp ~/.p10k.zsh p10k-macos/.p10k.zsh
```

- [ ] **Step 2: Verify Nerd Font mode setting**

```bash
grep -E "^\s*typeset -g POWERLEVEL9K_MODE" p10k-macos/.p10k.zsh
```

Expected: a line like `typeset -g POWERLEVEL9K_MODE=nerdfont-complete` or `=nerdfont-v3`. If it shows something else (e.g. `compatible` or `awesome-fontconfig`), edit the file and replace the value with `nerdfont-v3`. If the line is missing entirely, leave the file alone — p10k defaults are fine.

- [ ] **Step 3: Commit**

```bash
git add p10k-macos/.p10k.zsh
git commit -m "feat(p10k-macos): import ~/.p10k.zsh"
```

---

## Task 8: Migrate ~/.gitconfig into git/

**Files:**
- Create: `git/.gitconfig` (copy of `~/.gitconfig`)

`~/.gitignore_global` does not exist on this machine (`git config --global core.excludesfile` returns empty), so it is not migrated.

- [ ] **Step 1: Copy**

```bash
mkdir -p git
cp ~/.gitconfig git/.gitconfig
```

- [ ] **Step 2: Sanity check**

```bash
cat git/.gitconfig
```

Expected: typical git config (user.name, user.email, maybe aliases). Confirm no surprises.

- [ ] **Step 3: Commit**

```bash
git add git/.gitconfig
git commit -m "feat(git): import ~/.gitconfig"
```

---

## Task 9: Migrate ~/.ssh/config into ssh-config/, strip REDpass UUID

**Files:**
- Create: `ssh-config/.ssh/config` (copy of `~/.ssh/config` with REDpass block removed)

- [ ] **Step 1: Copy and strip in one go**

```bash
mkdir -p ssh-config/.ssh
# Strip everything from "# REDpassSSHAgent BEGIN" through "# REDpassSSHAgent END" inclusive.
sed '/# REDpassSSHAgent BEGIN/,/# REDpassSSHAgent END/d' ~/.ssh/config > ssh-config/.ssh/config
chmod 600 ssh-config/.ssh/config
```

- [ ] **Step 2: Verify REDpass is gone, OrbStack & coral-mutagen are kept**

```bash
grep -c "REDpass" ssh-config/.ssh/config         # expect: 0
grep -c "orbstack" ssh-config/.ssh/config        # expect: 1
grep -c "coral-mutagen" ssh-config/.ssh/config   # expect: 2 (start + end markers)
```

If REDpass count > 0: rerun the sed; if OrbStack/coral counts are wrong: the original file was unexpected, abort and have the user inspect.

- [ ] **Step 3: Commit**

```bash
git add ssh-config/.ssh/config
git commit -m "feat(ssh-config): import ~/.ssh/config, strip REDpass UUID block"
```

---

## Task 10: Migrate tmux + nvim configs

**Files:**
- Create: `tmux/.tmux.conf` (copy of `~/.tmux.conf`)
- Create: `nvim/.config/nvim/...` (copy of `~/.config/nvim/` tree)

No `~/.vimrc` exists, so vim package is skipped this round.

- [ ] **Step 1: Copy tmux**

```bash
mkdir -p tmux
cp ~/.tmux.conf tmux/.tmux.conf
```

- [ ] **Step 2: Copy nvim tree**

```bash
mkdir -p nvim/.config
cp -R ~/.config/nvim nvim/.config/nvim
```

- [ ] **Step 3: Verify**

```bash
ls -la tmux/.tmux.conf nvim/.config/nvim/init.lua
```

Expected: both files listed with sane sizes.

- [ ] **Step 4: Commit**

```bash
git add tmux/ nvim/
git commit -m "feat(tmux,nvim): import ~/.tmux.conf and ~/.config/nvim/"
```

---

## Task 11: Generate Brewfile, append required additions

**Files:**
- Modify: `Brewfile` (overwrite the placeholder)

- [ ] **Step 1: Dump current brew state**

```bash
brew bundle dump --file=Brewfile --force --describe
```

This overwrites the placeholder created in Task 1 with the real list of formulas, casks, and mas apps.

- [ ] **Step 2: Append the four required dependencies**

The dump above may already include some of these (esp. `fzf` and `jq`). Append only the ones not already present. Check first:

```bash
for pkg in age stow fzf jq; do
    grep -q "^brew \"$pkg\"" Brewfile || echo "MISSING: brew \"$pkg\""
done
grep -q "font-maple-mono-nf" Brewfile || echo "MISSING: cask \"font-maple-mono-nf\""
```

For each `MISSING:` line, append the corresponding entry to `Brewfile`. Example:

```bash
{
    echo ''
    echo '# --- required by dotfile bootstrap, ensure present ---'
    grep -q '^brew "age"'  Brewfile || echo 'brew "age",  link: true'
    grep -q '^brew "stow"' Brewfile || echo 'brew "stow", link: true'
    grep -q '^brew "fzf"'  Brewfile || echo 'brew "fzf"'
    grep -q '^brew "jq"'   Brewfile || echo 'brew "jq"'
    grep -q '"font-maple-mono-nf"' Brewfile || echo 'cask "font-maple-mono-nf"'
} >> Brewfile
```

- [ ] **Step 3: User trims the Brewfile manually**

> **PAUSE.** The Brewfile contains every formula and cask currently installed on this mac. The user must review and remove anything they don't actually want on the new mac. Common cuts: one-off experimental tools, ClickHouse-specific binaries, dependencies of since-uninstalled apps.

After the user is done trimming, proceed.

- [ ] **Step 4: Commit**

```bash
git add Brewfile
git commit -m "feat(brewfile): dump current brew state + add age/stow/fzf/jq/maple-font"
```

---

## Task 12: Set up iTerm2 to write prefs into iterm2/ (USER MANUAL STEP)

**Files:**
- Create: `iterm2/com.googlecode.iterm2.plist` (written by iTerm2 itself)

> **MANUAL STEP, no script.** iTerm2 only writes the plist when the user clicks through Settings.

- [ ] **Step 1: User configures iTerm2**

1. Open iTerm2.
2. Settings → General → Settings.
3. Tick **"Load preferences from a custom folder or URL"**.
4. Click **Browse…** and select the absolute path of the repo's `iterm2/` directory (e.g. `/Users/heldon/Directory/Project/dotfile/iterm2/`).
5. When prompted "What would you like to do?", choose **"Copy Local Preferences to Folder"**.
6. Confirm `iterm2/com.googlecode.iterm2.plist` now exists:

```bash
ls -la iterm2/com.googlecode.iterm2.plist
```

Expected: file present, ~50-200KB.

- [ ] **Step 2: Set the font to Maple Mono NF**

In iTerm2: Settings → Profiles → Text → Font → choose **Maple Mono NF**. (Requires `font-maple-mono-nf` already installed via `brew bundle`; if not yet installed, do `brew install --cask font-maple-mono-nf` first or postpone this step until after the new mac is set up.)

iTerm2 will auto-write the change to the plist in the repo.

- [ ] **Step 3: Commit**

```bash
git add iterm2/com.googlecode.iterm2.plist
git commit -m "feat(iterm2): import current iTerm2 prefs via custom folder mechanism"
```

---

## Task 13: Write bootstrap-macos.sh

**Files:**
- Create: `bootstrap-macos.sh`

- [ ] **Step 1: Write the script**

Create `bootstrap-macos.sh` with this exact content:

```bash
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
```

- [ ] **Step 2: Make executable**

```bash
chmod +x bootstrap-macos.sh
```

- [ ] **Step 3: Syntax check**

```bash
bash -n bootstrap-macos.sh && echo "SYNTAX OK"
```

Expected: `SYNTAX OK`.

- [ ] **Step 4: Commit**

```bash
git add bootstrap-macos.sh
git commit -m "feat: add bootstrap-macos.sh orchestrator (brew → stow → iterm2 → decrypt-ssh)"
```

---

## Task 14: Write tests/test-bootstrap-dryrun.sh (stow into fake HOME)

**Files:**
- Create: `tests/test-bootstrap-dryrun.sh`

We can't end-to-end test the full bootstrap on this mac without clobbering the user's real `$HOME`. The valuable part to verify is the **stow step**: does it correctly symlink the packages into a target dir? Other steps (`brew bundle`, `defaults write`, `decrypt-ssh.sh`) are tested elsewhere or are too invasive to mock.

- [ ] **Step 1: Write the test**

```bash
#!/usr/bin/env bash
# Verify stow can lay down the always-stow packages into a fresh fake $HOME.

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAKE_HOME="$(mktemp -d)"
trap 'rm -rf "$FAKE_HOME"' EXIT

cd "$REPO_ROOT"

# Mirror the ALWAYS list from bootstrap-macos.sh
ALWAYS=(zsh-macos p10k-macos git ssh-config)

stow -v -t "$FAKE_HOME" -d "$REPO_ROOT" "${ALWAYS[@]}" 2>&1

# Assert each expected symlink landed
declare -a expected=(
    "$FAKE_HOME/.zshrc"
    "$FAKE_HOME/.config/zsh/env.zsh"
    "$FAKE_HOME/.config/zsh/zinit.zsh"
    "$FAKE_HOME/.config/zsh/prompt.zsh"
    "$FAKE_HOME/.config/zsh/functions.zsh"
    "$FAKE_HOME/.config/zsh/extras.zsh"
    "$FAKE_HOME/.p10k.zsh"
    "$FAKE_HOME/.gitconfig"
    "$FAKE_HOME/.ssh/config"
)
for path in "${expected[@]}"; do
    if [[ ! -L "$path" ]]; then
        echo "FAIL: not a symlink: $path"
        exit 1
    fi
done

# Conflict scenario: stow must refuse when target exists as a real file
CONFLICT_HOME="$(mktemp -d)"
trap 'rm -rf "$FAKE_HOME" "$CONFLICT_HOME"' EXIT
echo "preexisting" > "$CONFLICT_HOME/.zshrc"
if stow -v -t "$CONFLICT_HOME" -d "$REPO_ROOT" zsh-macos 2>/dev/null; then
    echo "FAIL: stow did not refuse to overwrite preexisting .zshrc"
    exit 1
fi

echo "PASS: stow lays down all expected symlinks; refuses conflicts"
```

- [ ] **Step 2: Make executable and run**

```bash
chmod +x tests/test-bootstrap-dryrun.sh
./tests/test-bootstrap-dryrun.sh
```

Expected: `PASS: stow lays down all expected symlinks; refuses conflicts`.

If FAIL on a missing symlink: the path is wrong in the test or in the stow package (open the package dir and verify file location matches `expected`).

- [ ] **Step 3: Commit**

```bash
git add tests/test-bootstrap-dryrun.sh
git commit -m "test: verify bootstrap stow step lays down expected symlinks + refuses conflicts"
```

---

## Task 15: Migrate Ubuntu side verbatim (placeholder only, not refactored)

**Files:**
- Create: `zsh-ubuntu/.zshrc` (copy of `ubuntu/zsh/zshrc`)
- Create: `p10k-ubuntu/.p10k.zsh` (copy of `ubuntu/zsh/p10k.zsh`)

Ubuntu refactor (mirror the 6-file split) is out of scope. We move the existing files into the new layout slots so the upcoming deletion of `ubuntu/` doesn't lose data.

- [ ] **Step 1: Move files**

```bash
mkdir -p zsh-ubuntu p10k-ubuntu
cp ubuntu/zsh/zshrc zsh-ubuntu/.zshrc
cp ubuntu/zsh/p10k.zsh p10k-ubuntu/.p10k.zsh
```

- [ ] **Step 2: Commit**

```bash
git add zsh-ubuntu/ p10k-ubuntu/
git commit -m "feat(ubuntu): move existing zshrc + p10k.zsh into new package slots (no refactor)"
```

---

## Task 16: Delete old top-level files and directories

**Files:**
- Delete: `init.sh`
- Delete: `link.sh`
- Delete: `macos/` (recursive)
- Delete: `ubuntu/` (recursive)
- Delete: `script/` (recursive)

- [ ] **Step 1: Sanity check — confirm new files exist before deleting old**

```bash
test -f zsh-macos/.zshrc \
    && test -f zsh-macos/.config/zsh/functions.zsh \
    && test -f p10k-macos/.p10k.zsh \
    && test -f zsh-ubuntu/.zshrc \
    && test -f p10k-ubuntu/.p10k.zsh \
    && echo "OK to delete"
```

Expected: `OK to delete`. If anything is missing, do NOT proceed — go back and fix.

- [ ] **Step 2: Delete**

```bash
git rm -r init.sh link.sh macos ubuntu script
```

- [ ] **Step 3: Confirm nothing else references them**

```bash
grep -RIn "macos/zsh\|ubuntu/zsh\|script/clickhouse\|script/git_functions\|init\.sh\|link\.sh" \
    --exclude-dir=.git --exclude-dir=docs . || echo "no stale references"
```

Expected: `no stale references`. (References inside `docs/superpowers/specs/` are historical and intentional.)

- [ ] **Step 4: Commit**

```bash
git commit -m "chore: remove legacy init.sh/link.sh/macos/ubuntu/script directories"
```

---

## Task 17: Write README.md

**Files:**
- Modify: `README.md` (created by writing fresh; the repo currently has no README)

- [ ] **Step 1: Write the README**

Create `README.md` with this exact content:

```markdown
# dotfile

Personal macOS dotfiles managed with [GNU stow](https://www.gnu.org/software/stow/) + Homebrew `brew bundle` + age-encrypted SSH keys.

## What's in the box

| Package | Symlinks to | Purpose |
|---|---|---|
| `zsh-macos/` | `~/.zshrc` + `~/.config/zsh/*.zsh` | zsh entry + 5 ordered fragments (env, zinit, prompt, functions, extras) |
| `p10k-macos/` | `~/.p10k.zsh` | powerlevel10k config |
| `git/` | `~/.gitconfig` | git global config |
| `ssh-config/` | `~/.ssh/config` | SSH config (REDpass UUID is regenerated locally; OrbStack include + coral-mutagen block are kept) |
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

`~/.ssh/config` is a symlink to the repo. Tools like **REDpass**, **OrbStack**, and the **Coral** dev-sandbox toolchain may auto-append blocks to it — that's fine, the writes land in the repo file. But review `git diff ssh-config/` before committing to avoid leaking machine-specific UUIDs or ephemeral Pod IPs.

## Troubleshooting

- **Nerd Font icons not rendering**: iTerm2 → Profiles → Text → confirm font is **Maple Mono NF**. If not in the picker, `brew install --cask font-maple-mono-nf` and restart iTerm2.
- **p10k complains about font**: same as above.
- **`stow` reports conflict on `.zshrc`**: an oh-my-zsh or default install left a `~/.zshrc`. `mv ~/.zshrc ~/.zshrc.preexisting && ./bootstrap-macos.sh` again.
- **`ssh -T git@github.com` → permission denied**: `ls -la ~/.ssh/id_rsa_myself` — file should be present, perms 600. If missing, `./scripts/decrypt-ssh.sh`.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: README with new-mac install + daily maintenance + ssh encryption"
```

---

## Task 18: Final end-to-end smoke verification

- [ ] **Step 1: Re-run both test suites**

```bash
./tests/test-roundtrip.sh
./tests/test-bootstrap-dryrun.sh
```

Both must print PASS lines.

- [ ] **Step 2: Verify repo tree matches spec §2**

```bash
ls -la
```

Expected top-level entries (alphabetical):
```
.git/
.gitignore
Brewfile
README.md
bootstrap-macos.sh
docs/
git/
iterm2/
nvim/
p10k-macos/
p10k-ubuntu/
scripts/
secrets/
ssh-config/
tests/
tmux/
zsh-macos/
zsh-ubuntu/
```

(No `init.sh`, `link.sh`, `macos/`, `ubuntu/`, `script/`.)

- [ ] **Step 3: Verify `git status` is clean**

```bash
git status
```

Expected: `nothing to commit, working tree clean`.

- [ ] **Step 4: Print commit log for review**

```bash
git log --oneline main..HEAD
```

Expected: ~14-18 commits on `feat/macos-dotfile-sync` since branching from `main`, each describing one task.

- [ ] **Step 5: Tell the user the branch is ready to merge / PR**

The branch is complete on this (old) mac. The new mac end-to-end test (spec §7) happens when the user actually sets up the new machine and runs `./bootstrap-macos.sh` — that validation lives outside this plan.
