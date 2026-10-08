#!/usr/bin/env bash
# check_security.sh
# Detects changes to system accounts (UID < 1000) and to their password entries.
#
# Usage:
#   sudo ./check_security.sh --init   # create the baseline (run once, on a trusted system)
#   sudo ./check_security.sh          # compare the current state with the baseline
#
# Exit codes: 0 = no change, 1 = change detected, 2 = error / no baseline.

set -euo pipefail
umask 077

BASE_DIR="${BASE_DIR:-/var/lib/sysuser-watch}"
PASSWD_FILE="${PASSWD_FILE:-/etc/passwd}"
SHADOW_FILE="${SHADOW_FILE:-/etc/shadow}"
UID_LIMIT="${UID_LIMIT:-1000}"

BASE_USERS="$BASE_DIR/systemusers.txt"
BASE_SHADOW_HASH="$BASE_DIR/shadow.sha256"

current_users() {
  awk -F: -v limit="$UID_LIMIT" '$3 < limit {print $1}' "$PASSWD_FILE" | sort
}

# Hash of the shadow lines of the system users: the hashes themselves are never copied to disk.
current_shadow_hash() {
  local users
  users="$(current_users)"
  while IFS= read -r user; do
    grep -E "^${user}:" "$SHADOW_FILE" || true
  done <<< "$users" | sha256sum | awk '{print $1}'
}

notify() {
  # Writes to the system log (auth facility) and to stdout (cron mails it if MAILTO is set).
  logger -p auth.warning -t sysuser-watch "$1" 2>/dev/null || true
  echo "$1"
}

if [[ "${1:-}" == "--init" ]]; then
  mkdir -p "$BASE_DIR"
  current_users > "$BASE_USERS"
  current_shadow_hash > "$BASE_SHADOW_HASH"
  echo "Baseline created in $BASE_DIR"
  exit 0
fi

if [[ ! -f "$BASE_USERS" || ! -f "$BASE_SHADOW_HASH" ]]; then
  echo "No baseline found in $BASE_DIR. Run with --init first." >&2
  exit 2
fi

changed=0

users_diff="$(diff "$BASE_USERS" <(current_users) || true)"
if [[ -n "$users_diff" ]]; then
  notify "WARNING: the list of system users changed:"
  echo "$users_diff"
  changed=1
fi

if [[ "$(current_shadow_hash)" != "$(cat "$BASE_SHADOW_HASH")" ]]; then
  notify "WARNING: password information of system users changed."
  changed=1
fi

if [[ $changed -eq 0 ]]; then
  echo "No changes found."
fi
exit $changed
