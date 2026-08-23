#!/usr/bin/env bash
#
# test_sync_unit_hashing.sh — SPEC-002 TEST-1.3: SHA-256 hash computation.
#
# Traceability:
#   - FR-5.1 modification detection is hash-based (current vs manifest hash).
#   - TR-2.1/TR-4.1 deterministic lowercase-hex SHA-256 (macOS shasum fallback).
#   - TR-4.3 per-file hashing (manifest records a hash per installed file).
#   - DM-2 hash pattern ^[a-f0-9]{64}$.
#
# Asserts the script's recorded manifest hashes equal independently computed
# SHA-256 (empty file known-vector, known text vector, binary content) and that
# the command-derived entry hashes match the generated SKILL.md bytes.
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "TEST-1.3 SHA-256 hashing"

FIX="$(sync_make_fixture_repo)"
HOME_DIR="$(sync_make_home)"
trap 'rm -rf "$FIX" "$HOME_DIR"' EXIT
SCRIPT="$FIX/scripts/sync-managed-skills.sh"
MANIFEST="$HOME_DIR/.agents/skills/.manifest.json"
OUT="$(mktemp)"

# Source skill with three files exercising the hash surface.
mkdir -p "$FIX/templates/opencode/skills/hasher"
printf -- '---\nname: hasher\ndescription: h\n---\n\nbody\n' > "$FIX/templates/opencode/skills/hasher/SKILL.md"
: > "$FIX/templates/opencode/skills/hasher/empty.txt"            # zero-byte file
printf 'abc' > "$FIX/templates/opencode/skills/hasher/known.txt" # known vector (no newline)
# Binary content (non-UTF8 bytes incl. NULs).
printf '\x00\x01\x02\xff\xfe\n' > "$FIX/templates/opencode/skills/hasher/bin.dat"

# Known SHA-256 vectors (prove it is real SHA-256, not a stub).
EMPTY_VEC="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"  # sha256("")
ABC_VEC="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"    # sha256("abc")

sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "hashing fixture install exit 0" "$SYNC_RC"

# Independent dynamic cross-checks (portable: same tool the script uses).
EMPTY_GOT="$(sync_sha256 "$FIX/templates/opencode/skills/hasher/empty.txt")"
ABC_GOT="$(sync_sha256 "$FIX/templates/opencode/skills/hasher/known.txt")"
BIN_GOT="$(sync_sha256 "$FIX/templates/opencode/skills/hasher/bin.dat")"

# --- TR-2.1: hashes are 64-char lowercase hex --------------------------------
assert_eq "empty hash length 64" "${#EMPTY_GOT}" "64"
assert_eq "empty hash is lowercase hex" "$EMPTY_GOT" "$EMPTY_VEC"
assert_eq "known 'abc' vector matches" "$ABC_GOT" "$ABC_VEC"

# --- TR-4.3 / FR-5.1: manifest records per-file hashes equal to source -------
assert_eq "manifest empty.txt hash == source" \
  "$(sync_manifest_file_hash "$MANIFEST" hasher "templates/opencode/skills/hasher/empty.txt")" "$EMPTY_GOT"
assert_eq "manifest known.txt hash == source" \
  "$(sync_manifest_file_hash "$MANIFEST" hasher "templates/opencode/skills/hasher/known.txt")" "$ABC_GOT"
assert_eq "manifest bin.dat hash == source" \
  "$(sync_manifest_file_hash "$MANIFEST" hasher "templates/opencode/skills/hasher/bin.dat")" "$BIN_GOT"

# --- DM-2: hash pattern ^[a-f0-9]{64}$ (no uppercase, no short) --------------
SKILL_MD_HASH="$(sync_manifest_file_hash "$MANIFEST" hasher "templates/opencode/skills/hasher/SKILL.md")"
if [[ "$SKILL_MD_HASH" =~ ^[a-f0-9]{64}$ ]]; then
  check OK "hash matches DM-2 pattern"
else
  check FAIL "hash matches DM-2 pattern (got: $SKILL_MD_HASH)"
fi

# --- command-derived hash == generated SKILL.md bytes ------------------------
mkdir -p "$FIX/templates/opencode/commands"
cat > "$FIX/templates/opencode/commands/c1.md" <<'CMD'
---
description: derived one
agent: orchestrator
---

Derived body.
CMD
rm -rf "$HOME_DIR/.agents"
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "command-derived install exit 0" "$SYNC_RC"
DERIVED_INSTALLED="$HOME_DIR/.agents/skills/c1/SKILL.md"
DERIVED_PREDICTED="$(sync_sha256 "$DERIVED_INSTALLED")"
assert_eq "command-derived manifest hash == installed SKILL.md" \
  "$(sync_manifest_file_hash "$MANIFEST" c1 ".opencode/commands/c1.md")" "$DERIVED_PREDICTED"

rm -f "$OUT"
sync_done
