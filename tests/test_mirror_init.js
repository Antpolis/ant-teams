#!/usr/bin/env node
'use strict';

/*
 * tests/test_mirror_init.js — initializer runs from the managed skill mirror.
 *
 * Regression suite for the project-init skill/script conflict (2026-08):
 * "$ANT_TEAM_SCRIPTS/init-project.sh" executes the ENGINE copy installed
 * in the managed mirror (~/.agents/skills/project-initialization/...), not a
 * source checkout. The engine therefore resolves required skills from the
 * SIBLING skills root (the directory the skill lives in), and the wrapper
 * invokes the engine with `bash` so the mirror's execute bits are never
 * required (managed sync may tighten updated files to mode 0644 per
 * ARCH-004 SEC-3.2).
 *
 *   MIR-1  the installed wrapper initializes a target repo from a simulated
 *          ~/.agents/skills mirror in which NO file is executable, and the
 *          copied skills come from the mirror (sentinel), not the checkout
 *   MIR-2  preflight fails cleanly ([error], exit 1) when a required sibling
 *          skill is missing from the mirror — before any write happens
 *   MIR-3  the REAL scripts/init-company.sh installs into a temp HOME, then
 *          "$ANT_TEAM_SCRIPTS/gh_project_helper.sh" is invoked directly and
 *          executes the engine from the managed mirror — with the mirror
 *          engine forced non-executable (0644), proving centralized wrapper
 *          execution without mirror execute bits
 *
 * No external npm dependencies — Node built-ins only. No network access.
 */

const { spawnSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const assert = require('assert');

const REPO_ROOT = path.resolve(__dirname, '..');
const REQUIRED_SKILLS = [
  'github-issues-projects-cli',
  'do-task',
  'project-initialization',
];

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

function mkdtemp(prefix) {
  return fs.mkdtempSync(path.join(os.tmpdir(), `${prefix}-`));
}

// Recursively copy a directory, then force EVERY file to mode 0644 and every
// directory to 0755 — a worst-case mirror in which nothing is executable.
// This is the regression condition: the wrapper must still work.
function copyTreeNoExec(src, dst) {
  fs.cpSync(src, dst, { recursive: true });
  const walk = (dir) => {
    fs.chmodSync(dir, 0o755);
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const p = path.join(dir, entry.name);
      if (entry.isDirectory()) walk(p);
      else fs.chmodSync(p, 0o644);
    }
  };
  walk(dst);
}

// Build a simulated post-sync-company install layout:
//   <home>/.agents/skills/{required skills}   (managed mirror, no exec bits)
//   <home>/.agents/scripts/*.sh               (installed wrappers, 0755)
// Returns { home, mirrorSkills, teamScripts, wrapper }.
function buildSimulatedInstall(home) {
  const agentsDir = path.join(home, '.agents');
  const mirrorSkills = path.join(agentsDir, 'skills');
  const teamScripts = path.join(agentsDir, 'scripts');
  fs.mkdirSync(mirrorSkills, { recursive: true });
  fs.mkdirSync(teamScripts, { recursive: true });

  for (const skill of REQUIRED_SKILLS) {
    copyTreeNoExec(
      path.join(REPO_ROOT, '.opencode', 'skills', skill),
      path.join(mirrorSkills, skill)
    );
  }

  for (const f of fs.readdirSync(path.join(REPO_ROOT, 'scripts'))) {
    if (!f.endsWith('.sh')) continue;
    fs.copyFileSync(path.join(REPO_ROOT, 'scripts', f), path.join(teamScripts, f));
    fs.chmodSync(path.join(teamScripts, f), 0o755);
  }

  return {
    home,
    mirrorSkills,
    teamScripts,
    wrapper: path.join(teamScripts, 'init-project.sh'),
  };
}

function mkTargetRepo() {
  const tmp = mkdtemp('mir-target');
  fs.mkdirSync(path.join(tmp, '.git'), { recursive: true });
  return tmp;
}

function initArgs(tmp) {
  return [
    '--noninteractive',
    '--project-dir', tmp,
    '--worktree-root', path.join(tmp, 'wt'),
    '--name', 'mirror-demo',
    '--github-owner', 'antpolis',
    '--github-project-number', '1',
    '--skip-inspection',
  ];
}

function runWrapper(sim, args, cwd) {
  return spawnSync('bash', [sim.wrapper, ...args], {
    encoding: 'utf8',
    cwd,
    env: {
      ...process.env,
      HOME: sim.home,
      ANT_TEAM_SCRIPTS: sim.teamScripts,
    },
  });
}

// --- MIR-1: wrapper initializes a target from the mirror ----------------------

check('MIR-1: installed wrapper runs the mirror engine with no execute bits anywhere', () => {
  const home = mkdtemp('mir-home');
  const sim = buildSimulatedInstall(home);

  // Sentinel: proves the copied skills come from the MIRROR, not the checkout.
  fs.writeFileSync(path.join(sim.mirrorSkills, 'do-task', 'MIRROR-SENTINEL'), 'mirror\n');
  fs.chmodSync(path.join(sim.mirrorSkills, 'do-task', 'MIRROR-SENTINEL'), 0o644);

  // Sanity: the engine really is non-executable in the simulated mirror.
  const engine = path.join(sim.mirrorSkills, 'project-initialization', 'scripts', 'init_project_docs.sh');
  assert.strictEqual(
    fs.statSync(engine).mode & 0o111,
    0,
    'test setup: mirror engine must be non-executable for this regression'
  );

  const target = mkTargetRepo();
  const r = runWrapper(sim, initArgs(target), target);
  assert.strictEqual(r.status, 0, `wrapper exit ${r.status}\nstdout:\n${r.stdout}\nstderr:\n${r.stderr}`);

  // Core artifacts exist.
  assert.ok(fs.existsSync(path.join(target, '.github-project.env')), '.github-project.env created');
  assert.ok(fs.existsSync(path.join(target, 'AGENTS.md')), 'AGENTS.md created');

  // All three required skills were copied from the sibling mirror root.
  for (const skill of REQUIRED_SKILLS) {
    assert.ok(
      fs.existsSync(path.join(target, '.opencode', 'skills', skill, 'SKILL.md')),
      `required skill copied: ${skill}`
    );
  }
  assert.ok(
    fs.existsSync(path.join(target, '.opencode', 'skills', 'do-task', 'MIRROR-SENTINEL')),
    'skills must be sourced from the mirror (sentinel file missing at target)'
  );

  // The simulated HOME layout contains no checkout-style .opencode/skills —
  // success therefore proves the engine never depended on a checkout root.
  assert.ok(
    !fs.existsSync(path.join(home, '.opencode', 'skills')),
    'simulated HOME must not contain a checkout-style skills tree (test invariant)'
  );
});

// --- MIR-2: missing required sibling skill fails preflight --------------------

check('MIR-2: missing required sibling skill fails preflight before any write', () => {
  const home = mkdtemp('mir-home');
  const sim = buildSimulatedInstall(home);
  fs.rmSync(path.join(sim.mirrorSkills, 'do-task'), { recursive: true, force: true });

  const target = mkTargetRepo();
  const r = runWrapper(sim, initArgs(target), target);
  assert.notStrictEqual(r.status, 0, 'preflight must exit non-zero when a required sibling skill is missing');
  assert.ok(r.stderr.includes('[error]'), `[error] line expected on stderr:\n${r.stderr}`);
  assert.ok(
    r.stderr.includes('do-task'),
    `stderr must name the missing required skill:\n${r.stderr}`
  );

  // ERR-1.1: preflight runs BEFORE any write — the target stays untouched.
  assert.ok(
    !fs.existsSync(path.join(target, '.github-project.env')),
    'no artifact may be written when preflight fails'
  );
  assert.ok(
    !fs.existsSync(path.join(target, '.opencode')),
    'no skills may be copied when preflight fails'
  );
});

// --- MIR-3: real sync install, then direct centralized wrapper invocation ----

check('MIR-3: real init-company.sh into temp HOME; direct $ANT_TEAM_SCRIPTS/gh_project_helper.sh executes the mirror engine', () => {
  const home = mkdtemp('mir-sync-home');

  // Real install with the REAL scripts/init-company.sh (canonical config,
  // ~/.agents/scripts, managed ~/.agents/skills mirror — all under temp HOME).
  const syncEnv = { ...process.env, HOME: home };
  delete syncEnv.OPENCODE_CONFIG_DIR;
  const sync = spawnSync('bash', [path.join(REPO_ROOT, 'scripts', 'init-company.sh')], {
    encoding: 'utf8',
    env: syncEnv,
  });
  assert.strictEqual(
    sync.status,
    0,
    `init-company.sh exit ${sync.status}\nstdout:\n${sync.stdout}\nstderr:\n${sync.stderr}`
  );

  const teamScripts = path.join(home, '.agents', 'scripts');
  const wrapper = path.join(teamScripts, 'gh_project_helper.sh');
  assert.ok(fs.existsSync(wrapper), 'sync must install the centralized gh_project_helper.sh wrapper');
  assert.notStrictEqual(
    fs.statSync(wrapper).mode & 0o111,
    0,
    'installed wrapper must be executable (sync_team_scripts chmod 0755)'
  );

  // The install configures the centralized entry in the shell rc files.
  const rcLine = 'export ANT_TEAM_SCRIPTS="$HOME/.agents/scripts"';
  assert.ok(
    fs.readFileSync(path.join(home, '.zshrc'), 'utf8').includes(rcLine),
    'sync must export ANT_TEAM_SCRIPTS from the installed rc files'
  );

  // Worst-case managed mirror: the engine copy is NOT executable (managed
  // sync may tighten updated files to mode 0644 — ARCH-004 SEC-3.2).
  const mirrorEngine = path.join(
    home, '.agents', 'skills', 'github-issues-projects-cli', 'scripts', 'gh_project_helper.sh'
  );
  assert.ok(fs.existsSync(mirrorEngine), 'sync must install the engine into the managed mirror');
  fs.chmodSync(mirrorEngine, 0o644);
  assert.strictEqual(
    fs.statSync(mirrorEngine).mode & 0o111,
    0,
    'test setup: mirror engine must be non-executable for this smoke'
  );

  // Target repo with its own env config (engine sources .github-project.env
  // from its working directory) and a fake gh shim that records every call —
  // no network, no live board access.
  const target = mkTargetRepo();
  fs.writeFileSync(
    path.join(target, '.github-project.env'),
    "export ANT_TEAM_GITHUB_OWNER='env-owner'\n" +
      "export ANT_TEAM_GITHUB_PROJECT_NUMBER='7'\n"
  );
  const bin = fs.mkdtempSync(path.join(os.tmpdir(), 'mir3-bin-'));
  const ghLog = path.join(bin, 'gh-calls.log');
  fs.writeFileSync(
    path.join(bin, 'gh'),
    '#!/usr/bin/env bash\n' +
      `printf 'ARGS:' >> '${ghLog}'; printf ' [%s]' "$@" >> '${ghLog}'; ` +
      "echo '{\"fields\":[{\"name\":\"Workflow State\",\"options\":[{\"name\":\"Open\"},{\"name\":\"Done\"}]}]}'\n"
  );
  fs.chmodSync(path.join(bin, 'gh'), 0o755);

  // Direct invocation of the installed centralized wrapper — exactly the
  // documented "$ANT_TEAM_SCRIPTS/gh_project_helper.sh" entry point.
  const r = spawnSync(wrapper, ['list-statuses'], {
    encoding: 'utf8',
    cwd: target,
    env: {
      ...process.env,
      HOME: home,
      ANT_TEAM_SCRIPTS: teamScripts,
      PATH: `${bin}:${process.env.PATH}`,
    },
  });
  assert.strictEqual(r.status, 0, `wrapper exit ${r.status}\nstdout:\n${r.stdout}\nstderr:\n${r.stderr}`);

  // The mirror engine really ran: jq-processed field options on stdout.
  assert.ok(r.stdout.includes('Open'), `engine must list the Open option:\n${r.stdout}`);
  assert.ok(r.stdout.includes('Done'), `engine must list the Done option:\n${r.stdout}`);

  // And it resolved the board target from the target repo's env config.
  const calls = fs.readFileSync(ghLog, 'utf8');
  assert.ok(calls.includes('[env-owner]'), `owner must come from the env, got: ${calls}`);
  assert.ok(calls.includes('[7]'), `project number must come from the env, got: ${calls}`);
});

// --- summary -------------------------------------------------------------------

console.log(`\n${passed} passed, ${failed} failed (mirror init)`);
if (failed > 0) process.exit(1);
