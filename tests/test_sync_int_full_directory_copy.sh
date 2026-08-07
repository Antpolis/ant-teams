#!/usr/bin/env bash
#
# test_sync_int_full_directory_copy.sh — SPEC-002 TEST-2.14: source skill
# full-directory copy.
#
# Traceability:
#   - FR-2.2a every directory under .opencode/skills/<name>/ is copied in full
#     to ~/.agents/skills/<name>/, including all subdirectories (scripts,
#     references, assets, evals, agents, examples) and all files.
#   - INT-1.2 the entire tree is copied recursively (excluding only in-skill
#     .gitignore if present).
#   - AC-9.1 a multi-file skill is installed intact.
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "TEST-2.14 source skill full-directory copy"

FIX="$(sync_make_fixture_repo)"
HOME_DIR="$(sync_make_home)"
trap 'rm -rf "$FIX" "$HOME_DIR"' EXIT
SCRIPT="$FIX/scripts/sync-managed-skills.sh"
OUT="$(mktemp)"

# A richly-structured source skill exercising nested subdirs + an executable.
mkdir -p "$FIX/.opencode/skills/rich/scripts/nested" \
         "$FIX/.opencode/skills/rich/references" \
         "$FIX/.opencode/skills/rich/assets"
printf -- '---\nname: rich\ndescription: r\n---\n\nrich\n' > "$FIX/.opencode/skills/rich/SKILL.md"
printf '#!/usr/bin/env bash\necho run\n'                 > "$FIX/.opencode/skills/rich/scripts/run.sh"
printf 'deep\n'                                          > "$FIX/.opencode/skills/rich/scripts/nested/deep.txt"
printf 'ref\n'                                            > "$FIX/.opencode/skills/rich/references/ref.md"
printf 'asset-data\n'                                     > "$FIX/.opencode/skills/rich/assets/logo.bin"
chmod 0755 "$FIX/.opencode/skills/rich/scripts/run.sh"
# An in-skill .gitignore that must be EXCLUDED from the install target (INT-1.2).
printf 'ignored\n' > "$FIX/.opencode/skills/rich/.gitignore"

sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "full-dir install exit 0" "$SYNC_RC"

T="$HOME_DIR/.agents/skills/rich"
assert_exists "SKILL.md copied"                "$T/SKILL.md"
assert_exists "scripts/run.sh copied"          "$T/scripts/run.sh"
assert_exists "scripts/nested/deep.txt copied" "$T/scripts/nested/deep.txt"
assert_exists "references/ref.md copied"       "$T/references/ref.md"
assert_exists "assets/logo.bin copied"         "$T/assets/logo.bin"

# Content fidelity for a nested file.
assert_file_contains_str "nested deep.txt content" "$T/scripts/nested/deep.txt" "deep"

# Executable script preserves its exec bit (SEC-3.1 / INT-1.x).
assert_exec "executable script preserves exec bit" "$T/scripts/run.sh"

# INT-1.2: in-skill .gitignore is excluded from the install.
assert_not_exists ".gitignore excluded from install" "$T/.gitignore"

# Tree identical to source excluding .gitignore (AC-9.1).
DIFF_OUT="$(diff -r "$FIX/.opencode/skills/rich" "$T" 2>&1 || true)"
if echo "$DIFF_OUT" | grep -qv 'Only in.*\.gitignore'; then
  if [[ -z "$DIFF_OUT" ]]; then
    check OK "source tree installed intact"
  else
    check FAIL "source tree installed intact ($DIFF_OUT)"
  fi
else
  check OK "source tree installed intact (.gitignore excluded as specified)"
fi

rm -f "$OUT"
sync_done
