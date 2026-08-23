#!/usr/bin/env node
'use strict';

/*
 * tests/test_gh_project_helper_board_output.js — curated board-command
 * output contract (SPEC-003 follow-up #44, Gap 1).
 *
 * Founder demo contract (2026-08-23): helper board commands must not merely
 * call gh; they return useful structured results — `set-status 37 Ready`
 * prints the issue's number/title/state/url with state verified from the
 * board AFTER the edit. This suite locks that contract for all four curated
 * board commands:
 *
 *   BOC-1  list-items prints one curated JSON object per item, each with
 *          issue_number, title, state, url (plus assignees)
 *   BOC-2  list-items <state> filters on the canonical Workflow State key
 *          and keeps the same curated shape
 *   BOC-3  item-id prints {item_id, issue_number, title, url, state}
 *   BOC-4  set-status <n> <state> resolves IDs (env first), performs the
 *          item-edit mutation with them, then prints
 *          {issue_number, title, state, url} where state is the POST-EDIT
 *          board value
 *   BOC-5  set-status-id <n> <option_id> has the same post-edit curated
 *          output contract
 *   BOC-6  set-status fails cleanly (exit 1, no mutation) when the state
 *          option cannot be resolved
 *
 * The fake gh is stateful: the first gh project item-edit flips the fake
 * board item's Workflow State, so the post-edit re-read in BOC-4/BOC-5
 * observably differs from the pre-edit value — proving the printed state is
 * a verification re-read, not an echo of the request.
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

// gh project item-list payload shaped like the real gh CLI output: the
// single-select field value is flattened to a top-level item key named
// after the field (literally "workflow State").
const ITEM_37_READY = {
  id: 'PVTI_lADOAGcCyM4Bdw3L_issue37',
  'workflow State': 'Ready',
  content: {
    number: 37,
    title: 'SPEC-003-T7: Local-first dual-record sync',
    url: 'https://github.com/env-owner/env-repo/issues/37',
    assignees: [{ login: 'chrissim' }],
  },
};
const ITEM_42_TODO = {
  id: 'PVTI_lADOAGcCyM4Bdw3L_issue42',
  'workflow State': 'Todo',
  content: {
    number: 42,
    title: 'Board output contract demo',
    url: 'https://github.com/env-owner/env-repo/issues/42',
    assignees: [],
  },
};

function boardPayload(stateFor42) {
  const items = [ITEM_37_READY, { ...ITEM_42_TODO, 'workflow State': stateFor42 }];
  return JSON.stringify({ items: [...items] }); // fresh copies per call
}

// Stateful fake gh: dispatches on argv.
//   gh project item-list ...        -> prints the current board payload
//   gh project item-edit ...        -> flips issue 42's state to In Review,
//                                      prints {"itemId": ...}
//   gh project field-list ...       -> prints the Workflow State field
// Every invocation is logged as one CALL line of [arg] groups.
function setup(prefix, { withOptionEnv } = { withOptionEnv: true }) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), `${prefix}-`));
  const docs = path.join(tmp, 'docs');
  fs.mkdirSync(docs, { recursive: true });

  const envLines = [
    "export ANT_TEAM_GITHUB_REPO='env-owner/env-repo'",
    "export ANT_TEAM_GITHUB_OWNER='env-owner'",
    "export ANT_TEAM_GITHUB_PROJECT_NUMBER='9'",
    "export ANT_TEAM_GITHUB_PROJECT_ID='PVT_testProjectId'",
    "export ANT_TEAM_GITHUB_WORKFLOW_STATE_FIELD_ID='PVTFS_testFieldId'",
  ];
  if (withOptionEnv) {
    envLines.push("export ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_IN_REVIEW_ID='PVTFS_testOptionInReview'");
  }
  fs.writeFileSync(path.join(tmp, '.github-project.env'), envLines.join('\n') + '\n');

  const bin = path.join(tmp, 'bin');
  fs.mkdirSync(bin);
  const ghLog = path.join(bin, 'gh-calls.log');
  const board = path.join(bin, 'board.json');
  const boardTodo = path.join(bin, 'board-todo.json');
  const boardReview = path.join(bin, 'board-inreview.json');
  fs.writeFileSync(boardTodo, boardPayload('Todo'));
  fs.writeFileSync(boardReview, boardPayload('In Review'));
  fs.writeFileSync(board, boardPayload('Todo')); // issue 42 starts in Todo

  fs.writeFileSync(
    path.join(bin, 'gh'),
    '#!/usr/bin/env bash\n' +
      `printf 'CALL:' >> '${ghLog}'; for a in "$@"; do printf ' [%s]' "$a" >> '${ghLog}'; done; printf '\\n' >> '${ghLog}'\n` +
      `if [[ "$1 $2" == "project item-list" ]]; then cat '${board}'; exit 0; fi\n` +
      `if [[ "$1 $2" == "project item-edit" ]]; then cp '${boardReview}' '${board}'; ` +
      `echo '{"itemId":"PVTI_lADOAGcCyM4Bdw3L_issue42"}'; exit 0; fi\n` +
      `if [[ "$1 $2" == "project field-list" ]]; then ` +
      `echo '{"fields":[{"name":"Workflow State","id":"PVTFS_testFieldId","options":[{"name":"Ready","id":"PVTFS_optReady"},{"name":"In Review","id":"PVTFS_testOptionInReview"}]}]}'; exit 0; fi\n` +
      `echo 'unexpected gh invocation: "$@"' >&2; exit 1\n`
  );
  fs.chmodSync(path.join(bin, 'gh'), 0o755);

  return { tmp, docs, bin, ghLog };
}

// jq pretty-prints each curated object across multiple lines; collapse the
// stream back into one JSON array for parsing.
function parseJqObjects(stdout) {
  const collapsed = stdout.trim().replace(/\}\s*\{/g, '},{');
  return JSON.parse(`[${collapsed}]`);
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

// --- BOC-1: list-items curated shape ------------------------------------------

check('BOC-1: list-items prints curated JSON with issue_number/title/state/url (+assignees)', () => {
  const ctx = setup('boc1');
  const r = runHelper(ctx, ['list-items']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}\nstdout:\n${r.stdout}`);
  const items = parseJqObjects(r.stdout);
  assert.strictEqual(items.length, 2, 'both board items listed');
  for (const it of items) {
    for (const key of ['issue_number', 'title', 'state', 'url', 'assignees']) {
      assert.ok(key in it, `every item must carry ${key}: ${JSON.stringify(it)}`);
    }
  }
  const byNumber = Object.fromEntries(items.map((i) => [i.issue_number, i]));
  assert.strictEqual(byNumber[37].state, 'Ready');
  assert.strictEqual(byNumber[42].state, 'Todo');
  assert.deepStrictEqual(byNumber[37].assignees, ['chrissim']);
  assert.strictEqual(byNumber[42].url, ITEM_42_TODO.content.url);
});

// --- BOC-2: list-items <state> filters + same shape ----------------------------

check('BOC-2: list-items <state> filters on the canonical Workflow State key', () => {
  const ctx = setup('boc2');
  const r = runHelper(ctx, ['list-items', 'Ready']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const items = parseJqObjects(r.stdout);
  assert.strictEqual(items.length, 1, 'only the Ready item is listed');
  assert.strictEqual(items[0].issue_number, 37);
  assert.strictEqual(items[0].state, 'Ready');
  for (const key of ['issue_number', 'title', 'state', 'url', 'assignees']) {
    assert.ok(key in items[0], `filtered item must keep the curated ${key}`);
  }
});

// --- BOC-3: item-id curated shape ----------------------------------------------

check('BOC-3: item-id prints {item_id, issue_number, title, url, state}', () => {
  const ctx = setup('boc3');
  const r = runHelper(ctx, ['item-id', '37']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}\nstdout:\n${r.stdout}`);
  const out = JSON.parse(r.stdout);
  assert.strictEqual(out.item_id, ITEM_37_READY.id);
  assert.strictEqual(out.issue_number, 37);
  assert.strictEqual(out.title, ITEM_37_READY.content.title);
  assert.strictEqual(out.url, ITEM_37_READY.content.url);
  assert.strictEqual(out.state, 'Ready', 'item-id must report the Workflow State');
});

// --- BOC-4: set-status post-edit verification output ----------------------------

check('BOC-4: set-status mutates via resolved IDs and prints the POST-EDIT state', () => {
  const ctx = setup('boc4');
  const r = runHelper(ctx, ['set-status', '42', 'In Review']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}\nstdout:\n${r.stdout}`);

  // Exactly the expected gh conversation: option id resolved from the env
  // (no field-list), item id resolved, item-edit mutation, verification
  // re-read. The env carries project/field IDs, so no extra resolutions.
  const all = calls(ctx);
  const itemListCalls = all.filter((c) => c[0] === 'project' && c[1] === 'item-list');
  const editCalls = all.filter((c) => c[0] === 'project' && c[1] === 'item-edit');
  assert.strictEqual(editCalls.length, 1, 'exactly one item-edit mutation');
  assert.ok(itemListCalls.length >= 2, 'item id resolution + post-edit verification re-read');
  const edit = editCalls[0];
  assert.ok(edit.includes('--id') && edit[edit.indexOf('--id') + 1] === ITEM_42_TODO.id,
    `item-edit must target the resolved item id: ${edit.join(' ')}`);
  assert.ok(edit.includes('--project-id') && edit[edit.indexOf('--project-id') + 1] === 'PVT_testProjectId',
    'project id from the env');
  assert.ok(edit.includes('--field-id') && edit[edit.indexOf('--field-id') + 1] === 'PVTFS_testFieldId',
    'field id from the env');
  assert.ok(edit.includes('--single-select-option-id')
    && edit[edit.indexOf('--single-select-option-id') + 1] === 'PVTFS_testOptionInReview',
    `option id for "In Review" resolved from the env: ${edit.join(' ')}`);

  // The printed object is the four-field curated contract, and its state is
  // the POST-EDIT board value (fake board flips to In Review on item-edit).
  const out = JSON.parse(r.stdout);
  assert.deepStrictEqual(
    Object.keys(out).sort(),
    ['issue_number', 'state', 'title', 'url'],
    'set-status output is exactly the curated four-field contract'
  );
  assert.strictEqual(out.issue_number, 42);
  assert.strictEqual(out.state, 'In Review', 'printed state must be the post-edit verification value');
  assert.strictEqual(out.url, ITEM_42_TODO.content.url);
});

// --- BOC-5: set-status-id same output contract ----------------------------------

check('BOC-5: set-status-id prints the same post-edit curated output', () => {
  const ctx = setup('boc5');
  const r = runHelper(ctx, ['set-status-id', '42', 'PVTFS_testOptionInReview']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}\nstdout:\n${r.stdout}`);
  const out = JSON.parse(r.stdout);
  assert.deepStrictEqual(
    Object.keys(out).sort(),
    ['issue_number', 'state', 'title', 'url'],
    'set-status-id output is exactly the curated four-field contract'
  );
  assert.strictEqual(out.issue_number, 42);
  assert.strictEqual(out.state, 'In Review', 'post-edit verification re-read');
  const edit = calls(ctx).find((c) => c[0] === 'project' && c[1] === 'item-edit');
  assert.ok(edit, 'item-edit mutation happened');
  assert.ok(edit.includes('PVTFS_testOptionInReview'), 'caller-provided option id is used verbatim');
});

// --- BOC-6: unresolvable state fails cleanly ------------------------------------

check('BOC-6: set-status with an unresolvable state option fails before any mutation', () => {
  const ctx = setup('boc6', { withOptionEnv: false });
  const r = runHelper(ctx, ['set-status', '42', 'NotAState']);
  assert.notStrictEqual(r.status, 0, 'unresolvable option must exit non-zero');
  assert.ok(/Could not resolve Workflow State option ID/.test(r.stderr),
    `friendly error expected: ${r.stderr}`);
  const all = calls(ctx);
  assert.strictEqual(all.filter((c) => c[0] === 'project' && c[1] === 'item-edit').length, 0,
    'no mutation may happen when the option cannot be resolved');
});

// --- summary ---------------------------------------------------------------------

console.log(`\n${passed} passed, ${failed} failed (curated board-command output contract)`);
if (failed > 0) process.exit(1);
