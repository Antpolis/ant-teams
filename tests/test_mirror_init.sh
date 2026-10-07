#!/usr/bin/env bash
#
# tests/test_mirror_init.sh — initializer runs from the team-scripts install.
#
# Migrated from tests/test_mirror_init.js (SPEC-004-T4, issue #54).
# Assertion parity: all 3 Node checks migrated 1:1; none weakened.
# Stale-setup classification (pre-migration failures):
#   - the harness seeded every init invocation with `--skip-inspection`, a
#     flag retired by SPEC-005-T1 → dropped from the harness args;
#   - MIR-1/MIR-3 asserted `init-project/inspect_repo.js` next to the engine,
#     an asset removed by SPEC-004-T3 (#53) → replaced with the actual current
#     support asset (`init-project/github-project.env.template`).
# The behavioral assertions (wrapper-over-no-exec-bits, preflight, sentinel,
# direct centralized-wrapper execution) are migrated unchanged.
#
# Regression suite for the project-init engine location contract (2026-08
# tooling-path migration): "$ANT_TEAM_SCRIPTS/init-project.sh" IS the engine
# (installed from templates/scripts/ by scripts/init-company.sh), with
# support assets in the sibling init-project/ directory. The engine resolves
# required skills from the SIBLING skills root (~/.agents/skills), and the
# source-checkout wrapper scripts/init-project.sh delegates to the installed
# engine via `bash`, so no execute bits are required anywhere in the install
# (managed sync may tighten updated files to mode 0644 per ARCH-004 SEC-3.2).
#
#   MIR-1  the source-checkout wrapper initializes a target repo through a
#          simulated team-scripts install (~/.agents/scripts + ~/.agents/
#          skills) in which NO file is executable, and the copied skills
#          come from the install (sentinel), not the checkout
#   MIR-2  preflight fails cleanly ([error], exit 1) when a required sibling
#          skill is missing from the install — before any write happens
#   MIR-3  the REAL scripts/init-company.sh installs into a temp HOME, then
#          "$ANT_TEAM_SCRIPTS/gh_project_helper.sh" is invoked directly and
#          executes the engine from the managed mirror — with the mirror
#          engine forced non-executable (0644), proving centralized wrapper
#          execution without mirror execute bits; the init engine and its
#          support assets must be installed into ~/.agents/scripts. The
#          coordinator regenerates the repo-local `.opencode/` mirror next to
#          itself, so it runs from a disposable copy of the canonical sources
#          (sync-suite fixture convention) and the source checkout's tracked
#          mirror is asserted unchanged (review-loop-1 fix, PR #74).
#
# No network access. Temp HOME fixtures only — never the real ~/.agents or
# ~/.config trees, and never the source checkout's generated `.opencode/`
# mirror.
#
# Run directly: `bash tests/test_mirror_init.sh`.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/init_helpers.sh"

REQUIRED_SKILLS=( github-issues-projects-cli do-task )

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

OUT="$TMP/out.txt"
ERR="$TMP/err.txt"

# copy_tree_no_exec SRC DST — recursive copy of CONTENTS (Node cpSync
# semantics, including dotfiles), then force EVERY file to 0644 and every
# directory to 0755 (worst-case install: nothing is executable).
copy_tree_no_exec() {
  local src="$1" dst="$2"
  mkdir -p "$dst"
  cp -R "$src/." "$dst/"
  find "$dst" -type d -exec chmod 0755 {} +
  find "$dst" -type f -exec chmod 0644 {} +
}

# opencode_mirror_state REPO_ROOT — stable fingerprint of REPO_ROOT's
# generated `.opencode/` mirror: one "<mode> <sha256> <relpath>" line per
# regular file. Prints ABSENT when the mirror does not exist. Used to prove a
# run left the source checkout's tracked mirror byte-identical (git-visible
# dirt = file content, mode, or inventory changes — all captured here).
opencode_mirror_state() {
  local root="$1"
  if [[ ! -d "$root/.opencode" ]]; then
    printf 'ABSENT\n'
    return 0
  fi
  (
    cd "$root" || exit 1
    find .opencode -type f | LC_ALL=C sort | while IFS= read -r f; do
      printf '%s %s %s\n' \
        "$(stat -c %a "$f" 2>/dev/null || stat -f %Lp "$f")" \
        "$(sha256sum "$f" 2>/dev/null | awk '{print tolower($1)}')" "$f"
    done
  )
}

# build_simulated_install HOME — simulated post-init-company layout. Echoes
# nothing; sets REPLY-like globals via stdout path printing instead:
# prints "<mirror_skills>\n<team_scripts>".
build_simulated_install() {
  local home="$1"
  local agents_dir="$home/.agents"
  local mirror_skills="$agents_dir/skills"
  local team_scripts="$agents_dir/scripts"
  mkdir -p "$mirror_skills" "$team_scripts"
  local skill
  for skill in "${REQUIRED_SKILLS[@]}"; do
    copy_tree_no_exec "$INIT_REPO_ROOT/templates/opencode/skills/$skill" "$mirror_skills/$skill"
  done
  copy_tree_no_exec "$INIT_REPO_ROOT/templates/scripts" "$team_scripts"
  printf '%s\n%s\n' "$mirror_skills" "$team_scripts"
}

# mk_target_repo — throwaway target with a .git marker (under the suite TMP).
mk_target_repo() {
  init_make_repo "$TMP/mir-target"
}

# run_wrapper HOME TEAM_SCRIPTS CWD ARGS... — run the source-checkout wrapper
# with the simulated install env.
run_wrapper() {
  local home="$1" team_scripts="$2" cwd="$3"; shift 3
  init_run_cmd "$OUT" "$ERR" "$cwd" \
    "HOME=$home" "ANT_TEAM_SCRIPTS=$team_scripts" -- \
    bash "$INIT_REPO_ROOT/scripts/init-project.sh" "$@"
}

# init_args_for TARGET — standard noninteractive invocation (no retired flags).
init_args_for() {
  printf '%s\n' \
    --noninteractive \
    --project-dir "$1" \
    --worktree-root "$1/wt" \
    --name mirror-demo \
    --github-owner antpolis \
    --github-project-number 1
}

# --- MIR-1: wrapper initializes a target through the simulated install --------

init_suite "MIR-1 wrapper + no execute bits anywhere"

mir1_home="$TMP/mir1-home"
mkdir -p "$mir1_home"
{
  read -r mir1_skills
  read -r mir1_scripts
} < <(build_simulated_install "$mir1_home")

# Sentinel: proves the copied skills come from the INSTALL, not the checkout.
printf 'mirror\n' > "$mir1_skills/do-task/MIRROR-SENTINEL"
chmod 0644 "$mir1_skills/do-task/MIRROR-SENTINEL"

# Sanity: the engine really is non-executable in the simulated install, and
# the current support asset ships next to it.
engine_copy="$mir1_scripts/init-project.sh"
assert_exists "MIR-1 setup: engine installed into simulated team scripts" "$engine_copy"
if [[ -x "$engine_copy" ]]; then
  check FAIL "MIR-1 setup: installed engine must be non-executable for this regression"
else
  check OK "MIR-1 setup: installed engine is non-executable"
fi
assert_exists "MIR-1 setup: support asset installed next to the engine (github-project.env.template)" \
  "$mir1_scripts/init-project/github-project.env.template"

mir1_target="$(mk_target_repo)"
mapfile -t mir1_args < <(init_args_for "$mir1_target")
run_wrapper "$mir1_home" "$mir1_scripts" "$mir1_target" "${mir1_args[@]}"
assert_exit_zero "MIR-1: wrapper exit 0" "$INIT_RC"

# Core artifacts exist.
assert_exists "MIR-1: .github-project.env created" "$mir1_target/.github-project.env"
assert_exists "MIR-1: AGENTS.md created" "$mir1_target/AGENTS.md"

# All required skills were copied from the sibling skills root.
for skill in "${REQUIRED_SKILLS[@]}"; do
  assert_exists "MIR-1: required skill copied: $skill" "$mir1_target/.opencode/skills/$skill/SKILL.md"
done
assert_exists "MIR-1: skills sourced from the install (sentinel at target)" \
  "$mir1_target/.opencode/skills/do-task/MIRROR-SENTINEL"
# The retired project-initialization skill is never copied into targets.
assert_not_exists "MIR-1: project-initialization skill not copied into targets" \
  "$mir1_target/.opencode/skills/project-initialization"
# The simulated HOME layout contains no checkout-style .opencode/skills —
# success therefore proves the engine never depended on a checkout root.
assert_not_exists "MIR-1: simulated HOME has no checkout-style skills tree" "$mir1_home/.opencode/skills"

# --- MIR-2: missing required sibling skill fails preflight ----------------------

init_suite "MIR-2 missing sibling skill preflight"

mir2_home="$TMP/mir2-home"
mkdir -p "$mir2_home"
{
  read -r mir2_skills
  read -r mir2_scripts
} < <(build_simulated_install "$mir2_home")
rm -rf "$mir2_skills/do-task"

mir2_target="$(mk_target_repo)"
mapfile -t mir2_args < <(init_args_for "$mir2_target")
run_wrapper "$mir2_home" "$mir2_scripts" "$mir2_target" "${mir2_args[@]}"
assert_exit_nonzero "MIR-2: preflight exits non-zero on missing sibling skill" "$INIT_RC"
assert_out_contains "$ERR" '\[error\]' "MIR-2: [error] line on stderr"
assert_out_contains "$ERR" 'do-task' "MIR-2: stderr names the missing required skill"
# ERR-1.1: preflight runs BEFORE any write — the target stays untouched.
assert_not_exists "MIR-2: no artifact written on preflight failure" "$mir2_target/.github-project.env"
assert_not_exists "MIR-2: no skills copied on preflight failure" "$mir2_target/.opencode"

# --- MIR-3: real sync install, then direct centralized wrapper invocation -------

init_suite "MIR-3 real init-company + direct wrapper execution"

# init-company.sh regenerates the repo-local `.opencode/` mirror NEXT TO
# ITSELF (sync_repo_opencode: rm -rf + copy from templates/opencode), so it
# must never run with $script_root inside the source checkout. Mirror the
# sync-suite fixture convention (sync_make_fixture_repo_with_company): copy
# the real coordinator + managed sync and the canonical templates/opencode
# into a disposable repo under the suite TMP — every generated output lands
# in the copy and the checkout stays byte-identical.
mir3_repo="$TMP/mir3-repo"
mkdir -p "$mir3_repo/scripts" "$mir3_repo/templates"
cp "$INIT_REPO_ROOT/scripts/init-company.sh" \
  "$INIT_REPO_ROOT/scripts/sync-managed-skills.sh" "$mir3_repo/scripts/"
chmod 0755 "$mir3_repo/scripts/init-company.sh" \
  "$mir3_repo/scripts/sync-managed-skills.sh" 2>/dev/null || true
cp -R "$INIT_REPO_ROOT/templates/opencode" "$mir3_repo/templates/opencode"
cp -R "$INIT_REPO_ROOT/templates/scripts" "$mir3_repo/templates/scripts"

# Isolation proof setup: fingerprint the checkout's generated `.opencode/`
# mirror before the run; compared unchanged below.
mir3_checkout_before="$(opencode_mirror_state "$INIT_REPO_ROOT")"

mir3_home="$TMP/mir3-home"
mkdir -p "$mir3_home"
init_run_cmd "$OUT" "$ERR" "$mir3_repo" \
  -u OPENCODE_CONFIG_DIR "HOME=$mir3_home" -- \
  bash "$mir3_repo/scripts/init-company.sh"
assert_exit_zero "MIR-3: init-company.sh exits 0 into temp HOME" "$INIT_RC"

# The disposable copy absorbed the generated repo-local mirror; the source
# checkout's tracked mirror is unchanged (isolation promise,
# tests/lib/init_helpers.sh).
assert_exists "MIR-3: generated repo-local mirror lands in the disposable copy" \
  "$mir3_repo/.opencode/opencode.json"
mir3_checkout_after="$(opencode_mirror_state "$INIT_REPO_ROOT")"
if [[ "$mir3_checkout_after" == "$mir3_checkout_before" ]]; then
  check OK "MIR-3: source checkout .opencode/ mirror unchanged (mode+content+inventory)"
else
  check FAIL "MIR-3: source checkout .opencode/ mirror mutated during the run"
fi

mir3_scripts="$mir3_home/.agents/scripts"
wrapper="$mir3_scripts/gh_project_helper.sh"
assert_exists "MIR-3: sync installs the centralized gh_project_helper.sh wrapper" "$wrapper"
if [[ -x "$wrapper" ]]; then
  check OK "MIR-3: installed wrapper is executable (sync_team_scripts chmod 0755)"
else
  check FAIL "MIR-3: installed wrapper must be executable (sync_team_scripts chmod 0755)"
fi

# Tooling-path contract: the init engine installs at
# $ANT_TEAM_SCRIPTS/init-project.sh with its support assets alongside.
assert_exists "MIR-3: sync installs the init engine into the team scripts" "$mir3_scripts/init-project.sh"
assert_exists "MIR-3: sync installs the engine support asset (github-project.env.template)" \
  "$mir3_scripts/init-project/github-project.env.template"

# The install configures the centralized entry in the shell rc files.
assert_file_contains_str "MIR-3: rc file exports ANT_TEAM_SCRIPTS" "$mir3_home/.zshrc" \
  'export ANT_TEAM_SCRIPTS="$HOME/.agents/scripts"'

# Worst-case managed mirror: the engine copy is NOT executable (managed sync
# may tighten updated files to mode 0644 — ARCH-004 SEC-3.2).
mirror_engine="$mir3_home/.agents/skills/github-issues-projects-cli/scripts/gh_project_helper.sh"
assert_exists "MIR-3: sync installs the engine into the managed mirror" "$mirror_engine"
chmod 0644 "$mirror_engine"
if [[ -x "$mirror_engine" ]]; then
  check FAIL "MIR-3 setup: mirror engine must be non-executable for this smoke"
else
  check OK "MIR-3 setup: mirror engine forced non-executable"
fi

# Target repo with its own env config (engine sources .github-project.env
# from its working directory) and a fake gh shim that records every call —
# no network, no live board access.
mir3_target="$(mk_target_repo)"
printf "export ANT_TEAM_GITHUB_OWNER='env-owner'\nexport ANT_TEAM_GITHUB_PROJECT_NUMBER='7'\n" \
  > "$mir3_target/.github-project.env"
mir3_bin="$TMP/mir3-bin"
mkdir -p "$mir3_bin"
gh_log="$mir3_bin/gh-calls.log"
cat > "$mir3_bin/gh" <<GH
#!/usr/bin/env bash
printf 'ARGS:' >> '$gh_log'; printf ' [%s]' "\$@" >> '$gh_log'; echo '{"fields":[{"name":"Workflow State","options":[{"name":"Open"},{"name":"Done"}]}]}'
GH
chmod 0755 "$mir3_bin/gh"

# Direct invocation of the installed centralized wrapper — exactly the
# documented "$ANT_TEAM_SCRIPTS/gh_project_helper.sh" entry point.
init_run_cmd "$OUT" "$ERR" "$mir3_target" \
  "HOME=$mir3_home" "ANT_TEAM_SCRIPTS=$mir3_scripts" "PATH=$mir3_bin:$PATH" -- \
  "$wrapper" list-statuses
assert_exit_zero "MIR-3: direct wrapper invocation exits 0" "$INIT_RC"

# The mirror engine really ran: jq-processed field options on stdout.
assert_out_contains_str "$OUT" 'Open' "MIR-3: engine lists the Open option"
assert_out_contains_str "$OUT" 'Done' "MIR-3: engine lists the Done option"

# And it resolved the board target from the target repo's env config.
calls="$(cat "$gh_log")"
if [[ "$calls" == *'[env-owner]'* ]]; then
  check OK "MIR-3: owner resolved from the env"
else
  check FAIL "MIR-3: owner must come from the env, got: $calls"
fi
if [[ "$calls" == *'[7]'* ]]; then
  check OK "MIR-3: project number resolved from the env"
else
  check FAIL "MIR-3: project number must come from the env, got: $calls"
fi

# --- Summary ----------------------------------------------------------------------

init_done
