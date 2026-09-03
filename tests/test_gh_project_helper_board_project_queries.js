#!/usr/bin/env node
'use strict';

/*
 * tests/test_gh_project_helper_board_project_queries.js — board/project
 * query subcommand contracts (SPEC-003 followup #46, 2026-08-23).
 *
 * Founder standard (2026-08-23, second round): the board ITEM queries and
 * the project metadata queries must return useful structured results via
 * helper subcommands, never raw gh + jq recipes. This suite locks:
 *
 *   BPQ-1  usage lists list-unassigned, item-state, and the three
 *          project-* commands
 *   BPQ-2  list-items runs the ONE shared GraphQL project-items engine
 *          (first:100 cursor pages) and prints
 *          {item_id, issue_number, title, state, assignees, url} per
 *          issue-linked item with REAL assignees; draft items are dropped
 *          (multi-page pagination is locked by
 *          tests/test_gh_project_helper_hardening.js)
 *   BPQ-3  list-items <canonical-state> filters by optionId (name-agnostic:
 *          a canonical Backlog filter matches the Backlog option id even
 *          when the remote display name is a legacy rename) and the output
 *          state is the REMOTE option name preserved as-is
 *   BPQ-4  list-items <unknown-state> exits non-zero with set-status-style
 *          guidance BEFORE the GraphQL items fetch
 *   BPQ-5  list-unassigned returns only zero-assignee issue-linked items,
 *          same curated shape
 *   BPQ-6  project-list prints a curated JSON array sorted by number;
 *          --owner flag wins over env; positional arguments are rejected
 *          before gh
 *   BPQ-7  project-view requires a numeric PROJECT_NUMBER and accepts only
 *          --format json; both validated before gh; curated object out
 *   BPQ-8  project-field-list prints {total_count, fields} with options
 *          only on single-select fields; same validation as project-view
 *   BPQ-9  owner resolution is flag -> ANT_TEAM_GITHUB_OWNER env -> legacy
 *          OWNER; empty resolution fails before gh for all three commands
 *   BPQ-10 positional owner is rejected for every board/project query
 *          command (HIC-17 extension); gh is never called
 *
 * The fake gh serves both data sources by contract: gh api graphql for the
 * shared items query (list-items family) and gh project list/view/
 * field-list for the metadata family (deliberately NOT GraphQL — locked by
 * asserting the metadata commands never touch the graphql endpoint).
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

// Fixture constants. The remote option display names come from THIS
// fixture only — assertions reference the fixture constant, never an
// assumption that the remote name equals the canonical name (guardrail:
// remote names are never hardcoded in helper output or docs).
const FIELD_ID = 'PVTFS_testFieldId';
const PROJECT_ID = 'PVT_testProjectId';
const OPT_BACKLOG = 'PVTFS_optBacklogCanonical';
const OPT_READY = 'PVTFS_optReady';
// Illustrative legacy remote rename of the canonical Backlog state: the
// remote board still displays this name while the option id is stable.
const REMOTE_BACKLOG_NAME = 'Shaping';

// Shared GraphQL project-items payload: one assigned Backlog-state item
// (remote legacy display name), one unassigned Ready item, one draft item
// (content carries no issue number — not issue-linked, must be dropped).
function graphqlItemsPayload() {
  return JSON.stringify({
    data: {
      node: {
        items: {
          nodes: [
            {
              id: 'PVTI_issue11',
              content: {
                number: 11,
                title: 'Assigned backlog work',
                url: 'https://github.com/env-owner/env-repo/issues/11',
                assignees: { nodes: [{ login: 'chrissim' }] },
              },
              fieldValues: {
                nodes: [
                  { name: REMOTE_BACKLOG_NAME, optionId: OPT_BACKLOG, field: { id: FIELD_ID } },
                ],
              },
            },
            {
              id: 'PVTI_issue12',
              content: {
                number: 12,
                title: 'Unassigned ready work',
                url: 'https://github.com/env-owner/env-repo/issues/12',
                assignees: { nodes: [] },
              },
              fieldValues: {
                nodes: [
                  { name: 'Ready', optionId: OPT_READY, field: { id: FIELD_ID } },
                ],
              },
            },
            {
              id: 'PVTI_draft',
              content: { number: null, title: 'Draft note', url: '', assignees: { nodes: [] } },
              fieldValues: { nodes: [] },
            },
          ],
          pageInfo: { hasNextPage: false, endCursor: null },
        },
      },
    },
  });
}

// gh project payloads shaped like the real gh CLI (verified live against
// Project #9 with gh 2.45): list wraps in {"projects":[...]}; view is a
// single object; field-list wraps in {fields, totalCount}.
const PROJECT_LIST_PAYLOAD = JSON.stringify({
  projects: [
    {
      closed: false,
      fields: { totalCount: 14 },
      id: 'PVT_nine',
      items: { totalCount: 25 },
      number: 9,
      owner: { login: 'env-owner', type: 'organization' },
      public: false,
      readme: '',
      shortDescription: '',
      title: 'Ant Teams Fixture',
      url: 'https://github.com/orgs/env-owner/projects/9',
    },
    {
      closed: true,
      fields: { totalCount: 3 },
      id: 'PVT_four',
      items: { totalCount: 1 },
      number: 4,
      owner: { login: 'env-owner', type: 'organization' },
      public: true,
      readme: '',
      shortDescription: '',
      title: 'Older Fixture',
      url: 'https://github.com/orgs/env-owner/projects/4',
    },
  ],
});

const PROJECT_VIEW_PAYLOAD = JSON.stringify({
  closed: false,
  fields: { totalCount: 14 },
  id: 'PVT_nine',
  items: { totalCount: 25 },
  number: 9,
  owner: { login: 'env-owner', type: 'organization' },
  public: false,
  readme: '',
  shortDescription: '',
  title: 'Ant Teams Fixture',
  url: 'https://github.com/orgs/env-owner/projects/9',
});

const PROJECT_FIELD_LIST_PAYLOAD = JSON.stringify({
  totalCount: 3,
  fields: [
    { id: 'PVTF_title', name: 'Title', type: 'ProjectV2Field' },
    {
      id: FIELD_ID,
      name: 'Workflow State',
      type: 'ProjectV2SingleSelectField',
      options: [
        { name: 'Inbox', id: 'eb66d5a6' },
        { name: REMOTE_BACKLOG_NAME, id: OPT_BACKLOG },
        { name: 'Ready', id: OPT_READY },
      ],
    },
    { id: 'PVTF_iter', name: 'Sprint', type: 'ProjectV2IterationField' },
  ],
});

// Fake gh: dispatches on argv. Multi-line argv entries (the fixed GraphQL
// query) are flattened to spaces in the CALL log so line-based parsing
// keeps working.
function setup(prefix, envLines) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), `${prefix}-`));
  const docs = path.join(tmp, 'docs');
  fs.mkdirSync(docs, { recursive: true });
  fs.writeFileSync(path.join(tmp, '.github-project.env'), envLines.join('\n') + '\n');

  const bin = path.join(tmp, 'bin');
  fs.mkdirSync(bin);
  const ghLog = path.join(bin, 'gh-calls.log');
  fs.writeFileSync(
    path.join(bin, 'gh'),
    '#!/usr/bin/env bash\n' +
      `printf 'CALL:' >> '${ghLog}'; for a in "$@"; do printf ' [%s]' "$(printf '%s' "$a" | tr '\\n' ' ')" >> '${ghLog}'; done; printf '\\n' >> '${ghLog}'\n` +
      `if [[ "$1 $2" == "api graphql" ]]; then printf '%s' '${graphqlItemsPayload()}'; exit 0; fi\n` +
      `if [[ "$1 $2" == "project list" ]]; then printf '%s' '${PROJECT_LIST_PAYLOAD}'; exit 0; fi\n` +
      `if [[ "$1 $2" == "project view" ]]; then printf '%s' '${PROJECT_VIEW_PAYLOAD}'; exit 0; fi\n` +
      `if [[ "$1 $2" == "project field-list" ]]; then printf '%s' '${PROJECT_FIELD_LIST_PAYLOAD}'; exit 0; fi\n` +
      `echo 'unexpected gh invocation: "$@"' >&2; exit 1\n`
  );
  fs.chmodSync(path.join(bin, 'gh'), 0o755);

  return { tmp, docs, bin, ghLog };
}

const BASE_ENV = [
  "export ANT_TEAM_GITHUB_REPO='env-owner/env-repo'",
  "export ANT_TEAM_GITHUB_OWNER='env-owner'",
  "export ANT_TEAM_GITHUB_PROJECT_NUMBER='9'",
  `export ANT_TEAM_GITHUB_PROJECT_ID='${PROJECT_ID}'`,
  `export ANT_TEAM_GITHUB_WORKFLOW_STATE_FIELD_ID='${FIELD_ID}'`,
  `export ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_BACKLOG_ID='${OPT_BACKLOG}'`,
  `export ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_READY_ID='${OPT_READY}'`,
];

function ctx(prefix) {
  return setup(prefix, BASE_ENV);
}

function runHelper(c, args) {
  return spawnSync('bash', [HELPER, ...args], {
    encoding: 'utf8',
    cwd: c.tmp,
    env: {
      PATH: `${c.bin}:${process.env.PATH}`,
      HOME: process.env.HOME,
    },
  });
}

function calls(c) {
  if (!fs.existsSync(c.ghLog)) return [];
  return fs
    .readFileSync(c.ghLog, 'utf8')
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

function graphqlCalls(c) {
  return calls(c).filter((x) => x[0] === 'api' && x[1] === 'graphql');
}

function parseJqObjects(stdout) {
  const collapsed = stdout.trim().replace(/\}\s*\{/g, '},{');
  return JSON.parse(`[${collapsed}]`);
}

// --- BPQ-1: usage lists the new subcommands --------------------------------------

check('BPQ-1: usage lists list-unassigned, item-state, and the project-* query subcommands', () => {
  const c = ctx('bpq1');
  const usage = runHelper(c, []);
  assert.notStrictEqual(usage.status, 0, 'no-args must exit non-zero');
  for (const sub of ['list-unassigned', 'item-state', 'project-list', 'project-view', 'project-field-list']) {
    assert.ok(usage.stdout.includes(sub), `usage must list ${sub}`);
  }
});

// --- BPQ-2: list-items = the ONE shared GraphQL items engine ----------------------

check('BPQ-2: list-items runs the ONE shared GraphQL items engine with real assignees, drafts dropped', () => {
  const c = ctx('bpq2');
  const r = runHelper(c, ['list-items']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}\nstdout:\n${r.stdout}`);
  const gql = graphqlCalls(c);
  assert.strictEqual(gql.length, 1, 'a single-page board needs exactly one items fetch');
  const query = gql[0].find((a) => a.startsWith('query=')) || '';
  assert.ok(query.includes('items(first: 100)'), 'first:100 page size');
  assert.ok(query.includes('pageInfo'), 'cursor pagination requests pageInfo');
  assert.ok(query.includes('hasNextPage') && query.includes('endCursor'),
    'pageInfo carries hasNextPage + endCursor for the cursor loop');
  assert.ok(query.includes('assignees(first: 10)'), 'assignees come from the GraphQL join');
  assert.ok(query.includes('optionId'), 'single-select optionId requested for name-agnostic filtering');
  assert.ok(gql[0].includes(`projectId=${PROJECT_ID}`), 'project id resolved from the env');
  const items = parseJqObjects(r.stdout);
  assert.strictEqual(items.length, 2, 'draft item dropped; only issue-linked items listed');
  for (const it of items) {
    assert.deepStrictEqual(
      Object.keys(it).sort(),
      ['assignees', 'issue_number', 'item_id', 'state', 'title', 'url'],
      `curated #46 shape: ${JSON.stringify(it)}`
    );
  }
  const byNumber = Object.fromEntries(items.map((i) => [i.issue_number, i]));
  assert.deepStrictEqual(byNumber[11].assignees, ['chrissim'], 'REAL assignees from GraphQL');
  assert.deepStrictEqual(byNumber[12].assignees, []);
  assert.strictEqual(byNumber[11].state, REMOTE_BACKLOG_NAME,
    'state is the remote option name preserved as-is (fixture remote name)');
});

// --- BPQ-3: canonical-state filtering is optionId-based (name-agnostic) -----------

check('BPQ-3: list-items Backlog filters by optionId and prints the remote name as-is', () => {
  const c = ctx('bpq3');
  const r = runHelper(c, ['list-items', 'Backlog']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}\nstdout:\n${r.stdout}`);
  const items = parseJqObjects(r.stdout);
  assert.strictEqual(items.length, 1, 'the item carrying the Backlog OPTION ID matches');
  assert.strictEqual(items[0].issue_number, 11);
  assert.strictEqual(items[0].state, REMOTE_BACKLOG_NAME,
    'output state is the remote display name as-is, never translated to the canonical name');
  assert.notStrictEqual(items[0].state, 'Backlog',
    'the canonical filter argument is never echoed as the output state');
  // The canonical resolution used the env-pinned option id: no field-list
  // discovery call was needed and the option id never leaks into output.
  assert.strictEqual(calls(c).filter((x) => x[1] === 'field-list').length, 0,
    'env-pinned canonical option id resolves without remote discovery');
  assert.ok(!r.stdout.includes(OPT_BACKLOG), 'option ids are internal and never printed');
  assert.strictEqual(graphqlCalls(c).length, 1, 'one shared items query');
});

// --- BPQ-4: unknown state fails with guidance before the items fetch --------------

check('BPQ-4: list-items <unknown state> exits non-zero with guidance before the GraphQL fetch', () => {
  const c = ctx('bpq4');
  const r = runHelper(c, ['list-items', 'NotAState']);
  assert.notStrictEqual(r.status, 0, 'unknown state must fail');
  assert.ok(/Could not resolve Workflow State option ID for 'NotAState'/.test(r.stderr),
    `set-status-style guidance expected: ${r.stderr}`);
  assert.ok(/never renames remote board options/.test(r.stderr), 'guidance explains the rename policy');
  assert.strictEqual(graphqlCalls(c).length, 0, 'the shared items query must not run for an unknown state');
  assert.strictEqual(r.stdout.trim(), '', 'no partial output');
});

// --- BPQ-5: list-unassigned --------------------------------------------------------

check('BPQ-5: list-unassigned returns zero-assignee issue-linked items in the same shape', () => {
  const c = ctx('bpq5');
  const r = runHelper(c, ['list-unassigned']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}\nstdout:\n${r.stdout}`);
  assert.strictEqual(graphqlCalls(c).length, 1, 'reuses the ONE shared GraphQL items query');
  const items = parseJqObjects(r.stdout);
  assert.strictEqual(items.length, 1, 'only the unassigned issue-linked item');
  assert.strictEqual(items[0].issue_number, 12);
  assert.deepStrictEqual(items[0].assignees, []);
  assert.deepStrictEqual(
    Object.keys(items[0]).sort(),
    ['assignees', 'issue_number', 'item_id', 'state', 'title', 'url'],
    'same curated shape as list-items'
  );
});

// --- BPQ-6: project-list -----------------------------------------------------------

check('BPQ-6: project-list prints a curated array sorted by number; --owner flag beats env; positional rejected', () => {
  let c = ctx('bpq6');
  let r = runHelper(c, ['project-list']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const out = JSON.parse(r.stdout);
  assert.ok(Array.isArray(out), 'output is a JSON array');
  assert.deepStrictEqual(out.map((p) => p.number), [4, 9], 'sorted by number (fixture was unsorted)');
  for (const p of out) {
    assert.deepStrictEqual(
      Object.keys(p).sort(),
      ['closed', 'fields_count', 'items_count', 'number', 'public', 'title', 'url'],
      `curated project-list entry: ${JSON.stringify(p)}`
    );
  }
  assert.strictEqual(out[1].items_count, 25, 'items_count from items.totalCount');
  assert.strictEqual(out[1].fields_count, 14, 'fields_count from fields.totalCount');
  let call = calls(c)[0];
  assert.deepStrictEqual(call.slice(0, 2), ['project', 'list']);
  assert.ok(call.includes('--owner') && call[call.indexOf('--owner') + 1] === 'env-owner',
    'owner resolves from the env by default');

  // --owner flag wins over the env value.
  c = ctx('bpq6b');
  r = runHelper(c, ['project-list', '--owner', 'flag-owner']);
  assert.strictEqual(r.status, 0, `flag exit ${r.status}\nstderr:\n${r.stderr}`);
  call = calls(c)[0];
  assert.ok(call[call.indexOf('--owner') + 1] === 'flag-owner', '--owner flag beats the env owner');

  // A positional argument (a positional owner) is rejected before gh.
  c = ctx('bpq6c');
  r = runHelper(c, ['project-list', 'Antpolis']);
  assert.notStrictEqual(r.status, 0, 'project-list takes no positional argument');
  assert.strictEqual(calls(c).length, 0, 'gh must not be called');
});

// --- BPQ-7: project-view ------------------------------------------------------------

check('BPQ-7: project-view curates the payload and validates number + format before gh', () => {
  let c = ctx('bpq7');
  let r = runHelper(c, ['project-view', '9', '--format', 'json']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}\nstdout:\n${r.stdout}`);
  const out = JSON.parse(r.stdout);
  assert.deepStrictEqual(
    Object.keys(out).sort(),
    ['closed', 'fields_count', 'items_count', 'number', 'owner', 'public', 'title', 'url'],
    'curated project-view object'
  );
  assert.strictEqual(out.number, 9);
  assert.strictEqual(out.owner, 'env-owner', 'owner comes from the payload owner.login');
  assert.strictEqual(out.items_count, 25);
  let call = calls(c)[0];
  assert.deepStrictEqual(call.slice(0, 3), ['project', 'view', '9']);
  assert.ok(call[call.indexOf('--owner') + 1] === 'env-owner', 'env owner by default');

  c = ctx('bpq7b');
  r = runHelper(c, ['project-view', '9', '--owner', 'flag-owner', '--format', 'json']);
  assert.strictEqual(r.status, 0, `flag exit ${r.status}\nstderr:\n${r.stderr}`);
  call = calls(c)[0];
  assert.ok(call[call.indexOf('--owner') + 1] === 'flag-owner', '--owner flag beats the env owner');

  // Non-numeric PROJECT_NUMBER (the positional-owner footgun) fails before gh.
  c = ctx('bpq7c');
  r = runHelper(c, ['project-view', 'Antpolis']);
  assert.notStrictEqual(r.status, 0, 'a non-numeric positional must be rejected');
  assert.ok(/Invalid project number 'Antpolis'/.test(r.stderr), `friendly error: ${r.stderr}`);
  assert.strictEqual(calls(c).length, 0, 'gh must not be called');

  // Missing PROJECT_NUMBER fails before gh.
  r = runHelper(c, ['project-view', '--owner', 'flag-owner']);
  assert.notStrictEqual(r.status, 0, 'missing PROJECT_NUMBER must fail');
  assert.ok(/PROJECT_NUMBER/.test(r.stderr), 'error must name the missing positional');
  assert.strictEqual(calls(c).length, 0, 'gh must not be called');

  // --format only accepts json.
  r = runHelper(c, ['project-view', '9', '--format', 'table']);
  assert.notStrictEqual(r.status, 0, 'non-json --format must fail');
  assert.ok(/only json is accepted/.test(r.stderr), 'error must name the accepted value');
  assert.strictEqual(calls(c).length, 0, 'validation fails before gh');
});

// --- BPQ-8: project-field-list -------------------------------------------------------

check('BPQ-8: project-field-list curates fields; options only on single-select fields', () => {
  const c = ctx('bpq8');
  const r = runHelper(c, ['project-field-list', '9', '--format', 'json']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}\nstdout:\n${r.stdout}`);
  const call = calls(c)[0];
  assert.deepStrictEqual(call.slice(0, 3), ['project', 'field-list', '9']);
  assert.strictEqual(graphqlCalls(c).length, 0,
    'metadata commands never touch the GraphQL items engine');
  const out = JSON.parse(r.stdout);
  assert.deepStrictEqual(Object.keys(out).sort(), ['fields', 'total_count']);
  assert.strictEqual(out.total_count, 3);
  const byName = Object.fromEntries(out.fields.map((f) => [f.name, f]));
  for (const f of out.fields) {
    assert.deepStrictEqual(
      Object.keys(f).filter((k) => k !== 'options').sort(),
      ['id', 'name', 'type'],
      'each field carries id/name/type'
    );
  }
  assert.strictEqual(byName['Title'].options, undefined, 'plain fields carry no options key');
  assert.strictEqual(byName['Sprint'].options, undefined, 'iteration fields carry no options key');
  const wf = byName['Workflow State'];
  assert.deepStrictEqual(
    wf.options.map((o) => ({ name: o.name, id: o.id })),
    [
      { name: 'Inbox', id: 'eb66d5a6' },
      { name: REMOTE_BACKLOG_NAME, id: OPT_BACKLOG },
      { name: 'Ready', id: OPT_READY },
    ],
    'single-select options preserved as {name, id}'
  );
});

// --- BPQ-9: owner resolution precedence flag -> env -> legacy; empty fails ---------

check('BPQ-9: owner resolves flag -> env -> legacy OWNER; empty fails before gh', () => {
  // env-only resolution (flag beats env was proven in BPQ-6/BPQ-7).
  let c = ctx('bpq9');
  let r = runHelper(c, ['project-view', '9']);
  assert.strictEqual(r.status, 0, `env exit ${r.status}\nstderr:\n${r.stderr}`);
  let call = calls(c)[0];
  assert.ok(call[call.indexOf('--owner') + 1] === 'env-owner', 'env owner resolves');

  // legacy OWNER fallback when ANT_TEAM_GITHUB_OWNER is absent.
  c = setup('bpq9b', [
    "export ANT_TEAM_GITHUB_PROJECT_NUMBER='9'",
    "export OWNER='legacy-owner'",
  ]);
  r = runHelper(c, ['project-list']);
  assert.strictEqual(r.status, 0, `legacy exit ${r.status}\nstderr:\n${r.stderr}`);
  call = calls(c)[0];
  assert.ok(call[call.indexOf('--owner') + 1] === 'legacy-owner', 'legacy OWNER is the last resort');

  // Empty resolution fails before gh for all three commands.
  c = setup('bpq9c', ["export ANT_TEAM_GITHUB_PROJECT_NUMBER='9'"]);
  for (const args of [['project-list'], ['project-view', '9'], ['project-field-list', '9']]) {
    const rr = runHelper(c, args);
    assert.notStrictEqual(rr.status, 0, `${args.join(' ')} must fail without an owner`);
    assert.ok(/owner/.test(rr.stderr), `error must name the owner: ${rr.stderr}`);
  }
  assert.strictEqual(calls(c).length, 0, 'gh must not be called');
});

// --- BPQ-10: positional owner rejected everywhere (HIC-17 extension) -----------------

check('BPQ-10: every board/project query command rejects a positional owner before gh', () => {
  const c = ctx('bpq10');
  for (const args of [
    ['list-unassigned', 'Antpolis'],
    ['list-items', 'Antpolis', '9'],
    ['item-id', 'Antpolis', '9'],
    ['item-state', 'Antpolis', '9'],
    ['next-status', 'Antpolis', '9', 'Ready', 'In Progress'],
    ['project-list', 'Antpolis'],
    ['project-view', 'Antpolis'],
    ['project-view', '9', 'Antpolis'],
    ['project-field-list', 'Antpolis', '9'],
    ['project-view', 'Antpolis', '--owner', 'x'],
  ]) {
    const r = runHelper(c, args);
    assert.notStrictEqual(r.status, 0, `${args.join(' ')} must be rejected (no positional owner)`);
  }
  assert.strictEqual(calls(c).length, 0, 'gh must never be called for positional-owner misuse');
});

// --- summary --------------------------------------------------------------------------

console.log(`\n${passed} passed, ${failed} failed (board/project query subcommands, issue #46)`);
if (failed > 0) process.exit(1);
