#!/usr/bin/env node
'use strict';

/*
 * tests/test_gh_project_helper_dual_record.js — local-first dual-record sync
 * contract tests for gh_project_helper.sh (SPEC-003-T7, issue #37, 2026-08).
 *
 * Runs the canonical engine in templates/opencode/ against an isolated
 * temporary ANT_TEAM_DOCS_PROJECT_PATH and a stateful fake gh that can be
 * flipped between online and offline (no-network) modes. Locks the
 * local-first contract of FR-10..FR-19 / AC-09..AC-13:
 *
 *   DRC-1  usage lists issue-sync / milestone-sync; positionals enforced
 *   DRC-2  missing or invalid ANT_TEAM_DOCS_PROJECT_PATH fails before gh
 *   DRC-3  online issue-create writes the local record FIRST, then gh;
 *          deterministic ISSUE-0NN-<slug>.md mapping + frontmatter backfill
 *   DRC-4  issue-edit merges execution-state while preserving "Local Notes"
 *          and local-only frontmatter (online)
 *   DRC-5  issue-close sets local state closed, preserves content (online)
 *   DRC-6  offline (no-network) issue-create keeps the local write with
 *          provisional github_number, pending_sync: true, exit 3, and a
 *          recovery warning naming issue-sync
 *   DRC-7  issue-sync backfills the offline record (creates on GitHub,
 *          renames to the canonical file, clears pending) and is idempotent
 *          on re-run (no duplicate mutations)
 *   DRC-8  issue-sync detects a conflict (both sides changed since the last
 *          sync): durable content resolves toward local (pushed),
 *          execution-state toward GitHub (pulled), reported on stderr
 *   DRC-9  online milestone-create writes spec/SPEC-0NN-*.md first and
 *          backfills github_milestone; curated stdout stays intact
 *   DRC-10 offline milestone-close queues pending; milestone-sync pushes
 *          state=closed exactly once; re-run is a no-op
 *   DRC-11 offline reads fall back to the local record and never write it;
 *          issue-comment and board commands stay GitHub-only
 *   DRC-12 malformed titles (traversal, control chars, leading dash) are
 *          rejected before gh and before any file write
 *   DRC-13 all writes stay confined to {issue,spec}/ under the base and no
 *          temp files leak
 *
 * The helper under test is the canonical engine in templates/opencode/
 * (never a generated or globally installed mirror). No npm dependencies,
 * no network: the fake gh simulates GitHub entirely on the local disk.
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

// Stateful fake gh: every call is logged as one line of [arg] groups; a
// mode file flips between online and offline; a fixtures dir stores the
// simulated GitHub state (issues and milestones as JSON files). On every
// online call it also logs how many local records already exist under the
// docs base (LOCALPROBE) so tests can assert local-first ordering.
const FAKE_GH = [
  '#!/usr/bin/env bash',
  'BIN="$(cd "$(dirname "$0")" && pwd)"',
  'LOG="$BIN/calls.log"',
  'MODE="$(cat "$BIN/mode" 2>/dev/null || printf online)"',
  'log() { printf \'CALL:\' >> "$LOG"; for a in "$@"; do printf \' [%s]\' "$(printf \'%s\' "$a" | tr \'\\n\' \' \')" >> "$LOG"; done; printf \'\\n\' >> "$LOG"; }',
  'now() { date -u +%Y-%m-%dT%H:%M:%SZ; }',
  'log "$@"',
  'base="${ANT_TEAM_DOCS_PROJECT_PATH/#\\~/${HOME:-/root}}"',
  'probe=0',
  'for sub in issue spec; do if [[ -d "$base/$sub" ]]; then probe=$((probe + $(ls -1 "$base/$sub" 2>/dev/null | wc -l))); fi; done',
  'printf \'LOCALPROBE:%s\\n\' "$probe" >> "$LOG"',
  'if [[ "$MODE" == offline ]]; then echo "fake gh: network unavailable" >&2; exit 1; fi',
  'FIX="$BIN/fixtures"; mkdir -p "$FIX"',
  'lbljson() { if [[ $# -eq 0 ]]; then printf \'[]\'; else printf \'%s\\0\' "$@" | jq -Rs \'split("\\u0000")|map(select(length>0))\'; fi }',
  'cmd="$1"; shift',
  'case "$cmd" in',
  '  issue)',
  '    sub="$1"; shift',
  '    case "$sub" in',
  '      create)',
  '        title=""; body=""; labels=(); assignees=(); milestone=""',
  '        while [[ $# -gt 0 ]]; do case "$1" in',
  '          --title) title="$2"; shift 2;;',
  '          --body) body="$2"; shift 2;;',
  '          --label) labels+=("$2"); shift 2;;',
  '          --assignee) assignees+=("$2"); shift 2;;',
  '          --milestone) milestone="$2"; shift 2;;',
  '          *) shift;;',
  '        esac; done',
  '        n=$(( $(cat "$FIX/next-issue" 2>/dev/null || printf 100) + 1 ))',
  '        printf \'%s\\n\' "$n" > "$FIX/next-issue"',
  '        url="https://github.com/env-owner/env-repo/issues/$n"',
  '        jq -n --argjson number "$n" --arg title "$title" --arg body "$body" \\',
  '          --argjson labels "$(lbljson "${labels[@]}")" \\',
  '          --argjson assignees "$(lbljson "${assignees[@]}")" \\',
  '          --arg m "$milestone" --arg url "$url" --arg updatedAt "$(now)" \\',
  '          \'{number:$number,title:$title,body:$body,state:"open",labels:($labels|map({name:.})),assignees:($assignees|map({login:.})),milestone:(if $m=="" then null else {title:$m} end),url:$url,updatedAt:$updatedAt}\' > "$FIX/issue-$n.json"',
  '        printf \'%s\\n\' "$url"',
  '        ;;',
  '      view)',
  '        n="$1"; shift',
  '        if [[ -f "$FIX/issue-$n.json" ]]; then cat "$FIX/issue-$n.json"; exit 0; fi',
  '        echo "no issue #$n" >&2; exit 1',
  '        ;;',
  '      edit)',
  '        n="$1"; shift',
  '        f="$FIX/issue-$n.json"',
  '        if [[ ! -f "$f" ]]; then echo "no issue #$n" >&2; exit 1; fi',
  '        title=""; body=""',
  '        while [[ $# -gt 0 ]]; do case "$1" in',
  '          --title) title="$2"; shift 2;;',
  '          --body) body="$2"; shift 2;;',
  '          *) shift;;',
  '        esac; done',
  '        jq --arg title "$title" --arg body "$body" --arg updatedAt "$(now)" \\',
  '          \'if $title != "" then .title=$title else . end | if $body != "" then .body=$body else . end | .updatedAt=$updatedAt\' "$f" > "$f.tmp" && mv "$f.tmp" "$f"',
  '        printf \'https://github.com/env-owner/env-repo/issues/%s\\n\' "$n"',
  '        ;;',
  '      close)',
  '        n="$1"; shift',
  '        f="$FIX/issue-$n.json"',
  '        if [[ ! -f "$f" ]]; then echo "no issue #$n" >&2; exit 1; fi',
  '        jq --arg updatedAt "$(now)" \'.state="closed"|.updatedAt=$updatedAt\' "$f" > "$f.tmp" && mv "$f.tmp" "$f"',
  '        printf \'https://github.com/env-owner/env-repo/issues/%s\\n\' "$n"',
  '        ;;',
  '      *) printf \'{}\\n\';;',
  '    esac',
  '    ;;',
  '  api)',
  '    url=""; method=""; fields=()',
  '    while [[ $# -gt 0 ]]; do case "$1" in',
  '      -X) method="$2"; shift 2;;',
  '      -f) fields+=("$2"); shift 2;;',
  '      repos/*) url="$1"; shift;;',
  '      *) shift;;',
  '    esac; done',
  '    if [[ "$url" =~ ^repos/[^/]+/[^/]+/milestones/([0-9]+)$ ]]; then',
  '      n="${BASH_REMATCH[1]}"; f="$FIX/ms-$n.json"',
  '      if [[ "$method" == PATCH ]]; then',
  '        if [[ ! -f "$f" ]]; then echo "no milestone #$n" >&2; exit 1; fi',
  '        for fld in "${fields[@]}"; do case "$fld" in',
  '          title=*) jq --arg v "${fld#title=}" \'.title=$v\' "$f" > "$f.tmp" && mv "$f.tmp" "$f";;',
  '          description=*) jq --arg v "${fld#description=}" \'.description=$v\' "$f" > "$f.tmp" && mv "$f.tmp" "$f";;',
  '          state=*) jq --arg v "${fld#state=}" \'.state=$v\' "$f" > "$f.tmp" && mv "$f.tmp" "$f";;',
  '          due_on=*) jq --arg v "${fld#due_on=}" \'.due_on=(if $v=="" then null else $v end)\' "$f" > "$f.tmp" && mv "$f.tmp" "$f";;',
  '        esac; done',
  '        jq --arg updatedAt "$(now)" \'.updated_at=$updatedAt\' "$f" > "$f.tmp" && mv "$f.tmp" "$f"',
  '        cat "$f"; exit 0',
  '      fi',
  '      if [[ -f "$f" ]]; then cat "$f"; exit 0; fi',
  '      echo "no milestone #$n" >&2; exit 1',
  '    fi',
  '    if [[ "$url" == *milestones* ]]; then',
  '      if [[ "${#fields[@]}" -gt 0 ]]; then',
  '        title=""; desc=""',
  '        for fld in "${fields[@]}"; do case "$fld" in',
  '          title=*) title="${fld#title=}";;',
  '          description=*) desc="${fld#description=}";;',
  '        esac; done',
  '        n=$(( $(cat "$FIX/next-ms" 2>/dev/null || printf 0) + 1 ))',
  '        printf \'%s\\n\' "$n" > "$FIX/next-ms"',
  '        jq -n --argjson number "$n" --arg title "$title" --arg description "$desc" \\',
  '          --arg url "https://github.com/env-owner/env-repo/milestone/$n" --arg updatedAt "$(now)" \\',
  '          \'{number:$number,title:$title,description:$description,state:"open",open_issues:0,closed_issues:0,due_on:null,html_url:$url,updated_at:$updatedAt}\' > "$FIX/ms-$n.json"',
  '        cat "$FIX/ms-$n.json"; exit 0',
  '      fi',
  '      jq -s \'.\' "$FIX"/ms-*.json 2>/dev/null || printf \'[]\\n\'; exit 0',
  '    fi',
  '    printf \'{}\\n\'',
  '    ;;',
  '  *) printf \'{}\\n\';;',
  'esac',
].join('\n');

function setup(prefix, envLines) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), `${prefix}-`));
  const docs = path.join(tmp, 'docs');
  fs.mkdirSync(docs, { recursive: true });
  const bin = path.join(tmp, 'bin');
  fs.mkdirSync(bin);
  fs.writeFileSync(path.join(bin, 'gh'), FAKE_GH);
  fs.chmodSync(path.join(bin, 'gh'), 0o755);
  fs.writeFileSync(path.join(bin, 'mode'), 'online\n');
  const lines =
    envLines === null
      ? []
      : envLines || [`export ANT_TEAM_GITHUB_REPO='${ENV_REPO}'`, `export ANT_TEAM_DOCS_PROJECT_PATH='${docs}'`];
  if (lines.length > 0) {
    fs.writeFileSync(path.join(tmp, '.github-project.env'), `${lines.join('\n')}\n`);
  }
  return {
    tmp,
    docs,
    bin,
    ghLog: path.join(bin, 'calls.log'),
    setMode: (mode) => fs.writeFileSync(path.join(bin, 'mode'), `${mode}\n`),
    fixture: (name) => path.join(bin, 'fixtures', name),
    fixtureDir: path.join(bin, 'fixtures'),
    readFixture: (name) => JSON.parse(fs.readFileSync(path.join(bin, 'fixtures', name), 'utf8')),
    writeFixture: (name, obj) => {
      fs.mkdirSync(path.join(bin, 'fixtures'), { recursive: true });
      fs.writeFileSync(path.join(bin, 'fixtures', name), `${JSON.stringify(obj, null, 2)}\n`);
    },
  };
}

function runHelper(ctx, args) {
  // ANT_TEAM_DOCS_PROJECT_PATH must come from .github-project.env (the
  // sole config source), never from the process env, so missing-config
  // tests observe the real resolution path.
  return spawnSync('bash', [HELPER, ...args], {
    encoding: 'utf8',
    cwd: ctx.tmp,
    env: {
      PATH: `${ctx.bin}:${process.env.PATH}`,
      HOME: process.env.HOME,
    },
  });
}

// Parse the fake gh log into calls; each call is an args array. Bracketed
// args cannot be asserted (parser limitation shared with the main harness).
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

// Number of local records that existed when the i-th gh call ran.
function probeAt(ctx, index) {
  const lines = fs.readFileSync(ctx.ghLog, 'utf8').split('\n').filter((l) => l.startsWith('LOCALPROBE:'));
  return index < lines.length ? parseInt(lines[index].split(':')[1], 10) : -1;
}

function argIndex(call, flag) {
  return call.indexOf(flag);
}

function recordFiles(ctx, sub) {
  const dir = path.join(ctx.docs, sub);
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir).filter((f) => f.endsWith('.md'));
}

function readRecord(ctx, sub, name) {
  return fs.readFileSync(path.join(ctx.docs, sub, name), 'utf8');
}

// Parse frontmatter of a record into an object (values are JSON scalars).
function fm(record) {
  const m = record.match(/^---\n([\s\S]*?)\n---\n/);
  assert.ok(m, 'record must have frontmatter delimiters');
  const obj = {};
  for (const line of m[1].split('\n')) {
    const kv = line.match(/^([a-z_]+): (.*)$/);
    if (kv) {
      try {
        obj[kv[1]] = JSON.parse(kv[2]);
      } catch {
        obj[kv[1]] = kv[2];
      }
    }
  }
  return obj;
}

function bodyOf(record) {
  const m = record.match(/^---\n[\s\S]*?\n---\n([\s\S]*)$/);
  return m ? m[1] : '';
}

// --- DRC-1: usage + positionals --------------------------------------------------

check('DRC-1: usage lists issue-sync / milestone-sync; positionals enforced', () => {
  const ctx = setup('drc1');
  const usage = runHelper(ctx, []);
  assert.notStrictEqual(usage.status, 0, 'no-args must exit non-zero');
  for (const sub of ['issue-sync', 'milestone-sync']) {
    assert.ok(usage.stdout.includes(sub), `usage must list ${sub}`);
  }
  for (const args of [['issue-sync'], ['milestone-sync']]) {
    const r = runHelper(ctx, args);
    assert.notStrictEqual(r.status, 0, `${args.join(' ')} must fail without its number`);
    assert.deepStrictEqual(calls(ctx).length, 0, 'gh must not be called on a usage error');
  }
});

// --- DRC-2: docs base validation before gh ---------------------------------------

check('DRC-2: missing or invalid ANT_TEAM_DOCS_PROJECT_PATH fails before gh', () => {
  const ctxMissing = setup('drc2a', [`export ANT_TEAM_GITHUB_REPO='${ENV_REPO}'`]);
  for (const args of [
    ['issue-create', 'Valid title'],
    ['issue-edit', '5', '--title', 'X'],
    ['issue-close', '5'],
    ['milestone-create', 'SPEC-X: valid'],
    ['milestone-close', '2'],
    ['issue-sync', '5'],
    ['milestone-sync', '2'],
  ]) {
    const r = runHelper(ctxMissing, args);
    assert.notStrictEqual(r.status, 0, `${args.join(' ')} must fail without a docs base`);
    assert.ok(r.stderr.includes('ANT_TEAM_DOCS_PROJECT_PATH'), 'error must name the env key');
  }
  assert.deepStrictEqual(calls(ctxMissing).length, 0, 'gh must not be called');

  const ctxBad = setup('drc2b', [
    `export ANT_TEAM_GITHUB_REPO='${ENV_REPO}'`,
    "export ANT_TEAM_DOCS_PROJECT_PATH='/nonexistent/docs/path'",
  ]);
  const r = runHelper(ctxBad, ['issue-create', 'Valid title']);
  assert.notStrictEqual(r.status, 0, 'nonexistent docs base must fail');
  assert.ok(/not a directory/.test(r.stderr), 'error must explain the invalid path');
  assert.deepStrictEqual(calls(ctxBad).length, 0, 'gh must not be called');
});

// --- DRC-3: online issue-create is local-first ------------------------------------

check('DRC-3: online issue-create writes the local record first, then gh', () => {
  const ctx = setup('drc3');
  const r = runHelper(ctx, [
    'issue-create', 'SPEC-009: Fix login flow',
    '--body', 'Problem: login breaks.',
    '--label', 'type:bug', '--label', 'role:builder',
    '--assignee', 'agent-b',
  ]);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const all = calls(ctx);
  assert.strictEqual(all.length, 1, 'exactly one gh call');
  assert.deepStrictEqual(all[0].slice(0, 2), ['issue', 'create']);
  assert.strictEqual(probeAt(ctx, 0), 1, 'the local record must exist before gh runs (local-first)');
  const repo = argIndex(all[0], '--repo');
  assert.ok(repo !== -1 && all[0][repo + 1] === ENV_REPO, 'env repo must be sent');
  assert.ok(r.stdout.trim().startsWith('https://github.com/env-owner/env-repo/issues/'), 'gh stdout (issue URL) must pass through');

  // Deterministic mapping: fake gh minted #101
  assert.deepStrictEqual(recordFiles(ctx, 'issue'), ['ISSUE-101-spec-009-fix-login-flow.md']);
  const record = readRecord(ctx, 'issue', 'ISSUE-101-spec-009-fix-login-flow.md');
  const front = fm(record);
  assert.strictEqual(front.github_number, 101, 'github_number backfilled from the created issue');
  assert.strictEqual(front.github_url, 'https://github.com/env-owner/env-repo/issues/101');
  assert.strictEqual(front.title, 'SPEC-009: Fix login flow');
  assert.strictEqual(front.state, 'open');
  assert.deepStrictEqual(front.labels, ['type:bug', 'role:builder']);
  assert.deepStrictEqual(front.assignees, ['agent-b']);
  assert.strictEqual(front.pending_sync, false, 'confirmed online create is not pending');
  assert.ok(typeof front.last_synced_at === 'string' && /^\d{4}-\d{2}-\d{2}T/.test(front.last_synced_at), 'last_synced_at set');
  assert.ok(bodyOf(record).includes('Problem: login breaks.'), 'body written');
});

// --- DRC-4: issue-edit preserves Local Notes and local-only frontmatter -----------

check('DRC-4: issue-edit merges execution-state and preserves Local Notes + local frontmatter', () => {
  const ctx = setup('drc4');
  const r0 = runHelper(ctx, ['issue-create', 'Original title', '--body', 'Original body.']);
  assert.strictEqual(r0.status, 0, `create exit ${r0.status}\nstderr:\n${r0.stderr}`);
  const name = recordFiles(ctx, 'issue')[0];

  // An agent adds local-only content offline (plain text edit, no helper).
  const recordPath = path.join(ctx.docs, 'issue', name);
  const seeded = readRecord(ctx, 'issue', name)
    .replace(/^---\n([\s\S]*?)\n---\n/, (_m, inner) => `---\n${inner}\npriority: high\nowner_role: builder\n---\n`)
    .replace(/$/, '\n## Local Notes\n\n- agent note: keep me across syncs\n');
  fs.writeFileSync(recordPath, seeded);

  const r = runHelper(ctx, ['issue-edit', '101', '--title', 'Revised durable title', '--body', 'Revised durable body.', '--add-label', 'blocked']);
  assert.strictEqual(r.status, 0, `edit exit ${r.status}\nstderr:\n${r.stderr}`);
  const record = readRecord(ctx, 'issue', name);
  const front = fm(record);
  assert.strictEqual(front.github_number, 101, 'number preserved');
  assert.strictEqual(front.title, 'Revised durable title', 'title merged');
  assert.deepStrictEqual(front.labels, ['blocked'], 'labels merged');
  assert.strictEqual(front.pending_sync, false, 'online edit clears pending');
  assert.strictEqual(front.priority, 'high', 'local-only frontmatter preserved');
  assert.strictEqual(front.owner_role, 'builder', 'local-only frontmatter preserved (2)');
  assert.ok(bodyOf(record).includes('Revised durable body.'), 'body replaced');
  assert.ok(record.includes('## Local Notes'), 'Local Notes heading preserved');
  assert.ok(record.includes('- agent note: keep me across syncs'), 'Local Notes content preserved');

  const editCalls = calls(ctx).slice(1);
  assert.strictEqual(editCalls.length, 1, 'exactly one gh call for the edit');
  assert.deepStrictEqual(editCalls[0].slice(0, 3), ['issue', 'edit', '101'], 'edit targets the created issue number');
  const t = argIndex(editCalls[0], '--title');
  assert.ok(t !== -1 && editCalls[0][t + 1] === 'Revised durable title', 'edit flags pass through');
});

// --- DRC-5: issue-close sets local closed state -----------------------------------

check('DRC-5: issue-close sets local state closed and preserves content', () => {
  const ctx = setup('drc5');
  const r0 = runHelper(ctx, ['issue-create', 'Close me', '--body', 'Body to keep.']);
  assert.strictEqual(r0.status, 0, `create exit ${r0.status}\nstderr:\n${r0.stderr}`);
  const name = recordFiles(ctx, 'issue')[0];
  const r = runHelper(ctx, ['issue-close', '101', '--comment', 'Completed and validated.']);
  assert.strictEqual(r.status, 0, `close exit ${r.status}\nstderr:\n${r.stderr}`);
  const front = fm(readRecord(ctx, 'issue', name));
  assert.strictEqual(front.state, 'closed', 'local record reflects closure');
  assert.strictEqual(front.pending_sync, false);
  const closeCall = calls(ctx)[1];
  assert.deepStrictEqual(closeCall.slice(0, 3), ['issue', 'close', '101']);
  assert.ok(closeCall.includes('--comment'), 'close flags pass through');
  assert.ok(readRecord(ctx, 'issue', name).includes('Body to keep.'), 'body preserved on close');
});

// --- DRC-6: offline issue-create queues pending ------------------------------------

check('DRC-6: offline issue-create keeps the local write, marks pending, exits 3', () => {
  const ctx = setup('drc6');
  ctx.setMode('offline');
  const r = runHelper(ctx, ['issue-create', 'Offline task', '--body', 'Offline body.', '--label', 'type:feature']);
  assert.strictEqual(r.status, 3, `offline create must exit 3 (got ${r.status})`);
  assert.deepStrictEqual(recordFiles(ctx, 'issue'), ['ISSUE-001-offline-task.md'], 'provisional canonical filename');
  const record = readRecord(ctx, 'issue', 'ISSUE-001-offline-task.md');
  const front = fm(record);
  assert.strictEqual(front.github_number, 1, 'provisional github_number');
  assert.strictEqual(front.github_url, null, 'no confirmed URL while pending');
  assert.strictEqual(front.pending_sync, true, 'pending_sync is the offline queue');
  assert.strictEqual(front.last_synced_at, null, 'last_synced_at stays unset while never synced');
  assert.ok(bodyOf(record).includes('Offline body.'), 'body kept offline');
  assert.ok(/pending_sync: true/.test(r.stderr) || /sync deferred/.test(r.stderr), 'stderr warns about the deferred sync');
  assert.ok(r.stderr.includes('issue-sync'), 'stderr names the recovery command');
  assert.deepStrictEqual(calls(ctx).length, 1, 'gh was attempted exactly once (and failed)');
  assert.strictEqual(probeAt(ctx, 0), 1, 'local write happened before the gh attempt');
});

// --- DRC-7: issue-sync backfills and is idempotent ----------------------------------

check('DRC-7: issue-sync backfills the offline record and is idempotent', () => {
  const ctx = setup('drc7');
  ctx.setMode('offline');
  let r = runHelper(ctx, ['issue-create', 'Offline feature', '--body', 'Queued body.', '--label', 'type:feature']);
  assert.strictEqual(r.status, 3, 'offline create defers');
  assert.deepStrictEqual(recordFiles(ctx, 'issue'), ['ISSUE-001-offline-feature.md']);
  ctx.setMode('online');
  const callsBeforeSync = calls(ctx).length;

  r = runHelper(ctx, ['issue-sync', '1']);
  assert.strictEqual(r.status, 0, `sync exit ${r.status}\nstderr:\n${r.stderr}`);
  assert.deepStrictEqual(recordFiles(ctx, 'issue'), ['ISSUE-101-offline-feature.md'], 'file renamed to the confirmed number');
  const record = readRecord(ctx, 'issue', 'ISSUE-101-offline-feature.md');
  const front = fm(record);
  assert.strictEqual(front.github_number, 101, 'confirmed number backfilled');
  assert.strictEqual(front.github_url, 'https://github.com/env-owner/env-repo/issues/101');
  assert.strictEqual(front.pending_sync, false, 'pending cleared after successful sync');
  assert.ok(bodyOf(record).includes('Queued body.'), 'durable body preserved through backfill');
  const syncJson = JSON.parse(r.stdout);
  assert.strictEqual(syncJson.number, 101, 'sync prints a curated convergence summary');
  assert.strictEqual(syncJson.pending_sync, false);

  // The pending record was pushed exactly once: one gh issue create call.
  const createCalls = calls(ctx).slice(callsBeforeSync).filter((c) => c[0] === 'issue' && c[1] === 'create');
  assert.strictEqual(createCalls.length, 1, 'pending record pushed to GitHub exactly once');
  const c = createCalls[0];
  const t = argIndex(c, '--title');
  assert.ok(t !== -1 && c[t + 1] === 'Offline feature', 'pushed title from the record');
  const lbl = argIndex(c, '--label');
  assert.ok(lbl !== -1 && c[lbl + 1] === 'type:feature', 'pushed queued labels');

  // Idempotent re-run: no further mutation calls, exit 0.
  const callsBefore = calls(ctx).length;
  r = runHelper(ctx, ['issue-sync', '101']);
  assert.strictEqual(r.status, 0, `re-sync exit ${r.status}\nstderr:\n${r.stderr}`);
  const newCalls = calls(ctx).slice(callsBefore);
  assert.strictEqual(newCalls.length, 1, 're-sync only reads (converge pull)');
  assert.deepStrictEqual(newCalls[0].slice(0, 3), ['issue', 'view', '101'], 'no duplicate mutation');
  const frontAfter = fm(readRecord(ctx, 'issue', 'ISSUE-101-offline-feature.md'));
  assert.strictEqual(frontAfter.pending_sync, false, 'still not pending');
});

// --- DRC-8: conflict detection and resolution ---------------------------------------

check('DRC-8: issue-sync detects conflicts: durable toward local, execution-state toward GitHub', () => {
  const ctx = setup('drc8');
  let r = runHelper(ctx, ['issue-create', 'Conflict base', '--body', 'Base body.', '--label', 'original']);
  assert.strictEqual(r.status, 0, `create exit ${r.status}`);
  const name = recordFiles(ctx, 'issue')[0];
  const record = readRecord(ctx, 'issue', name);
  const last = fm(record).last_synced_at;

  // Offline local durable edit -> pending record.
  ctx.setMode('offline');
  r = runHelper(ctx, ['issue-edit', '101', '--title', 'Local durable title', '--body', 'Local durable body.']);
  assert.strictEqual(r.status, 3, 'offline edit defers');
  ctx.setMode('online');

  // GitHub also changed since the last sync (labels + later updatedAt).
  const bumped = new Date(Date.parse(last) + 5000).toISOString().replace(/\.\d+Z$/, 'Z');
  const fx = ctx.readFixture('issue-101.json');
  fx.labels = [{ name: 'changed-on-github' }];
  fx.updatedAt = bumped;
  ctx.writeFixture('issue-101.json', fx);

  r = runHelper(ctx, ['issue-sync', '101']);
  assert.strictEqual(r.status, 0, `conflict sync resolves and exits 0 (got ${r.status})\nstderr:\n${r.stderr}`);
  assert.ok(/conflict on issue #101/.test(r.stderr), 'conflict reported on stderr');
  assert.ok(r.stderr.includes('title'), 'conflict report names differing fields');

  const front = fm(readRecord(ctx, 'issue', name));
  assert.strictEqual(front.title, 'Local durable title', 'durable content resolved toward local');
  assert.ok(readRecord(ctx, 'issue', name).includes('Local durable body.'), 'durable body resolved toward local');
  assert.deepStrictEqual(front.labels, ['changed-on-github'], 'execution-state resolved toward GitHub');
  assert.strictEqual(front.pending_sync, false, 'conflict resolved clears pending');

  // GitHub received the local durable title (pushed).
  assert.strictEqual(ctx.readFixture('issue-101.json').title, 'Local durable title');
  assert.deepStrictEqual(ctx.readFixture('issue-101.json').labels, [{ name: 'changed-on-github' }], 'GitHub labels untouched by the durable push');
});

// --- DRC-9: online milestone-create local-first -------------------------------------

check('DRC-9: online milestone-create writes spec/SPEC-0NN-*.md first and backfills', () => {
  const ctx = setup('drc9');
  const r = runHelper(ctx, ['milestone-create', 'SPEC-007: Release one', 'Ship the first release.']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const all = calls(ctx);
  assert.strictEqual(all.length, 1, 'exactly one gh call');
  assert.deepStrictEqual(all[0].slice(0, 3), ['api', `repos/${ENV_REPO}/milestones`, '-f']);
  assert.strictEqual(probeAt(ctx, 0), 1, 'local spec record written before gh runs');
  assert.deepStrictEqual(recordFiles(ctx, 'spec'), ['SPEC-001-spec-007-release-one.md'], 'deterministic spec mapping');
  const front = fm(readRecord(ctx, 'spec', 'SPEC-001-spec-007-release-one.md'));
  assert.strictEqual(front.github_milestone, 1, 'github_milestone backfilled');
  assert.strictEqual(front.github_milestone_url, 'https://github.com/env-owner/env-repo/milestone/1');
  assert.strictEqual(front.state, 'open');
  assert.strictEqual(front.pending_sync, false);
  assert.ok(bodyOf(readRecord(ctx, 'spec', 'SPEC-001-spec-007-release-one.md')).includes('Ship the first release.'), 'description as body');
  const out = JSON.parse(r.stdout);
  assert.strictEqual(out.number, 1, 'curated milestone stdout stays intact');
  assert.strictEqual(out.node_id, undefined, 'curation preserved');
});

// --- DRC-10: offline milestone-close + milestone-sync push exactly once --------------

check('DRC-10: offline milestone-close queues pending; milestone-sync pushes once, then no-op', () => {
  const ctx = setup('drc10');
  let r = runHelper(ctx, ['milestone-create', 'SPEC-008: Ship it', 'Body.']);
  assert.strictEqual(r.status, 0, `create exit ${r.status}`);
  const name = recordFiles(ctx, 'spec')[0];

  ctx.setMode('offline');
  r = runHelper(ctx, ['milestone-close', '1']);
  assert.strictEqual(r.status, 3, 'offline close defers');
  let front = fm(readRecord(ctx, 'spec', name));
  assert.strictEqual(front.state, 'closed', 'local closure recorded');
  assert.strictEqual(front.pending_sync, true, 'close queued');
  assert.ok(r.stderr.includes('milestone-sync'), 'recovery command named');
  ctx.setMode('online');
  const callsBeforeSync = calls(ctx).length;

  r = runHelper(ctx, ['milestone-sync', '1']);
  assert.strictEqual(r.status, 0, `sync exit ${r.status}\nstderr:\n${r.stderr}`);
  front = fm(readRecord(ctx, 'spec', name));
  assert.strictEqual(front.pending_sync, false, 'pending cleared');
  assert.strictEqual(front.state, 'closed', 'closure survives the sync (not pulled back open)');
  const patchCalls = calls(ctx)
    .slice(callsBeforeSync)
    .filter((c) => c.includes('-X') && c.includes('state=closed'));
  assert.strictEqual(patchCalls.length, 1, 'closure pushed exactly once');
  assert.strictEqual(ctx.readFixture('ms-1.json').state, 'closed');

  const callsBefore = calls(ctx).length;
  r = runHelper(ctx, ['milestone-sync', '1']);
  assert.strictEqual(r.status, 0, `re-sync exit ${r.status}\nstderr:\n${r.stderr}`);
  const newCalls = calls(ctx).slice(callsBefore);
  assert.strictEqual(newCalls.length, 1, 're-sync only reads');
  assert.ok(!newCalls[0].includes('PATCH'), 'no duplicate PATCH on re-run');
  assert.strictEqual(fm(readRecord(ctx, 'spec', name)).state, 'closed', 'still closed');
});

// --- DRC-11: reads fall back local (never write); comment/board stay GitHub-only ------

check('DRC-11: offline reads serve the local record read-only; issue-comment and board stay GitHub-only', () => {
  const ctx = setup('drc11');
  let r = runHelper(ctx, ['issue-create', 'Readable task', '--body', 'Readable body.']);
  assert.strictEqual(r.status, 0);
  const name = recordFiles(ctx, 'issue')[0];
  const recordPath = path.join(ctx.docs, 'issue', name);
  const before = fs.readFileSync(recordPath, 'utf8');
  const mtimeBefore = fs.statSync(recordPath).mtimeMs;

  ctx.setMode('offline');
  r = runHelper(ctx, ['issue-view', '101']);
  assert.strictEqual(r.status, 0, `offline view must fall back to the local record (got ${r.status})`);
  const view = JSON.parse(r.stdout);
  assert.strictEqual(view.number, 101);
  assert.strictEqual(view.title, 'Readable task');
  assert.ok(view.body.includes('Readable body.'));
  assert.ok(/served the local record/.test(r.stderr), 'fallback is announced on stderr');
  assert.strictEqual(fs.readFileSync(recordPath, 'utf8'), before, 'reads never rewrite the record');
  assert.strictEqual(fs.statSync(recordPath).mtimeMs, mtimeBefore, 'reads never touch the record mtime');

  // issue-list fallback serves the local set as an array.
  r = runHelper(ctx, ['issue-list']);
  assert.strictEqual(r.status, 0, `offline list must fall back (got ${r.status})`);
  const list = JSON.parse(r.stdout);
  assert.ok(Array.isArray(list) && list.length === 1 && list[0].number === 101, 'local records served as a list');

  // issue-comment stays GitHub-only: fails offline, writes nothing.
  r = runHelper(ctx, ['issue-comment', '101', '--body', 'final decision']);
  assert.notStrictEqual(r.status, 0, 'issue-comment must fail offline (not queued)');
  assert.deepStrictEqual(recordFiles(ctx, 'issue'), [name], 'no new records from issue-comment');

  // Board commands stay GitHub-only: fail offline, write nothing.
  const boardCtx = setup('drc11b', [
    `export ANT_TEAM_GITHUB_REPO='${ENV_REPO}'`,
    `export ANT_TEAM_DOCS_PROJECT_PATH='${ctx.docs}'`,
    "export ANT_TEAM_GITHUB_OWNER='env-owner'",
    "export ANT_TEAM_GITHUB_PROJECT_NUMBER='9'",
  ]);
  boardCtx.setMode('offline');
  const rb = runHelper(boardCtx, ['set-status', '101', 'In Review']);
  assert.notStrictEqual(rb.status, 0, 'set-status must fail offline');
  assert.deepStrictEqual(recordFiles(ctx, 'issue'), [name], 'board commands never write local records');
});

// --- DRC-12: malformed titles rejected before gh and before any write -----------------

check('DRC-12: traversal / malformed titles are rejected before gh and before writes', () => {
  const ctx = setup('drc12');
  const badTitles = [
    '../../escape/to/vault-root',
    'a/../../b',
    'a\nb',
    'title\x07bell',
    '-leading-dash',
  ];
  for (const title of badTitles) {
    const r = runHelper(ctx, ['issue-create', title]);
    assert.notStrictEqual(r.status, 0, `title ${JSON.stringify(title)} must be rejected`);
    assert.ok(/Invalid title/.test(r.stderr), `rejection reason must be actionable (got: ${r.stderr.trim()})`);
  }
  for (const title of ['../escape', 'a\nb']) {
    const r = runHelper(ctx, ['milestone-create', title]);
    assert.notStrictEqual(r.status, 0, `milestone title ${JSON.stringify(title)} must be rejected`);
  }
  assert.deepStrictEqual(calls(ctx).length, 0, 'gh must never be called for malformed titles');
  assert.deepStrictEqual(recordFiles(ctx, 'issue'), [], 'no issue records written');
  assert.deepStrictEqual(recordFiles(ctx, 'spec'), [], 'no spec records written');

  // Normal titles with slashes/colons slugify safely instead of being rejected.
  const r = runHelper(ctx, ['issue-create', 'PR/review: odd but legal']);
  assert.strictEqual(r.status, 0, `legal title must pass: ${r.stderr}`);
  assert.deepStrictEqual(recordFiles(ctx, 'issue'), ['ISSUE-101-pr-review-odd-but-legal.md']);
});

// --- DRC-13: confinement + atomicity ---------------------------------------------------

check('DRC-13: writes confined to {issue,spec}/ under the base; no temp files leak', () => {
  const ctx = setup('drc13');
  ctx.setMode('offline');
  runHelper(ctx, ['issue-create', 'Offline one', '--body', 'b1']);
  runHelper(ctx, ['milestone-create', 'SPEC-010: Offline spec', 'd1']);
  ctx.setMode('online');
  runHelper(ctx, ['issue-sync', '1']);
  runHelper(ctx, ['issue-edit', '101', '--title', 'Edit after sync', '--body', 'b2']);
  runHelper(ctx, ['issue-close', '101']);
  runHelper(ctx, ['milestone-sync', '1']);
  runHelper(ctx, ['milestone-close', '1']);
  runHelper(ctx, ['issue-view', '101']);

  const walk = (dir) => {
    const out = [];
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      const p = path.join(dir, e.name);
      if (e.isDirectory()) out.push(...walk(p));
      else out.push(p);
    }
    return out;
  };
  const files = walk(ctx.docs);
  assert.ok(files.length > 0, 'records were written');
  for (const f of files) {
    const rel = path.relative(ctx.docs, f);
    assert.ok(
      /^issue\/|^spec\//.test(rel),
      `write escaped the confined base: ${rel}`
    );
    assert.ok(!path.basename(f).includes('.tmp.'), `temp file leaked: ${rel}`);
  }
  assert.ok(!fs.existsSync(path.join(ctx.tmp, '.github-project.json')), 'no JSON config may appear');
});

// --- summary ----------------------------------------------------------------------------

console.log(`\n${passed} passed, ${failed} failed (gh_project_helper dual-record local-first sync)`);
if (failed > 0) process.exit(1);
