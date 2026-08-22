#!/usr/bin/env node
'use strict';

/*
 * tests/test_workflow_invariants.js — workflow-revision invariants (2026-08).
 *
 * Locks the agreed workflow revision into executable checks so later edits
 * cannot silently regress it:
 *
 *   INV-1  Canonical state model: Open -> Backlog -> Ready -> In Progress ->
 *          In Review -> Ready to Merge -> Done, with Need attentions
 *          (founder-only, after strategist and tech-lead review) and Blocked
 *          (exception, any state may enter, typically In Progress/In Review).
 *   INV-2  The canonical state set lives as constants in the workflow skills,
 *          tests, and docs; `.github-project.env` carries the verified
 *          Workflow State field and option IDs under canonical keys (no JSON
 *          config, no `canonicalWorkflowStates` field).
 *   INV-3  The GitHub helper targets the canonical "Workflow State" field and
 *          never mutates remote board options.
 *   INV-4  Record split: Obsidian is the full agent communication and
 *          role-memory record; GitHub issue/PR comments carry only final
 *          decisions, status, closure, and code-review results.
 *   INV-5  Tech-lead owns merge and cleanup.
 *   INV-6  Operational scripts run through ANT_TEAM_SCRIPTS (sync-company
 *          prerequisite); the legacy local-markdown pm-lib script family is
 *          fully retired — no active script may reference it.
 *   INV-7  /migrate command and --migrate-agent-md are retired.
 *   INV-8  Orchestrator model stays openai/gpt-5.6-luna-fast.
 *   INV-9  project-init is env-only with NO JSON import/removal path: a stray
 *          .github-project.json is ignored (never read, never removed); init
 *          reads and writes only .github-project.env.
 *   INV-10 Runtime metadata comes from .github-project.env, not runtime JSON
 *          parsing: AGENTS.md is the primary agent-facing runtime guidance
 *          (must-source rule, key ANT_TEAM_* variables, no-JSON rule,
 *          sync-company + project-init prerequisite, tilde expansion), and the
 *          runtime-facing commands and skills mention .github-project.json
 *          only in env-paired, no-JSON, or canonical-source contexts.
 *   INV-11 No active surface claims GitHub comments are the canonical or
 *          durable communication record: Obsidian is the full record, GitHub
 *          comments carry only final decisions, status, closure, and
 *          code-review results (2026-08 audit finding 1).
 *   INV-12 No legacy state names (Shaping, Inbox) or board statuses on active
 *          surfaces; the issue template Workflow State dropdown lists exactly
 *          the canonical nine states (audit finding 2).
 *   INV-13 No legacy role names or legacy local-board statuses on active
 *          surfaces (scripts, skills, commands, README, AGENTS.md, templates);
 *          retired operational scripts stay retired (audit finding 3).
 *   INV-14 README reflects the current model: roles, commands, record split,
 *          env-only config, state model, tech-lead merge/cleanup — and no
 *          retired command/role/script claims (audit finding 4).
 *   INV-15 No stale ANT_TEAM_GITHUB_STATUS_* legacy env keys anywhere: the
 *          board is driven only by the Workflow State field (audit finding 5).
 *
 * No external npm dependencies — Node built-ins only. No network access.
 */

const { execFileSync, spawnSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const assert = require('assert');

const REPO_ROOT = path.resolve(__dirname, '..');
const INIT_SCRIPT = path.join(
  REPO_ROOT,
  '.opencode/skills/project-initialization/scripts/init_project_docs.sh'
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

function read(p) {
  return fs.readFileSync(path.join(REPO_ROOT, p), 'utf8');
}

function mustContain(content, needle, context) {
  if (!content.includes(needle)) {
    assert.fail(`${context || 'content'} must contain ${JSON.stringify(needle)}`);
  }
}

function mustNotContain(content, needle, context) {
  if (content.includes(needle)) {
    assert.fail(`${context || 'content'} must not contain ${JSON.stringify(needle)}`);
  }
}

// Active surfaces = guidance a runtime agent or operator actually consumes.
// Historical docs (docs/, including docs/memory and superseded templates) are
// append-only history and are deliberately NOT scanned.
function walkFiles(dir, exts, out = []) {
  for (const e of fs.readdirSync(path.join(REPO_ROOT, dir), { withFileTypes: true })) {
    const rel = path.join(dir, e.name);
    if (e.isDirectory()) walkFiles(rel, exts, out);
    else if (exts.some((x) => e.name.endsWith(x))) out.push(rel);
  }
  return out;
}

function activeMarkdownSurfaces() {
  return [
    ...walkFiles('.opencode/skills', ['.md']),
    ...walkFiles('.opencode/commands', ['.md']),
    'README.md',
    'AGENTS.md',
    '.github/ISSUE_TEMPLATE/task.yml',
  ];
}

function activeScriptSurfaces() {
  return [
    ...walkFiles('scripts', ['.sh']),
    ...walkFiles('.opencode/skills', ['.sh']),
  ];
}

const CURRENT_ROLES = ['orchestrator', 'strategist', 'tech-lead', 'builder', 'reviewer'];
const CANONICAL_BOARD_STATES = [
  'Open',
  'Backlog',
  'Need attentions',
  'Ready',
  'In Progress',
  'In Review',
  'Ready to Merge',
  'Blocked',
  'Done',
];
// The retired local-markdown operational script family (audit finding 3).
const RETIRED_SCRIPT_BASENAMES = [
  'pm-lib.sh', 'add-task-dependency.sh', 'close-task.sh', 'create-blocker.sh',
  'create-defer-task.sh', 'create-spec.sh', 'create-spec-tasks.sh',
  'create-task-comment.sh', 'create-task.sh', 'list-tasks.sh', 'next-id.sh',
  'open-review-loop.sh', 'read-role-memory.sh', 'read-task-comments.sh',
  'read-task-replies.sh', 'record-loop-breaker.sh', 'record-merge.sh',
  'record-pr-comment.sh', 'record-pr.sh', 'record-qa-smoke.sh',
  'record-release.sh', 'record-review-result.sh', 'reply-task-comment.sh',
  'resolve-blocker.sh', 'setup-doc-structure.sh', 'update-document-index.sh',
  'update-role-memory.sh', 'update-task-owner.sh', 'update-task-status.sh',
  'validate-project-state.sh',
];

const CANONICAL_STATES = [
  'Open',
  'Backlog',
  'Ready',
  'In Progress',
  'In Review',
  'Ready to Merge',
  'Done',
];
const EXCEPTION_STATES = ['Need attentions', 'Blocked'];
const OPTION_KEYS = [
  'open',
  'backlog',
  'need-attentions',
  'ready',
  'in-progress',
  'in-review',
  'ready-to-merge',
  'blocked',
  'done',
];
const OPTION_VAR_NAMES = [
  'OPEN',
  'BACKLOG',
  'NEED_ATTENTIONS',
  'READY',
  'IN_PROGRESS',
  'IN_REVIEW',
  'READY_TO_MERGE',
  'BLOCKED',
  'DONE',
];

// --- INV-1: canonical state model in skills + metadata -----------------------

check('INV-1a: state-transitions defines the canonical happy path in order', () => {
  const s = read('.opencode/skills/state-transitions/SKILL.md');
  mustContain(s, '`Open` -> `Backlog` -> `Ready` -> `In Progress` -> `In Review` -> `Ready to Merge` -> `Done`', 'state-transitions');
  mustContain(s, '`Open` -> `Backlog`', 'state-transitions');
  mustContain(s, '`Backlog` -> `Ready`', 'state-transitions');
});

check('INV-1b: state-transitions has no legacy Inbox/Shaping transitions', () => {
  const s = read('.opencode/skills/state-transitions/SKILL.md');
  mustNotContain(s, '### `Inbox`', 'state-transitions');
  mustNotContain(s, '### `Shaping`', 'state-transitions');
  // Legacy names may only appear in the explicit legacy-alias note.
  const withoutNote = s.replace(/Legacy board option names[^\n]*\n/, '');
  mustNotContain(withoutNote, '`Inbox`', 'state-transitions (outside legacy note)');
  mustNotContain(withoutNote, '`Shaping`', 'state-transitions (outside legacy note)');
});

check('INV-1c: Need attentions is founder-only after strategist and tech-lead review', () => {
  const files = [
    '.opencode/skills/state-transitions/SKILL.md',
    '.opencode/skills/approval-or-escalation/SKILL.md',
    '.opencode/skills/github-agentic-delivery-flow/SKILL.md',
    '.opencode/skills/github-conventions/SKILL.md',
  ];
  for (const f of files) {
    const s = read(f);
    mustContain(s, 'founder-only', f);
  }
  const st = read('.opencode/skills/state-transitions/SKILL.md');
  mustContain(st, 'after strategist and tech-lead review', 'state-transitions');
});

check('INV-1d: Blocked is an exception state, any state may enter, typically In Progress/In Review', () => {
  const st = read('.opencode/skills/state-transitions/SKILL.md');
  mustContain(st, 'Any State` -> `Blocked` (exception)', 'state-transitions');
  mustContain(st, 'typically `In Progress` or `In Review`', 'state-transitions');
});

check('INV-1e: flow and conventions skills list the canonical states, not legacy ones', () => {
  const flow = read('.opencode/skills/github-agentic-delivery-flow/SKILL.md');
  mustContain(flow, '- `Open`', 'github-agentic-delivery-flow');
  mustContain(flow, '- `Backlog`', 'github-agentic-delivery-flow');
  mustNotContain(flow, '- `Inbox`', 'github-agentic-delivery-flow');
  mustNotContain(flow, '- `Shaping`', 'github-agentic-delivery-flow');
  const conv = read('.opencode/skills/github-conventions/SKILL.md');
  mustContain(conv, '- `Open`', 'github-conventions');
  mustContain(conv, '- `Backlog`', 'github-conventions');
  mustNotContain(conv, '- `Inbox`', 'github-conventions');
  mustNotContain(conv, '- `Shaping`', 'github-conventions');
});

// --- INV-2: canonical state set is a code/docs constant; env carries IDs ------

check('INV-2a: no .github-project.json config exists (env-only contract)', () => {
  assert.ok(
    !fs.existsSync(path.join(REPO_ROOT, '.github-project.json')),
    '.github-project.json must not exist under the env-only contract'
  );
});

check('INV-2b: state-transitions and the helper carry the canonical model as constants', () => {
  const st = read('.opencode/skills/state-transitions/SKILL.md');
  for (const state of [...CANONICAL_STATES, ...EXCEPTION_STATES]) {
    mustContain(st, state, 'state-transitions canonical state name');
  }
  const h = read('.opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh');
  mustContain(h, 'CANONICAL_FIELD_NAME="Workflow State"', 'helper');
});

check('INV-2c: .github-project.env carries the canonical Workflow State field and option IDs', () => {
  const env = read('.github-project.env');
  mustContain(env, 'export ANT_TEAM_GITHUB_WORKFLOW_STATE_FIELD_ID=', '.github-project.env');
  for (const key of OPTION_VAR_NAMES) {
    mustContain(
      env,
      `export ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_${key}_ID=`,
      '.github-project.env workflow state option'
    );
  }
  // The dropped canonicalWorkflowStates config field must not reappear.
  mustNotContain(env, 'canonicalWorkflowStates', '.github-project.env');
  mustNotContain(env, 'identity', '.github-project.env');
  mustNotContain(env, 'boundaries', '.github-project.env');
  mustNotContain(env, 'initMeta', '.github-project.env');
});

// --- INV-3: helper targets Workflow State, never mutates remote options ------

check('INV-3a: gh_project_helper targets the canonical Workflow State field', () => {
  const h = read('.opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh');
  mustContain(h, 'CANONICAL_FIELD_NAME="Workflow State"', 'helper');
  mustContain(h, 'ANT_TEAM_GITHUB_WORKFLOW_STATE_FIELD_ID', 'helper');
  mustContain(h, 'ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_', 'helper');
});

check('INV-3b: helper contains no legacy Status-field selection or list-todo', () => {
  const h = read('.opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh');
  mustNotContain(h, 'select(.name == "Status")', 'helper');
  mustNotContain(h, 'list-todo', 'helper');
});

check('INV-3c: helper performs no option-mutating mutations (no field/option create or rename)', () => {
  const h = read('.opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh');
  mustNotContain(h, 'field-update', 'helper');
  mustNotContain(h, 'option-update', 'helper');
  mustNotContain(h, 'updateProjectV2Field', 'helper'); // raw GraphQL option mutation
  mustContain(h, 'never renames remote board options', 'helper');
});

check('INV-3d: helper resolves option IDs by exact remote name or known local IDs only', () => {
  const h = read('.opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh');
  mustContain(h, 'select(.name == $state)', 'helper');
});

// --- INV-4: record split ------------------------------------------------------

check('INV-4a: top-level flow skill states the Obsidian/GitHub record split', () => {
  const flow = read('.opencode/skills/github-agentic-delivery-flow/SKILL.md');
  mustContain(flow, 'central Obsidian project folder is the canonical full agent communication and role-memory record', 'flow skill');
  mustContain(flow, 'GitHub issue comments and PR comments carry only final decisions, status, closure, and code-review results', 'flow skill');
});

check('INV-4b: no skill or agent prompt still claims GitHub comments are the canonical handoff log', () => {
  const offenders = [];
  const roots = ['.opencode/skills', '.opencode/commands', 'AGENTS.md'];
  const walk = (dir) => {
    for (const e of fs.readdirSync(path.join(REPO_ROOT, dir), { withFileTypes: true })) {
      const rel = path.join(dir, e.name);
      if (e.isDirectory()) walk(rel);
      else if (e.name.endsWith('.md')) {
        if (read(rel).includes('canonical handoff and review log')) offenders.push(rel);
      }
    }
  };
  for (const r of roots) {
    const full = path.join(REPO_ROOT, r);
    if (fs.statSync(full).isDirectory()) walk(r);
    else if (read(r).includes('canonical handoff and review log')) offenders.push(r);
  }
  const oc = read('.opencode/opencode.json');
  if (oc.includes('canonical handoff and review log')) offenders.push('.opencode/opencode.json');
  assert.deepStrictEqual(offenders, [], 'no file may claim GitHub comments are the canonical handoff log');
});

check('INV-4c: agent prompts carry the Obsidian record rule', () => {
  const oc = JSON.parse(read('.opencode/opencode.json'));
  const agents = Object.values(oc.agent || {});
  assert.ok(agents.length >= 5, 'expected at least 5 role agents');
  for (const a of agents) {
    mustContain(a.prompt || '', 'canonical full agent communication and role-memory record', 'agent prompt');
  }
});

// --- INV-5: tech-lead owns merge and cleanup ---------------------------------

check('INV-5a: tech-lead merge gate stays exclusive', () => {
  const flow = read('.opencode/skills/github-agentic-delivery-flow/SKILL.md');
  mustContain(flow, 'Tech-lead is the only role that merges', 'flow skill');
});

check('INV-5b: tech-lead owns post-merge cleanup', () => {
  const oc = JSON.parse(read('.opencode/opencode.json'));
  const agents = Object.values(oc.agent || {});
  const techLead = agents.find((a) => (a.prompt || '').includes('technical gatekeeper'));
  assert.ok(techLead, 'tech-lead agent prompt not found');
  mustContain(techLead.prompt, 'clean up the task worktree and local branch with `$ANT_TEAM_SCRIPTS/cleanup-task-worktree.sh`', 'tech-lead prompt');
  const builder = agents.find((a) => (a.prompt || '').includes('You implement approved work'));
  assert.ok(builder, 'builder agent prompt not found');
  mustNotContain(builder.prompt, 'clean up the task worktree and local branch once they are no longer needed', 'builder prompt');
  const doTask = read('.opencode/skills/do-task/SKILL.md');
  mustContain(doTask, '`tech-lead` cleans up the issue worktree and local branch', 'do-task skill');
});

// --- INV-6: ANT_TEAM_SCRIPTS / sync-company prerequisite ---------------------

check('INV-6a: no operational script sources pm-lib relatively', () => {
  const dir = path.join(REPO_ROOT, 'scripts');
  const offenders = [];
  for (const f of fs.readdirSync(dir)) {
    if (!f.endsWith('.sh')) continue;
    const c = fs.readFileSync(path.join(dir, f), 'utf8');
    if (c.includes('$(dirname "$0")/pm-lib.sh')) offenders.push(f);
  }
  assert.deepStrictEqual(offenders, [], 'scripts must source pm-lib via ANT_TEAM_SCRIPTS');
});

check('INV-6b: the retired pm-lib script family stays retired', () => {
  // The retired files must not come back (sync-company would install them).
  for (const f of RETIRED_SCRIPT_BASENAMES) {
    assert.ok(
      !fs.existsSync(path.join(REPO_ROOT, 'scripts', f)),
      `scripts/${f} is retired local-markdown workflow and must not exist`
    );
  }
  // No active script may reference pm-lib (the shared legacy library).
  const offenders = [];
  for (const f of activeScriptSurfaces()) {
    if (read(f).includes('pm-lib')) offenders.push(f);
  }
  assert.deepStrictEqual(offenders, [], 'no active script may reference the retired pm-lib');
});

check('INV-6c: init-project wrappers route through ANT_TEAM_SCRIPTS', () => {
  const w = read('scripts/init-project-docs.sh');
  mustContain(w, '${ANT_TEAM_SCRIPTS:', 'init-project-docs.sh');
  mustContain(w, 'sync-company.sh', 'init-project-docs.sh');
  mustNotContain(w, '$(dirname "$0")/../.opencode', 'init-project-docs.sh');
  const wrappers = ['scripts/create-task-branch.sh', 'scripts/cleanup-task-worktree.sh'];
  for (const f of wrappers) {
    mustContain(read(f), '${ANT_TEAM_SCRIPTS:', f);
  }
});

check('INV-6d: sync-company installs team scripts and exports ANT_TEAM_SCRIPTS', () => {
  const s = read('scripts/sync-company.sh');
  mustContain(s, 'sync_team_scripts', 'sync-company.sh');
  mustContain(s, 'export ANT_TEAM_SCRIPTS="$HOME/.agents/scripts"', 'sync-company.sh');
});

// --- INV-7: /migrate and --migrate-agent-md retired --------------------------

check('INV-7a: /migrate command file is gone', () => {
  assert.ok(
    !fs.existsSync(path.join(REPO_ROOT, '.opencode/commands/migrate.md')),
    '.opencode/commands/migrate.md must not exist'
  );
});

check('INV-7b: init engine has no --migrate-agent-md flag', () => {
  const s = read('.opencode/skills/project-initialization/scripts/init_project_docs.sh');
  mustNotContain(s, '--migrate-agent-md', 'init engine');
  mustNotContain(s, 'opt_migrate_agent_md', 'init engine');
});

// --- INV-8: orchestrator model ------------------------------------------------

check('INV-8: orchestrator agent model is openai/gpt-5.6-luna-fast', () => {
  const oc = JSON.parse(read('.opencode/opencode.json'));
  assert.ok(oc.agent && oc.agent.orchestrator, 'orchestrator agent not found');
  assert.strictEqual(oc.agent.orchestrator.model, 'openai/gpt-5.6-luna-fast');
});

// --- INV-9: project-init is env-only with NO JSON import/removal path --------

function mkdtempRepo(prefix) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), `${prefix}-`));
  fs.mkdirSync(path.join(tmp, '.git'), { recursive: true });
  return tmp;
}

function runInit(args) {
  return spawnSync('bash', [INIT_SCRIPT, ...args], { encoding: 'utf8' });
}

function initArgs(tmp, extra = []) {
  return [
    '--noninteractive',
    '--project-dir', tmp,
    '--worktree-root', path.join(tmp, 'wt'),
    '--name', 'demo',
    '--github-owner', 'antpolis',
    '--github-project-number', '1',
    '--skip-inspection',
    ...extra,
  ];
}

check('INV-9a: a stray .github-project.json is ignored (never read, never removed)', () => {
  const tmp = mkdtempRepo('inv9a');
  const strayPath = path.join(tmp, '.github-project.json');
  fs.writeFileSync(
    strayPath,
    JSON.stringify({ owner: 'json-owner', project: { id: 'PVT_JSON' } }, null, 2)
  );
  const r = runInit(initArgs(tmp));
  assert.strictEqual(r.status, 0, `init exit ${r.status}\nstderr:\n${r.stderr}`);
  // Not removed — there is no JSON removal path.
  assert.ok(fs.existsSync(strayPath), '.github-project.json must be left in place');
  // Not imported — flag value wins, JSON values absent.
  const env = fs.readFileSync(path.join(tmp, '.github-project.env'), 'utf8');
  assert.ok(env.includes("export ANT_TEAM_GITHUB_OWNER='antpolis'"), 'flag owner recorded');
  assert.ok(!env.includes('json-owner'), 'JSON owner must not be imported');
  assert.ok(!env.includes('PVT_JSON'), 'JSON project id must not be imported');
});

check('INV-9b: rerun with a stray JSON is idempotent and leaves the JSON untouched', () => {
  const tmp = mkdtempRepo('inv9b');
  const strayPath = path.join(tmp, '.github-project.json');
  fs.writeFileSync(strayPath, '{ "owner": "json-owner" }');
  const args = initArgs(tmp, ['--force']);
  const first = runInit(args);
  assert.strictEqual(first.status, 0, `first run exit ${first.status}\nstderr:\n${first.stderr}`);
  const envPath = path.join(tmp, '.github-project.env');
  const envAfterFirst = fs.readFileSync(envPath, 'utf8');
  const second = runInit(args);
  assert.strictEqual(second.status, 0, `second run exit ${second.status}\nstderr:\n${second.stderr}`);
  assert.ok(fs.existsSync(strayPath), 'stray JSON must not be removed on rerun');
  assert.strictEqual(
    fs.readFileSync(envPath, 'utf8'),
    envAfterFirst,
    'rerun must be byte-identical (idempotent)'
  );
});

// --- INV-10: runtime metadata via .github-project.env, not JSON parsing -------

check('INV-10a: AGENTS.md is the primary runtime guidance for .github-project.env', () => {
  const a = read('AGENTS.md');
  // Must-source rule covering the three runtime operation classes.
  mustContain(a, 'source ./.github-project.env', 'AGENTS.md');
  mustContain(a, 'before GitHub API/project operations', 'AGENTS.md');
  mustContain(a, 'documentation access', 'AGENTS.md');
  mustContain(a, 'worktree operations', 'AGENTS.md');
  // No-JSON rule: the env is the sole committed config; no JSON config exists.
  mustContain(a, 'sole committed project config source', 'AGENTS.md');
  mustContain(a, 'there is no `.github-project.json`', 'AGENTS.md');
  // Key ANT_TEAM_* variables are shown.
  for (const v of [
    'ANT_TEAM_GITHUB_OWNER',
    'ANT_TEAM_GITHUB_REPO',
    'ANT_TEAM_GITHUB_PROJECT_NUMBER',
    'ANT_TEAM_GITHUB_PROJECT_ID',
    'ANT_TEAM_GITHUB_WORKFLOW_STATE_FIELD_ID',
    'ANT_TEAM_WORKTREE_ROOT',
    'ANT_TEAM_DOCS_VAULT_PATH',
    'ANT_TEAM_DOCS_PROJECT_NAME',
    'ANT_TEAM_DOCS_PROJECT_PATH',
    'ANT_TEAM_DOCS_REPOSITORY',
  ]) {
    mustContain(a, v, 'AGENTS.md key variables');
  }
  // Prerequisite chain: sync-company installs scripts, project-init seeds the env.
  mustContain(a, 'scripts/sync-company.sh', 'AGENTS.md');
  mustContain(a, 'init-project-docs.sh', 'AGENTS.md');
  mustContain(a, 'no standalone generator', 'AGENTS.md');
  mustContain(a, 'no JSON config', 'AGENTS.md');
  // Worktree root may carry a literal ~ that git will not expand.
  mustContain(a, 'git does not expand tildes inside variables', 'AGENTS.md');
});

// Runtime-facing guidance files identified by tech-lead (2026-08): these must
// not instruct agents to parse .github-project.json for runtime GitHub or
// documentation paths. Every JSON mention must sit in an allowed context:
// env-paired, no-JSON, or canonical-source.
const RUNTIME_FACING_GUIDANCE_FILES = [
  '.opencode/commands/plan-sprint.md',
  '.opencode/commands/sprint-clean.md',
  '.opencode/commands/sync-spec.md',
  '.opencode/skills/documentation-standard/SKILL.md',
  '.opencode/skills/agent-communication-log/SKILL.md',
  '.opencode/skills/role-memory/SKILL.md',
  '.opencode/skills/founder-escalation-preflight/SKILL.md',
  '.opencode/skills/pr-review-flow/SKILL.md',
  '.opencode/skills/development-hygiene/SKILL.md',
  'AGENTS.md',
];
const JSON_MENTION_ALLOWED_CONTEXT = [
  '.github-project.env',
  'ANT_TEAM_',
  'canonical',
  'source of truth',
  'initializat',
  'init-project',
  'instead of parsing',
  'do not parse',
  'never parse',
  'no JSON',
  'no `.github-project.json`',
  'regenerat',
  'generated',
];

check('INV-10b: runtime-facing commands and skills never instruct runtime JSON parsing', () => {
  const offenders = [];
  for (const f of RUNTIME_FACING_GUIDANCE_FILES) {
    const lines = read(f).split('\n');
    lines.forEach((line, i) => {
      if (!line.includes('.github-project.json')) return;
      const ok = JSON_MENTION_ALLOWED_CONTEXT.some((m) => line.includes(m));
      if (!ok) offenders.push(`${f}:${i + 1}: ${line.trim()}`);
    });
  }
  assert.deepStrictEqual(
    offenders,
    [],
    '.github-project.json mentions must be env-paired, no-JSON, or canonical-source contexts:\n' +
      offenders.join('\n')
  );
});

// --- INV-11: no GitHub-comments-as-canonical-record language (audit 1) -------

const GITHUB_AUTHORITY_PHRASES = [
  'canonical collaboration log',
  'canonical handoff log',
  'canonical handoff surface',
  'canonical handoff and review log',
  'durable handoff surface',
  'durable GitHub comment',
  'GitHub-ready summary',
];

check('INV-11a: no active surface claims GitHub comments are the canonical/durable record', () => {
  const offenders = [];
  for (const f of activeMarkdownSurfaces()) {
    for (const phrase of GITHUB_AUTHORITY_PHRASES) {
      if (read(f).includes(phrase)) offenders.push(`${f}: ${phrase}`);
    }
  }
  const oc = read('.opencode/opencode.json');
  for (const phrase of GITHUB_AUTHORITY_PHRASES) {
    if (oc.includes(phrase)) offenders.push(`.opencode/opencode.json: ${phrase}`);
  }
  assert.deepStrictEqual(
    offenders,
    [],
    'GitHub comments carry only final decisions/status/closure/review results; the full record is Obsidian:\n' +
      offenders.join('\n')
  );
});

check('INV-11b: the finding-1 files route the full record through Obsidian', () => {
  const files = [
    '.opencode/skills/how-to-create-task/SKILL.md',
    '.opencode/commands/new-spec.md',
    '.opencode/commands/deliver.md',
    '.opencode/skills/product-shaping/SKILL.md',
  ];
  for (const f of files) {
    const s = read(f);
    mustContain(s, 'Obsidian', f);
    mustNotContain(s, 'only canonical collaboration log', f);
  }
  const log = read('.opencode/skills/agent-communication-log/SKILL.md');
  mustContain(log, 'The full agent communication and role-memory record is stored in Obsidian', 'agent-communication-log');
  mustContain(
    log,
    'GitHub issue and PR comments carry only',
    'agent-communication-log'
  );
});

// --- INV-12: legacy state names and issue-template drift (audit 2) -----------

check('INV-12a: issue template Workflow State options are exactly the canonical nine', () => {
  const yml = read('.github/ISSUE_TEMPLATE/task.yml');
  const m = yml.match(/id: workflow_state[\s\S]*?options:\n((?:\s+- .+\n)+)/);
  assert.ok(m, 'workflow_state dropdown with options not found in task.yml');
  const options = m[1].trim().split('\n').map((l) => l.trim().replace(/^- /, ''));
  assert.deepStrictEqual(
    options,
    CANONICAL_BOARD_STATES,
    `task.yml Workflow State options must be the canonical nine in order:\n${options.join(', ')}`
  );
});

check('INV-12b: issue template role owner options are the current roles only', () => {
  const yml = read('.github/ISSUE_TEMPLATE/task.yml');
  const m = yml.match(/id: role_owner[\s\S]*?options:\n((?:\s+- .+\n)+)/);
  assert.ok(m, 'role_owner dropdown with options not found in task.yml');
  const options = m[1].trim().split('\n').map((l) => l.trim().replace(/^- /, ''));
  assert.deepStrictEqual(
    [...options].sort(),
    [...CURRENT_ROLES].sort(),
    `task.yml role owner options must be exactly the current roles:\n${options.join(', ')}`
  );
});

check('INV-12c: no backticked legacy states on active surfaces outside legacy-alias notes', () => {
  const offenders = [];
  const files = [...activeMarkdownSurfaces(), ...activeScriptSurfaces()];
  for (const f of files) {
    read(f).split('\n').forEach((line, i) => {
      if (!/`(Shaping|Inbox)`/.test(line)) return;
      if (/legacy/i.test(line)) return; // explicit legacy-alias note is allowed
      offenders.push(`${f}:${i + 1}: ${line.trim()}`);
    });
  }
  assert.deepStrictEqual(
    offenders,
    [],
    'legacy state names may appear only in explicit legacy-alias notes:\n' + offenders.join('\n')
  );
});

check('INV-12d: sprint/spec command surfaces use Open/Backlog semantics, not Shaping', () => {
  const files = [
    '.opencode/commands/new-spec.md',
    '.opencode/commands/sync-spec.md',
    '.opencode/commands/plan-sprint.md',
  ];
  for (const f of files) {
    const s = read(f);
    mustNotContain(s, '`Shaping`', f);
    mustNotContain(s, '`Inbox`', f);
    mustContain(s, '`Backlog`', f);
  }
});

// --- INV-13: legacy roles/statuses and retired scripts (audit 3) -------------

const OLD_ROLE_TERMS = [
  'product-owner',
  'delivery-manager',
  'qa-smoke',
  'developer-memory',
  'qa-memory',
];
const OLD_STATUS_TERMS = ['In Development', 'PR Open', 'QA Smoke', 'Architecture Review'];

check('INV-13a: no legacy role names on active surfaces', () => {
  const offenders = [];
  const files = [...activeMarkdownSurfaces(), ...activeScriptSurfaces()];
  for (const f of files) {
    const c = read(f);
    for (const term of OLD_ROLE_TERMS) {
      if (c.includes(term)) offenders.push(`${f}: ${term}`);
    }
    if (/\b(CPO|CTO)\b/.test(c)) offenders.push(`${f}: CPO/CTO`);
  }
  const oc = read('.opencode/opencode.json');
  for (const term of OLD_ROLE_TERMS) {
    if (oc.includes(term)) offenders.push(`.opencode/opencode.json: ${term}`);
  }
  if (/\b(CPO|CTO)\b/.test(oc)) offenders.push('.opencode/opencode.json: CPO/CTO');
  assert.deepStrictEqual(
    offenders,
    [],
    `active surfaces must use the current roles (${CURRENT_ROLES.join(', ')}):\n` + offenders.join('\n')
  );
});

check('INV-13b: no legacy local-board statuses on active surfaces', () => {
  const offenders = [];
  const files = [...activeMarkdownSurfaces(), ...activeScriptSurfaces()];
  for (const f of files) {
    const c = read(f);
    for (const term of OLD_STATUS_TERMS) {
      if (c.includes(term)) offenders.push(`${f}: ${term}`);
    }
  }
  assert.deepStrictEqual(
    offenders,
    [],
    'the board is driven only by the canonical Workflow State model:\n' + offenders.join('\n')
  );
});

// --- INV-14: README drift (audit 4) -------------------------------------------

check('INV-14a: README carries the current model anchors', () => {
  const r = read('README.md');
  for (const role of CURRENT_ROLES) {
    mustContain(r, `\`${role}\``, 'README current roles');
  }
  mustContain(r, '`Open` -> `Backlog` -> `Ready` -> `In Progress` -> `In Review` -> `Ready to Merge` -> `Done`', 'README');
  mustContain(r, '`Need attentions`', 'README');
  mustContain(r, 'Workflow State', 'README');
  mustContain(r, 'only role that merges', 'README');
  mustContain(r, '.github-project.env', 'README');
  mustContain(r, 'ANT_TEAM_', 'README');
  mustContain(r, 'sole committed project config source', 'README');
  mustContain(r, 'Obsidian', 'README');
  mustContain(r, 'final decisions, status, closure, and code-review results', 'README');
});

check('INV-14b: README makes no retired command, role, or script claims', () => {
  const r = read('README.md');
  const banned = [
    '`migrate`', '/migrate', 'product-owner', 'delivery-manager', 'CPO', 'CTO',
    'qa-smoke', 'DOC_ROOT', 'OBSIDIAN_VAULT_PATH', 'developer-memory', 'qa-memory',
    ...RETIRED_SCRIPT_BASENAMES.map((f) => `scripts/${f}`),
  ];
  const offenders = banned.filter((term) => r.includes(term));
  assert.deepStrictEqual(offenders, [], `README must not reference retired artifacts:\n${offenders.join('\n')}`);
});

// --- INV-15: no stale legacy env keys (audit 5) -------------------------------

check('INV-15: no ANT_TEAM_GITHUB_STATUS_* legacy keys in the env or its seed sources', () => {
  const files = [
    '.github-project.env',
    '.opencode/skills/project-initialization/scripts/setup_project_docs.sh',
    '.opencode/skills/project-initialization/scripts/init_project_docs.sh',
    '.opencode/skills/github-issues-projects-cli/references/command-patterns.md',
  ];
  for (const f of files) {
    mustNotContain(read(f), 'ANT_TEAM_GITHUB_STATUS_', f);
  }
  // The env itself keeps exactly the canonical Workflow State field + options.
  const env = read('.github-project.env');
  mustContain(env, 'export ANT_TEAM_GITHUB_WORKFLOW_STATE_FIELD_ID=', '.github-project.env');
});

// --- summary -------------------------------------------------------------------

console.log(`\n${passed} passed, ${failed} failed (workflow invariants)`);
if (failed > 0) process.exit(1);
