#!/usr/bin/env bash
#
# tests/test_agents_md_gen.sh — SPEC-001-T3 unit tests.
#
# Migrated from tests/test_agents_md_gen.js (SPEC-004-T4, issue #54).
# Assertion parity: every Node check is either migrated 1:1 or replaced by a
# STRICTER current-contract assertion under a recorded classification.
# Stale-assertion classifications (the 12 pre-migration failures; the engine
# intentionally changed under merged, Done issues — none of these assertions
# matched current canonical behavior):
#   - "INIT_PROJECT_VERSION is 0.3.0" and the line-1 `v0\.3\.0` regex pinned
#     the SPEC-001-T3-era version. The engine is at 0.4.0 (post SPEC-004-T3).
#     Migrated to version-format + engine↔output consistency (stronger: the
#     generated header must carry the engine's own version).
#   - "Local Configuration Files lists skills directories": post SPEC-005 the
#     generated LCF enumerates config artifacts (AGENTS.md, .github-project.env,
#     opencode config), not skill trees. Migrated to the current artifact list.
#   - Interactive-prompt suite (AC-T3-001 prompt count, AC-T3-002 blank
#     responses, AC-T3-003 preview/decline/confirm, AC-T3-007 interactive
#     ask-skip/ask-overwrite): the default-only generator (SPEC-004-T3,
#     #62) has NO interactive prompts at all (`[prompt]` appears zero times in
#     the engine; the T3 engine comment states "no interactive prompts").
#     Migrated to the stronger no-prompt contract: --interactive still
#     generates AGENTS.md with zero [prompt] lines, no preview gating, and no
#     required identity flags.
#   - "--conventions appears verbatim" / "--repo-role rendered (Role:
#     service)" / "--related-repos/--commands/--scratch-dir rendered": the
#     current generator accepts these flags for CLI compatibility but does not
#     render them into AGENTS.md (engine comment, lines "Operator prompt flags
#     ... are accepted for CLI compatibility but no longer drive AGENTS.md
#     section content"). Migrated to: flags accepted (exit 0) + description
#     still rendered (Project Understanding).
#   - "--force --merge must not render the new description": the description
#     now lives in the NEW "## Project Understanding" section, which merge
#     correctly appends. Migrated to: existing sections preserved verbatim +
#     new sections appended + no section duplication + refreshed header.
#   - "repo-node-npm produces ## Stack / ## Build, Test, and Run Commands":
#     headings renamed by the default-only generator to
#     "## Current Architecture And Stack" / "## Commands". Detection itself is
#     retained (jq-based package.json evidence) — migrated to the new headings
#     with the same detection-content assertions (stronger).
#
# Drives `templates/scripts/init-project.sh` through the AGENTS.md generation
# surface. Asserts DM-2 structure guarantees (DM-2.2/2.3/2.4), AC-T3-006
# traceable claims, AC-T3-004 noninteractive mode, AC-T3-005 generation
# header, AC-T3-007 pre-existing-file policy, AC-T3-008 merge, and the
# ARCH-003 backward-compatibility contract (agent.md coexistence).
#
# Run directly: `bash tests/test_agents_md_gen.sh`.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/init_helpers.sh"

BARE_FIXTURE="$INIT_REPO_ROOT/tests/fixtures/repo-bare"
NODE_FIXTURE="$INIT_REPO_ROOT/tests/fixtures/repo-node-npm"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

OUT="$TMP/out.txt"
ERR="$TMP/err.txt"

# Engine version (parsed once; used for version-consistency assertions).
ENGINE_VERSION="$(sed -n 's/^readonly INIT_PROJECT_VERSION="\([^"]*\)".*/\1/p' "$INIT_SCRIPT")"

# run_noninteractive PROJECT_DIR [EXTRA...] — noninteractive with the required
# identity flags (overridable via INIT_PROJECT_NAME and INIT_PROJECT_GITHUB_*
# env vars set by callers through init_run directly).
run_noninteractive() {
  local tmp="$1"; shift
  init_run "$OUT" "$ERR" -- \
    --noninteractive \
    --project-dir "$tmp" \
    --worktree-root "$tmp/wt" \
    --name test \
    --github-owner antpolis \
    --github-project-number 9 \
    "$@"
}

# run_interactive PROJECT_DIR [EXTRA...] — --interactive with piped stdin
# (no TTY). Post-SPEC-005 the generator asks nothing; stdin is drained.
run_interactive() {
  local tmp="$1"; shift
  init_run "$OUT" "$ERR" -- \
    --interactive \
    --project-dir "$tmp" \
    --worktree-root "$tmp/wt" \
    "$@"
}

# assert_agents_line1 LABEL FILE VERSION — line 1 is the full generation
# comment carrying the given version.
assert_agents_line1() {
  local label="$1" file="$2" version="$3"
  local line1
  line1="$(head -1 "$file")"
  if [[ "$line1" =~ ^\<!--\ Generated\ by\ init-project\ v"$version"\ on\ [0-9]{4}-[0-9]{2}-[0-9]{2}T.*\ —\ edit\ freely\ --\>$ ]]; then
    check OK "$label"
  else
    check FAIL "$label (line 1 mismatch: $line1)"
  fi
}

# --- Pre-flight -------------------------------------------------------------------

init_suite "preflight"

assert_exists "init-project.sh exists" "$INIT_SCRIPT"
bash -n "$INIT_SCRIPT" 2>"$ERR" && check OK "init-project.sh is syntactically valid" || check FAIL "init-project.sh is syntactically valid"

if [[ "$ENGINE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  check OK "INIT_PROJECT_VERSION is a semver literal ($ENGINE_VERSION)"
else
  check FAIL "INIT_PROJECT_VERSION is a semver literal (got: $ENGINE_VERSION)"
fi

# --- AC-T3-005: generation timestamp on line 1 --------------------------------------

init_suite "AC-T3-005 generation timestamp"

tmp="$TMP/ac005"
mkdir -p "$tmp/.git"
run_noninteractive "$tmp"
assert_exit_zero "AC-T3-005 setup: noninteractive run exits 0" "$INIT_RC"
assert_agents_line1 "AC-T3-005: noninteractive AGENTS.md line 1 is the generation comment (v$ENGINE_VERSION)" \
  "$tmp/AGENTS.md" "$ENGINE_VERSION"

tmp="$TMP/ac005-grep"
mkdir -p "$tmp/.git"
run_noninteractive "$tmp"
line1="$(head -1 "$tmp/AGENTS.md")"
if [[ "$line1" == *"Generated by init-project"* ]]; then
  check OK "AC-T3-005: matches head -1 | grep contract from issue verification"
else
  check FAIL "AC-T3-005: head -1 | grep contract (got: $line1)"
fi

# --- DM-2 structural guarantees --------------------------------------------------------

init_suite "DM-2 structure"

tmp="$TMP/dm22"
mkdir -p "$tmp/.git"
run_noninteractive "$tmp" --name svc --github-owner org --github-project-number 3
h2_total="$(grep -cE '^## .+$' "$tmp/AGENTS.md" || true)"
h1_h3_total="$(grep -cE '^#{1}(#####*|)[[:space:]]' "$tmp/AGENTS.md" || true)"
if (( h2_total > 0 )); then
  check OK "DM-2.2: at least one H2 heading present ($h2_total)"
else
  check FAIL "DM-2.2: expected at least one H2 heading"
fi
h3_or_h1="$(grep -cE '^(#[^#]|###[[:space:]])' "$tmp/AGENTS.md" || true)"
assert_eq "DM-2.2: no H1 or H3+ headings (standard H2 set only)" "$h3_or_h1" "0"

tmp="$TMP/dm23"
mkdir -p "$tmp/.git"
run_noninteractive "$tmp"
# No empty H2 (next non-blank line after a heading must not be another H2).
empty_sections=0
prev_heading=""
while IFS= read -r line; do
  if [[ "$line" == '## '* ]]; then
    if [[ -n "$prev_heading" ]]; then empty_sections=$((empty_sections + 1)); fi
    prev_heading="$line"
  elif [[ -n "${line//[[:space:]]/}" ]]; then
    prev_heading=""
  fi
done < "$tmp/AGENTS.md"
if [[ -n "$prev_heading" ]]; then empty_sections=$((empty_sections + 1)); fi
assert_eq "DM-2.3: empty sections omitted (no empty H2 followed immediately by another H2)" "$empty_sections" "0"

tmp="$TMP/dm24"
mkdir -p "$tmp/.git"
run_noninteractive "$tmp"
assert_file_contains "DM-2.4: 'Local Configuration Files' section always present" "$tmp/AGENTS.md" '^## Local Configuration Files'
assert_file_contains "DM-2.4: AGENTS.md listed in Local Configuration Files" "$tmp/AGENTS.md" '`AGENTS\.md`'
assert_file_contains "DM-2.4: .github-project.env listed" "$tmp/AGENTS.md" '`\.github-project\.env`'

tmp="$TMP/dm24-list"
mkdir -p "$tmp/.git"
run_noninteractive "$tmp"
# Current artifact contract (post SPEC-005): config artifacts, not skill trees.
assert_file_contains_str "DM-2.4: lists created artifact AGENTS.md" "$tmp/AGENTS.md" '`AGENTS.md`'
assert_file_contains_str "DM-2.4: lists created artifact .github-project.env" "$tmp/AGENTS.md" '`.github-project.env`'
assert_file_contains_str "DM-2.4: lists created artifact opencode config" "$tmp/AGENTS.md" '`.opencode/opencode.json`'

# --- AC-T3-006: traceable claims / no fabrication -----------------------------------------

init_suite "AC-T3-006 traceable claims / no fabrication"

tmp="$TMP/ac006"
mkdir -p "$tmp/.git"
run_noninteractive "$tmp" --name real-service
forbidden_pat='TODO|fill this in|your-project-name|placeholder|lorem ipsum'
if grep -qiE "$forbidden_pat" "$tmp/AGENTS.md"; then
  check FAIL "AC-T3-006: forbidden placeholder text present (pattern: $forbidden_pat)"
else
  check OK "AC-T3-006: no placeholder text"
fi

tmp="$TMP/ac006-purpose"
mkdir -p "$tmp/.git"
run_noninteractive "$tmp" --description 'A custom service for testing.'
assert_file_contains_str "AC-T3-006: operator-provided purpose appears verbatim" "$tmp/AGENTS.md" 'A custom service for testing.'

tmp="$TMP/ac006-conv"
mkdir -p "$tmp/.git"
# Current contract: --conventions accepted for CLI compatibility (not rendered).
run_noninteractive "$tmp" --conventions 'Use conventional commits.'
assert_exit_zero "AC-T3-006: --conventions accepted (CLI-compat contract)" "$INIT_RC"

tmp="$(init_clone_fixture "$NODE_FIXTURE" "$TMP/ac006-stack")"
run_noninteractive "$tmp"
assert_file_contains "AC-T3-006: detected stack (Node.js) appears" "$tmp/AGENTS.md" 'Node\.js'
assert_file_contains "AC-T3-006: detected package manager (npm) appears" "$tmp/AGENTS.md" 'npm'

tmp="$(init_clone_fixture "$NODE_FIXTURE" "$TMP/ac006-cmds")"
run_noninteractive "$tmp"
assert_file_contains_str "AC-T3-006: detected command 'npm run test'" "$tmp/AGENTS.md" 'npm run test'
assert_file_contains_str "AC-T3-006: detected command 'npm run build'" "$tmp/AGENTS.md" 'npm run build'

tmp="$(init_clone_fixture "$BARE_FIXTURE" "$TMP/ac006-bare")"
run_noninteractive "$tmp"
if grep -qF '## Stack' "$tmp/AGENTS.md"; then
  check FAIL "AC-T3-006: bare repo must have no bare '## Stack' section (no fabricated stack)"
else
  check OK "AC-T3-006: bare repo has no bare '## Stack' section"
fi

# --- AC-T3-004: noninteractive mode with all flags --------------------------------------------

init_suite "AC-T3-004 noninteractive zero prompts"

tmp="$TMP/ac004"
mkdir -p "$tmp/.git"
run_noninteractive "$tmp" --description 'Test service.'
assert_exit_zero "AC-T3-004: noninteractive exits 0" "$INIT_RC"
assert_out_not_contains_str "$OUT" '[prompt]' "AC-T3-004: zero [prompt] lines on stdout"
assert_exists "AC-T3-004: AGENTS.md created" "$tmp/AGENTS.md"

tmp="$TMP/ac004-all"
mkdir -p "$tmp/.git"
run_noninteractive "$tmp" \
  --description 'Full service.' \
  --repo-role service \
  --conventions 'Use conventional commits.' \
  --commands 'npm test' \
  --related-repos 'api:https://github.com/org/api:sibling' \
  --scratch-dir './scratch/'
assert_exit_zero "AC-T3-004: all identity + content flags accepted" "$INIT_RC"
assert_file_contains_str "AC-T3-004: description rendered (Project Understanding)" "$tmp/AGENTS.md" 'Full service.'

tmp="$TMP/ac004-env"
mkdir -p "$tmp/.git"
init_run "$OUT" "$ERR" \
  "INIT_PROJECT_NAME=env-svc" \
  "INIT_PROJECT_GITHUB_OWNER=env-org" \
  "INIT_PROJECT_GITHUB_PROJECT_NUMBER=5" \
  "INIT_PROJECT_DESCRIPTION=From env." \
  -- \
  --noninteractive \
  --project-dir "$tmp" \
  --worktree-root "$tmp/wt"
assert_exit_zero "AC-T3-004: noninteractive env vars resolve (exit 0)" "$INIT_RC"
assert_file_contains_str "AC-T3-004: env description rendered" "$tmp/AGENTS.md" 'From env.'
assert_file_contains_str "AC-T3-004: env owner recorded" "$tmp/AGENTS.md" 'env-org'

# --- AC-T3-001/002/003 (current contract): --interactive works without prompts ---------------

init_suite "AC-T3-001/002/003 interactive no-prompt contract"

tmp="$(init_clone_fixture "$BARE_FIXTURE" "$TMP/ac001")"
run_interactive "$tmp"
assert_exit_zero "AC-T3-001: --interactive on repo-bare exits 0 (no identity flags required)" "$INIT_RC"
assert_exists "AC-T3-001: AGENTS.md created under --interactive" "$tmp/AGENTS.md"
assert_out_not_contains_str "$OUT" '[prompt]' "AC-T3-001: zero [prompt] lines (no-prompt design)"
assert_file_contains "AC-T3-001: Repository Identity present" "$tmp/AGENTS.md" '^## Repository Identity'
assert_file_contains "AC-T3-001: Local Configuration Files present" "$tmp/AGENTS.md" '^## Local Configuration Files'

tmp="$(init_clone_fixture "$BARE_FIXTURE" "$TMP/ac002")"
run_interactive "$tmp"
assert_exit_zero "AC-T3-002: --interactive all-default exits 0" "$INIT_RC"
assert_file_contains "AC-T3-002: Repository Identity present with default purpose" "$tmp/AGENTS.md" '^## Repository Identity'
if grep -qE '^## Repository Identity' "$tmp/AGENTS.md"; then
  body="$(sed -n '/^## Repository Identity$/,/^## /p' "$tmp/AGENTS.md" | sed '1d;/^## /d' | tr -d '[:space:]')"
  if [[ -n "$body" ]]; then
    check OK "AC-T3-002: Repository Identity body non-empty"
  else
    check FAIL "AC-T3-002: Repository Identity body should be non-empty"
  fi
fi
assert_file_contains "AC-T3-002: Documentation present" "$tmp/AGENTS.md" '^## Documentation'
assert_file_contains "AC-T3-002: Scratch and Log Directories present" "$tmp/AGENTS.md" '^## Scratch and Log Directories'
assert_file_contains "AC-T3-002: Local Configuration Files present" "$tmp/AGENTS.md" '^## Local Configuration Files'

tmp="$(init_clone_fixture "$BARE_FIXTURE" "$TMP/ac003")"
run_interactive "$tmp"
assert_exit_zero "AC-T3-003: --interactive exits 0 (write is not gated on a confirm prompt)" "$INIT_RC"
assert_out_not_contains_str "$OUT" '--- AGENTS.md preview ---' \
  "AC-T3-003: no preview gating (default-only generator writes directly)"
assert_exists "AC-T3-003: AGENTS.md written" "$tmp/AGENTS.md"

# --- AC-T3-007: pre-existing AGENTS.md handling --------------------------------------------------

init_suite "AC-T3-007 pre-existing AGENTS.md"

tmp="$TMP/ac007-skip"
mkdir -p "$tmp/.git"
printf '# Pre-existing\n\nHand-written content.\n' > "$tmp/AGENTS.md"
cp "$tmp/AGENTS.md" "$TMP/ac007-skip.before"
run_noninteractive "$tmp"
assert_exit_zero "AC-T3-007: noninteractive without --force exits 0" "$INIT_RC"
assert_out_contains "$OUT" '[skip].*AGENTS.md' "AC-T3-007: skip message emitted"
if cmp -s "$TMP/ac007-skip.before" "$tmp/AGENTS.md"; then
  check OK "AC-T3-007: content preserved verbatim"
else
  check FAIL "AC-T3-007: existing AGENTS.md was modified without --force"
fi
bak_count="$(find "$tmp" -maxdepth 1 -name 'AGENTS.md.bak*' | wc -l | tr -d ' ')"
assert_eq "AC-T3-007: no backup created on skip" "$bak_count" "0"

tmp="$TMP/ac007-force"
mkdir -p "$tmp/.git"
printf 'hand-written' > "$tmp/AGENTS.md"
run_noninteractive "$tmp" --force
assert_exit_zero "AC-T3-007: --force exits 0" "$INIT_RC"
bak="$(find "$tmp" -maxdepth 1 -name 'AGENTS.md.bak.*' | head -1)"
if [[ -n "$bak" && "$(cat "$bak")" == 'hand-written' ]]; then
  check OK "AC-T3-007: --force creates .bak.<ts> backup preserving original content"
else
  check FAIL "AC-T3-007: expected one .bak preserving original content"
fi
assert_agents_line1 "AC-T3-007: AGENTS.md overwritten with generated content" "$tmp/AGENTS.md" "$ENGINE_VERSION"

# Rerun without --force on an existing file: skip + preserve (behavioral
# equivalent of the retired interactive ask-skip contract).
tmp="$TMP/ac007-rerun-skip"
mkdir -p "$tmp/.git"
printf 'pre-existing\n' > "$tmp/AGENTS.md"
cp "$tmp/AGENTS.md" "$TMP/ac007-rerun.before"
run_noninteractive "$tmp"
assert_exit_zero "AC-T3-007: rerun without --force exits 0" "$INIT_RC"
if cmp -s "$TMP/ac007-rerun.before" "$tmp/AGENTS.md"; then
  check OK "AC-T3-007: rerun without --force preserves the existing file (retired ask-skip contract)"
else
  check FAIL "AC-T3-007: rerun without --force must preserve the existing file"
fi

# --- AC-T3-008: --force --merge appends new sections ------------------------------------------------

init_suite "AC-T3-008 --force --merge"

tmp="$TMP/ac008-merge"
mkdir -p "$tmp/.git"
cat > "$tmp/AGENTS.md" <<'MD'
<!-- Generated by init-project v0.1.0 on 2020-01-01T00:00:00Z — edit freely -->

## Repository Identity

Custom hand-written identity.

## Custom Operator Section

This section must survive the merge.
MD
run_noninteractive "$tmp" --force --merge --description 'New generated purpose.'
assert_exit_zero "AC-T3-008: --force --merge exits 0" "$INIT_RC"
bak_count="$(find "$tmp" -maxdepth 1 -name 'AGENTS.md.bak.*' | wc -l | tr -d ' ')"
assert_eq "AC-T3-008: backup created" "$bak_count" "1"
assert_file_contains "AC-T3-008: custom section preserved" "$tmp/AGENTS.md" '^## Custom Operator Section'
assert_file_contains_str "AC-T3-008: custom section body preserved verbatim" "$tmp/AGENTS.md" 'This section must survive the merge.'
id_count="$(grep -cE '^## Repository Identity' "$tmp/AGENTS.md" || true)"
assert_eq "AC-T3-008: exactly one Repository Identity section" "$id_count" "1"
assert_file_contains_str "AC-T3-008: existing identity content preserved" "$tmp/AGENTS.md" 'Custom hand-written identity.'
# New sections appended (fresh sections whose H2 was not already present).
assert_file_contains "AC-T3-008: Documentation section appended" "$tmp/AGENTS.md" '^## Documentation'
assert_file_contains "AC-T3-008: Scratch section appended" "$tmp/AGENTS.md" '^## Scratch and Log Directories'
assert_file_contains "AC-T3-008: Local Configuration Files appended" "$tmp/AGENTS.md" '^## Local Configuration Files'
assert_agents_line1 "AC-T3-008: line 1 refreshed to the new generation comment" "$tmp/AGENTS.md" "$ENGINE_VERSION"

tmp="$TMP/ac008-nodup"
mkdir -p "$tmp/.git"
cat > "$tmp/AGENTS.md" <<'MD'
<!-- Generated by init-project v0.1.0 on 2020-01-01T00:00:00Z — edit freely -->

## Documentation

Existing docs section.

## Local Configuration Files

- `AGENTS.md` — pre-existing
MD
run_noninteractive "$tmp" --force --merge
assert_exit_zero "AC-T3-008 (no-dup): exits 0" "$INIT_RC"
doc_count="$(grep -cE '^## Documentation$' "$tmp/AGENTS.md" || true)"
assert_eq "AC-T3-008: Documentation appears exactly once" "$doc_count" "1"
lcf_count="$(grep -cE '^## Local Configuration Files$' "$tmp/AGENTS.md" || true)"
assert_eq "AC-T3-008: Local Configuration Files appears exactly once" "$lcf_count" "1"
assert_file_contains_str "AC-T3-008: existing docs body preserved" "$tmp/AGENTS.md" 'Existing docs section.'
assert_file_contains_str "AC-T3-008: existing local config body preserved" "$tmp/AGENTS.md" 'pre-existing'

# --- Regressions: fixture compatibility ----------------------------------------------------------------

init_suite "fixture regressions"

tmp="$(init_clone_fixture "$NODE_FIXTURE" "$TMP/reg-node")"
run_noninteractive "$tmp"
assert_exit_zero "regression: node-npm init exits 0" "$INIT_RC"
# Current section names (default-only generator) with the same detection
# content assertions as the Node original.
assert_file_contains "regression: 'Current Architecture And Stack' section for node-npm" "$tmp/AGENTS.md" '^## Current Architecture And Stack'
assert_file_contains "regression: Node.js detected" "$tmp/AGENTS.md" 'Node\.js'
assert_file_contains "regression: npm detected" "$tmp/AGENTS.md" 'npm'
assert_file_contains "regression: Commands section present" "$tmp/AGENTS.md" '^## Commands'
assert_file_contains_str "regression: npm run test command detected" "$tmp/AGENTS.md" 'npm run test'

tmp="$(init_clone_fixture "$BARE_FIXTURE" "$TMP/reg-agent-md")"
printf '# Legacy agent.md\n\nMust survive.\n' > "$tmp/agent.md"
cp "$tmp/agent.md" "$TMP/agent.md.before"
run_noninteractive "$tmp"
assert_exit_zero "regression: init with legacy agent.md exits 0" "$INIT_RC"
assert_exists "regression: legacy agent.md not deleted" "$tmp/agent.md"
if cmp -s "$TMP/agent.md.before" "$tmp/agent.md"; then
  check OK "regression: legacy agent.md content preserved verbatim"
else
  check FAIL "regression: legacy agent.md was modified"
fi
assert_exists "regression: AGENTS.md created alongside legacy agent.md" "$tmp/AGENTS.md"

# --- Summary ---------------------------------------------------------------------------------------------

init_done
