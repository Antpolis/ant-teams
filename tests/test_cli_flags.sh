#!/usr/bin/env bash
#
# tests/test_cli_flags.sh — SPEC-001-T2 unit tests.
#
# Migrated from tests/test_cli_flags.js (SPEC-004-T4, issue #54).
# Assertion parity: all 81 Node checks migrated; none weakened.
# Stale-assertion classification (the single pre-migration failure):
#   "guardrail: --force / --skip-inspection / --dry-run accepted" asserted
#   `--skip-inspection` is accepted. That flag was retired by SPEC-005-T1
#   (the inspection engine was removed; the engine comment block states
#   operator prompt flags are accepted for CLI compatibility only). The
#   migrated harness asserts the stronger post-SPEC-005 contract:
#   `--skip-inspection` is REJECTED as an unknown argument, alongside the
#   retired `--migrate-agent-md`, while `--force` / `--dry-run` are accepted.
#
# Drives `templates/scripts/init-project.sh` through the CLI surface added by
# issue #3 (CLI-2 / FR-4 / ERR-4):
#
#   - AC-T2-001: TTY present + no flags → interactive mode (no required-flag
#                accounting). Stdout-piped (no TTY) + no flags → noninteractive
#                default.
#   - AC-T2-002: --noninteractive with the three required identity flags
#                exits 0 with no prompts.
#   - AC-T2-003: --noninteractive missing any of the three required flags
#                exits 1 and lists the missing entries on stderr.
#   - AC-T2-004: env vars supply defaults; CLI flags override env vars
#                (resolution order: default < env < CLI).
#   - AC-T2-005: pre-existing --project-dir / --docs-root / --worktree-root
#                continue to behave as before.
#   - AC-T2-006: every --repo-role enum value is accepted; invalid_role is
#                rejected with a clear stderr error.
#   - AC-T2-007: --commands @/path/to/file reads the file; --commands "inline"
#                uses the inline text verbatim; @missing-file is a hard error.
#
# Run directly: `bash tests/test_cli_flags.sh`.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/init_helpers.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

OUT="$TMP/out.txt"
ERR="$TMP/err.txt"

# mk_repo PREFIX — throwaway target with a .git marker.
mk_repo() { init_make_repo "$TMP/cli-$1"; }

# run_init [ENV...] -- ARGS... — run the engine (stdin: /dev/null, so the
# default mode is noninteractive — no TTY).
run_init() { init_run "$OUT" "$ERR" "$@"; }

# required_args PROJECT_DIR [EXTRA...] — the minimal noninteractive required
# set plus extras, one arg per line (feed through mapfile).
required_args() {
  local tmp="$1"; shift
  printf '%s\n' \
    --project-dir "$tmp" \
    --worktree-root "$tmp/wt" \
    --noninteractive \
    --name test \
    --github-owner antpolis \
    --github-project-number 9 \
    "$@"
}

# run_required PROJECT_DIR [EXTRA...] — noninteractive with required flags.
run_required() {
  local tmp="$1"; shift
  local -a args=()
  mapfile -t args < <(required_args "$tmp" "$@")
  run_init -- "${args[@]}"
}

# --- Pre-flight -------------------------------------------------------------------

init_suite "preflight"

assert_exists "init-project.sh exists" "$INIT_SCRIPT"
bash -n "$INIT_SCRIPT" 2>"$ERR" && check OK "init-project.sh is syntactically valid" || check FAIL "init-project.sh is syntactically valid"

# --- AC-T2-001: TTY-based default mode ----------------------------------------------

init_suite "AC-T2-001 TTY default mode"

tmp="$(mk_repo ac001a)"
run_init -- --project-dir "$tmp" --worktree-root "$tmp/wt"
assert_exit_nonzero "AC-T2-001a: stdout piped + no flags → noninteractive (exit 1)" "$INIT_RC"
assert_out_contains "$ERR" 'Noninteractive mode requires' \
  "AC-T2-001a: missing-flag check fires"

tmp="$(mk_repo ac001b)"
run_init -- --project-dir "$tmp" --worktree-root "$tmp/wt" --interactive
assert_exit_zero "AC-T2-001b: --interactive bypasses required-flag accounting" "$INIT_RC"

# AC-T2-001c: TTY default resolves to interactive (pseudo-TTY via `script`).
if command -v script >/dev/null 2>&1; then
  tmp="$(mk_repo ac001c)"
  printf '\n%.0s' $(seq 1 12) > "$TMP/pty-input.txt"
  init_run_cmd "$OUT" "$ERR" "$TMP" \
    "HOME=$HOME" -- \
    script -qec "bash '$INIT_SCRIPT' --project-dir '$tmp' --worktree-root '$tmp/wt'" /dev/null \
    < "$TMP/pty-input.txt"
  assert_exit_zero "AC-T2-001c: TTY default is interactive (exit 0)" "$INIT_RC"
  if grep -qF 'Noninteractive mode requires' "$ERR"; then
    check FAIL "AC-T2-001c: TTY default must not trigger missing-flag check"
  else
    check OK "AC-T2-001c: TTY default does not trigger missing-flag check"
  fi
else
  check OK "AC-T2-001c: (skipped: `script` not available on host)"
fi

# --- AC-T2-002: full noninteractive succeeds silently ---------------------------------

init_suite "AC-T2-002 noninteractive success"

tmp="$(mk_repo ac002)"
run_required "$tmp"
assert_exit_zero "AC-T2-002: --noninteractive with required flags exits 0" "$INIT_RC"

tmp="$(mk_repo ac002-prompts)"
run_required "$tmp"
assert_exit_zero "AC-T2-002 (prompts): exits 0" "$INIT_RC"
assert_out_not_contains_str "$OUT" '[prompt]' "AC-T2-002: no [prompt] lines on stdout"

# --- AC-T2-003: missing-flag errors -------------------------------------------------------

init_suite "AC-T2-003 missing-flag errors"

for flag in --name --github-owner --github-project-number; do
  tmp="$(mk_repo "ac003-${flag#--}")"
  local_args=()
  while IFS= read -r a; do local_args+=("$a"); done < <(required_args "$tmp")
  # Drop the flag under test and its value.
  filtered=()
  skip_next=0
  for a in "${local_args[@]}"; do
    if (( skip_next )); then skip_next=0; continue; fi
    if [[ "$a" == "$flag" ]]; then skip_next=1; continue; fi
    filtered+=("$a")
  done
  run_init -- "${filtered[@]}"
  assert_exit_nonzero "AC-T2-003: --noninteractive without $flag exits 1" "$INIT_RC"
  assert_out_contains "$ERR" 'Noninteractive mode requires' "AC-T2-003 ($flag): missing banner"
  assert_out_contains_str "$ERR" "Missing: $flag" "AC-T2-003 ($flag): missing-flag line"
done

tmp="$(mk_repo ac003-all)"
run_init -- --project-dir "$tmp" --worktree-root "$tmp/wt" --noninteractive
assert_exit_nonzero "AC-T2-003 (all missing): exits 1" "$INIT_RC"
for flag in --name --github-owner --github-project-number; do
  assert_out_contains_str "$ERR" "Missing: $flag" "AC-T2-003 (all missing): lists $flag"
done

tmp="$(mk_repo ac003-hint)"
run_init -- --project-dir "$tmp" --worktree-root "$tmp/wt" --noninteractive
assert_exit_nonzero "AC-T2-003 (hint): exits 1" "$INIT_RC"
assert_out_contains "$ERR" 'INIT_PROJECT_[A-Z_]+' "AC-T2-003: ERR-4.1 hint mentions the env-var fallback"

# --- AC-T2-004: env var resolution + CLI override --------------------------------------------

init_suite "AC-T2-004 env vs CLI resolution"

tmp="$(mk_repo ac004a)"
run_init -- \
  --project-dir "$tmp" --worktree-root "$tmp/wt" \
  --noninteractive --name t --github-project-number 1
# (re-run with env; the first call above is the no-env control)
tmp="$(mk_repo ac004a)"
run_init "INIT_PROJECT_GITHUB_OWNER=env-owner" -- \
  --project-dir "$tmp" --worktree-root "$tmp/wt" \
  --noninteractive --name t --github-project-number 1
assert_exit_zero "AC-T2-004a: INIT_PROJECT_GITHUB_OWNER supplies the missing required value" "$INIT_RC"

tmp="$(mk_repo ac004b)"
run_init "INIT_PROJECT_GITHUB_OWNER=env-owner" -- \
  --project-dir "$tmp" --worktree-root "$tmp/wt" \
  --noninteractive --name t --github-owner flag-owner --github-project-number 1
assert_exit_zero "AC-T2-004b: CLI --github-owner overrides INIT_PROJECT_GITHUB_OWNER" "$INIT_RC"

tmp="$(mk_repo ac004c)"
run_init "INIT_PROJECT_INTERACTIVE=1" -- \
  --project-dir "$tmp" --worktree-root "$tmp/wt"
assert_exit_zero "AC-T2-004c: INIT_PROJECT_INTERACTIVE=1 forces interactive (bypasses required-flag check)" "$INIT_RC"

tmp="$(mk_repo ac004d)"
run_init "INIT_PROJECT_NONINTERACTIVE=1" -- \
  --project-dir "$tmp" --worktree-root "$tmp/wt"
assert_exit_nonzero "AC-T2-004d: INIT_PROJECT_NONINTERACTIVE=1 forces noninteractive (check fires)" "$INIT_RC"
assert_out_contains "$ERR" 'Noninteractive mode requires' "AC-T2-004d: missing-flag banner"

tmp="$(mk_repo ac004e)"
run_init "INIT_PROJECT_INTERACTIVE=1" "INIT_PROJECT_NONINTERACTIVE=1" -- \
  --project-dir "$tmp" --worktree-root "$tmp/wt"
assert_exit_nonzero "AC-T2-004e: contradictory mode env vars → exit 1" "$INIT_RC"
assert_out_contains "$ERR" 'Both INIT_PROJECT_INTERACTIVE and INIT_PROJECT_NONINTERACTIVE' \
  "AC-T2-004e: contradiction error text"

tmp="$(mk_repo ac004f)"
run_required "$tmp"
assert_exit_zero "AC-T2-004f: --merge default in noninteractive is 0 (accepted as-is)" "$INIT_RC"

tmp="$(mk_repo ac004g)"
run_required "$tmp" --merge
assert_exit_zero "AC-T2-004g: --merge flag forces merge=1 in noninteractive (no error)" "$INIT_RC"

# --- AC-T2-005: pre-existing flags preserved ---------------------------------------------------

init_suite "AC-T2-005 pre-existing flags preserved"

tmp="$(mk_repo ac005a)"
run_required "$tmp" --docs-root .docs
assert_exit_zero "AC-T2-005a: --docs-root .docs accepted" "$INIT_RC"
assert_exists "AC-T2-005a: .docs directory created" "$tmp/.docs"

tmp="$(mk_repo ac005b)"
run_required "$tmp"
assert_exit_zero "AC-T2-005b: --worktree-root accepted" "$INIT_RC"
assert_exists "AC-T2-005b: worktree root created" "$tmp/wt"

tmp="$(mk_repo ac005c)"
run_init -- --project-dir "$tmp" --worktree-root "$tmp/wt" --bogus-flag
assert_exit_nonzero "AC-T2-005c: unknown flag rejected" "$INIT_RC"
assert_out_contains_str "$ERR" "Unknown argument: --bogus-flag" "AC-T2-005c: unknown-flag error text"

run_init -- --help
assert_exit_zero "AC-T2-005d: --help exits 0" "$INIT_RC"
assert_out_contains_str "$OUT" "--noninteractive" "AC-T2-005d: usage documents --noninteractive"
assert_out_contains_str "$OUT" "--repo-role" "AC-T2-005d: usage documents --repo-role"

# --- AC-T2-006: --repo-role enum ------------------------------------------------------------------

init_suite "AC-T2-006 --repo-role enum"

for role in service library infra monorepo-root tool docs other; do
  tmp="$(mk_repo "ac006-$role")"
  run_required "$tmp" --repo-role "$role"
  assert_exit_zero "AC-T2-006: --repo-role $role accepted" "$INIT_RC"
done

tmp="$(mk_repo ac006-invalid)"
run_required "$tmp" --repo-role invalid_role
assert_exit_nonzero "AC-T2-006: invalid --repo-role rejected" "$INIT_RC"
assert_out_contains_str "$ERR" "Invalid --repo-role value: 'invalid_role'" \
  "AC-T2-006 (invalid): clear stderr error"
assert_out_contains_str "$ERR" "service" "AC-T2-006 (invalid): valid-value list includes service"
assert_out_contains_str "$ERR" "monorepo-root" "AC-T2-006 (invalid): valid-value list includes monorepo-root"

tmp="$(mk_repo ac006-env)"
mapfile -t env_args < <(required_args "$tmp")
run_init "INIT_PROJECT_ROLE=library" -- "${env_args[@]}"
assert_exit_zero "AC-T2-006: INIT_PROJECT_ROLE env supplies --repo-role" "$INIT_RC"

tmp="$(mk_repo ac006-env-invalid)"
mapfile -t env_args < <(required_args "$tmp")
run_init "INIT_PROJECT_ROLE=spaceship" -- "${env_args[@]}"
assert_exit_nonzero "AC-T2-006: INIT_PROJECT_ROLE env with invalid value rejected" "$INIT_RC"
assert_out_contains_str "$ERR" "Invalid --repo-role value: 'spaceship'" \
  "AC-T2-006 (env invalid): clear stderr error"

# --- AC-T2-007: @file + inline for --commands / --conventions -------------------------------

init_suite "AC-T2-007 --commands / --conventions @file"

tmp="$(mk_repo ac007a)"
printf 'npm test\nnpm build\n' > "$TMP/cmds.txt"
run_required "$tmp" --commands "@$TMP/cmds.txt"
assert_exit_zero "AC-T2-007a: --commands @/path reads file (accepted, exits 0)" "$INIT_RC"

tmp="$(mk_repo ac007b)"
init_run "$OUT" "$ERR" -- \
  --project-dir "$tmp" --worktree-root "$tmp/wt" \
  --noninteractive --name test --github-owner antpolis --github-project-number 9 \
  --commands $'npm test\nnpm build'
assert_exit_zero "AC-T2-007b: --commands inline text used verbatim" "$INIT_RC"

tmp="$(mk_repo ac007c)"
run_required "$tmp" --commands "@/no/such/file"
assert_exit_nonzero "AC-T2-007c: --commands @missing-file is a hard error" "$INIT_RC"
assert_out_contains_str "$ERR" "--commands: file not found: /no/such/file" \
  "AC-T2-007c: file-not-found error text"

tmp="$(mk_repo ac007d)"
printf 'Use conventional commits.\n' > "$TMP/conventions.txt"
run_required "$tmp" --conventions "@$TMP/conventions.txt"
assert_exit_zero "AC-T2-007d: --conventions @/path reads file" "$INIT_RC"

# --- Guardrails (related-repos, booleans, dry-run) ---------------------------------------------

init_suite "guardrails (related-repos, booleans, dry-run)"

tmp="$(mk_repo gr-rr-valid)"
run_required "$tmp" --related-repos 'sibling:https://github.com/org/sibling:sibling'
assert_exit_zero "guardrail: --related-repos valid triple accepted" "$INIT_RC"

tmp="$(mk_repo gr-rr-multi)"
run_required "$tmp" --related-repos 'a:https://github.com/o/a:sibling,b:https://github.com/o/b:parent'
assert_exit_zero "guardrail: --related-repos multiple triples accepted" "$INIT_RC"

tmp="$(mk_repo gr-rr-bad)"
run_required "$tmp" --related-repos 'just-a-name'
assert_exit_nonzero "guardrail: --related-repos malformed triple rejected" "$INIT_RC"
assert_out_contains_str "$ERR" "Invalid --related-repos entry: 'just-a-name'" \
  "guardrail: malformed-triple error text"

# Boolean flags: --force / --dry-run accepted; --skip-inspection retired
# (SPEC-005-T1) and must now be rejected like --migrate-agent-md.
tmp="$(mk_repo gr-bool)"
run_required "$tmp" --force --dry-run
assert_exit_zero "guardrail: --force / --dry-run accepted in noninteractive" "$INIT_RC"

tmp="$(mk_repo gr-skip-inspection)"
run_required "$tmp" --skip-inspection
assert_exit_nonzero "guardrail: retired --skip-inspection rejected (SPEC-005-T1)" "$INIT_RC"
assert_out_contains_str "$ERR" "Unknown argument: --skip-inspection" \
  "guardrail: --skip-inspection rejected as unknown argument"

tmp="$(mk_repo gr-migrate)"
run_required "$tmp" --migrate-agent-md
assert_exit_nonzero "guardrail: retired --migrate-agent-md rejected" "$INIT_RC"
assert_out_contains_str "$ERR" "Unknown argument: --migrate-agent-md" \
  "guardrail: --migrate-agent-md rejected as unknown argument"

tmp="$(mk_repo gr-env-bool)"
mapfile -t env_args < <(required_args "$tmp")
run_init "INIT_PROJECT_SKIP_INSPECTION=1" "INIT_PROJECT_DRY_RUN=1" -- "${env_args[@]}"
assert_exit_zero "guardrail: INIT_PROJECT_SKIP_INSPECTION=1 + INIT_PROJECT_DRY_RUN=1 accepted via env" "$INIT_RC"

# --- Regression: --github-project-number positive integer -----------------------------------------

init_suite "regression --github-project-number positive integer"

gpn_bad=( 'nope' '0' '-1' '1.5' '1e10' '0x10' ' 9' '9 ' 'abc123' '123abc' '07' )
for bad in "${gpn_bad[@]}"; do
  tmp="$(mk_repo "reg-gpn-$(printf '%s' "$bad" | tr -c 'a-zA-Z0-9' '_')")"
  run_init -- \
    --project-dir "$tmp" --worktree-root "$tmp/wt" \
    --noninteractive --name test --github-owner antpolis \
    --github-project-number "$bad"
  assert_exit_nonzero "regression: --github-project-number '$bad' rejected" "$INIT_RC"
  assert_out_contains "$ERR" 'Invalid --github-project-number' \
    "regression ($bad): 'Invalid --github-project-number' on stderr"
done

for good in 1 9 42 123456 9999999; do
  tmp="$(mk_repo "reg-gpn-good-$good")"
  run_init -- \
    --project-dir "$tmp" --worktree-root "$tmp/wt" \
    --noninteractive --name test --github-owner antpolis \
    --github-project-number "$good"
  assert_exit_zero "regression: --github-project-number '$good' accepted" "$INIT_RC"
done

tmp="$(mk_repo reg-gpn-env-bad)"
run_init "INIT_PROJECT_GITHUB_PROJECT_NUMBER=nope" -- \
  --project-dir "$tmp" --worktree-root "$tmp/wt" \
  --noninteractive --name test --github-owner antpolis
assert_exit_nonzero "regression: INIT_PROJECT_GITHUB_PROJECT_NUMBER=nope rejected via env" "$INIT_RC"
assert_out_contains "$ERR" 'Invalid --github-project-number' "regression (env bad): error text"

# --- Regression: --related-repos opaque URL contract (first/last colon) ------------------------------

init_suite "regression --related-repos opaque URL contract"

rr_good=(
  'sibling:https://github.com:443/org/repo:sibling'
  'sibling:ssh://git@github.com:22/org/repo:sibling'
  'a:git@github.com:org/repo:sibling'
  'a:https://github.com/org/repo:sibling'
  'a:ssh://git@github.com/org/repo:sibling'
  'a:/abs/local/path:child'
  'a:./rel/path:child'
  'a:b:c'
  'a:https://github.com/o/a:parent:extra'
  'a:b:c:d:e'
  'a:b:c:d:e:f:g'
  'a:https://github.com:443/o/a:sibling,b:ssh://git@github.com:22/o/b:parent,c:git@github.com:o/c:child'
)
i=0
for good in "${rr_good[@]}"; do
  i=$((i + 1))
  tmp="$(mk_repo "reg-rr-good-$i")"
  run_required "$tmp" --related-repos "$good"
  assert_exit_zero "regression: --related-repos '$good' accepted (opaque url)" "$INIT_RC"
done

rr_bad=(
  'just-a-name'
  'a:b'
  ':https://github.com/o/a:parent'
  'name::relationship'
  'a:https://github.com/o/a:'
  'a:'
  ':'
  'a::'
  '::relationship'
)
i=0
for bad in "${rr_bad[@]}"; do
  i=$((i + 1))
  tmp="$(mk_repo "reg-rr-bad-$i")"
  run_required "$tmp" --related-repos "$bad"
  assert_exit_nonzero "regression: --related-repos '$bad' rejected (unambiguous)" "$INIT_RC"
  assert_out_contains "$ERR" 'Invalid --related-repos entry' "regression ($bad): error text"
done

tmp="$(mk_repo reg-rr-list-one-bad)"
run_required "$tmp" --related-repos 'a:https://github.com:443/o/a:sibling,b:not-a-triple'
assert_exit_nonzero "regression: --related-repos list with one malformed triple rejected" "$INIT_RC"
assert_out_contains "$ERR" 'Invalid --related-repos entry' "regression (list one bad): error text"

# --- Summary -------------------------------------------------------------------------------------------

init_done
