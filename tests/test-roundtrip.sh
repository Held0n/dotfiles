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
