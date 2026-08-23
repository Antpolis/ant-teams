#!/usr/bin/env node
'use strict';

/*
 * tests/test_gh_project_helper_mutator_output.js — curated mutator output
 * contract (SPEC-003 follow-up #45, founder standard, 2026-08).
 *
 * Founder feedback (2026-08-23): helper commands must not merely call gh;
 * they must return useful structured results. #44 locked the board
 * commands; this suite locks the same mutate -> verify -> curated-JSON
 * contract for every remaining mutator except the two comment commands
 * (their URL permalink output IS the useful result):
 *
 *   MOC-1  issue-edit mutates, re-reads, prints {number,title,state,url}
 *          where title/state are the POST-EDIT values — proof the output
 *          is a verification read, not an echo of the request
 *   MOC-2  issue-close prints the post-close state from the re-read
 *   MOC-3  issue-create reuses the mutation URL response: curated
 *          {number,title,state,url} with exactly ONE gh call (no re-read)
 *   MOC-4  pr-create reuses the mutation URL response the same way
 *   MOC-5  pr-close prints the post-close state from the re-read
 *   MOC-6  pr-merge prints the post-merge (MERGED) state from the re-read
 *   MOC-7  workflow-run prints {workflow,repo,status:"dispatched"} with
 *          exactly ONE gh call — no invented run read after dispatch
 *   MOC-8  release-create re-reads and prints the curated release-view
 *          shape (name/draft/prerelease are not derivable from the URL)
 *   MOC-9  release-edit prints the POST-EDIT name from the re-read
 *   MOC-10 release-delete prints {tagName,url,deleted:true} with exactly
 *          ONE gh call — a deleted release is never re-read
 *   MOC-11 issue-comment / pr-comment output stays the URL permalink
 *          pass-through (unchanged contract)
 *   MOC-12 pr-create falls back to the raw response + warning when the
 *          number cannot be parsed (a succeeded mutation never fails)
 *   MOC-13 a failed mutation propagates gh's failure; no curated output
 *
 * The fake gh is stateful (the #44 board-output pattern extended): it
 * stores issues/PRs/releases as JSON fixtures on disk and applies every
 * mutation to them, so the helper's post-mutation re-reads observably
 * differ from the pre-mutation state.
 *
 * The helper under test is the canonical engine in templates/opencode/
 * (the repo-local .opencode/ skills mirror is not tracked since the
 * templates/opencode restructure); tests never depend on a generated or
 * globally installed mirror. No external npm dependencies — Node built-ins
 * only. No network access.
 */

const { spawnSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const assert = require('assert');

const REPO_ROOT = path.resolve(__dirname, '..');
const HELPER = path.join(
  REPO_ROOT,
  'templates/opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh'
);

let passed = 0;
let failed = 0;

function check(name, fn) {
  try {
    fn();
    passed += 1;
    console.log(`ok   - ${name}`);
  } catch (err) {
    failed += 1;
    console.error(`FAIL - ${name}\n      ${err.message}`);
  }
}

const ENV_REPO = 'env-owner/env-repo';

// Stateful fake gh. Every invocation is logged as one CALL line of [arg]
// groups. Issues, PRs, and releases live as JSON fixtures under <bin>/fix;
// mutations rewrite them, so the helper's verification re-reads return the
// simulated post-mutation GitHub state. Real-gh state enums are used
// (OPEN/CLOSED/MERGED).
function setup(prefix) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), `${prefix}-`));
  const docs = path.join(tmp, 'docs');
  fs.mkdirSync(docs, { recursive: true });
  fs.writeFileSync(
    path.join(tmp, '.github-project.env'),
    [
      `export ANT_TEAM_GITHUB_REPO='${ENV_REPO}'`,
      `export ANT_TEAM_DOCS_PROJECT_PATH='${docs}'`,
    ].join('\n') + '\n'
  );

  const bin = path.join(tmp, 'bin');
  fs.mkdirSync(bin);
  const ghLog = path.join(bin, 'gh-calls.log');
  const fix = path.join(bin, 'fix');
  fs.mkdirSync(fix);

  fs.writeFileSync(
    path.join(bin, 'gh'),
    [
      '#!/usr/bin/env bash',
      'BIN="$(cd "$(dirname "$0")" && pwd)"',
      'LOG="$BIN/gh-calls.log"',
      'FIX="$BIN/fix"',
      'log() { printf \'CALL:\' >> "$LOG"; for a in "$@"; do printf \' [%s]\' "$(printf \'%s\' "$a" | tr \'\\n\' \' \')" >> "$LOG"; done; printf \'\\n\' >> "$LOG"; }',
      'log "$@"',
      'now() { date -u +%Y-%m-%dT%H:%M:%SZ; }',
      // flagof FLAG — echo the value following the first FLAG occurrence
      'flagof() { local f="$1"; shift; local i; for i in "$@"; do if [[ "$prev" == "$f" ]]; then printf \'%s\' "$i"; return 0; fi; prev="$i"; done; return 0; }',
      'prev=""',
      'case "$1 $2" in',
      '  "issue create")',
      '    title="$(flagof --title "$@")"',
      '    n=$(( $(cat "$FIX/next-issue" 2>/dev/null || printf 100) + 1 ))',
      '    printf \'%s\\n\' "$n" > "$FIX/next-issue"',
      '    url="https://github.com/env-owner/env-repo/issues/$n"',
      '    jq -n --argjson number "$n" --arg title "$title" --arg url "$url" --arg updatedAt "$(now)" \\',
      '      \'{number:$number,title:$title,body:"",state:"OPEN",labels:[],assignees:[],node_id:"I_shouldNeverLeak",url:$url,updatedAt:$updatedAt}\' > "$FIX/issue-$n.json"',
      '    printf \'%s\\n\' "$url"',
      '    ;;',
      '  "issue view")',
      '    f="$FIX/issue-$3.json"',
      '    if [[ -f "$f" ]]; then cat "$f"; exit 0; fi',
      '    echo "no issue #$3" >&2; exit 1',
      '    ;;',
      '  "issue edit")',
      '    f="$FIX/issue-$3.json"',
      '    if [[ ! -f "$f" ]]; then echo "no issue #$3" >&2; exit 1; fi',
      '    title="$(flagof --title "$@")"',
      '    jq --arg title "$title" --arg updatedAt "$(now)" \'if $title != "" then .title=$title else . end | .updatedAt=$updatedAt\' "$f" > "$f.tmp" && mv "$f.tmp" "$f"',
      '    printf \'https://github.com/env-owner/env-repo/issues/%s\\n\' "$3"',
      '    ;;',
      '  "issue close")',
      '    f="$FIX/issue-$3.json"',
      '    if [[ ! -f "$f" ]]; then echo "no issue #$3" >&2; exit 1; fi',
      '    jq --arg updatedAt "$(now)" \'.state="CLOSED"|.updatedAt=$updatedAt\' "$f" > "$f.tmp" && mv "$f.tmp" "$f"',
      '    printf \'https://github.com/env-owner/env-repo/issues/%s\\n\' "$3"',
      '    ;;',
      '  "issue comment")',
      '    printf \'https://github.com/env-owner/env-repo/issues/%s#issuecomment-777\\n\' "$3"',
      '    ;;',
      '  "pr create")',
      '    if [[ -f "$FIX/pr-create-raw" ]]; then cat "$FIX/pr-create-raw"; exit 0; fi',
      '    title="$(flagof --title "$@")"',
      '    n=$(( $(cat "$FIX/next-pr" 2>/dev/null || printf 200) + 1 ))',
      '    printf \'%s\\n\' "$n" > "$FIX/next-pr"',
      '    url="https://github.com/env-owner/env-repo/pull/$n"',
      '    jq -n --argjson number "$n" --arg title "$title" --arg url "$url" \\',
      '      \'{number:$number,title:$title,state:"OPEN",node_id:"PR_shouldNeverLeak",url:$url}\' > "$FIX/pr-$n.json"',
      '    printf \'%s\\n\' "$url"',
      '    ;;',
      '  "pr view")',
      '    f="$FIX/pr-$3.json"',
      '    if [[ -f "$f" ]]; then cat "$f"; exit 0; fi',
      '    echo "no pr #$3" >&2; exit 1',
      '    ;;',
      '  "pr close")',
      '    f="$FIX/pr-$3.json"',
      '    if [[ ! -f "$f" ]]; then echo "no pr #$3" >&2; exit 1; fi',
      '    jq \'.state="CLOSED"\' "$f" > "$f.tmp" && mv "$f.tmp" "$f"',
      '    printf \'✓ Closed pull request #%s\\n\' "$3"',
      '    ;;',
      '  "pr merge")',
      '    f="$FIX/pr-$3.json"',
      '    if [[ ! -f "$f" ]]; then echo "no pr #$3" >&2; exit 1; fi',
      '    jq \'.state="MERGED"\' "$f" > "$f.tmp" && mv "$f.tmp" "$f"',
      '    printf \'✓ Merged pull request #%s\\n\' "$3"',
      '    ;;',
      '  "pr comment")',
      '    printf \'https://github.com/env-owner/env-repo/pull/%s#issuecomment-888\\n\' "$3"',
      '    ;;',
      '  "release create")',
      '    tag="$3"; name="$(flagof --title "$@")"',
      '    [[ -z "$name" ]] && name="$tag"',
      '    url="https://github.com/env-owner/env-repo/releases/tag/$tag"',
      '    jq -n --arg name "$name" --arg tagName "$tag" --arg url "$url" --arg publishedAt "$(now)" \\',
      '      \'{name:$name,tagName:$tagName,targetCommitish:"master",isDraft:false,isPrerelease:false,createdAt:$publishedAt,publishedAt:$publishedAt,author:{login:"chrissim"},body:"",url:$url,node_id:"R_shouldNeverLeak"}\' > "$FIX/rel-$tag.json"',
      '    printf \'%s\\n\' "$url"',
      '    ;;',
      '  "release view")',
      '    f="$FIX/rel-$3.json"',
      '    if [[ -f "$f" ]]; then cat "$f"; exit 0; fi',
      '    echo "release $3 not found" >&2; exit 1',
      '    ;;',
      '  "release edit")',
      '    f="$FIX/rel-$3.json"',
      '    if [[ ! -f "$f" ]]; then echo "release $3 not found" >&2; exit 1; fi',
      '    name="$(flagof --title "$@")"',
      '    jq --arg name "$name" \'if $name != "" then .name=$name else . end\' "$f" > "$f.tmp" && mv "$f.tmp" "$f"',
      '    printf \'https://github.com/env-owner/env-repo/releases/tag/%s\\n\' "$3"',
      '    ;;',
      '  "release delete")',
      '    f="$FIX/rel-$3.json"',
      '    if [[ ! -f "$f" ]]; then echo "release $3 not found" >&2; exit 1; fi',
      '    rm -f "$f"',
      '    printf \'✓ Deleted release %s\\n\' "$3"',
      '    ;;',
      '  "workflow run")',
      '    exit 0',
      '    ;;',
      '  *)',
      '    echo "unexpected gh invocation: $*" >&2; exit 1',
      '    ;;',
      'esac',
    ].join('\n')
  );
  fs.chmodSync(path.join(bin, 'gh'), 0o755);

  return {
    tmp,
    docs,
    bin,
    ghLog,
    fix: (name) => path.join(fix, name),
  };
}

function runHelper(ctx, args) {
  return spawnSync('bash', [HELPER, ...args], {
    encoding: 'utf8',
    cwd: ctx.tmp,
    env: {
      PATH: `${ctx.bin}:${process.env.PATH}`,
      HOME: process.env.HOME,
    },
  });
}

function calls(ctx) {
  if (!fs.existsSync(ctx.ghLog)) return [];
  return fs
    .readFileSync(ctx.ghLog, 'utf8')
    .split('\n')
    .filter((l) => l.startsWith('CALL:'))
    .map((l) => {
      const args = [];
      const re = /\[([^\]]*)\]/g;
      let m;
      while ((m = re.exec(l)) !== null) args.push(m[1]);
      return args;
    });
}

const FOUR_FIELDS = ['number', 'state', 'title', 'url'];

// --- MOC-1: issue-edit post-edit verification -----------------------------------

check('MOC-1: issue-edit prints the POST-EDIT values from the verification re-read', () => {
  const ctx = setup('moc1');
  let r = runHelper(ctx, ['issue-create', 'Original title']);
  assert.strictEqual(r.status, 0, `create exit ${r.status}\nstderr:\n${r.stderr}`);
  fs.writeFileSync(ctx.ghLog, ''); // count only the edit conversation

  r = runHelper(ctx, ['issue-edit', '101', '--title', 'Revised title']);
  assert.strictEqual(r.status, 0, `edit exit ${r.status}\nstderr:\n${r.stderr}`);
  const all = calls(ctx);
  assert.strictEqual(all.length, 2, 'mutation + verification re-read');
  assert.deepStrictEqual(all[0].slice(0, 3), ['issue', 'edit', '101']);
  assert.deepStrictEqual(all[1].slice(0, 3), ['issue', 'view', '101']);
  const out = JSON.parse(r.stdout);
  assert.deepStrictEqual(Object.keys(out).sort(), FOUR_FIELDS, 'exact four-field contract');
  assert.strictEqual(out.title, 'Revised title', 'title is the post-edit value, not the pre-edit "Original title"');
  assert.strictEqual(out.state, 'OPEN');
  assert.strictEqual(out.url, 'https://github.com/env-owner/env-repo/issues/101');
  assert.strictEqual(out.node_id, undefined, 'raw fixture fields must not leak');
});

// --- MOC-2: issue-close post-close verification ---------------------------------

check('MOC-2: issue-close prints the post-close state from the verification re-read', () => {
  const ctx = setup('moc2');
  const r0 = runHelper(ctx, ['issue-create', 'Close me']);
  assert.strictEqual(r0.status, 0, `create exit ${r0.status}\nstderr:\n${r0.stderr}`);
  fs.writeFileSync(ctx.ghLog, '');

  const r = runHelper(ctx, ['issue-close', '101', '--comment', 'Completed and validated.']);
  assert.strictEqual(r.status, 0, `close exit ${r.status}\nstderr:\n${r.stderr}`);
  const all = calls(ctx);
  assert.strictEqual(all.length, 2, 'mutation + verification re-read');
  assert.deepStrictEqual(all[0].slice(0, 3), ['issue', 'close', '101']);
  assert.ok(all[0].includes('--comment'), 'close flags pass through');
  const out = JSON.parse(r.stdout);
  assert.deepStrictEqual(Object.keys(out).sort(), FOUR_FIELDS, 'exact four-field contract');
  assert.strictEqual(out.state, 'CLOSED', 'post-close state verified by the re-read');
  assert.strictEqual(out.number, 101);
});

// --- MOC-3: issue-create reuses the URL response ---------------------------------

check('MOC-3: issue-create curates from the mutation URL response with no re-read', () => {
  const ctx = setup('moc3');
  const r = runHelper(ctx, ['issue-create', 'Curated create contract']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const all = calls(ctx);
  assert.strictEqual(all.length, 1, 'exactly one gh call — URL response reused');
  assert.deepStrictEqual(all[0].slice(0, 2), ['issue', 'create']);
  const out = JSON.parse(r.stdout);
  assert.deepStrictEqual(Object.keys(out).sort(), FOUR_FIELDS, 'exact four-field contract');
  assert.strictEqual(out.number, 101, 'number parsed from the URL response');
  assert.strictEqual(out.title, 'Curated create contract');
  assert.strictEqual(out.state, 'OPEN', 'freshly created issue is deterministically OPEN');
  assert.strictEqual(out.url, 'https://github.com/env-owner/env-repo/issues/101');
});

// --- MOC-4: pr-create reuses the URL response -----------------------------------

check('MOC-4: pr-create curates from the mutation URL response with no re-read', () => {
  const ctx = setup('moc4');
  const r = runHelper(ctx, ['pr-create', 'ISSUE-45: mutator contract', '--base', 'master', '--head', 'feat/issue-45']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const all = calls(ctx);
  assert.strictEqual(all.length, 1, 'exactly one gh call — URL response reused');
  assert.deepStrictEqual(all[0].slice(0, 2), ['pr', 'create']);
  const out = JSON.parse(r.stdout);
  assert.deepStrictEqual(Object.keys(out).sort(), FOUR_FIELDS, 'exact four-field contract');
  assert.strictEqual(out.number, 201, 'number parsed from the PR URL response');
  assert.strictEqual(out.title, 'ISSUE-45: mutator contract');
  assert.strictEqual(out.state, 'OPEN', 'freshly created PR is deterministically OPEN');
  assert.strictEqual(out.url, 'https://github.com/env-owner/env-repo/pull/201');
});

// --- MOC-5: pr-close post-close verification ------------------------------------

check('MOC-5: pr-close prints the post-close state from the verification re-read', () => {
  const ctx = setup('moc5');
  runHelper(ctx, ['pr-create', 'PR to close']);
  fs.writeFileSync(ctx.ghLog, '');

  const r = runHelper(ctx, ['pr-close', '201', '--comment', 'Superseded.']);
  assert.strictEqual(r.status, 0, `close exit ${r.status}\nstderr:\n${r.stderr}`);
  const all = calls(ctx);
  assert.strictEqual(all.length, 2, 'mutation + verification re-read');
  assert.deepStrictEqual(all[0].slice(0, 3), ['pr', 'close', '201']);
  assert.deepStrictEqual(
    all[1].slice(0, 5),
    ['pr', 'view', '201', '--json', 'number,title,state,url'],
    're-read requests exactly the curated fields'
  );
  const out = JSON.parse(r.stdout);
  assert.deepStrictEqual(Object.keys(out).sort(), FOUR_FIELDS, 'exact four-field contract');
  assert.strictEqual(out.state, 'CLOSED', 'post-close state verified by the re-read');
});

// --- MOC-6: pr-merge post-merge verification ------------------------------------

check('MOC-6: pr-merge prints the post-merge MERGED state from the verification re-read', () => {
  const ctx = setup('moc6');
  runHelper(ctx, ['pr-create', 'PR to merge']);
  fs.writeFileSync(ctx.ghLog, '');

  const r = runHelper(ctx, ['pr-merge', '201', '--squash']);
  assert.strictEqual(r.status, 0, `merge exit ${r.status}\nstderr:\n${r.stderr}`);
  const all = calls(ctx);
  assert.strictEqual(all.length, 2, 'mutation + verification re-read');
  assert.deepStrictEqual(all[0].slice(0, 3), ['pr', 'merge', '201']);
  assert.ok(all[0].includes('--squash'), 'merge flags pass through');
  assert.ok(!all[0].includes('--admin'), 'never inject --admin');
  const out = JSON.parse(r.stdout);
  assert.deepStrictEqual(Object.keys(out).sort(), FOUR_FIELDS, 'exact four-field contract');
  assert.strictEqual(out.state, 'MERGED', 'post-merge state verified by the re-read');
});

// --- MOC-7: workflow-run curated dispatch summary -------------------------------

check('MOC-7: workflow-run prints a curated dispatch summary with no invented run read', () => {
  const ctx = setup('moc7');
  const r = runHelper(ctx, ['workflow-run', 'ci.yml', '--ref', 'feat/issue-45']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const all = calls(ctx);
  assert.strictEqual(all.length, 1, 'exactly one gh call — the dispatch response carries no run id, so no run read follows');
  assert.deepStrictEqual(all[0].slice(0, 3), ['workflow', 'run', 'ci.yml']);
  assert.ok(all[0].includes('--ref'), 'dispatch flags pass through');
  const out = JSON.parse(r.stdout);
  assert.deepStrictEqual(Object.keys(out).sort(), ['repo', 'status', 'workflow'], 'exact dispatch summary shape');
  assert.strictEqual(out.workflow, 'ci.yml');
  assert.strictEqual(out.repo, ENV_REPO);
  assert.strictEqual(out.status, 'dispatched');
});

// --- MOC-8: release-create verification re-read ---------------------------------

check('MOC-8: release-create re-reads and prints the curated release-view shape', () => {
  const ctx = setup('moc8');
  const r = runHelper(ctx, ['release-create', 'v1.2.0', '--title', 'v1.2.0 — ant-teams', '--target', 'master']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const all = calls(ctx);
  assert.strictEqual(all.length, 2, 'mutation + verification re-read');
  assert.deepStrictEqual(all[0].slice(0, 3), ['release', 'create', 'v1.2.0']);
  assert.ok(all[0].includes('--title'), 'create flags pass through');
  assert.deepStrictEqual(all[1].slice(0, 3), ['release', 'view', 'v1.2.0']);
  const out = JSON.parse(r.stdout);
  assert.deepStrictEqual(
    Object.keys(out).sort(),
    [
      'author', 'body', 'createdAt', 'isDraft', 'isPrerelease',
      'name', 'publishedAt', 'tagName', 'targetCommitish', 'url',
    ],
    'release-create output matches the curated release-view shape'
  );
  assert.strictEqual(out.name, 'v1.2.0 — ant-teams', 'name comes from the post-create re-read');
  assert.strictEqual(out.tagName, 'v1.2.0');
  assert.strictEqual(out.isDraft, false);
  assert.strictEqual(out.url, 'https://github.com/env-owner/env-repo/releases/tag/v1.2.0');
  assert.strictEqual(out.node_id, undefined, 'raw fixture fields must not leak');
});

// --- MOC-9: release-edit post-edit verification ---------------------------------

check('MOC-9: release-edit prints the POST-EDIT name from the verification re-read', () => {
  const ctx = setup('moc9');
  runHelper(ctx, ['release-create', 'v1.2.0', '--title', 'Original release name']);
  fs.writeFileSync(ctx.ghLog, '');

  const r = runHelper(ctx, ['release-edit', 'v1.2.0', '--title', 'Revised release name']);
  assert.strictEqual(r.status, 0, `edit exit ${r.status}\nstderr:\n${r.stderr}`);
  const all = calls(ctx);
  assert.strictEqual(all.length, 2, 'mutation + verification re-read');
  assert.deepStrictEqual(all[0].slice(0, 3), ['release', 'edit', 'v1.2.0']);
  const out = JSON.parse(r.stdout);
  assert.strictEqual(out.name, 'Revised release name', 'name is the post-edit value, not the original');
  assert.strictEqual(out.tagName, 'v1.2.0');
});

// --- MOC-10: release-delete curated summary, never re-read ----------------------

check('MOC-10: release-delete prints {tagName,url,deleted:true} with no re-read', () => {
  const ctx = setup('moc10');
  runHelper(ctx, ['release-create', 'v1.2.0']);
  fs.writeFileSync(ctx.ghLog, '');

  const r = runHelper(ctx, ['release-delete', 'v1.2.0', '--cleanup-tag']);
  assert.strictEqual(r.status, 0, `delete exit ${r.status}\nstderr:\n${r.stderr}`);
  const all = calls(ctx);
  assert.strictEqual(all.length, 1, 'exactly one gh call — the deleted release cannot be re-read');
  assert.deepStrictEqual(all[0].slice(0, 3), ['release', 'delete', 'v1.2.0']);
  assert.ok(all[0].includes('--cleanup-tag'), 'caller flags pass through');
  assert.ok(!all[0].includes('--yes') && !all[0].includes('-y'), 'never default the --yes auto-confirm');
  const out = JSON.parse(r.stdout);
  assert.deepStrictEqual(Object.keys(out).sort(), ['deleted', 'tagName', 'url'], 'exact deletion summary shape');
  assert.strictEqual(out.tagName, 'v1.2.0');
  assert.strictEqual(out.url, `https://github.com/${ENV_REPO}/releases/tag/v1.2.0`);
  assert.strictEqual(out.deleted, true);
});

// --- MOC-11: comment commands stay URL-permalink pass-throughs ------------------

check('MOC-11: issue-comment / pr-comment output stays the URL permalink', () => {
  const ctx = setup('moc11');
  let r = runHelper(ctx, ['issue-comment', '101', '--body', 'Final decision: approved.']);
  assert.strictEqual(r.status, 0, `issue-comment exit ${r.status}\nstderr:\n${r.stderr}`);
  assert.strictEqual(calls(ctx).length, 1, 'one gh call, no re-read');
  assert.strictEqual(
    r.stdout.trim(),
    'https://github.com/env-owner/env-repo/issues/101#issuecomment-777',
    'the comment permalink IS the useful result — output unchanged'
  );

  r = runHelper(ctx, ['pr-comment', '201', '--body', 'Code review result: no blockers.']);
  assert.strictEqual(r.status, 0, `pr-comment exit ${r.status}\nstderr:\n${r.stderr}`);
  assert.strictEqual(calls(ctx).length, 2, 'one gh call per comment, no re-read');
  assert.strictEqual(
    r.stdout.trim(),
    'https://github.com/env-owner/env-repo/pull/201#issuecomment-888',
    'the comment permalink IS the useful result — output unchanged'
  );
});

// --- MOC-12: pr-create unparseable-response fallback ----------------------------

check('MOC-12: pr-create falls back to the raw response when the number is unparseable', () => {
  const ctx = setup('moc12');
  fs.writeFileSync(ctx.fix('pr-create-raw'), '✓ Created pull request (non-URL output)\n');
  const r = runHelper(ctx, ['pr-create', 'Odd PR output']);
  assert.strictEqual(r.status, 0, `a succeeded mutation must not fail (got ${r.status})\nstderr:\n${r.stderr}`);
  assert.strictEqual(calls(ctx).length, 1, 'no invented recovery read');
  assert.ok(/could not be parsed/.test(r.stderr), 'stderr warns about the unparseable response');
  assert.strictEqual(r.stdout.trim(), '✓ Created pull request (non-URL output)', 'raw response passes through');
});

// --- MOC-13: failed mutation propagates -----------------------------------------

check('MOC-13: a failed mutation propagates gh failure with no curated output', () => {
  const ctx = setup('moc13');
  const r = runHelper(ctx, ['pr-merge', '999', '--squash']);
  assert.notStrictEqual(r.status, 0, 'merging a missing PR must fail');
  assert.strictEqual(calls(ctx).length, 1, 'only the mutation was attempted');
  assert.ok(!r.stdout.trim(), 'no curated JSON on failure');
  assert.ok(/no pr #999/.test(r.stderr), "gh's error reaches the caller");

  const r2 = runHelper(ctx, ['issue-edit', '999', '--title', 'X']);
  assert.notStrictEqual(r2.status, 0, 'editing a missing issue must fail');
  assert.ok(!r2.stdout.trim(), 'no curated JSON on failure');
});

// --- summary ---------------------------------------------------------------------

console.log(`\n${passed} passed, ${failed} failed (curated mutator output contract)`);
if (failed > 0) process.exit(1);
