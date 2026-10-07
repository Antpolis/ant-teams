#!/usr/bin/env bash
#
# tests/test_skills_copy.sh — SPEC-001-T4 unit tests.
#
# Migrated from tests/test_skills_copy.js (SPEC-004-T4, issue #54).
# Assertion parity: all 42 Node checks migrated (bundled Node checks split
# into individual bash checks — equivalent-or-stronger; none weakened).
#
# Drives `templates/scripts/init-project.sh` against throwaway target project
# directories and asserts the FR-7 / AC-T4 contract:
#
#   - AC-T4-001: github-issues-projects-cli/scripts/gh_project_helper.sh
#                exists with execute permission.
#   - AC-T4-002: do-task/scripts/create_task_worktree.sh and
#                cleanup_task_worktree.sh exist WITH execute permission.
#   - AC-T4-003: the retired project-initialization skill is NOT copied
#                (the engine lives at $ANT_TEAM_SCRIPTS/init-project.sh and
#                is not re-installed into targets).
#   - AC-T4-004: skill-creator/, webapp-testing/, doc-coauthoring/,
#                frontend-design/ are NOT copied.
#   - AC-T4-005: a project-customized SKILL.md is preserved verbatim
#                (merge, not overwrite).
#   - AC-T4-006: .opencode/.gitignore exists with a node_modules entry.
#
# Plus idempotency (TR-2.1) and ARCH-003 guarantee 4 / SEC-3.2: every shell
# script under `.opencode/skills/<skill>/scripts/` carries the execute bit at
# source AND at target after init. The positive iteration over every copied
# `.sh` is what reconciles the reviewer finding on PR #13.
#
# Canonical source rule: assertions run against `templates/opencode/skills/`
# (the sibling skills root of a source-checkout run), never the generated
# `.opencode/` mirror.
#
# Run directly: `bash tests/test_skills_copy.sh`.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/init_helpers.sh"

SOURCE_SKILLS_DIR="$INIT_REPO_ROOT/templates/opencode/skills"

REQUIRED_SKILLS=( github-issues-projects-cli do-task )
EXCLUDED_SKILLS=( skill-creator webapp-testing doc-coauthoring frontend-design )
REQUIRED_SCRIPT_PATHS=(
  'github-issues-projects-cli/scripts/gh_project_helper.sh'
  'do-task/scripts/create_task_worktree.sh'
  'do-task/scripts/cleanup_task_worktree.sh'
)

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

OUT="$TMP/out.txt"
ERR="$TMP/err.txt"

# has_exec PATH — true when the path has any execute bit.
has_exec() { [[ -f "$1" && -x "$1" ]]; }

# list_required_skill_scripts ROOT — every .sh under ROOT/<required-skill>/scripts/.
list_required_skill_scripts() {
  local root="$1" skill
  for skill in "${REQUIRED_SKILLS[@]}"; do
    find "$root/$skill/scripts" -maxdepth 1 -name '*.sh' -type f 2>/dev/null || true
  done | sort
}

# run_init PROJECT_DIR — noninteractive with the required identity flags.
run_init() {
  local project_dir="$1"
  init_run "$OUT" "$ERR" -- \
    --project-dir "$project_dir" \
    --worktree-root "$project_dir/wt" \
    --noninteractive \
    --name test \
    --github-owner antpolis \
    --github-project-number 9
}

# --- Source preflight ---------------------------------------------------------

init_suite "source preflight"

for s in "${REQUIRED_SKILLS[@]}"; do
  if [[ -f "$SOURCE_SKILLS_DIR/$s/SKILL.md" ]]; then
    check OK "source skill present: $s"
  else
    check FAIL "source skill present: $s (missing $SOURCE_SKILLS_DIR/$s/SKILL.md)"
  fi
done

# ARCH-003 guarantee 4 / SEC-3.2 source invariant: every required shell script
# under the canonical skills root carries the execute bit (cp -p only
# preserves what already exists).
for rel in "${REQUIRED_SCRIPT_PATHS[@]}"; do
  if has_exec "$SOURCE_SKILLS_DIR/$rel"; then
    check OK "source required script is executable: $rel"
  else
    check FAIL "source required script is executable: $rel"
  fi
done

# Defensive sweep: every .sh under source required-skill scripts/ dirs (not
# only the known required paths) must be executable.
src_scripts="$(list_required_skill_scripts "$SOURCE_SKILLS_DIR")"
src_count="$(printf '%s' "$src_scripts" | grep -c . || true)"
if (( src_count >= ${#REQUIRED_SCRIPT_PATHS[@]} )); then
  check OK "source sweep: at least ${#REQUIRED_SCRIPT_PATHS[@]} scripts found ($src_count)"
  sweep_ok=1
  while IFS= read -r p; do
    [[ -n "$p" ]] || continue
    has_exec "$p" || { sweep_ok=0; check FAIL "source sweep: not executable: ${p#$INIT_REPO_ROOT/}"; }
  done <<< "$src_scripts"
  (( sweep_ok )) && check OK "source sweep: every .sh under required-skill scripts/ is executable"
else
  check FAIL "source sweep: expected at least ${#REQUIRED_SCRIPT_PATHS[@]} scripts, got $src_count"
fi

# --- Console contract: OBS-1 [writing] lines for skills copy ------------------

init_suite "OBS-1 console contract for skills copy"

console_dir="$TMP/console-target"
mkdir -p "$console_dir/.git"
run_init "$console_dir"
assert_exit_zero "init exits 0" "$INIT_RC"
assert_out_contains "$OUT" '\[writing\][[:space:]]+\.opencode/skills/' \
  "console emits at least one [writing] .opencode/skills/ line"
assert_out_contains "$OUT" '\.opencode/skills/ \(2 required skills, [0-9]+ copied, [0-9]+ merged\)' \
  "console emits skills copy summary line"
assert_out_contains "$OUT" '\[writing\][[:space:]]+\.opencode/\.gitignore' \
  "console emits [writing] .opencode/.gitignore line"

# --- Shared fresh-repo suite ---------------------------------------------------

fresh="$TMP/fresh-target"
mkdir -p "$fresh/.git"
run_init "$fresh"
assert_exit_zero "fresh project init exits 0" "$INIT_RC"

init_suite "AC-T4-001/002/003 required scripts exist & executable"

tgt_gih="$fresh/.opencode/skills/github-issues-projects-cli"
tgt_dotask="$fresh/.opencode/skills/do-task"

assert_exists "AC-T4-001: gh_project_helper.sh exists" "$tgt_gih/scripts/gh_project_helper.sh"
if has_exec "$tgt_gih/scripts/gh_project_helper.sh"; then
  check OK "AC-T4-001: gh_project_helper.sh has execute permission"
else
  check FAIL "AC-T4-001: gh_project_helper.sh has execute permission"
fi
assert_exists "AC-T4-001: github-issues-projects-cli/SKILL.md exists" "$tgt_gih/SKILL.md"

assert_exists "AC-T4-002: do-task/scripts/create_task_worktree.sh exists" "$tgt_dotask/scripts/create_task_worktree.sh"
if has_exec "$tgt_dotask/scripts/create_task_worktree.sh"; then
  check OK "AC-T4-002: create_task_worktree.sh has execute permission"
else
  check FAIL "AC-T4-002: create_task_worktree.sh has execute permission"
fi
assert_exists "AC-T4-002: do-task/scripts/cleanup_task_worktree.sh exists" "$tgt_dotask/scripts/cleanup_task_worktree.sh"
if has_exec "$tgt_dotask/scripts/cleanup_task_worktree.sh"; then
  check OK "AC-T4-002: cleanup_task_worktree.sh has execute permission"
else
  check FAIL "AC-T4-002: cleanup_task_worktree.sh has execute permission"
fi

init_suite "AC-T4-003 retired project-initialization not copied"

assert_not_exists "AC-T4-003: project-initialization/ not copied into targets" "$fresh/.opencode/skills/project-initialization"

init_suite "AC-T4-004 excluded skills absent"

for s in "${EXCLUDED_SKILLS[@]}"; do
  assert_not_exists "AC-T4-004: $s/ not copied" "$fresh/.opencode/skills/$s"
done

init_suite "AC-T4-006 .opencode/.gitignore"

assert_exists "AC-T4-006: .opencode/.gitignore exists" "$fresh/.opencode/.gitignore"
if grep -qFx 'node_modules' "$fresh/.opencode/.gitignore"; then
  check OK "AC-T4-006: node_modules entry present"
else
  check FAIL "AC-T4-006: node_modules entry present"
fi

init_suite "ARCH-003 g4 / SEC-3.2 every copied .sh is executable"

tgt_scripts="$(list_required_skill_scripts "$fresh/.opencode/skills")"
tgt_count="$(printf '%s' "$tgt_scripts" | grep -c . || true)"
if (( tgt_count >= ${#REQUIRED_SCRIPT_PATHS[@]} )); then
  check OK "init copied at least the required shell scripts ($tgt_count)"
  while IFS= read -r tgt; do
    [[ -n "$tgt" ]] || continue
    rel="${tgt#$fresh/.opencode/skills/}"
    if has_exec "$tgt"; then
      check OK "target shell script is executable: $rel"
    else
      check FAIL "target shell script is executable: $rel"
    fi
    src="$SOURCE_SKILLS_DIR/$rel"
    if [[ -f "$src" ]]; then
      src_mode="$(stat -c %a "$src")"
      tgt_mode="$(stat -c %a "$tgt")"
      if (( (8#$tgt_mode & 8#111) == (8#$src_mode & 8#111) )); then
        check OK "target execute bits match source: $rel"
      else
        check FAIL "target execute bits match source: $rel (source=$src_mode target=$tgt_mode)"
      fi
    fi
  done <<< "$tgt_scripts"
else
  check FAIL "init copied at least the required shell scripts (expected >= ${#REQUIRED_SCRIPT_PATHS[@]}, got $tgt_count)"
fi

init_suite "TR-2.1 idempotency"

# File set + sizes + modes unchanged after rerun (mtime excluded, as in the
# Node original).
snapshot() {
  local root="$1"
  ( cd "$root" && find . -type f | sort | while IFS= read -r rel; do
      st="$(stat -c '%s %a' "$rel")"
      printf '%s %s\n' "$rel" "$st"
    done )
}
snapshot "$fresh" > "$TMP/before.txt"
run_init "$fresh"
snapshot "$fresh" > "$TMP/after.txt"
if cmp -s "$TMP/before.txt" "$TMP/after.txt"; then
  check OK "TR-2.1: file set, sizes, and modes unchanged after rerun"
else
  check FAIL "TR-2.1: rerun changed the file set, a file size, or a mode"
  diff "$TMP/before.txt" "$TMP/after.txt" >&2 || true
fi

init_suite "FR-7.3 merge does not overwrite arbitrary files"

sentinel_target="$fresh/.opencode/skills/do-task/scripts/create_task_worktree.sh"
sentinel='# project-local sentinel — init must not overwrite this file'
printf '%s\n' "$sentinel" > "$sentinel_target"
run_init "$fresh"
if [[ "$(cat "$sentinel_target")" == "$sentinel" ]]; then
  check OK "FR-7.3: pre-existing local script preserved verbatim"
else
  check FAIL "FR-7.3: init overwrote an existing local script"
fi

# --- AC-T4-005 customized SKILL.md preservation --------------------------------

init_suite "AC-T4-005 customized SKILL.md preserved"

custom="$TMP/custom-target"
mkdir -p "$custom/.git"
run_init "$custom"
assert_exit_zero "custom-suite init exits 0" "$INIT_RC"

custom_skill_md="$custom/.opencode/skills/github-issues-projects-cli/SKILL.md"
marker='<!-- project-local customization marker - do not overwrite -->'
printf '%s\n# Custom project-local SKILL.md\n\nEdited by the project operator.\n' "$marker" > "$custom_skill_md"
cp "$custom_skill_md" "$TMP/custom.before"
mtime_before="$(stat -c %Y "$custom_skill_md")"
run_init "$custom"
mtime_after="$(stat -c %Y "$custom_skill_md")"
if cmp -s "$TMP/custom.before" "$custom_skill_md"; then
  check OK "AC-T4-005: customized SKILL.md content preserved verbatim"
else
  check FAIL "AC-T4-005: customized SKILL.md was modified by init"
fi
assert_eq "AC-T4-005: customized SKILL.md mtime unchanged" "$mtime_after" "$mtime_before"
if grep -qF "$marker" "$custom_skill_md"; then
  check OK "AC-T4-005: marker line still present"
else
  check FAIL "AC-T4-005: customization marker lost from SKILL.md"
fi

# --- AC-T4-006 additivity: existing .gitignore entries preserved ----------------

init_suite "AC-T4-006 additivity"

gi="$TMP/gitignore-target"
mkdir -p "$gi/.git" "$gi/.opencode"
printf 'custom-entry\n.env\n' > "$gi/.opencode/.gitignore"
run_init "$gi"
if grep -qFx 'custom-entry' "$gi/.opencode/.gitignore"; then
  check OK "AC-T4-006: pre-existing custom-entry preserved"
else
  check FAIL "AC-T4-006: pre-existing custom-entry preserved"
fi
if grep -qFx '.env' "$gi/.opencode/.gitignore"; then
  check OK "AC-T4-006: pre-existing .env preserved"
else
  check FAIL "AC-T4-006: pre-existing .env preserved"
fi
nm_count="$(grep -cFx 'node_modules' "$gi/.opencode/.gitignore" || true)"
assert_eq "AC-T4-006: node_modules appended exactly once" "$nm_count" "1"

# --- Summary --------------------------------------------------------------------

init_done
