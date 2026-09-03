#!/usr/bin/env node
'use strict';

/*
 * tests/test_gh_project_helper_hardening.js — founder-direct
 * gh-helper-hardening contract (2026-09-03, no linked issue; task key
 * gh-helper-hardening).
 *
 * Locks the five approved hardening items for the board engine:
 *
 *   HARD-1  pagination-safe listing: the shared GraphQL engine follows
 *           pageInfo cursor pages; a two-page board is fully listed and
 *           the follow-up request carries after: $cursor (matched by
 *           option id, never by display name)
 *   HARD-2  pagination is BOUNDED: an always-next board stops at the page
 *           bound with a stderr truncation warning; collected items are
 *           still printed
 *   HARD-3  idempotent set-status: an item already in the requested state
 *           (matched by option id) performs ZERO item-edit mutations and
 *           still prints the verified curated object
 *   HARD-4  verified mutation: an item-edit that leaves the board state
 *           unchanged exits non-zero with the actual board state on
 *           stderr and prints no curated success object
 *   HARD-5  next-status precondition pass: the item sits in the claimed
 *           CURRENT state (option id match under a legacy remote display
 *           name) and transitions to NEXT with the same verified output
 *   HARD-6  next-status precondition fail: the item is NOT in the claimed
 *           CURRENT state — non-zero, zero mutations, stderr names the
 *           actual board state and points at item-state recovery
 *   HARD-7  read-only item-state recovery: prints
 *           {item_id, issue_number, title, state, url, canonical_state};
 *           canonical_state reverse-maps the option id via env pins (so a
 *           legacy remote display name reports its canonical state), null
 *           for an unknown option id; not-found exits non-zero; option
 *           ids never leak into output
 *   HARD-8  bounded read-only retry: a rate-limited GraphQL read fails
 *           twice then succeeds — the engine retries, then succeeds
 *   HARD-9  exhausted retries: a persistently rate-limited read exits 3
 *           (retryable) after exactly 3 attempts
 *   HARD-10 mutations are never retried: a transient-looking item-edit
 *           failure is attempted exactly once and fails immediately
 *   HARD-11 non-transient read failures are not retried: a hard GraphQL
 *           error fails on the first attempt with gh's exit code
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

// Fixture constants. Remote option display names come from THIS fixture
// only — assertions reference the fixture constant, never an assumption
// that the remote name equals the canonical name (guardrail: remote names
// are never hardcoded in helper output or docs).
const FIELD_ID = 'PVTFS_testFieldId';
const PROJECT_ID = 'PVT_testProjectId';
const OPT_BACKLOG = 'PVTFS_optBacklogCanonical';
const OPT_READY = 'PVTFS_optReady';
const OPT_IN_PROGRESS = 'PVTFS_optInProgress';
// Illustrative legacy remote rename of the canonical Backlog state: the
// remote board still displays this name while the option id is stable.
const REMOTE_BACKLOG_NAME = 'Shaping';
const REMOTE_READY_NAME = 'Ready';
const REMOTE_IN_PROGRESS_NAME = 'In Progress';

const ENV_LINES = [
  "export ANT_TEAM_GITHUB_REPO='env-owner/env-repo'",
  "export ANT_TEAM_GITHUB_OWNER='env-owner'",
  "export ANT_TEAM_GITHUB_PROJECT_NUMBER='9'",
  `export ANT_TEAM_GITHUB_PROJECT_ID='${PROJECT_ID}'`,
  `export ANT_TEAM_GITHUB_WORKFLOW_STATE_FIELD_ID='${FIELD_ID}'`,
  `export ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_BACKLOG_ID='${OPT_BACKLOG}'`,
  `export ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_READY_ID='${OPT_READY}'`,
  `export ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_IN_PROGRESS_ID='${OPT_IN_PROGRESS}'`,
];

// One issue-linked board item node for the GraphQL items payload.
function gqlNode({ id, number, title, url, assignees, state, optionId }) {
  return {
    id,
    content: {
      number,
      title,
      url,
      assignees: { nodes: (assignees || []).map((login) => ({ login })) },
    },
    fieldValues: {
      nodes: [
        { name: state, optionId, field: { id: FIELD_ID } },
      ],
    },
  };
}

function itemsPayload(nodes, { hasNextPage = false, endCursor = null } = {}) {
  return JSON.stringify({
    data: {
      node: {
        items: {
          nodes,
          pageInfo: { hasNextPage, endCursor },
        },
      },
    },
  });
}

const ITEM_11 = {
  id: 'PVTI_issue11',
  number: 11,
  title: 'Assigned backlog work',
  url: 'https://github.com/env-owner/env-repo/issues/11',
  assignees: ['chrissim'],
  state: REMOTE_BACKLOG_NAME,
  optionId: OPT_BACKLOG,
};
const ITEM_12 = {
  id: 'PVTI_issue12',
  number: 12,
  title: 'Unassigned ready work',
  url: 'https://github.com/env-owner/env-repo/issues/12',
  assignees: [],
  state: REMOTE_READY_NAME,
  optionId: OPT_READY,
};

// Canonical board fixtures: page 1 = issue 11 (legacy Backlog name), the
// follow-up page (cursor c1) = issue 12. The flip target replaces issue
// 11's option with In Progress (remote canonical name here).
function pageOnePayload() {
  return itemsPayload([gqlNode(ITEM_11)], { hasNextPage: true, endCursor: 'c1' });
}
function pageTwoPayload() {
  return itemsPayload([gqlNode(ITEM_12)], { hasNextPage: false, endCursor: null });
}
function pageOneFlippedPayload() {
  return itemsPayload(
    [gqlNode({ ...ITEM_11, state: REMOTE_IN_PROGRESS_NAME, optionId: OPT_IN_PROGRESS })],
    { hasNextPage: true, endCursor: 'c1' }
  );
}

// Configurable fake gh. Knobs:
//   pages          { '': payload, c1: payload }  served by cursor argument
//   boardPageOne   mutable page-1 payload file (item-edit 'flip' rewrites it)
//   editMode       'flip' | 'noop' | 'fail-transient'
//   graphqlFailFirst  N: first N graphql reads fail with a rate-limit stderr
//   graphqlHardFail   true: graphql reads fail once with a non-transient error
// Every invocation is logged as one CALL line of [arg] groups (multi-line
// argv entries flattened to spaces).
function setup(prefix, { editMode = 'flip', graphqlFailFirst = 0, graphqlHardFail = false } = {}) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), `${prefix}-`));
  const docs = path.join(tmp, 'docs');
  fs.mkdirSync(docs, { recursive: true });
  fs.writeFileSync(path.join(tmp, '.github-project.env'), ENV_LINES.join('\n') + '\n');

  const bin = path.join(tmp, 'bin');
  fs.mkdirSync(bin);
  const ghLog = path.join(bin, 'gh-calls.log');
  const pageTwo = path.join(bin, 'page2.json');
  const boardPageOne = path.join(bin, 'page1.json');
  const flipped = path.join(bin, 'page1-flipped.json');
  const failLeft = path.join(bin, 'fail-left');
  fs.writeFileSync(pageTwo, pageTwoPayload());
  fs.writeFileSync(boardPageOne, pageOnePayload());
  fs.writeFileSync(flipped, pageOneFlippedPayload());
  fs.writeFileSync(failLeft, `${graphqlFailFirst}\n`);

  fs.writeFileSync(
    path.join(bin, 'gh'),
    '#!/usr/bin/env bash\n' +
      `printf 'CALL:' >> '${ghLog}'; for a in "$@"; do printf ' [%s]' "$(printf '%s' "$a" | tr '\\n' ' ')" >> '${ghLog}'; done; printf '\\n' >> '${ghLog}'\n` +
      `if [[ "$1 $2" == "api graphql" ]]; then\n` +
      `  left=0; [[ -f '${failLeft}' ]] && left=$(cat '${failLeft}')\n` +
      `  if [[ "$left" -gt 0 ]]; then echo "$((left - 1))" > '${failLeft}'; echo 'gh: GraphQL: API rate limit exceeded (retry after 60s)' >&2; exit 1; fi\n` +
      `  if [[ '${graphqlHardFail}' == 'true' ]]; then echo 'gh: Some project was not found' >&2; exit 1; fi\n` +
      `  if printf '%s\\n' "$@" | grep -q 'cursor=c1'; then cat '${pageTwo}'; else cat '${boardPageOne}'; fi\n` +
      `  exit 0; fi\n` +
      `if [[ "$1 $2" == "project item-edit" ]]; then\n` +
      `  if [[ '${editMode}' == 'flip' ]]; then cp '${flipped}' '${boardPageOne}'; echo '{"itemId":"${ITEM_11.id}"}'; exit 0; fi\n` +
      `  if [[ '${editMode}' == 'noop' ]]; then echo '{"itemId":"${ITEM_11.id}"}'; exit 0; fi\n` +
      `  if [[ '${editMode}' == 'fail-transient' ]]; then echo 'gh: API rate limit exceeded (transient-looking)' >&2; exit 1; fi\n` +
      `  exit 1; fi\n` +
      `if [[ "$1 $2" == "project field-list" ]]; then ` +
      `echo '{"fields":[{"name":"Workflow State","id":"${FIELD_ID}","options":[{"name":"${REMOTE_BACKLOG_NAME}","id":"${OPT_BACKLOG}"},{"name":"${REMOTE_READY_NAME}","id":"${OPT_READY}"},{"name":"${REMOTE_IN_PROGRESS_NAME}","id":"${OPT_IN_PROGRESS}"}]}]}'; exit 0; fi\n` +
      `echo 'unexpected gh invocation: "$@"' >&2; exit 1\n`
  );
  fs.chmodSync(path.join(bin, 'gh'), 0o755);

  return { tmp, docs, bin, ghLog };
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

function graphqlCalls(ctx) {
  return calls(ctx).filter((c) => c[0] === 'api' && c[1] === 'graphql');
}

function editCalls(ctx) {
  return calls(ctx).filter((c) => c[0] === 'project' && c[1] === 'item-edit');
}

function parseJqObjects(stdout) {
  const collapsed = stdout.trim().replace(/\}\s*\{/g, '},{');
  return JSON.parse(`[${collapsed}]`);
}

// --- HARD-1: pagination-safe listing ---------------------------------------------

check('HARD-1: list-items follows pageInfo cursor pages and lists the whole board', () => {
  const ctx = setup('hard1');
  const r = runHelper(ctx, ['list-items']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}\nstdout:\n${r.stdout}`);
  const gql = graphqlCalls(ctx);
  assert.strictEqual(gql.length, 2, 'one fetch per page for a two-page board');
  const first = gql[0].find((a) => a.startsWith('query=')) || '';
  const second = gql[1].find((a) => a.startsWith('query=')) || '';
  assert.ok(first.includes('items(first: 100)') && !first.includes('after:'),
    'page-1 query has no after clause');
  assert.ok(second.includes('items(first: 100, after: $cursor)'),
    `follow-up query pages with after: $cursor — got: ${second.slice(0, 120)}`);
  assert.ok(gql[1].includes('cursor=c1'), 'the page-2 request passes the endCursor value');
  const items = parseJqObjects(r.stdout);
  assert.strictEqual(items.length, 2, 'items from BOTH pages are listed');
  assert.deepStrictEqual(items.map((i) => i.issue_number).sort(), [11, 12]);
  assert.strictEqual(items.find((i) => i.issue_number === 11).state, REMOTE_BACKLOG_NAME,
    'remote display name preserved as-is');
});

// --- HARD-2: pagination is bounded ------------------------------------------------

check('HARD-2: an always-next board stops at the page bound with a truncation warning', () => {
  const ctx = setup('hard2');
  // Reuse the page-1 payload for the cursor page too: every response says
  // hasNextPage with cursor c1, so only the bound stops the loop.
  const bin = ctx.bin;
  fs.writeFileSync(path.join(bin, 'page2.json'), pageOnePayload());
  const r = runHelper(ctx, ['list-items']);
  assert.strictEqual(r.status, 0, `bounded listing still succeeds: exit ${r.status}\nstderr:\n${r.stderr}`);
  assert.ok(/pagination bound/.test(r.stderr), `truncation must be warned: ${r.stderr}`);
  const gql = graphqlCalls(ctx);
  assert.strictEqual(gql.length, 10, 'the page bound (10) caps the fetch loop');
  const items = parseJqObjects(r.stdout);
  assert.ok(items.length >= 10, 'items from every fetched page are still printed');
});

// --- HARD-3: idempotent set-status ------------------------------------------------

check('HARD-3: set-status on an item already in the target state performs no mutation', () => {
  const ctx = setup('hard3');
  const r = runHelper(ctx, ['set-status', '11', 'Backlog']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}\nstdout:\n${r.stdout}`);
  assert.strictEqual(editCalls(ctx).length, 0, 'an idempotent re-run must not item-edit');
  assert.ok(/already in the requested Workflow State/.test(r.stderr),
    `the skip is noted on stderr: ${r.stderr}`);
  const out = JSON.parse(r.stdout);
  assert.deepStrictEqual(
    Object.keys(out).sort(),
    ['issue_number', 'state', 'title', 'url'],
    'idempotent path keeps the curated four-field contract'
  );
  assert.strictEqual(out.issue_number, 11);
  assert.strictEqual(out.state, REMOTE_BACKLOG_NAME,
    'verified from the read: the remote display name is printed as-is even on the skip path');
});

// --- HARD-4: verified mutation (mismatch is a hard failure) -----------------------

check('HARD-4: a post-edit state mismatch exits non-zero with the actual board state', () => {
  const ctx = setup('hard4', { editMode: 'noop' });
  const r = runHelper(ctx, ['set-status', '11', 'In Progress']);
  assert.notStrictEqual(r.status, 0, 'a silently ineffective edit must fail');
  assert.strictEqual(editCalls(ctx).length, 1, 'the mutation was attempted exactly once');
  assert.ok(/verification failed for issue #11/.test(r.stderr),
    `the mismatch is reported on stderr: ${r.stderr}`);
  assert.ok(r.stderr.includes(`found '${REMOTE_BACKLOG_NAME}'`),
    `the ACTUAL board state is named: ${r.stderr}`);
  assert.strictEqual(r.stdout.trim(), '', 'no curated success object may be printed');
});

// --- HARD-5: next-status precondition pass ---------------------------------------

check('HARD-5: next-status transitions when the item sits in the claimed current state', () => {
  const ctx = setup('hard5');
  // Item 11 sits on OPT_BACKLOG while the remote display name is the
  // legacy 'Shaping' — the precondition must match by option id.
  const r = runHelper(ctx, ['next-status', '11', 'Backlog', 'In Progress']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}\nstdout:\n${r.stdout}`);
  const edits = editCalls(ctx);
  assert.strictEqual(edits.length, 1, 'exactly one item-edit mutation');
  assert.ok(edits[0].includes('--single-select-option-id')
    && edits[0][edits[0].indexOf('--single-select-option-id') + 1] === OPT_IN_PROGRESS,
    'the mutation targets the NEXT state option id');
  const out = JSON.parse(r.stdout);
  assert.deepStrictEqual(
    Object.keys(out).sort(),
    ['issue_number', 'state', 'title', 'url'],
    'next-status keeps the curated four-field contract'
  );
  assert.strictEqual(out.state, REMOTE_IN_PROGRESS_NAME,
    'printed state is the post-edit verification value');
});

// --- HARD-6: next-status precondition fail ---------------------------------------

check('HARD-6: next-status fails without mutating when the precondition does not hold', () => {
  const ctx = setup('hard6');
  // Item 11 is in Backlog; the caller claims Ready as the current state.
  const r = runHelper(ctx, ['next-status', '11', 'Ready', 'In Progress']);
  assert.notStrictEqual(r.status, 0, 'a failed precondition must exit non-zero');
  assert.strictEqual(editCalls(ctx).length, 0, 'no mutation may happen');
  assert.ok(/precondition failed for issue #11/.test(r.stderr),
    `the precondition failure is reported: ${r.stderr}`);
  assert.ok(r.stderr.includes(`board reports '${REMOTE_BACKLOG_NAME}'`),
    `the actual board state is named: ${r.stderr}`);
  assert.ok(/item-state 11/.test(r.stderr), `recovery guidance points at item-state: ${r.stderr}`);
  assert.strictEqual(r.stdout.trim(), '', 'no partial output');
});

// --- HARD-7: read-only item-state recovery ----------------------------------------

check('HARD-7: item-state reports remote state as-is plus canonical_state from the option id', () => {
  const ctx = setup('hard7');
  const r = runHelper(ctx, ['item-state', '11']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}\nstdout:\n${r.stdout}`);
  const out = JSON.parse(r.stdout);
  assert.deepStrictEqual(
    Object.keys(out).sort(),
    ['canonical_state', 'issue_number', 'item_id', 'state', 'title', 'url'],
    'item-state prints exactly the recovery contract'
  );
  assert.strictEqual(out.state, REMOTE_BACKLOG_NAME,
    'the remote display name is reported as-is');
  assert.strictEqual(out.canonical_state, 'Backlog',
    'canonical_state reverse-maps the option id to the canonical name (name-agnostic)');
  assert.ok(!r.stdout.includes(OPT_BACKLOG), 'option ids are internal and never printed');
  assert.strictEqual(editCalls(ctx).length, 0, 'item-state is read-only');

  // An option id with no env pin reverse-maps to null (still useful output).
  const ctx2 = setup('hard7b');
  const bin = ctx2.bin;
  fs.writeFileSync(
    path.join(bin, 'page1.json'),
    itemsPayload([
      gqlNode({ ...ITEM_11, state: 'Mystery Legacy Name', optionId: 'PVTFS_optUnknown' }),
    ])
  );
  const r2 = runHelper(ctx2, ['item-state', '11']);
  assert.strictEqual(r2.status, 0, `exit ${r2.status}\nstderr:\n${r2.stderr}`);
  const out2 = JSON.parse(r2.stdout);
  assert.strictEqual(out2.state, 'Mystery Legacy Name');
  assert.strictEqual(out2.canonical_state, null, 'unknown option ids report canonical_state null');

  // Not-found stays a hard failure naming the issue.
  const nf = runHelper(ctx, ['item-state', '999']);
  assert.notStrictEqual(nf.status, 0, 'a missing board item must exit non-zero');
  assert.ok(/#999/.test(nf.stderr), `stderr must name the issue: ${nf.stderr}`);
  assert.strictEqual(nf.stdout.trim(), '');
});

// --- HARD-8: bounded read-only retry (recovers) -----------------------------------

check('HARD-8: a rate-limited board read is retried and recovers', () => {
  const ctx = setup('hard8', { graphqlFailFirst: 2 });
  const r = runHelper(ctx, ['list-items']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}\nstdout:\n${r.stdout}`);
  const gql = graphqlCalls(ctx);
  assert.strictEqual(gql.length, 4,
    '2 failed attempts + the successful retry on page 1, then the page-2 fetch');
  assert.ok(/attempt 1 failed \(transient\)/.test(r.stderr) && /attempt 2 failed \(transient\)/.test(r.stderr),
    `retries are announced on stderr: ${r.stderr}`);
  const items = parseJqObjects(r.stdout);
  assert.strictEqual(items.length, 2, 'the recovered read lists both pages');
});

// --- HARD-9: exhausted retries exit 3 ---------------------------------------------

check('HARD-9: a persistently rate-limited read exits 3 after the bounded attempts', () => {
  const ctx = setup('hard9', { graphqlFailFirst: 99 });
  const r = runHelper(ctx, ['list-items']);
  assert.strictEqual(r.status, 3, `exhausted transient reads must exit 3 (got ${r.status})`);
  assert.strictEqual(graphqlCalls(ctx).length, 3, 'exactly the bounded attempt count');
  assert.ok(/failed after 3 attempts/.test(r.stderr), `exhaustion is reported: ${r.stderr}`);
  assert.ok(/safe to retry: no mutation was attempted/.test(r.stderr),
    `the retryable contract is stated: ${r.stderr}`);
  assert.strictEqual(r.stdout.trim(), '', 'no partial output');
});

// --- HARD-10: mutations are never retried -----------------------------------------

check('HARD-10: a transient-looking mutation failure is attempted exactly once', () => {
  const ctx = setup('hard10', { editMode: 'fail-transient' });
  const r = runHelper(ctx, ['set-status', '11', 'In Progress']);
  assert.notStrictEqual(r.status, 0, 'the failed mutation must fail the command');
  assert.strictEqual(editCalls(ctx).length, 1, 'mutations are never retried — exactly one attempt');
  // The two-page board means the item LOOKUP alone is 2 graphql fetches; a
  // post-edit verification re-read would add 2 more.
  assert.strictEqual(graphqlCalls(ctx).length, 2,
    'the post-edit verification read never runs after a failed mutation');
  assert.strictEqual(r.stdout.trim(), '', 'no curated success object');
});

// --- HARD-11: non-transient read failures fail fast -------------------------------

check('HARD-11: a non-transient read error fails immediately with gh\'s exit code', () => {
  const ctx = setup('hard11', { graphqlHardFail: true });
  const r = runHelper(ctx, ['list-items']);
  assert.notStrictEqual(r.status, 0, 'a hard read error must fail');
  assert.notStrictEqual(r.status, 3, 'a non-transient error is NOT the retryable exit');
  assert.strictEqual(graphqlCalls(ctx).length, 1, 'no retry for non-transient failures');
  assert.ok(/Some project was not found/.test(r.stderr), `gh's error propagates: ${r.stderr}`);
});

// --- summary ----------------------------------------------------------------------

console.log(`\n${passed} passed, ${failed} failed (gh-helper-hardening board engine)`);
if (failed > 0) process.exit(1);
