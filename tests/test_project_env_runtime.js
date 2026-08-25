#!/usr/bin/env node
'use strict';

/*
 * tests/test_project_env_runtime.js — env-only project config contract (2026-08).
 *
 * Locks the founder-confirmed env-only configuration contract into executable
 * checks. `.github-project.json` no longer exists as a config artifact:
 * `.github-project.env` (ANT_TEAM_* exports) is the SOLE committed project
 * config source, seeded and updated DIRECTLY by project initialization (no
 * standalone generator, no jq, node-only). There is NO JSON import/removal
 * path — a stray `.github-project.json` is ignored (never read, never removed).
 *
 *   ENV-1   fresh init seeds the full canonical env key set; no JSON is written
 *   ENV-2   founder env values are preserved; only missing keys are filled
 *   ENV-3   a stray .github-project.json is ignored (not imported, not removed)
 *   ENV-4   ANT_TEAM_DOCS_PROJECT_NAME defaults to the git repo basename
 *   ENV-5   founder projectName override is preserved by init
 *   ENV-6   shell-hostile founder values survive a strict source round-trip
 *   ENV-7   idempotent rerun leaves the env byte-identical and mtime unchanged
 *   ENV-8   --dry-run reports [would-write] and writes/deletes nothing
 *   ENV-9   gh_project_helper resolves from the env alone (no JSON parse)
 *   ENV-10  do-task worktree helpers read ANT_TEAM_WORKTREE_ROOT from the env
 *   ENV-11  AGENTS.md Local Configuration Files lists .github-project.env
 *   ENV-12  ANT_TEAM_DOCS_PROJECT_PATH resolves as VAULT_PATH/02-Architecture-Landscape/projects/NAME
 *           (founder-set concrete value preserved verbatim; no template key emitted)
 *
 * No external npm dependencies — Node built-ins only. No network access.
 */

const { spawnSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const assert = require('assert');

const REPO_ROOT = path.resolve(__dirname, '..');
const INIT_SCRIPT = path.join(
  REPO_ROOT,
  'templates/scripts/init-project.sh'
);
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

function runBash(script, options) {
  return spawnSync('bash', ['-c', script], { encoding: 'utf8', ...options });
}

function runInit(args, options) {
  return spawnSync('bash', [INIT_SCRIPT, ...args], { encoding: 'utf8', ...options });
}

function mkdtempRepo(prefix) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), `${prefix}-`));
  fs.mkdirSync(path.join(tmp, '.git'), { recursive: true });
  return tmp;
}

// jq @sh equivalent, mirroring the init script's own value escaping.
function shq(v) {
  return "'" + String(v).replace(/'/g, "'\\''") + "'";
}

function readEnvFile(dir) {
  return fs.readFileSync(path.join(dir, '.github-project.env'), 'utf8');
}

function initArgs(tmp, extra = []) {
  return [
    '--noninteractive',
    '--project-dir', tmp,
    '--worktree-root', path.join(tmp, 'wt'),
    '--name', 'demo-name',
    '--github-owner', 'antpolis',
    '--github-project-number', '1',
    '--skip-inspection',
    ...extra,
  ];
}

// Source the env in a strict bash and print ONE var (empty string when unset).
function envVar(dir, varName) {
  const r = runBash(
    `set -euo pipefail; source '${path.join(dir, '.github-project.env')}'; printf '%s' "\${${varName}-}"`
  );
  assert.strictEqual(r.status, 0, `sourcing .github-project.env failed:\n${r.stderr}`);
  return r.stdout;
}

// Canonical key sets (mirrored in init + skills + docs constants).
const CANONICAL_STATE_KEYS = [
  'OPEN', 'BACKLOG', 'NEED_ATTENTIONS', 'READY', 'IN_PROGRESS',
  'IN_REVIEW', 'READY_TO_MERGE', 'BLOCKED', 'DONE',
];

// --- ENV-1: fresh init seeds the canonical env key set, no JSON --------------

check('ENV-1: fresh init seeds the full canonical env key set and writes no JSON', () => {
  const tmp = mkdtempRepo('env1');
  const r = runInit(initArgs(tmp));
  assert.strictEqual(r.status, 0, `init exit ${r.status}\nstderr:\n${r.stderr}`);
  const envPath = path.join(tmp, '.github-project.env');
  assert.ok(fs.existsSync(envPath), '.github-project.env created by init');
  assert.ok(
    !fs.existsSync(path.join(tmp, '.github-project.json')),
    'init must never create .github-project.json under the env-only contract'
  );
  const content = readEnvFile(tmp);
  const required = [
    'ANT_TEAM_GITHUB_OWNER',
    'ANT_TEAM_GITHUB_OWNER_TYPE',
    'ANT_TEAM_GITHUB_REPO',
    'ANT_TEAM_GITHUB_PROJECT_NUMBER',
    'ANT_TEAM_GITHUB_PROJECT_ID',
    'ANT_TEAM_GITHUB_WORKFLOW_STATE_FIELD_ID',
    'ANT_TEAM_WORKTREE_ROOT',
    'ANT_TEAM_DOCS_PROJECT_NAME',
  ];
  for (const name of required) {
    assert.ok(content.includes(`export ${name}=`), `missing export line for ${name}:\n${content}`);
  }
  for (const key of CANONICAL_STATE_KEYS) {
    assert.ok(
      content.includes(`export ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_${key}_ID=`),
      `missing canonical state option export for ${key}`
    );
  }
  // Every non-comment line is an export (sourceable contract).
  for (const line of content.split('\n')) {
    if (line.trim() === '' || line.startsWith('#')) continue;
    assert.ok(/^export ANT_TEAM_[A-Z0-9_]+=/.test(line), `non-export line: ${line}`);
  }
  // Operator flag value recorded, not overwritten by a placeholder.
  assert.strictEqual(envVar(tmp, 'ANT_TEAM_GITHUB_OWNER'), 'antpolis');
});

// --- ENV-2: founder values preserved ------------------------------------------

check('ENV-2: founder env values are preserved; only missing keys are filled', () => {
  const tmp = mkdtempRepo('env2');
  const envPath = path.join(tmp, '.github-project.env');
  fs.writeFileSync(
    envPath,
    "# founder-owned env\n" +
      "export ANT_TEAM_GITHUB_OWNER='founder-owner'\n" +
      "export ANT_TEAM_DOCS_PROJECT_NAME='founder-name'\n"
  );
  const r = runInit(initArgs(tmp));
  assert.strictEqual(r.status, 0, `init exit ${r.status}\nstderr:\n${r.stderr}`);
  const content = readEnvFile(tmp);
  assert.ok(
    content.includes("export ANT_TEAM_GITHUB_OWNER='founder-owner'"),
    'founder owner must be preserved verbatim:\n' + content
  );
  assert.ok(
    content.includes("export ANT_TEAM_DOCS_PROJECT_NAME='founder-name'"),
    'founder project name must be preserved verbatim'
  );
  // Missing keys were filled.
  assert.ok(content.includes('export ANT_TEAM_GITHUB_PROJECT_NUMBER='));
  assert.ok(content.includes('export ANT_TEAM_WORKTREE_ROOT='));
  // The founder header is normalized but the founder value survives.
  assert.strictEqual(envVar(tmp, 'ANT_TEAM_GITHUB_OWNER'), 'founder-owner');
  assert.strictEqual(envVar(tmp, 'ANT_TEAM_DOCS_PROJECT_NAME'), 'founder-name');
});

// --- ENV-3: stray .github-project.json is ignored (no import/removal path) ---

check('ENV-3: a stray .github-project.json is ignored (not imported, not removed)', () => {
  const tmp = mkdtempRepo('env3');
  fs.writeFileSync(
    path.join(tmp, '.github-project.json'),
    '{ "owner": "json-owner", "project": { "number": 9, "id": "PVT_JSON" } }'
  );
  const r = runInit(initArgs(tmp));
  assert.strictEqual(r.status, 0, `init exit ${r.status}\nstderr:\n${r.stderr}`);
  // Never removed: the JSON is not a config artifact and init must not touch it.
  assert.ok(
    fs.existsSync(path.join(tmp, '.github-project.json')),
    'a stray .github-project.json must be left in place (no removal path)'
  );
  // Never imported: operator flag values win; JSON values must not appear.
  const content = readEnvFile(tmp);
  assert.strictEqual(envVar(tmp, 'ANT_TEAM_GITHUB_OWNER'), 'antpolis');
  assert.ok(
    !content.includes('json-owner'),
    'JSON owner must not be imported into the env'
  );
  assert.ok(
    !content.includes('PVT_JSON'),
    'JSON project id must not be imported into the env'
  );
  assert.strictEqual(envVar(tmp, 'ANT_TEAM_GITHUB_PROJECT_NUMBER'), '1');
});

// --- ENV-4: project name defaults to the git repo basename ---------------------

check('ENV-4: ANT_TEAM_DOCS_PROJECT_NAME defaults to the git repo basename', () => {
  const tmp = mkdtempRepo('env4');
  const r = runInit(initArgs(tmp));
  assert.strictEqual(r.status, 0, `init exit ${r.status}\nstderr:\n${r.stderr}`);
  assert.strictEqual(
    envVar(tmp, 'ANT_TEAM_DOCS_PROJECT_NAME'),
    path.basename(tmp),
    'project name must default to the repo basename, not --name ("demo-name")'
  );
});

// --- ENV-5: founder project name preserved -------------------------------------

check('ENV-5: founder projectName override is preserved by init', () => {
  const tmp = mkdtempRepo('env5');
  fs.writeFileSync(
    path.join(tmp, '.github-project.env'),
    "export ANT_TEAM_DOCS_PROJECT_NAME='founder-chosen'\n"
  );
  const r = runInit(initArgs(tmp, ['--force']));
  assert.strictEqual(r.status, 0, `init exit ${r.status}\nstderr:\n${r.stderr}`);
  assert.strictEqual(envVar(tmp, 'ANT_TEAM_DOCS_PROJECT_NAME'), 'founder-chosen');
});

// --- ENV-6: shell-hostile founder values round-trip ----------------------------

check('ENV-6: shell-hostile founder values survive a strict source round-trip', () => {
  const tmp = mkdtempRepo('env6');
  const hostileOwner = "od'day $(rm -rf /) `id` \\evil";
  const hostileRepo = 'owner/repo with spaces';
  fs.writeFileSync(
    path.join(tmp, '.github-project.env'),
    "# founder-owned env\n" +
      'export ANT_TEAM_GITHUB_OWNER=' + shq(hostileOwner) + '\n' +
      'export ANT_TEAM_GITHUB_REPO=' + shq(hostileRepo) + '\n'
  );
  const r = runInit(initArgs(tmp));
  assert.strictEqual(r.status, 0, `init exit ${r.status}\nstderr:\n${r.stderr}`);
  assert.strictEqual(
    envVar(tmp, 'ANT_TEAM_GITHUB_OWNER'),
    hostileOwner,
    'single-quoted value must round-trip byte-for-byte'
  );
  assert.strictEqual(envVar(tmp, 'ANT_TEAM_GITHUB_REPO'), hostileRepo);
});

// --- ENV-7: idempotent rerun ---------------------------------------------------

check('ENV-7: idempotent rerun leaves the env byte-identical and mtime unchanged', () => {
  const tmp = mkdtempRepo('env7');
  const first = runInit(initArgs(tmp));
  assert.strictEqual(first.status, 0, `init exit ${first.status}\nstderr:\n${first.stderr}`);
  const envPath = path.join(tmp, '.github-project.env');
  const before = fs.readFileSync(envPath, 'utf8');
  const mtimeBefore = fs.statSync(envPath).mtimeMs;
  const second = runInit(initArgs(tmp));
  assert.strictEqual(second.status, 0, `rerun exit ${second.status}\nstderr:\n${second.stderr}`);
  assert.ok(
    /\.github-project\.env already up to date/.test(second.stdout),
    `rerun must report the env already up to date:\n${second.stdout}`
  );
  assert.strictEqual(fs.readFileSync(envPath, 'utf8'), before, 'env must be byte-identical on rerun');
  assert.strictEqual(fs.statSync(envPath).mtimeMs, mtimeBefore, 'env must not be rewritten on rerun');
});

// --- ENV-8: dry-run writes/deletes nothing ------------------------------------

check('ENV-8: --dry-run reports [would-write] and writes/deletes nothing', () => {
  const tmp = mkdtempRepo('env8');
  const r = runInit(initArgs(tmp, ['--dry-run']));
  assert.strictEqual(r.status, 0, `dry-run exit ${r.status}\nstderr:\n${r.stderr}`);
  assert.ok(
    /\[would-write\] \.github-project\.env/.test(r.stdout),
    `dry-run must report the env would-write:\n${r.stdout}`
  );
  assert.ok(!fs.existsSync(path.join(tmp, '.github-project.env')), 'dry-run writes nothing');
  assert.ok(!fs.existsSync(path.join(tmp, '.github-project.json')), 'dry-run creates no JSON');
});

// --- ENV-9: gh_project_helper resolves from the env alone ---------------------

check('ENV-9: gh_project_helper resolves owner/project number from the env alone', () => {
  const tmp = mkdtempRepo('env9');
  fs.writeFileSync(
    path.join(tmp, '.github-project.env'),
    "export ANT_TEAM_GITHUB_OWNER='env-owner'\n" +
      "export ANT_TEAM_GITHUB_PROJECT_NUMBER='7'\n"
  );
  const bin = fs.mkdtempSync(path.join(os.tmpdir(), 'env9-bin-'));
  const ghLog = path.join(bin, 'gh-calls.log');
  fs.writeFileSync(
    path.join(bin, 'gh'),
    `#!/usr/bin/env bash\nprintf 'ARGS:' >> '${ghLog}'; printf ' [%s]' "$@" >> '${ghLog}'; echo '{\"fields\":[]}'\n`
  );
  fs.chmodSync(path.join(bin, 'gh'), 0o755);

  const r = runBash(`'${HELPER}' list-statuses`, {
    cwd: tmp,
    env: { ...process.env, PATH: `${bin}:${process.env.PATH}` },
  });
  assert.strictEqual(r.status, 0, `helper exit ${r.status}\nstderr:\n${r.stderr}`);
  const calls = fs.readFileSync(ghLog, 'utf8');
  assert.ok(calls.includes('[env-owner]'), `owner must come from the env, got: ${calls}`);
  assert.ok(calls.includes('[7]'), `project number must come from the env, got: ${calls}`);
});

// --- ENV-10: do-task worktree helpers source the env ---------------------------

check('ENV-10: do-task worktree helpers read ANT_TEAM_WORKTREE_ROOT from the env', () => {
  const scripts = [
    'templates/opencode/skills/do-task/scripts/create_task_worktree.sh',
    'templates/opencode/skills/do-task/scripts/cleanup_task_worktree.sh',
  ];
  for (const s of scripts) {
    const c = fs.readFileSync(path.join(REPO_ROOT, s), 'utf8');
    assert.ok(c.includes('.github-project.env'), `${s} must source .github-project.env`);
    assert.ok(c.includes('ANT_TEAM_WORKTREE_ROOT'), `${s} must read ANT_TEAM_WORKTREE_ROOT`);
    assert.ok(
      !c.includes('.github-project.json'),
      `${s} must have no .github-project.json fallback under the env-only contract`
    );
  }
  // Behavioral: a founder-set worktree root survives init and reaches consumers.
  const tmp = mkdtempRepo('env10');
  fs.writeFileSync(
    path.join(tmp, '.github-project.env'),
    "export ANT_TEAM_WORKTREE_ROOT='/from/env'\n"
  );
  const init = runInit(initArgs(tmp));
  assert.strictEqual(init.status, 0, `init exit ${init.status}\nstderr:\n${init.stderr}`);
  assert.strictEqual(envVar(tmp, 'ANT_TEAM_WORKTREE_ROOT'), '/from/env');
});

// --- ENV-11: AGENTS.md lists the env -------------------------------------------

check('ENV-11: AGENTS.md Local Configuration Files lists .github-project.env', () => {
  const tmp = mkdtempRepo('env11');
  const r = runInit(initArgs(tmp));
  assert.strictEqual(r.status, 0, `init exit ${r.status}\nstderr:\n${r.stderr}`);
  const agents = fs.readFileSync(path.join(tmp, 'AGENTS.md'), 'utf8');
  assert.ok(
    agents.includes('`.github-project.env`'),
    'AGENTS.md Local Configuration Files must list .github-project.env'
  );
  assert.ok(
    !agents.includes('.github-project.json'),
    'AGENTS.md must not reference .github-project.json as a config artifact'
  );
});

// --- ENV-12: concrete project path derivation ----------------------------------

check('ENV-12a: ANT_TEAM_DOCS_PROJECT_PATH derives from vault + project name', () => {
  const tmp = mkdtempRepo('env12a');
  fs.writeFileSync(
    path.join(tmp, '.github-project.env'),
    "export ANT_TEAM_DOCS_VAULT_PATH='/vault/root'\n" +
      "export ANT_TEAM_DOCS_PROJECT_NAME='my-proj'\n"
  );
  const r = runInit(initArgs(tmp));
  assert.strictEqual(r.status, 0, `init exit ${r.status}\nstderr:\n${r.stderr}`);
  assert.strictEqual(
    envVar(tmp, 'ANT_TEAM_DOCS_PROJECT_PATH'),
    '/vault/root/02-Architecture-Landscape/projects/my-proj',
    'project path must resolve as VAULT_PATH/02-Architecture-Landscape/projects/PROJECT_NAME'
  );
  assert.ok(
    !readEnvFile(tmp).includes('ANT_TEAM_DOCS_PROJECT_PATH_TEMPLATE'),
    'ANT_TEAM_DOCS_PROJECT_PATH_TEMPLATE must not be emitted:\n' + readEnvFile(tmp)
  );
});

check('ENV-12b: founder-set ANT_TEAM_DOCS_PROJECT_PATH is preserved verbatim', () => {
  const tmp = mkdtempRepo('env12b');
  fs.writeFileSync(
    path.join(tmp, '.github-project.env'),
    "export ANT_TEAM_DOCS_VAULT_PATH='/vault/root'\n" +
      "export ANT_TEAM_DOCS_PROJECT_NAME='my-proj'\n" +
      "export ANT_TEAM_DOCS_PROJECT_PATH='/custom/elsewhere/proj'\n"
  );
  const r = runInit(initArgs(tmp, ['--force']));
  assert.strictEqual(r.status, 0, `init exit ${r.status}\nstderr:\n${r.stderr}`);
  assert.strictEqual(
    envVar(tmp, 'ANT_TEAM_DOCS_PROJECT_PATH'),
    '/custom/elsewhere/proj',
    'a founder-set concrete project path must not be overwritten by derivation'
  );
});

// --- summary -------------------------------------------------------------------

console.log(`\n${passed} passed, ${failed} failed (project env runtime)`);
if (failed > 0) process.exit(1);
