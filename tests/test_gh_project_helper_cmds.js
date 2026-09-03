#!/usr/bin/env node
'use strict';

/*
 * tests/test_gh_project_helper_cmds.js — env-only issue/milestone/PR/CI-testing/
 * release helper subcommands (2026-08).
 *
 * Locks the env-only contract of the gh_project_helper.sh subcommands
 * (issue-create, issue-view, issue-list, issue-edit, issue-comment,
 * issue-close, pr-create, pr-view, pr-list, pr-comment, pr-close, pr-merge,
 * pr-checks, pr-review-reply, run-list, run-view, workflow-list,
 * workflow-run, milestone-create, milestone-list, milestone-edit,
 * milestone-close, release-create, release-list, release-view, release-edit,
 * release-delete) into executable checks:
 *
 *   HIC-1  usage lists every new subcommand; required positionals enforced
 *   HIC-2  issue-create passes title + extras; env repo resolves and wins;
 *          curated {number,title,state,url} output reuses the URL response
 *   HIC-3  a pass-through --repo can never override the env repo
 *   HIC-4  issue-view prints curated JSON by default
 *   HIC-5  issue-view --comments skips the curated default
 *   HIC-6  issue-list prints curated JSON by default; filters pass through
 *   HIC-7  issue-list custom --json skips the curated default
 *   HIC-8  issue-comment stays a thin pass-through (URL permalink out);
 *          issue-edit / issue-close mutate then re-read and print curated
 *          post-mutation JSON (issue #45 contract replacement)
 *   HIC-9  milestone-create sends title/description -f fields, curated output
 *   HIC-10 milestone-create without description omits the description field
 *   HIC-11 milestone-list defaults to state=open; closed passes through
 *   HIC-12 milestone-list rejects an invalid state before calling gh
 *   HIC-13 milestone-edit PATCHes with pass-through -f fields
 *   HIC-14 milestone-close PATCHes state=closed
 *   HIC-15 missing ANT_TEAM_GITHUB_REPO fails fast without calling gh
 *   HIC-16 the helper writes no files: env byte-identical, no JSON config
 *   HIC-17 project subcommands remain env-only (no positional owner/project;
 *          extended by #46 with list-unassigned and the project-* family —
 *          their owner is a --owner flag only)
 *   PRC-1  usage lists every pr-* subcommand; required positionals enforced
 *   PRC-2  pr-create passes title + extras; env repo resolves and wins;
 *          curated {number,title,state,url} output reuses the URL response
 *   PRC-3  a pass-through --repo can never override the env repo (pr-list)
 *   PRC-4  pr-view prints curated JSON by default
 *   PRC-5  pr-view --comments skips the curated default
 *   PRC-6  pr-list prints curated JSON by default; filters pass through
 *   PRC-7  pr-comment is a thin pass-through (URL permalink out)
 *   PRC-8  pr-close / pr-merge mutate then re-read and print curated
 *          post-mutation JSON; no --admin injected (issue #45 replacement)
 *   PRC-9  pr-checks curates the tabular output into JSON by default
 *   PRC-10 pr-review-reply uses the fixed parameterized GraphQL mutation
 *   PRC-11 missing ANT_TEAM_GITHUB_REPO fails fast without calling gh (pr-*)
 *   CIC-1  usage lists run/workflow subcommands; positionals enforced
 *   CIC-2  run-list prints curated JSON by default; filters pass through
 *   CIC-3  run-view prints curated JSON by default
 *   CIC-4  caller format flags take over (run-view --web, run-list --json)
 *   CIC-5  workflow-list prints curated JSON by default; --all passes through
 *   CIC-6  workflow-run dispatches caller flags only; no --admin injected;
 *          curated dispatch summary out with no invented run read
 *   CIC-7  a pass-through --repo can never override the env repo (run/workflow)
 *   CIC-8  missing ANT_TEAM_GITHUB_REPO fails fast without calling gh (run/workflow)
 *   RLC-1  usage lists every release-* subcommand; positionals enforced
 *   RLC-2  release-create sends tag + extras, then re-reads the release and
 *          prints the curated release-view shape (issue #45 replacement)
 *   RLC-3  release-list prints curated JSON by default; filters pass through
 *   RLC-4  release-view prints curated JSON by default
 *   RLC-5  caller format flags take over (release-view --web, release-list --json)
 *   RLC-6  release-edit mutates then re-reads; curated release-view shape out
 *   RLC-7  release-delete passes caller flags only; no --admin/--yes injected;
 *          curated {tagName,url,deleted} summary out with no re-read
 *   RLC-8  a pass-through --repo can never override the env repo (release-*)
 *   RLC-9  invalid canonical tags fail before gh (create/edit/delete)
 *   RLC-10 valid canonical tags reach gh untouched; create then verify re-read
 *   RLC-11 missing ANT_TEAM_GITHUB_REPO fails fast without calling gh (release-*)
 *
 * The helper under test is the canonical engine in templates/opencode/
 * (the repo-local .opencode/ skills mirror is not tracked since the
 * templates/opencode restructure); tests never depend on a generated or
 * globally installed mirror.
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

// Temp dir with a sourceable .github-project.env, a fake gh on PATH that
// logs every invocation, and a canned gh stdout file. Each argument is
// logged as one [arg] group with embedded newlines flattened to spaces so
// multi-line argv entries (e.g. the fixed GraphQL query) stay parseable.
function setup(prefix, envContent) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), `${prefix}-`));
  const docs = path.join(tmp, 'docs');
  fs.mkdirSync(docs, { recursive: true });
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
      `printf 'CALL:' >> '${ghLog}'; for a in "$@"; do printf ' [%s]' "$(printf '%s' "$a" | tr '\\n' ' ')" >> '${ghLog}'; done; printf '\\n' >> '${ghLog}'\n` +
      `cat '${ghOut}'\n`
  );
  fs.chmodSync(path.join(bin, 'gh'), 0o755);
  fs.writeFileSync(ghOut, '{"fields":[]}');
  return { tmp, docs, bin, ghLog, ghOut };
}

// Mutating issue/milestone commands are local-first (SPEC-003-T7): the env
// must carry an isolated docs base so the local record write succeeds.
const DEFAULT_ENV = `export ANT_TEAM_GITHUB_REPO='${ENV_REPO}'\nexport ANT_TEAM_DOCS_PROJECT_PATH='DOCS_PATH'\n`;

function setupWithDocs(prefix) {
  const ctx = setup(prefix, null);
  fs.writeFileSync(
    path.join(ctx.tmp, '.github-project.env'),
    DEFAULT_ENV.replace('DOCS_PATH', ctx.docs)
  );
  return ctx;
}

const ISSUE_URL_OUT = 'https://github.com/env-owner/env-repo/issues/77\n';
const PR_URL_OUT = 'https://github.com/env-owner/env-repo/pull/88\n';

// Static canned payloads served for the post-mutation verification re-reads.
const ISSUE_VIEW_PAYLOAD = JSON.stringify({
  number: 42,
  title: 'Post-edit title from the re-read',
  state: 'OPEN',
  url: 'https://github.com/env-owner/env-repo/issues/42',
});
const PR_VIEW_PAYLOAD = (state) => JSON.stringify({
  number: 45,
  title: 'Curated PR mutation contract',
  state,
  url: 'https://github.com/env-owner/env-repo/pull/45',
});
const RELEASE_VIEW_PAYLOAD = JSON.stringify({
  name: 'v1.2.0 — ant-teams',
  tagName: 'v1.2.0',
  targetCommitish: 'master',
  isDraft: false,
  isPrerelease: false,
  createdAt: '2026-08-23T00:00:00Z',
  publishedAt: '2026-08-23T00:00:01Z',
  author: { login: 'chrissim' },
  body: 'Release notes body.',
  url: 'https://github.com/env-owner/env-repo/releases/tag/v1.2.0',
  node_id: 'RE_shouldNeverLeak',
});

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
  const ctx = setupWithDocs('hic1');
  const usage = runHelper(ctx, []);
  assert.notStrictEqual(usage.status, 0, 'no-args must exit non-zero');
  for (const sub of [
    'issue-create', 'issue-view', 'issue-list', 'issue-edit',
    'issue-comment', 'issue-close',
    'milestone-create', 'milestone-list', 'milestone-edit', 'milestone-close',
    'issue-sync', 'milestone-sync',
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
    ['issue-sync'],
    ['milestone-sync'],
  ]) {
    const r = runHelper(ctx, args);
    assert.notStrictEqual(r.status, 0, `${args.join(' ')} must fail without its required positional`);
    assert.deepStrictEqual(calls(ctx).length, 0, 'gh must not be called on a usage error');
  }
});

// --- HIC-2: issue-create -------------------------------------------------------

check('HIC-2: issue-create sends title + extras; curated output reuses the URL response', () => {
  const ctx = setupWithDocs('hic2');
  fs.writeFileSync(ctx.ghOut, ISSUE_URL_OUT); // gh issue create prints the issue URL
  const bodyFile = path.join(ctx.tmp, 'issue.md');
  fs.writeFileSync(bodyFile, 'body from file');
  const r = runHelper(ctx, [
    'issue-create', 'TASK: fix login', '--body-file', bodyFile, '--label', 'type:feature',
  ]);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const all = calls(ctx);
  assert.strictEqual(all.length, 1, 'exactly one gh call (URL response reused, no re-read)');
  const c = all[0];
  assert.deepStrictEqual(c.slice(0, 2), ['issue', 'create']);
  const t = argIndex(c, '--title');
  assert.ok(t !== -1 && c[t + 1] === 'TASK: fix login', `title positional must reach --title: ${c.join(' ')}`);
  assert.ok(c.includes('--body-file') && c.includes(bodyFile), 'extras must pass through');
  const repo = argIndex(c, '--repo');
  assert.ok(repo !== -1 && c[repo + 1] === ENV_REPO, `env repo must be sent: ${c.join(' ')}`);
  const out = JSON.parse(r.stdout);
  assert.deepStrictEqual(
    Object.keys(out).sort(),
    ['number', 'state', 'title', 'url'],
    'issue-create output is exactly the curated four-field contract'
  );
  assert.strictEqual(out.number, 77, 'number parsed from the mutation URL response');
  assert.strictEqual(out.title, 'TASK: fix login');
  assert.strictEqual(out.state, 'OPEN', 'a freshly created issue is deterministically OPEN');
  assert.strictEqual(out.url, 'https://github.com/env-owner/env-repo/issues/77');
});

// --- HIC-3: pass-through --repo never wins ------------------------------------

check('HIC-3: a pass-through --repo can never override the env repo', () => {
  const ctx = setupWithDocs('hic3');
  const r = runHelper(ctx, ['issue-list', '--repo', 'rogue/rogue']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const c = calls(ctx)[0];
  const last = c.lastIndexOf('--repo');
  assert.ok(last !== -1 && c[last + 1] === ENV_REPO, `env repo must be the final --repo: ${c.join(' ')}`);
});

// --- HIC-4: issue-view curated default ----------------------------------------

check('HIC-4: issue-view prints curated JSON by default', () => {
  const ctx = setupWithDocs('hic4');
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
  const ctx = setupWithDocs('hic5');
  const r = runHelper(ctx, ['issue-view', '42', '--comments']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const c = calls(ctx)[0];
  assert.ok(!c.includes('--json'), `caller shape must win: ${c.join(' ')}`);
  assert.ok(c.includes('--comments') && c.includes(ENV_REPO));
});

// --- HIC-6: issue-list curated default + filters ------------------------------

check('HIC-6: issue-list prints curated JSON by default; filters pass through', () => {
  const ctx = setupWithDocs('hic6');
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
  const ctx = setupWithDocs('hic7');
  const r = runHelper(ctx, ['issue-list', '--json', 'number,title']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const c = calls(ctx)[0];
  assert.strictEqual(c.filter((a) => a === '--json').length, 1, 'exactly the caller --json');
  assert.ok(c.includes('number,title'), 'caller fields pass through');
});

// --- HIC-8: curated mutation contract (issue #45 replacement) ------------------

check('HIC-8: issue-comment stays thin; issue-edit/issue-close mutate, re-read, curate', () => {
  // issue-comment output is unchanged: the comment URL permalink IS the
  // useful result (no verification re-read).
  let ctx = setupWithDocs('hic8');
  fs.writeFileSync(ctx.ghOut, 'https://github.com/env-owner/env-repo/issues/42#issuecomment-1\n');
  let r = runHelper(ctx, ['issue-comment', '42', '--body-file', '/tmp/handoff.md']);
  assert.strictEqual(r.status, 0, `comment exit ${r.status}\nstderr:\n${r.stderr}`);
  assert.strictEqual(calls(ctx).length, 1, 'exactly one gh call for issue-comment');
  let c = calls(ctx).pop();
  assert.deepStrictEqual(c.slice(0, 3), ['issue', 'comment', '42']);
  assert.ok(c.includes('--body-file') && c[argoAfter(c, '--body-file')] === '/tmp/handoff.md');

  // issue-edit: mutation, then verification re-read, curated four-field out.
  ctx = setupWithDocs('hic8b');
  fs.writeFileSync(ctx.ghOut, ISSUE_VIEW_PAYLOAD);
  r = runHelper(ctx, ['issue-edit', '42', '--add-label', 'blocked', '--milestone', 'SPEC-001']);
  assert.strictEqual(r.status, 0, `edit exit ${r.status}\nstderr:\n${r.stderr}`);
  let all = calls(ctx);
  assert.strictEqual(all.length, 2, 'mutation + verification re-read');
  c = all[0];
  assert.deepStrictEqual(c.slice(0, 3), ['issue', 'edit', '42']);
  assert.ok(c.includes('--add-label') && c.includes('--milestone'));
  assert.ok(c[c.lastIndexOf('--repo') + 1] === ENV_REPO, 'env repo last on the mutation');
  const reRead = all[1];
  assert.deepStrictEqual(
    reRead.slice(0, 5),
    ['issue', 'view', '42', '--json', 'number,title,state,url'],
    'verification re-read requests exactly the curated fields'
  );
  assert.ok(reRead[reRead.lastIndexOf('--repo') + 1] === ENV_REPO, 'env repo last on the re-read');
  const out = JSON.parse(r.stdout);
  assert.deepStrictEqual(
    Object.keys(out).sort(),
    ['number', 'state', 'title', 'url'],
    'issue-edit output is exactly the curated four-field contract'
  );
  assert.strictEqual(out.state, 'OPEN', 'post-edit state comes from the verification re-read');

  // issue-close: same mutate -> re-read -> curate contract.
  ctx = setupWithDocs('hic8c');
  fs.writeFileSync(ctx.ghOut, JSON.stringify({
    number: 42, title: 'Post-edit title from the re-read', state: 'CLOSED',
    url: 'https://github.com/env-owner/env-repo/issues/42',
  }));
  r = runHelper(ctx, ['issue-close', '42', '--comment', 'Completed and validated.']);
  assert.strictEqual(r.status, 0, `close exit ${r.status}\nstderr:\n${r.stderr}`);
  all = calls(ctx);
  assert.strictEqual(all.length, 2, 'mutation + verification re-read');
  assert.deepStrictEqual(all[0].slice(0, 3), ['issue', 'close', '42']);
  assert.ok(all[0].includes('--comment'));
  assert.deepStrictEqual(all[1].slice(0, 3), ['issue', 'view', '42']);
  const closed = JSON.parse(r.stdout);
  assert.strictEqual(closed.state, 'CLOSED', 'post-close state verified by the re-read');
  assert.strictEqual(closed.number, 42);
});

function argoAfter(call, flag) {
  return call.indexOf(flag) + 1;
}

// --- HIC-9: milestone-create ---------------------------------------------------

check('HIC-9: milestone-create sends title/description fields and curates output', () => {
  const ctx = setupWithDocs('hic9');
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
  const ctx = setupWithDocs('hic10');
  fs.writeFileSync(ctx.ghOut, MILESTONE_PAYLOAD);
  const r = runHelper(ctx, ['milestone-create', 'SPEC-003: Deliverable']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const c = calls(ctx)[0];
  assert.ok(argIndex(c, 'title=SPEC-003: Deliverable') !== -1, 'title -f must be sent');
  assert.ok(!c.some((a) => a.startsWith('description=')), 'no description field when omitted');
});

// --- HIC-11: milestone-list state handling -------------------------------------

check('HIC-11: milestone-list defaults to state=open and passes closed through', () => {
  const ctx = setupWithDocs('hic11');
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
  const ctx = setupWithDocs('hic12');
  const r = runHelper(ctx, ['milestone-list', 'bogus']);
  assert.notStrictEqual(r.status, 0, 'invalid state must fail');
  assert.ok(/Invalid milestone state/.test(r.stderr), 'friendly error expected');
  assert.deepStrictEqual(calls(ctx).length, 0, 'gh must not be called');
});

// --- HIC-13: milestone-edit ----------------------------------------------------

check('HIC-13: milestone-edit PATCHes with pass-through -f fields', () => {
  const ctx = setupWithDocs('hic13');
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
  const ctx = setupWithDocs('hic14');
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

check('HIC-16: helper writes only local records under the docs base; env stays byte-identical', () => {
  const ctx = setupWithDocs('hic16');
  const envPath = path.join(ctx.tmp, '.github-project.env');
  const before = fs.readFileSync(envPath, 'utf8');
  const mtimeBefore = fs.statSync(envPath).mtimeMs;
  const cwdBefore = fs.readdirSync(ctx.tmp).sort();
  const cases = [
    [['issue-create', 'T', '--body', 'b'], ISSUE_URL_OUT],
    [['issue-list'], '{"fields":[]}'],
    [['milestone-create', 'M', 'D'], MILESTONE_PAYLOAD],
    [['milestone-close', '3'], MILESTONE_PAYLOAD],
  ];
  for (const [args, out] of cases) {
    fs.writeFileSync(ctx.ghOut, out);
    assert.strictEqual(runHelper(ctx, args).status, 0, `${args[0]} must succeed`);
  }
  assert.strictEqual(fs.readFileSync(envPath, 'utf8'), before, 'env must stay byte-identical');
  assert.strictEqual(fs.statSync(envPath).mtimeMs, mtimeBefore, 'env must not be rewritten');
  assert.ok(!fs.existsSync(path.join(ctx.tmp, '.github-project.json')), 'no JSON config may appear');
  // Dual-record (T7): the only new files are local records under the docs
  // base; the repo working directory itself stays untouched.
  assert.deepStrictEqual(
    fs.readdirSync(ctx.tmp).sort(),
    cwdBefore,
    'helper must not write into the repo working directory'
  );
  const recordDirs = fs.readdirSync(ctx.docs).sort();
  assert.ok(
    recordDirs.every((d) => d === 'issue' || d === 'spec'),
    `all local writes confined to {issue,spec}/ (got: ${recordDirs})`
  );
});

// --- HIC-17: project subcommands stay env-only ---------------------------------

check('HIC-17: project subcommands reject positional owner/project arguments', () => {
  const ctx = setupWithDocs('hic17');
  for (const args of [
    ['list-statuses', 'Antpolis', '9'],
    ['list-items', 'Antpolis', '9', 'Ready'],
    ['item-id', 'Antpolis', '9', '42'],
    // #46 extension: the new board/project query commands take no
    // positional owner either (project-* owner is a --owner flag only).
    ['list-unassigned', 'Antpolis', '9'],
    ['item-state', 'Antpolis', '9'],
    ['next-status', 'Antpolis', '9', 'Ready', 'In Progress'],
    ['project-list', 'Antpolis'],
    ['project-view', 'Antpolis', '9'],
    ['project-field-list', 'Antpolis', '9'],
  ]) {
    const r = runHelper(ctx, args);
    assert.notStrictEqual(r.status, 0, `${args.join(' ')} must be rejected (env-only)`);
    assert.deepStrictEqual(calls(ctx).length, 0, 'gh must not be called');
  }
});

// --- PRC-1: usage lists pr-* subcommands; positionals enforced ------------------

check('PRC-1: usage lists every pr-* subcommand and enforces required positionals', () => {
  const ctx = setupWithDocs('prc1');
  const usage = runHelper(ctx, []);
  assert.notStrictEqual(usage.status, 0, 'no-args must exit non-zero');
  for (const sub of [
    'pr-create', 'pr-view', 'pr-list', 'pr-comment',
    'pr-close', 'pr-merge', 'pr-checks', 'pr-review-reply',
  ]) {
    assert.ok(usage.stdout.includes(sub), `usage must list ${sub}`);
  }
  for (const args of [
    ['pr-create'],
    ['pr-view'],
    ['pr-comment'],
    ['pr-close'],
    ['pr-merge'],
    ['pr-checks'],
    ['pr-review-reply'],
    ['pr-review-reply', 'IC_kwDOAGcCyM4Bdw3L_only-one-arg'],
  ]) {
    const r = runHelper(ctx, args);
    assert.notStrictEqual(r.status, 0, `${args.join(' ')} must fail without its required positional`);
    assert.deepStrictEqual(calls(ctx).length, 0, 'gh must not be called on a usage error');
  }
});

// --- PRC-2: pr-create -----------------------------------------------------------

check('PRC-2: pr-create sends title + extras; curated output reuses the URL response', () => {
  const ctx = setupWithDocs('prc2');
  fs.writeFileSync(ctx.ghOut, PR_URL_OUT); // the underlying command prints the PR URL
  const r = runHelper(ctx, [
    'pr-create', 'SPEC-003-T1: Extend helper with PR subcommands',
    '--base', 'master', '--head', 'feat/spec-003-t1', '--body-file', '/tmp/pr.md',
  ]);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const all = calls(ctx);
  assert.strictEqual(all.length, 1, 'exactly one gh call (URL response reused, no re-read)');
  const c = all[0];
  assert.deepStrictEqual(c.slice(0, 2), ['pr', 'create']);
  const t = argIndex(c, '--title');
  assert.ok(t !== -1 && c[t + 1] === 'SPEC-003-T1: Extend helper with PR subcommands', `title positional must reach --title: ${c.join(' ')}`);
  assert.ok(c.includes('--base') && c[c.indexOf('--base') + 1] === 'master', 'base flag passes through');
  assert.ok(c.includes('--head') && c[c.indexOf('--head') + 1] === 'feat/spec-003-t1', 'head flag passes through');
  assert.ok(c.includes('--body-file') && c.includes('/tmp/pr.md'), 'body file passes through');
  const repo = argIndex(c, '--repo');
  assert.ok(repo !== -1 && c[repo + 1] === ENV_REPO, `env repo must be sent: ${c.join(' ')}`);
  const out = JSON.parse(r.stdout);
  assert.deepStrictEqual(
    Object.keys(out).sort(),
    ['number', 'state', 'title', 'url'],
    'pr-create output is exactly the curated four-field contract'
  );
  assert.strictEqual(out.number, 88, 'number parsed from the mutation URL response');
  assert.strictEqual(out.state, 'OPEN', 'a freshly created PR is deterministically OPEN');
  assert.strictEqual(out.url, 'https://github.com/env-owner/env-repo/pull/88');
});

// --- PRC-3: pass-through --repo never wins (pr-list) ----------------------------

check('PRC-3: a pass-through --repo can never override the env repo (pr-list)', () => {
  const ctx = setupWithDocs('prc3');
  const r = runHelper(ctx, ['pr-list', '--repo', 'rogue/rogue']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const c = calls(ctx)[0];
  const last = c.lastIndexOf('--repo');
  assert.ok(last !== -1 && c[last + 1] === ENV_REPO, `env repo must be the final --repo: ${c.join(' ')}`);
});

// --- PRC-4: pr-view curated default ---------------------------------------------

check('PRC-4: pr-view prints curated JSON by default', () => {
  const ctx = setupWithDocs('prc4');
  const r = runHelper(ctx, ['pr-view', '45']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const c = calls(ctx)[0];
  assert.deepStrictEqual(c.slice(0, 3), ['pr', 'view', '45']);
  const j = argIndex(c, '--json');
  assert.ok(j !== -1, `default --json must be present: ${c.join(' ')}`);
  assert.strictEqual(
    c[j + 1],
    'number,title,state,body,headRefName,baseRefName,author,labels,reviewDecision,isDraft,url',
    'curated pr-view fields'
  );
  assert.ok(c[c.lastIndexOf('--repo') + 1] === ENV_REPO, 'env repo must be sent');
});

// --- PRC-5: pr-view --comments skips the default --------------------------------

check('PRC-5: pr-view --comments skips the curated default', () => {
  const ctx = setupWithDocs('prc5');
  const r = runHelper(ctx, ['pr-view', '45', '--comments']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const c = calls(ctx)[0];
  assert.ok(!c.includes('--json'), `caller shape must win: ${c.join(' ')}`);
  assert.ok(c.includes('--comments') && c.includes(ENV_REPO));
});

// --- PRC-6: pr-list curated default + filters ------------------------------------

check('PRC-6: pr-list prints curated JSON by default; filters pass through', () => {
  const ctx = setupWithDocs('prc6');
  const r = runHelper(ctx, ['pr-list', '--state', 'closed', '--label', 'role:builder']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const c = calls(ctx)[0];
  assert.deepStrictEqual(c.slice(0, 2), ['pr', 'list']);
  const j = argIndex(c, '--json');
  assert.strictEqual(
    j !== -1 ? c[j + 1] : '',
    'number,title,state,headRefName,baseRefName,author,isDraft,updatedAt,url',
    'curated pr-list fields'
  );
  assert.ok(c.includes('--state') && c[c.indexOf('--state') + 1] === 'closed', 'state filter passes through');
  assert.ok(c.includes('--label') && c[c.indexOf('--label') + 1] === 'role:builder', 'label filter passes through');
  assert.ok(c[c.lastIndexOf('--repo') + 1] === ENV_REPO, 'env repo last on every call');
});

// --- PRC-7: pr-comment thin pass-through -----------------------------------------

check('PRC-7: pr-comment is a thin pass-through', () => {
  const ctx = setupWithDocs('prc7');
  const r = runHelper(ctx, ['pr-comment', '45', '--body-file', '/tmp/handoff.md']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const c = calls(ctx)[0];
  assert.deepStrictEqual(c.slice(0, 3), ['pr', 'comment', '45']);
  assert.ok(c.includes('--body-file') && c[c.indexOf('--body-file') + 1] === '/tmp/handoff.md');
  assert.ok(c[c.lastIndexOf('--repo') + 1] === ENV_REPO, 'env repo last on every call');
});

// --- PRC-8: pr-close / pr-merge mutate, re-read, curate -------------------------

check('PRC-8: pr-close / pr-merge mutate then re-read; no --admin injected', () => {
  const ctx = setupWithDocs('prc8');
  fs.writeFileSync(ctx.ghOut, PR_VIEW_PAYLOAD('CLOSED'));
  let r = runHelper(ctx, ['pr-close', '45', '--comment', 'Superseded by #46.']);
  assert.strictEqual(r.status, 0, `close exit ${r.status}\nstderr:\n${r.stderr}`);
  let all = calls(ctx);
  assert.strictEqual(all.length, 2, 'mutation + verification re-read');
  let c = all[0];
  assert.deepStrictEqual(c.slice(0, 3), ['pr', 'close', '45']);
  assert.ok(c.includes('--comment'), 'close flags pass through');
  assert.ok(!c.includes('--admin'), 'close must never inject --admin');
  assert.ok(c[c.lastIndexOf('--repo') + 1] === ENV_REPO, 'env repo last on the mutation');
  assert.deepStrictEqual(
    all[1].slice(0, 5),
    ['pr', 'view', '45', '--json', 'number,title,state,url'],
    'verification re-read requests exactly the curated fields'
  );
  let out = JSON.parse(r.stdout);
  assert.deepStrictEqual(
    Object.keys(out).sort(),
    ['number', 'state', 'title', 'url'],
    'pr-close output is exactly the curated four-field contract'
  );
  assert.strictEqual(out.state, 'CLOSED', 'post-close state comes from the verification re-read');

  const ctx2 = setupWithDocs('prc8b');
  fs.writeFileSync(ctx2.ghOut, PR_VIEW_PAYLOAD('MERGED'));
  r = runHelper(ctx2, ['pr-merge', '45', '--squash', '--delete-branch']);
  assert.strictEqual(r.status, 0, `merge exit ${r.status}\nstderr:\n${r.stderr}`);
  all = calls(ctx2);
  assert.strictEqual(all.length, 2, 'mutation + verification re-read');
  c = all[0];
  assert.deepStrictEqual(c.slice(0, 3), ['pr', 'merge', '45']);
  assert.ok(c.includes('--squash') && c.includes('--delete-branch'), 'merge flags pass through');
  assert.ok(!c.includes('--admin'), 'merge must never inject --admin');
  assert.ok(c[c.lastIndexOf('--repo') + 1] === ENV_REPO, 'env repo last on the mutation');
  out = JSON.parse(r.stdout);
  assert.strictEqual(out.state, 'MERGED', 'post-merge state comes from the verification re-read');
  assert.strictEqual(out.number, 45);
});

// --- PRC-9: pr-checks curates tabular output into JSON ----------------------------

check('PRC-9: pr-checks curates the tabular output into JSON by default; --web takes over', () => {
  const ctx = setupWithDocs('prc9');
  fs.writeFileSync(
    ctx.ghOut,
    'Analyze (javascript-typescript)\tpass\t50s\thttps://example.com/job/1\t\n' +
      'CodeQL\tpass\t2s\thttps://example.com/runs/2\t\n'
  );
  const r = runHelper(ctx, ['pr-checks', '45']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const c = calls(ctx)[0];
  assert.deepStrictEqual(c.slice(0, 3), ['pr', 'checks', '45']);
  assert.ok(!c.includes('--json'), 'gh pr checks has no --json; curation is helper-side');
  assert.ok(c[c.lastIndexOf('--repo') + 1] === ENV_REPO, 'env repo last on every call');
  assert.deepStrictEqual(JSON.parse(r.stdout), [
    { name: 'Analyze (javascript-typescript)', status: 'pass', elapsed: '50s', url: 'https://example.com/job/1' },
    { name: 'CodeQL', status: 'pass', elapsed: '2s', url: 'https://example.com/runs/2' },
  ], 'tabular checks output must become curated JSON');

  const r2 = runHelper(ctx, ['pr-checks', '45', '--web']);
  assert.strictEqual(r2.status, 0, `web exit ${r2.status}\nstderr:\n${r2.stderr}`);
  const c2 = calls(ctx)[1];
  assert.ok(c2.includes('--web'), 'explicit format flag takes over');
  assert.ok(!r2.stdout.trim().startsWith('['), 'no helper-side curation when the caller shapes output');
});

// --- PRC-10: pr-review-reply fixed parameterized GraphQL --------------------------

check('PRC-10: pr-review-reply uses the fixed parameterized GraphQL mutation', () => {
  const ctx = setupWithDocs('prc10');
  const commentId = 'IC_kwDOAGcCyM4Bdw3L123456';
  const body = 'Fixed in commit abc123 — retested locally';
  const r = runHelper(ctx, ['pr-review-reply', commentId, body]);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const all = calls(ctx);
  assert.strictEqual(all.length, 1, 'exactly one gh call');
  const c = all[0];
  assert.deepStrictEqual(c.slice(0, 2), ['api', 'graphql']);
  assert.strictEqual(c.filter((a) => a === '-f').length, 3, 'exactly query/commentId/body as -f string fields');
  const qIdx = c.findIndex((a) => a.startsWith('query='));
  assert.ok(qIdx !== -1, 'query field must be sent');
  const q = c[qIdx];
  assert.ok(q.startsWith('query=mutation($commentId: ID!, $body: String!) {'), 'fixed mutation signature');
  assert.ok(q.includes('addPullRequestReviewCommentReply(input: {'), 'fixed reply mutation name');
  assert.ok(q.includes('pullRequestReviewCommentId: $commentId'), 'comment id is a GraphQL variable');
  assert.ok(q.includes('body: $body'), 'body is a GraphQL variable');
  assert.ok(!q.includes(commentId), 'comment id must never be interpolated into the query text');
  assert.ok(!q.includes(body) && !q.includes('retested'), 'reply body must never be interpolated into the query text');
  assert.ok(c.includes(`commentId=${commentId}`), 'comment id travels as a variable field');
  assert.ok(c.includes(`body=${body}`), 'reply body travels as a variable field');
});

// --- PRC-11: missing repo fails fast (pr-*) ----------------------------------------

check('PRC-11: missing ANT_TEAM_GITHUB_REPO fails fast without calling gh (pr-*)', () => {
  const ctx = setup('prc11', null); // no env file at all
  const r = runHelper(ctx, ['pr-list']);
  assert.notStrictEqual(r.status, 0, 'pr-list must fail without a repo');
  assert.ok(r.stderr.includes('ANT_TEAM_GITHUB_REPO'), 'error must name the env key');
  assert.deepStrictEqual(calls(ctx).length, 0, 'gh must not be called');

  const r2 = runHelper(ctx, ['pr-review-reply', 'IC_x', 'reply body']);
  assert.notStrictEqual(r2.status, 0, 'pr-review-reply must also require the env repo');
  assert.ok(r2.stderr.includes('ANT_TEAM_GITHUB_REPO'), 'error must name the env key');
  assert.deepStrictEqual(calls(ctx).length, 0, 'gh must not be called');
});

// --- CIC-1: usage lists run-*/workflow-* subcommands; positionals enforced -----

check('CIC-1: usage lists every run-*/workflow-* subcommand and enforces required positionals', () => {
  const ctx = setupWithDocs('cic1');
  const usage = runHelper(ctx, []);
  assert.notStrictEqual(usage.status, 0, 'no-args must exit non-zero');
  for (const sub of ['run-list', 'run-view', 'workflow-list', 'workflow-run']) {
    assert.ok(usage.stdout.includes(sub), `usage must list ${sub}`);
  }
  for (const args of [
    ['run-view'],
    ['workflow-run'],
  ]) {
    const r = runHelper(ctx, args);
    assert.notStrictEqual(r.status, 0, `${args.join(' ')} must fail without its required positional`);
    assert.deepStrictEqual(calls(ctx).length, 0, 'gh must not be called on a usage error');
  }
});

// --- CIC-2: run-list curated default + filters ----------------------------------

check('CIC-2: run-list prints curated JSON by default; filters pass through', () => {
  const ctx = setupWithDocs('cic2');
  const r = runHelper(ctx, ['run-list', '--workflow', 'ci.yml', '--limit', '5', '--status', 'failure']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const c = calls(ctx)[0];
  assert.deepStrictEqual(c.slice(0, 2), ['run', 'list']);
  const j = argIndex(c, '--json');
  assert.strictEqual(
    j !== -1 ? c[j + 1] : '',
    'number,displayTitle,workflowName,status,conclusion,event,headBranch,createdAt,updatedAt,url',
    'curated run-list fields'
  );
  assert.ok(c.includes('--workflow') && c[c.indexOf('--workflow') + 1] === 'ci.yml', 'workflow filter passes through');
  assert.ok(c.includes('--limit') && c.includes('5'), 'limit filter passes through');
  assert.ok(c.includes('--status') && c[c.indexOf('--status') + 1] === 'failure', 'status filter passes through');
  assert.ok(c[c.lastIndexOf('--repo') + 1] === ENV_REPO, 'env repo last on every call');
});

// --- CIC-3: run-view curated default (exact argv) -------------------------------

check('CIC-3: run-view prints curated JSON by default', () => {
  const ctx = setupWithDocs('cic3');
  const r = runHelper(ctx, ['run-view', '1234567890']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const c = calls(ctx)[0];
  assert.deepStrictEqual(
    c.slice(0, 5),
    ['run', 'view', '1234567890', '--json', 'number,displayTitle,workflowName,status,conclusion,event,headBranch,headSha,createdAt,updatedAt,url'],
    'exact curated run-view argv'
  );
  assert.ok(c[c.lastIndexOf('--repo') + 1] === ENV_REPO, 'env repo last on every call');
});

// --- CIC-4: caller format flags take over ---------------------------------------

check('CIC-4: caller format flags take over (run-view --web, run-list custom --json)', () => {
  const ctx = setupWithDocs('cic4');
  let r = runHelper(ctx, ['run-view', '1234567890', '--web']);
  assert.strictEqual(r.status, 0, `web exit ${r.status}\nstderr:\n${r.stderr}`);
  let c = calls(ctx)[0];
  assert.ok(!c.includes('--json'), `caller shape must win: ${c.join(' ')}`);
  assert.ok(c.includes('--web') && c.includes(ENV_REPO));

  r = runHelper(ctx, ['run-list', '--json', 'number,status']);
  assert.strictEqual(r.status, 0, `json exit ${r.status}\nstderr:\n${r.stderr}`);
  c = calls(ctx)[1];
  assert.strictEqual(c.filter((a) => a === '--json').length, 1, 'exactly the caller --json');
  assert.ok(c.includes('number,status'), 'caller fields pass through');
  assert.ok(!c.includes('displayTitle'), 'curated default must not leak into caller --json');
});

// --- CIC-5: workflow-list curated default ---------------------------------------

check('CIC-5: workflow-list prints curated JSON by default; --all passes through', () => {
  const ctx = setupWithDocs('cic5');
  const r = runHelper(ctx, ['workflow-list', '--all']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const c = calls(ctx)[0];
  assert.deepStrictEqual(
    c.slice(0, 4),
    ['workflow', 'list', '--json', 'id,name,path,state'],
    'exact curated workflow-list argv (gh 2.45 supports exactly these JSON fields)'
  );
  assert.ok(c.includes('--all'), '--all passes through');
  assert.ok(c[c.lastIndexOf('--repo') + 1] === ENV_REPO, 'env repo last on every call');
});

// --- CIC-6: workflow-run dispatch, caller flags only ----------------------------

check('CIC-6: workflow-run dispatches caller flags only; curated dispatch summary out', () => {
  const ctx = setupWithDocs('cic6');
  const r = runHelper(ctx, ['workflow-run', 'ci.yml', '--ref', 'feat/issue-32', '-f', 'suite=smoke']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const all = calls(ctx);
  assert.strictEqual(all.length, 1, 'exactly one gh call — no invented run read after dispatch');
  const c = all[0];
  assert.deepStrictEqual(c.slice(0, 3), ['workflow', 'run', 'ci.yml']);
  assert.ok(c.includes('--ref') && c[c.indexOf('--ref') + 1] === 'feat/issue-32', 'ref flag passes through');
  assert.ok(c.includes('-f') && c[c.indexOf('-f') + 1] === 'suite=smoke', 'raw input fields pass through');
  assert.ok(!c.includes('--admin'), 'dispatch must never inject --admin');
  assert.ok(c[c.lastIndexOf('--repo') + 1] === ENV_REPO, 'env repo last on every call');
  const out = JSON.parse(r.stdout);
  assert.deepStrictEqual(
    Object.keys(out).sort(),
    ['repo', 'status', 'workflow'],
    'workflow-run output is exactly the curated dispatch summary'
  );
  assert.strictEqual(out.workflow, 'ci.yml');
  assert.strictEqual(out.repo, ENV_REPO);
  assert.strictEqual(out.status, 'dispatched');
});

// --- CIC-7: pass-through --repo never wins (run/workflow) -----------------------

check('CIC-7: a pass-through --repo can never override the env repo (run/workflow)', () => {
  const ctx = setupWithDocs('cic7');
  for (const args of [
    ['run-list', '--repo', 'rogue/rogue'],
    ['workflow-list', '--repo', 'rogue/rogue'],
    ['workflow-run', 'ci.yml', '--repo', 'rogue/rogue'],
    ['run-view', '1234567890', '--repo', 'rogue/rogue'],
  ]) {
    const r = runHelper(ctx, args);
    assert.strictEqual(r.status, 0, `${args.join(' ')} exit ${r.status}\nstderr:\n${r.stderr}`);
    const c = calls(ctx).pop();
    const last = c.lastIndexOf('--repo');
    assert.ok(last !== -1 && c[last + 1] === ENV_REPO, `env repo must be the final --repo: ${c.join(' ')}`);
  }
});

// --- CIC-8: missing repo fails fast (run/workflow) ------------------------------

check('CIC-8: missing ANT_TEAM_GITHUB_REPO fails fast without calling gh (run/workflow)', () => {
  const ctx = setup('cic8', null); // no env file at all
  for (const args of [
    ['run-list'],
    ['run-view', '1234567890'],
    ['workflow-list'],
    ['workflow-run', 'ci.yml'],
  ]) {
    const r = runHelper(ctx, args);
    assert.notStrictEqual(r.status, 0, `${args.join(' ')} must fail without a repo`);
    assert.ok(r.stderr.includes('ANT_TEAM_GITHUB_REPO'), 'error must name the env key');
  }
  assert.deepStrictEqual(calls(ctx).length, 0, 'gh must not be called');
});

// --- RLC-1: usage lists release-* subcommands; positionals enforced -------------

check('RLC-1: usage lists every release-* subcommand and enforces required positionals', () => {
  const ctx = setupWithDocs('rlc1');
  const usage = runHelper(ctx, []);
  assert.notStrictEqual(usage.status, 0, 'no-args must exit non-zero');
  for (const sub of [
    'release-create', 'release-list', 'release-view', 'release-edit', 'release-delete',
  ]) {
    assert.ok(usage.stdout.includes(sub), `usage must list ${sub}`);
  }
  for (const args of [
    ['release-create'],
    ['release-view'],
    ['release-edit'],
    ['release-delete'],
  ]) {
    const r = runHelper(ctx, args);
    assert.notStrictEqual(r.status, 0, `${args.join(' ')} must fail without its required positional`);
    assert.deepStrictEqual(calls(ctx).length, 0, 'gh must not be called on a usage error');
  }
});

// --- RLC-2: release-create -------------------------------------------------------

check('RLC-2: release-create mutates then re-reads; curated release shape out', () => {
  const ctx = setupWithDocs('rlc2');
  fs.writeFileSync(ctx.ghOut, RELEASE_VIEW_PAYLOAD);
  const r = runHelper(ctx, [
    'release-create', 'v1.2.0', '--title', 'v1.2.0 — ant-teams',
    '--notes-file', '/tmp/notes.md', '--target', 'master',
  ]);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const all = calls(ctx);
  assert.strictEqual(all.length, 2, 'mutation + verification re-read');
  const c = all[0];
  assert.deepStrictEqual(c.slice(0, 3), ['release', 'create', 'v1.2.0'], 'tag positional must come first');
  assert.ok(c.includes('--title') && c[c.indexOf('--title') + 1] === 'v1.2.0 — ant-teams', 'title flag passes through');
  assert.ok(c.includes('--notes-file') && c[c.indexOf('--notes-file') + 1] === '/tmp/notes.md', 'notes file passes through');
  assert.ok(c.includes('--target') && c[c.indexOf('--target') + 1] === 'master', 'target flag passes through');
  const repo = argIndex(c, '--repo');
  assert.ok(repo !== -1 && c[repo + 1] === ENV_REPO, `env repo must be sent: ${c.join(' ')}`);
  const reRead = all[1];
  assert.deepStrictEqual(reRead.slice(0, 3), ['release', 'view', 'v1.2.0'], 'verification re-read targets the tag');
  assert.ok(reRead[reRead.lastIndexOf('--repo') + 1] === ENV_REPO, 'env repo last on the re-read');
  const out = JSON.parse(r.stdout);
  assert.strictEqual(out.tagName, 'v1.2.0');
  assert.strictEqual(out.name, 'v1.2.0 — ant-teams');
  assert.strictEqual(out.url, 'https://github.com/env-owner/env-repo/releases/tag/v1.2.0');
  assert.strictEqual(out.node_id, undefined, 'curated output must drop raw payload fields');
});

// --- RLC-3: release-list curated default + filters ------------------------------

check('RLC-3: release-list prints curated JSON by default; filters pass through', () => {
  const ctx = setupWithDocs('rlc3');
  const r = runHelper(ctx, ['release-list', '--limit', '5']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const c = calls(ctx)[0];
  assert.deepStrictEqual(
    c.slice(0, 4),
    ['release', 'list', '--json', 'name,tagName,isDraft,isPrerelease,isLatest,createdAt,publishedAt'],
    'exact curated release-list argv (gh 2.45 supports exactly these JSON fields; no url)'
  );
  assert.ok(c.includes('--limit') && c[c.indexOf('--limit') + 1] === '5', 'limit filter passes through');
  assert.ok(c[c.lastIndexOf('--repo') + 1] === ENV_REPO, 'env repo last on every call');
});

// --- RLC-4: release-view curated default (exact argv) ---------------------------

check('RLC-4: release-view prints curated JSON by default', () => {
  const ctx = setupWithDocs('rlc4');
  const r = runHelper(ctx, ['release-view', 'v1.2.0']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const c = calls(ctx)[0];
  assert.deepStrictEqual(
    c.slice(0, 5),
    ['release', 'view', 'v1.2.0', '--json', 'name,tagName,targetCommitish,isDraft,isPrerelease,createdAt,publishedAt,author,body,url'],
    'exact curated release-view argv'
  );
  assert.ok(c[c.lastIndexOf('--repo') + 1] === ENV_REPO, 'env repo last on every call');
});

// --- RLC-5: caller format flags take over ---------------------------------------

check('RLC-5: caller format flags take over (release-view --web, release-list custom --json)', () => {
  const ctx = setupWithDocs('rlc5');
  let r = runHelper(ctx, ['release-view', 'v1.2.0', '--web']);
  assert.strictEqual(r.status, 0, `web exit ${r.status}\nstderr:\n${r.stderr}`);
  let c = calls(ctx)[0];
  assert.ok(!c.includes('--json'), `caller shape must win: ${c.join(' ')}`);
  assert.ok(c.includes('--web') && c.includes(ENV_REPO));

  r = runHelper(ctx, ['release-list', '--json', 'name,tagName']);
  assert.strictEqual(r.status, 0, `json exit ${r.status}\nstderr:\n${r.stderr}`);
  c = calls(ctx)[1];
  assert.strictEqual(c.filter((a) => a === '--json').length, 1, 'exactly the caller --json');
  assert.ok(c.includes('name,tagName'), 'caller fields pass through');
  assert.ok(!c.includes('isLatest'), 'curated default must not leak into caller --json');
});

// --- RLC-6: release-edit mutates then re-reads -----------------------------------

check('RLC-6: release-edit mutates then re-reads; curated release shape out', () => {
  const ctx = setupWithDocs('rlc6');
  fs.writeFileSync(ctx.ghOut, RELEASE_VIEW_PAYLOAD);
  const r = runHelper(ctx, ['release-edit', 'v1.2.0', '--notes', 'Revised release notes.']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const all = calls(ctx);
  assert.strictEqual(all.length, 2, 'mutation + verification re-read');
  const c = all[0];
  assert.deepStrictEqual(c.slice(0, 3), ['release', 'edit', 'v1.2.0']);
  assert.ok(c.includes('--notes') && c[c.indexOf('--notes') + 1] === 'Revised release notes.', 'edit flags pass through');
  assert.ok(c[c.lastIndexOf('--repo') + 1] === ENV_REPO, 'env repo last on the mutation');
  assert.deepStrictEqual(all[1].slice(0, 3), ['release', 'view', 'v1.2.0'], 'verification re-read');
  const out = JSON.parse(r.stdout);
  assert.strictEqual(out.tagName, 'v1.2.0');
  assert.strictEqual(out.body, 'Release notes body.');
  assert.strictEqual(out.node_id, undefined, 'curated output must drop raw payload fields');
});

// --- RLC-7: release-delete caller flags only ------------------------------------

check('RLC-7: release-delete passes caller flags only; curated summary, no re-read', () => {
  const ctx = setupWithDocs('rlc7');
  const r = runHelper(ctx, ['release-delete', 'v1.2.0', '--cleanup-tag']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const all = calls(ctx);
  assert.strictEqual(all.length, 1, 'exactly one gh call — a deleted release cannot be re-read');
  const c = all[0];
  assert.deepStrictEqual(c.slice(0, 3), ['release', 'delete', 'v1.2.0']);
  assert.ok(c.includes('--cleanup-tag'), 'caller flags pass through');
  assert.ok(!c.includes('--admin'), 'delete must never inject --admin');
  assert.ok(!c.includes('--yes') && !c.includes('-y'), 'delete must never default the --yes auto-confirm');
  assert.ok(c[c.lastIndexOf('--repo') + 1] === ENV_REPO, 'env repo last on every call');
  const out = JSON.parse(r.stdout);
  assert.deepStrictEqual(
    Object.keys(out).sort(),
    ['deleted', 'tagName', 'url'],
    'release-delete output is exactly the curated deletion summary'
  );
  assert.strictEqual(out.tagName, 'v1.2.0');
  assert.strictEqual(out.url, `https://github.com/${ENV_REPO}/releases/tag/v1.2.0`);
  assert.strictEqual(out.deleted, true);
});

// --- RLC-8: pass-through --repo never wins (release-*) --------------------------

check('RLC-8: a pass-through --repo can never override the env repo (release-*)', () => {
  const ctx = setupWithDocs('rlc8');
  for (const args of [
    ['release-list', '--repo', 'rogue/rogue'],
    ['release-view', 'v1.2.0', '--repo', 'rogue/rogue'],
    ['release-create', 'v1.2.0', '--repo', 'rogue/rogue'],
    ['release-edit', 'v1.2.0', '--repo', 'rogue/rogue'],
    ['release-delete', 'v1.2.0', '--repo', 'rogue/rogue'],
  ]) {
    const r = runHelper(ctx, args);
    assert.strictEqual(r.status, 0, `${args.join(' ')} exit ${r.status}\nstderr:\n${r.stderr}`);
    const c = calls(ctx).pop();
    const last = c.lastIndexOf('--repo');
    assert.ok(last !== -1 && c[last + 1] === ENV_REPO, `env repo must be the final --repo: ${c.join(' ')}`);
  }
});

// --- RLC-9: invalid canonical tags fail before gh (create/edit/delete) ----------

check('RLC-9: invalid canonical tags fail before gh is invoked (create/edit/delete)', () => {
  const ctx = setupWithDocs('rlc9');
  const invalidTags = [
    '-v1',        // leading dash (positional safety)
    '.v1',        // leading dot
    'v1.',        // trailing dot
    'v1.lock',    // trailing .lock
    '/v1',        // leading slash
    'v1/',        // trailing slash
    'a//b',       // empty path component
    'a..b',       // consecutive dots
    '@',          // lone at
    'a@{b',       // reflog shorthand
    'v 1',        // whitespace
    'a~b', 'a^b', 'a:b', 'a?b', 'a*b', 'a[b', 'a\\b', // ref magic characters
  ];
  for (const cmd of ['release-create', 'release-edit', 'release-delete']) {
    for (const tag of invalidTags) {
      const r = runHelper(ctx, [cmd, tag]);
      assert.notStrictEqual(r.status, 0, `${cmd} ${tag} must fail`);
      assert.ok(
        /Invalid release tag/.test(r.stderr),
        `${cmd} ${tag} must name the invalid release tag (got: ${r.stderr.trim()})`
      );
    }
  }
  const ghCalls = calls(ctx);
  assert.deepStrictEqual(ghCalls.length, 0, `gh must never be called for invalid tags (got ${ghCalls.length} calls)`);
});

// --- RLC-10: valid canonical tags reach gh untouched ----------------------------

check('RLC-10: valid canonical tags reach gh untouched; create then verify re-read', () => {
  const ctx = setupWithDocs('rlc10');
  fs.writeFileSync(ctx.ghOut, RELEASE_VIEW_PAYLOAD);
  // NOTE: tags containing ']' round-trip gh fine but cannot be asserted
  // here because the fake-gh log parser splits args on brackets.
  const validTags = ['v1', 'v1.0.0', 'v1.0.0-rc.1', 'rel/2026-08-23', 'build.42', 'a@b'];
  for (const tag of validTags) {
    const r = runHelper(ctx, ['release-create', tag]);
    assert.strictEqual(r.status, 0, `release-create ${tag} exit ${r.status}\nstderr:\n${r.stderr}`);
    const createCalls = calls(ctx).filter((x) => x[1] === 'create');
    const c = createCalls[createCalls.length - 1];
    assert.deepStrictEqual(c.slice(0, 3), ['release', 'create', tag], `valid tag must pass through: ${c.join(' ')}`);
    assert.ok(c[c.lastIndexOf('--repo') + 1] === ENV_REPO, 'env repo last on the mutation');
    const last = calls(ctx).pop();
    assert.deepStrictEqual(last.slice(0, 3), ['release', 'view', tag], 'verification re-read targets the same tag');
    JSON.parse(r.stdout); // curated release-shaped JSON out
  }
});

// --- RLC-11: missing repo fails fast (release-*) --------------------------------

check('RLC-11: missing ANT_TEAM_GITHUB_REPO fails fast without calling gh (release-*)', () => {
  const ctx = setup('rlc11', null); // no env file at all
  for (const args of [
    ['release-list'],
    ['release-create', 'v1.2.0'],
    ['release-view', 'v1.2.0'],
    ['release-edit', 'v1.2.0'],
    ['release-delete', 'v1.2.0'],
  ]) {
    const r = runHelper(ctx, args);
    assert.notStrictEqual(r.status, 0, `${args.join(' ')} must fail without a repo`);
    assert.ok(r.stderr.includes('ANT_TEAM_GITHUB_REPO'), 'error must name the env key');
  }
  assert.deepStrictEqual(calls(ctx).length, 0, 'gh must not be called');
});

// --- summary -------------------------------------------------------------------

console.log(`\n${passed} passed, ${failed} failed (gh_project_helper env-only issue/PR/run/workflow/release/milestone subcommands)`);
if (failed > 0) process.exit(1);
