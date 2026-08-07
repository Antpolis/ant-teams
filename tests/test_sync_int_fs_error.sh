#!/usr/bin/env bash
#
# test_sync_int_fs_error.sh — SPEC-002 ERR-4 / ERR-6: filesystem write error.
#
# Traceability:
#   - ERR-4.1 if the sync cannot create or write to a managed path due to
#     permission errors, it emits [ERROR] with the path and exits 5.
#   - ERR-6.1 a write failure (ENOSPC/EACCES) => [ERROR] + exit 5; the partial
#     file is removed if possible. (Disk-full and permission-denied share the
#     same exit-5 FS-error code path in the failure table; permission denial is
#     the portable, representative trigger.)
#
# Skipped when running as root (chmod cannot deny root) — documented like all
# Unix-permission-based tests.
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "ERR-4/ERR-6 filesystem write error => exit 5"

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  printf '  [SKIP] fs-error test requires non-root (chmod denial)\n'
  sync_done
  exit 0
fi

FIX="$(sync_make_fixture_repo)"
HOME_DIR="$(sync_make_home)"
trap 'chmod 0700 "$HOME_DIR/.agents/skills/alpha" 2>/dev/null || true; rm -rf "$FIX" "$HOME_DIR"' EXIT
SCRIPT="$FIX/scripts/sync-managed-skills.sh"
OUT="$(mktemp)"

sync_write_skill "$FIX" "alpha" $'---\nname: alpha\ndescription: a\n---\n\nalpha\n'

# Pre-create the managed entry directory as read-only (no write bit) so the
# first `cp` of SKILL.md into it fails with EACCES. The script's write path
# then dies with exit 5 (die_fs).
mkdir -p "$HOME_DIR/.agents/skills/alpha"
chmod 0500 "$HOME_DIR/.agents/skills/alpha"

sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_eq "fs-error: exit 5 (ERR-4.1/ERR-6.1)" "$SYNC_RC" "5"
assert_file_contains_str "fs-error: [ERROR] emitted" "$OUT" "[ERROR]"

# Restore perms so cleanup can remove the tree.
chmod 0700 "$HOME_DIR/.agents/skills/alpha" 2>/dev/null || true

rm -f "$OUT"
sync_done
