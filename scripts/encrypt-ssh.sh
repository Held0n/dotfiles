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
    if [[ ${#candidates[@]} -gt 0 ]]; then
        for f in "${candidates[@]}"; do
            [[ -f "$f.pub" ]] && pubs+=("$f.pub")
        done
    fi
    candidates+=(${pubs[@]+"${pubs[@]}"})
    if [[ ${#candidates[@]} -eq 0 ]]; then
        echo "No candidate keys found in ~/.ssh or ~/." >&2
        exit 1
    fi
    files=()
    while IFS= read -r line; do files+=("$line"); done < <(printf '%s\n' "${candidates[@]}" | fzf --multi --prompt='Select files to encrypt > ')
    if [[ ${#files[@]} -eq 0 ]]; then
        echo "Nothing selected." >&2
        exit 1
    fi
fi

# age -p prompts on /dev/tty twice per invocation; one age call per file.
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
