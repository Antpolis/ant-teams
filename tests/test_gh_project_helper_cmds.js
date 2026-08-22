#!/usr/bin/env node
'use strict';

/*
 * tests/test_gh_project_helper_cmds.js — env-only issue/milestone helper
 * subcommands (2026-08).
 *
 * Locks the env-only contract of the new gh_project_helper.sh subcommands
 * (issue-create, issue-view, issue-list, issue-edit, issue-comment,
 * issue-close, milestone-create, milestone-list, milestone-edit,
 * milestone-close) into executable checks:
 *
 *   HIC-1  usage lists every new subcommand; required positionals enforced
 *   HIC-2  issue-create passes title + extras; env repo resolves and wins
 *   HIC-3  a pass-through --repo can never override the env repo
 *   HIC-4  issue-view prints curated JSON by default
 *   HIC-5  issue-view --comments skips the curated default
 *   HIC-6  issue-list prints curated JSON by default; filters pass through
 *   HIC-7  issue-list custom --json skips the curated default
 *   HIC-8  issue-comment / issue-edit / issue-close are thin pass-throughs
 *   HIC-9  milestone-create sends title/description -f fields, curated output
 *   HIC-10 milestone-create without description omits the description field
 *   HIC-11 milestone-list defaults to state=open; closed passes through
 *   HIC-12 milestone-list rejects an invalid state before calling gh
 *   HIC-13 milestone-edit PATCHes with pass-through -f fields
 *   HIC-14 milestone-close PATCHes state=closed
 *   HIC-15 missing ANT_TEAM_GITHUB_REPO fails fast without calling gh
 *   HIC-16 the helper writes no files: env byte-identical, no JSON config
 *   HIC-17 project subcommands remain env-only (no positional owner/project)
 *
 * No external npm dependencies — Node built-ins only. No network access.
 */

const { spawnSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const assert = require('assert');

const REPO_ROOT = path.resolve(__dirname, '..');
const HELPER = path.join(
  REPO_ROOT,
  '.opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh'
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

// Temp dir with a sourceable .github-project.env, a fake gh on PATH that
// logs every invocation, and a canned gh stdout file.
function setup(prefix, envContent) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), `${prefix}-`));
  if (envContent !== null) {
    fs.writeFileSync(path.join(tmp, '.github-project.env'), envContent);
  }
  const bin = path.join(tmp, 'bin');
  fs.mkdirSync(bin);
  const ghLog = path.join(bin, 'gh-calls.log');
  const ghOut = path.join(bin, 'gh-out.json');
  fs.writeFileSync(
    path.join(bin, 'gh'),
    '#!/usr/bin/env bash\n' +
      `printf 'CALL:' >> '${ghLog}'; printf ' [%s]' "$@" >> '${ghLog}'; printf '\\n' >> '${ghLog}'\n` +
      `cat '${ghOut}'\n`
  );
  fs.chmodSync(path.join(bin, 'gh'), 0o755);
  fs.writeFileSync(ghOut, '{"fields":[]}');
  return { tmp, bin, ghLog, ghOut };
}

const DEFAULT_ENV = `export ANT_TEAM_GITHUB_REPO='${ENV_REPO}'\n`;

const MILESTONE_PAYLOAD = JSON.stringify({
  number: 3,
  title: 'SPEC-003: Deliverable',
  description: 'secret-ish long description',
  state: 'open',
  open_issues: 2,
  closed_issues: 1,
  due_on: null,
  html_url: 'https://example.com/m/3',
  node_id: 'MDEzShouldNeverLeak',
});

function runHelper(ctx, args) {
  return spawnSync('bash', [HELPER, ...args], {
    encoding: 'utf8',
    cwd: ctx.tmp,
    env: {
      PATH: `${ctx.bin}:${process.env.PATH}`,
      GH_LOG: ctx.ghLog,
      GH_OUT: ctx.ghOut,
      HOME: process.env.HOME,
    },
  });
}

// Parse the fake gh log into an array of calls; each call is an args array.
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

function argIndex(call, flag) {
  return call.indexOf(flag);
}

// --- HIC-1: usage lists new subcommands; positionals enforced -----------------

check('HIC-1: usage lists every new subcommand and enforces required positionals', () => {
  const ctx = setup('hic1', DEFAULT_ENV);
  const usage = runHelper(ctx, []);
  assert.notStrictEqual(usage.status, 0, 'no-args must exit non-zero');
  for (const sub of [
    'issue-create', 'issue-view', 'issue-list', 'issue-edit',
    'issue-comment', 'issue-close',
    'milestone-create', 'milestone-list', 'milestone-edit', 'milestone-close',
  ]) {
    assert.ok(usage.stdout.includes(sub), `usage must list ${sub}`);
  }
  for (const args of [
    ['issue-create'],
    ['issue-view'],
    ['issue-edit'],
    ['issue-comment'],
    ['issue-close'],
    ['milestone-create'],
    ['milestone-edit'],
    ['milestone-close'],
    ['milestone-create', 'a', 'b', 'c'],
    ['milestone-list', 'open', 'closed'],
  ]) {
    const r = runHelper(ctx, args);
    assert.notStrictEqual(r.status, 0, `${args.join(' ')} must fail without its required positional`);
    assert.deepStrictEqual(calls(ctx).length, 0, 'gh must not be called on a usage error');
  }
});

// --- HIC-2: issue-create -------------------------------------------------------

check('HIC-2: issue-create sends title + extras; repo resolves from the env', () => {
  const ctx = setup('hic2', DEFAULT_ENV);
  const r = runHelper(ctx, [
    'issue-create', 'TASK: fix login', '--body-file', '/tmp/issue.md', '--label', 'type:feature',
  ]);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const all = calls(ctx);
  assert.strictEqual(all.length, 1, 'exactly one gh call');
  const c = all[0];
  assert.deepStrictEqual(c.slice(0, 2), ['issue', 'create']);
  const t = argIndex(c, '--title');
  assert.ok(t !== -1 && c[t + 1] === 'TASK: fix login', `title positional must reach --title: ${c.join(' ')}`);
  assert.ok(c.includes('--body-file') && c.includes('/tmp/issue.md'), 'extras must pass through');
  const repo = argIndex(c, '--repo');
  assert.ok(repo !== -1 && c[repo + 1] === ENV_REPO, `env repo must be sent: ${c.join(' ')}`);
});

// --- HIC-3: pass-through --repo never wins ------------------------------------

check('HIC-3: a pass-through --repo can never override the env repo', () => {
  const ctx = setup('hic3', DEFAULT_ENV);
  const r = runHelper(ctx, ['issue-list', '--repo', 'rogue/rogue']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const c = calls(ctx)[0];
  const last = c.lastIndexOf('--repo');
  assert.ok(last !== -1 && c[last + 1] === ENV_REPO, `env repo must be the final --repo: ${c.join(' ')}`);
});

// --- HIC-4: issue-view curated default ----------------------------------------

check('HIC-4: issue-view prints curated JSON by default', () => {
  const ctx = setup('hic4', DEFAULT_ENV);
  const r = runHelper(ctx, ['issue-view', '42']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const c = calls(ctx)[0];
  assert.deepStrictEqual(c.slice(0, 3), ['issue', 'view', '42']);
  const j = argIndex(c, '--json');
  assert.ok(j !== -1, `default --json must be present: ${c.join(' ')}`);
  assert.strictEqual(
    c[j + 1],
    'number,title,body,state,assignees,labels,milestone,projectItems,url',
    'curated view fields'
  );
  assert.ok(c.includes(ENV_REPO), 'env repo must be sent');
});

// --- HIC-5: issue-view --comments skips the default ---------------------------

check('HIC-5: issue-view --comments skips the curated default', () => {
  const ctx = setup('hic5', DEFAULT_ENV);
  const r = runHelper(ctx, ['issue-view', '42', '--comments']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const c = calls(ctx)[0];
  assert.ok(!c.includes('--json'), `caller shape must win: ${c.join(' ')}`);
  assert.ok(c.includes('--comments') && c.includes(ENV_REPO));
});

// --- HIC-6: issue-list curated default + filters ------------------------------

check('HIC-6: issue-list prints curated JSON by default; filters pass through', () => {
  const ctx = setup('hic6', DEFAULT_ENV);
  const r = runHelper(ctx, ['issue-list', '--label', 'blocked', '--state', 'closed']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const c = calls(ctx)[0];
  assert.deepStrictEqual(c.slice(0, 2), ['issue', 'list']);
  const j = argIndex(c, '--json');
  assert.strictEqual(
    j !== -1 ? c[j + 1] : '',
    'number,title,state,assignees,labels,milestone,url',
    'curated list fields'
  );
  assert.ok(c.includes('--label') && c.includes('blocked'), 'label filter passes through');
  assert.ok(c.includes('--state') && c.includes('closed'), 'state filter passes through');
  assert.ok(c.includes(ENV_REPO));
});

// --- HIC-7: issue-list custom --json skips the default ------------------------

check('HIC-7: issue-list custom --json skips the curated default', () => {
  const ctx = setup('hic7', DEFAULT_ENV);
  const r = runHelper(ctx, ['issue-list', '--json', 'number,title']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const c = calls(ctx)[0];
  assert.strictEqual(c.filter((a) => a === '--json').length, 1, 'exactly the caller --json');
  assert.ok(c.includes('number,title'), 'caller fields pass through');
});

// --- HIC-8: thin pass-through mutations ---------------------------------------

check('HIC-8: issue-comment / issue-edit / issue-close are thin pass-throughs', () => {
  const ctx = setup('hic8', DEFAULT_ENV);

  let r = runHelper(ctx, ['issue-comment', '42', '--body-file', '/tmp/handoff.md']);
  assert.strictEqual(r.status, 0, `comment exit ${r.status}\nstderr:\n${r.stderr}`);
  let c = calls(ctx).pop();
  assert.deepStrictEqual(c.slice(0, 3), ['issue', 'comment', '42']);
  assert.ok(c.includes('--body-file') && c[argoAfter(c, '--body-file')] === '/tmp/handoff.md');

  r = runHelper(ctx, ['issue-edit', '42', '--add-label', 'blocked', '--milestone', 'SPEC-001']);
  assert.strictEqual(r.status, 0, `edit exit ${r.status}\nstderr:\n${r.stderr}`);
  c = calls(ctx).pop();
  assert.deepStrictEqual(c.slice(0, 3), ['issue', 'edit', '42']);
  assert.ok(c.includes('--add-label') && c.includes('--milestone'));

  r = runHelper(ctx, ['issue-close', '42', '--comment', 'Completed and validated.']);
  assert.strictEqual(r.status, 0, `close exit ${r.status}\nstderr:\n${r.stderr}`);
  c = calls(ctx).pop();
  assert.deepStrictEqual(c.slice(0, 3), ['issue', 'close', '42']);
  assert.ok(c.includes('--comment'));
  assert.ok(c[c.lastIndexOf('--repo') + 1] === ENV_REPO, 'env repo last on every call');
});

function argoAfter(call, flag) {
  return call.indexOf(flag) + 1;
}

// --- HIC-9: milestone-create ---------------------------------------------------

check('HIC-9: milestone-create sends title/description fields and curates output', () => {
  const ctx = setup('hic9', DEFAULT_ENV);
  fs.writeFileSync(ctx.ghOut, MILESTONE_PAYLOAD);
  const r = runHelper(ctx, ['milestone-create', 'SPEC-003: Deliverable', 'Short summary with spec link']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const c = calls(ctx)[0];
  assert.deepStrictEqual(c.slice(0, 3), ['api', `repos/${ENV_REPO}/milestones`, '-f']);
  const title = argIndex(c, 'title=SPEC-003: Deliverable');
  const desc = argIndex(c, 'description=Short summary with spec link');
  assert.ok(title !== -1 && desc !== -1, `both -f fields must be sent: ${c.join(' ')}`);
  const out = JSON.parse(r.stdout);
  assert.strictEqual(out.number, 3);
  assert.strictEqual(out.url, 'https://example.com/m/3');
  assert.strictEqual(out.node_id, undefined, 'curated output must drop node_id');
  assert.strictEqual(out.description, undefined, 'curated output must drop the raw description');
});

// --- HIC-10: milestone-create without description ------------------------------

check('HIC-10: milestone-create without a description omits the field', () => {
  const ctx = setup('hic10', DEFAULT_ENV);
  fs.writeFileSync(ctx.ghOut, MILESTONE_PAYLOAD);
  const r = runHelper(ctx, ['milestone-create', 'SPEC-003: Deliverable']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const c = calls(ctx)[0];
  assert.ok(argIndex(c, 'title=SPEC-003: Deliverable') !== -1, 'title -f must be sent');
  assert.ok(!c.some((a) => a.startsWith('description=')), 'no description field when omitted');
});

// --- HIC-11: milestone-list state handling -------------------------------------

check('HIC-11: milestone-list defaults to state=open and passes closed through', () => {
  const ctx = setup('hic11', DEFAULT_ENV);
  fs.writeFileSync(ctx.ghOut, `[${MILESTONE_PAYLOAD}]`);
  let r = runHelper(ctx, ['milestone-list']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  let c = calls(ctx)[0];
  assert.deepStrictEqual(c.slice(0, 2), ['api', `repos/${ENV_REPO}/milestones?state=open`]);
  const items = JSON.parse(r.stdout);
  assert.ok(Array.isArray(items) && items.length === 1 && items[0].node_id === undefined,
    'list output must be a curated array');

  r = runHelper(ctx, ['milestone-list', 'closed']);
  assert.strictEqual(r.status, 0, `closed exit ${r.status}\nstderr:\n${r.stderr}`);
  c = calls(ctx)[1];
  assert.strictEqual(c[1], `repos/${ENV_REPO}/milestones?state=closed`);
});

// --- HIC-12: milestone-list rejects invalid state ------------------------------

check('HIC-12: milestone-list rejects an invalid state before calling gh', () => {
  const ctx = setup('hic12', DEFAULT_ENV);
  const r = runHelper(ctx, ['milestone-list', 'bogus']);
  assert.notStrictEqual(r.status, 0, 'invalid state must fail');
  assert.ok(/Invalid milestone state/.test(r.stderr), 'friendly error expected');
  assert.deepStrictEqual(calls(ctx).length, 0, 'gh must not be called');
});

// --- HIC-13: milestone-edit ----------------------------------------------------

check('HIC-13: milestone-edit PATCHes with pass-through -f fields', () => {
  const ctx = setup('hic13', DEFAULT_ENV);
  fs.writeFileSync(ctx.ghOut, MILESTONE_PAYLOAD);
  const r = runHelper(ctx, ['milestone-edit', '3', '-f', 'title=SPEC-003: Revised']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const c = calls(ctx)[0];
  assert.deepStrictEqual(
    c.slice(0, 5),
    ['api', '-X', 'PATCH', `repos/${ENV_REPO}/milestones/3`, '-f'],
    'PATCH with milestone number in the path'
  );
  assert.ok(argIndex(c, 'title=SPEC-003: Revised') !== -1, 'pass-through -f field must be sent');
  JSON.parse(r.stdout); // curated JSON out
});

// --- HIC-14: milestone-close ---------------------------------------------------

check('HIC-14: milestone-close PATCHes state=closed', () => {
  const ctx = setup('hic14', DEFAULT_ENV);
  fs.writeFileSync(ctx.ghOut, MILESTONE_PAYLOAD);
  const r = runHelper(ctx, ['milestone-close', '3']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const c = calls(ctx)[0];
  assert.deepStrictEqual(
    c.slice(0, 6),
    ['api', '-X', 'PATCH', `repos/${ENV_REPO}/milestones/3`, '-f', 'state=closed']
  );
  const out = JSON.parse(r.stdout);
  assert.strictEqual(out.node_id, undefined, 'curated output');
});

// --- HIC-15: missing repo fails fast -------------------------------------------

check('HIC-15: missing ANT_TEAM_GITHUB_REPO fails fast without calling gh', () => {
  const ctx = setup('hic15', null); // no env file at all
  const r = runHelper(ctx, ['issue-list']);
  assert.notStrictEqual(r.status, 0, 'must fail without a repo');
  assert.ok(r.stderr.includes('ANT_TEAM_GITHUB_REPO'), 'error must name the env key');
  assert.deepStrictEqual(calls(ctx).length, 0, 'gh must not be called');

  const ctx2 = setup('hic15b', "export OTHER='x'\n");
  const r2 = runHelper(ctx2, ['milestone-list']);
  assert.notStrictEqual(r2.status, 0, 'milestone-list must also require the repo');
  assert.ok(r2.stderr.includes('no repo argument'), 'error must explain the env-only contract');
});

// --- HIC-16: the helper writes no files ----------------------------------------

check('HIC-16: helper writes no files; env stays byte-identical, no JSON config', () => {
  const ctx = setup('hic16', DEFAULT_ENV);
  fs.writeFileSync(ctx.ghOut, MILESTONE_PAYLOAD);
  const envPath = path.join(ctx.tmp, '.github-project.env');
  const before = fs.readFileSync(envPath, 'utf8');
  const mtimeBefore = fs.statSync(envPath).mtimeMs;
  for (const args of [
    ['issue-create', 'T', '--body', 'b'],
    ['issue-list'],
    ['milestone-create', 'M', 'D'],
    ['milestone-close', '3'],
  ]) {
    assert.strictEqual(runHelper(ctx, args).status, 0, `${args[0]} must succeed`);
  }
  assert.strictEqual(fs.readFileSync(envPath, 'utf8'), before, 'env must stay byte-identical');
  assert.strictEqual(fs.statSync(envPath).mtimeMs, mtimeBefore, 'env must not be rewritten');
  assert.ok(!fs.existsSync(path.join(ctx.tmp, '.github-project.json')), 'no JSON config may appear');
});

// --- HIC-17: project subcommands stay env-only ---------------------------------

check('HIC-17: project subcommands reject positional owner/project arguments', () => {
  const ctx = setup('hic17', DEFAULT_ENV);
  for (const args of [
    ['list-statuses', 'Antpolis', '9'],
    ['list-items', 'Antpolis', '9', 'Ready'],
    ['item-id', 'Antpolis', '9', '42'],
  ]) {
    const r = runHelper(ctx, args);
    assert.notStrictEqual(r.status, 0, `${args.join(' ')} must be rejected (env-only)`);
    assert.deepStrictEqual(calls(ctx).length, 0, 'gh must not be called');
  }
});

// --- summary -------------------------------------------------------------------

console.log(`\n${passed} passed, ${failed} failed (gh_project_helper env-only issue/milestone subcommands)`);
if (failed > 0) process.exit(1);
