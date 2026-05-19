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
