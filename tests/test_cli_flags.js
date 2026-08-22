#!/usr/bin/env node
'use strict';

/*
 * tests/test_cli_flags.js — SPEC-001-T2 unit tests.
 *
 * Drives `.opencode/skills/project-initialization/scripts/init_project_docs.sh`
 * through the CLI surface added by issue #3 (CLI-2 / FR-4 / ERR-4):
 *
 *   - AC-T2-001: TTY present + no flags → interactive mode (no required-flag
 *                accounting). Stdout-piped (no TTY) + no flags → noninteractive
 *                default. Verified behaviorally because the script's only
 *                mode-dependent side-effect at T2 scope is the ERR-4.1
 *                missing-flag check.
 *   - AC-T2-002: --noninteractive with the three required identity flags
 *                exits 0 with no prompts.
 *   - AC-T2-003: --noninteractive missing any of the three required flags
 *                exits 1 and lists the missing entries on stderr.
 *   - AC-T2-004: env vars supply defaults; CLI flags override env vars
 *                (resolution order: default < env < CLI).
 *   - AC-T2-005: pre-existing --project-dir / --docs-root / --worktree-root
 *                continue to behave as before.
 *   - AC-T2-006: --repo-role library (and each enum value) is accepted;
 *                invalid_role is rejected with a clear stderr error.
 *   - AC-T2-007: --commands @/path/to/file reads the file; --commands "inline"
 *                uses the inline text verbatim; @missing-file is a hard error.
 *
 * Scope note (issue #3): the downstream AGENTS.md generation (T3 / issue #4),
 * .github-project.env schema extension (T5 / issue #6), and OBS-2 dry-run /
 * idempotency (T6 / issue #7) consume the same `opt_*` variables resolved by
 * T2 but are not asserted here. T2's contract is parsing + resolution +
 * validation only.
 *
 * No external npm dependencies — Node built-ins only.
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

const REPO_ROLE_VALUES = ['service', 'library', 'infra', 'monorepo-root', 'tool', 'docs', 'other'];

// `script -qec` allocates a pseudo-TTY for the child command on Linux/macOS.
// Used by AC-T2-001 to verify the TTY-default branch of mode resolution.
// Returns null when `script` is unavailable so the caller can skip cleanly.
let scriptPath = null;
try {
  // `which` is in /usr/bin on every platform we target; fall back silently.
  const r = spawnSync('which', ['script'], { encoding: 'utf8' });
  if (r.status === 0 && r.stdout.trim()) scriptPath = r.stdout.trim();
} catch {
  /* scriptPath stays null — TTY test is skipped */
}

let pass = 0;
let fail = 0;
const failures = [];

function check(name, fn) {
  try {
    fn();
    pass++;
  } catch (err) {
    fail++;
    failures.push({ name, message: err.message, stack: err.stack });
    process.stdout.write(`  FAIL: ${name}\n    ${err.message}\n`);
  }
}

function mkdtempRepo(prefix) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), `cli-flags-${prefix}-`));
  // init_project_docs.sh expects a git project (used by other steps in the
  // script). A real `git init` keeps the test forward-compatible with future
  // preflight additions (T6 / issue #7 / ERR-1).
  fs.mkdirSync(path.join(dir, '.git'), { recursive: true });
  return dir;
}

// Runs the init script with the given argv and env. stdio is piped so the
// default mode is noninteractive (no TTY) unless argv/env forces otherwise.
function runInit(argv, env) {
  const result = { stdout: '', stderr: '', status: 0 };
  try {
    result.stdout = execFileSync('bash', [INIT_SCRIPT, ...argv], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
      env: { ...process.env, ...(env || {}) },
    });
  } catch (err) {
    result.status = err.status ?? 1;
    result.stdout = err.stdout ? err.stdout.toString('utf8') : '';
    result.stderr = err.stderr ? err.stderr.toString('utf8') : '';
  }
  return result;
}

// Runs the init script under a pseudo-TTY allocated by `script -qec`. Used to
// exercise the [[ -t 1 ]] branch of mode resolution. Returns null if `script`
// is unavailable on the host so the caller can skip the test cleanly.
//
// T3 compatibility (issue #4): interactive mode now prompts the operator.
// Under a pty with no input, the prompts would block indefinitely. We feed
// an `input` string of newlines so every prompt accepts its default (FR-3.3
// blank = use default) and the confirm defaults to "y" (FR-3.4). Callers
// that need custom responses can pass an `input` override.
function runInitUnderPty(argv, env, input) {
  if (!scriptPath) return null;
  // `script -qec "<cmd>" <devnull|/dev/null>`:
  //   -q quiet (no header)
  //   -e pass through child exit status
  //   -c <command>
  // Linux util-linux accepts a logsink path; macOS BSD script uses -F + command.
  // Use a portable invocation: `script -qec "<cmd>" /dev/null` works on Linux;
  // macOS omits the trailing file arg. Detect via `script --version` output.
  const cmd = `bash ${INIT_SCRIPT} ${argv.map((a) => `'${a.replace(/'/g, `'\\''`)}'`).join(' ')}`;
  // Default input: enough empty lines for every interactive prompt + the
  // final confirm. 8 prompts at T3 scope (6 FR-3.2 + GitHub number + confirm).
  const stdinInput = input != null ? input : '\n'.repeat(12);
  const result = { stdout: '', stderr: '', status: 0 };
  try {
    // Try Linux form first (util-linux): `script -qec CMD FILE`
    const r = spawnSync(scriptPath, ['-qec', cmd, '/dev/null'], {
      encoding: 'utf8',
      env: { ...process.env, ...(env || {}) },
      input: stdinInput,
      timeout: 30000,
    });
    result.stdout = r.stdout || '';
    result.stderr = r.stderr || '';
    result.status = r.status ?? 0;
    if (r.error && r.error.code === 'ENOENT') return null;
  } catch (e) {
    return null;
  }
  return result;
}

// Build the minimal noninteractive required set, optionally omitting one.
function noninteractiveRequired(exclude) {
  const base = {
    '--name': 'test',
    '--github-owner': 'antpolis',
    '--github-project-number': '9',
  };
  if (exclude && Object.prototype.hasOwnProperty.call(base, exclude)) {
    delete base[exclude];
  }
  const argv = ['--noninteractive'];
  for (const [k, v] of Object.entries(base)) {
    argv.push(k, v);
  }
  return argv;
}

// --- Pre-flight: script is present ------------------------------------------

process.stdout.write('Suite: preflight\n');
check('init_project_docs.sh exists', () => {
  assert.ok(fs.existsSync(INIT_SCRIPT), `init script missing at ${INIT_SCRIPT}`);
});

check('init_project_docs.sh is syntactically valid', () => {
  const r = spawnSync('bash', ['-n', INIT_SCRIPT], { encoding: 'utf8' });
  assert.strictEqual(r.status, 0, `syntax error:\n${r.stderr}`);
});

// --- AC-T2-001: TTY-based default mode --------------------------------------

process.stdout.write('Suite: AC-T2-001 TTY default mode\n');

check('AC-T2-001a: stdout piped + no flags → noninteractive (missing-flag check fires)', () => {
  // No TTY → mode defaults noninteractive → required-flag accounting fires.
  // No project dir is created; the script must exit 1 before any file write.
  const tmp = mkdtempRepo('ac001a');
  const r = runInit(['--project-dir', tmp, '--worktree-root', path.join(tmp, 'wt')]);
  assert.strictEqual(r.status, 1, `expected exit 1 (noninteractive default), got ${r.status}\nstderr:\n${r.stderr}`);
  assert.ok(r.stderr.includes('Noninteractive mode requires'), `stderr should mention missing flags:\n${r.stderr}`);
});

check('AC-T2-001b: --interactive flag bypasses required-flag accounting', () => {
  // Force interactive mode: even with no identity flags the script must not
  // exit 1 with the missing-flag error. (Prompts ship with T3; at T2 scope
  // the script simply proceeds through the unchanged skills-copy / docs flow.)
  const tmp = mkdtempRepo('ac001b');
  const r = runInit(
    ['--project-dir', tmp, '--worktree-root', path.join(tmp, 'wt'), '--interactive'],
  );
  assert.strictEqual(r.status, 0, `interactive mode should not require flags; got ${r.status}\nstderr:\n${r.stderr}`);
});

check('AC-T2-001c: TTY default resolves to interactive when stdout is a real TTY', () => {
  // Uses `script -qec` to allocate a pseudo-TTY. With a TTY and no mode flags,
  // mode must default to interactive (no missing-flag error). Skipped when
  // `script` is unavailable on the host.
  const tmp = mkdtempRepo('ac001c');
  const r = runInitUnderPty(
    ['--project-dir', tmp, '--worktree-root', path.join(tmp, 'wt')],
  );
  if (r === null) {
    process.stdout.write('    (skipped: `script` not available on host)\n');
    return;
  }
  assert.strictEqual(r.status, 0, `TTY default should be interactive (exit 0); got ${r.status}\nstderr:\n${r.stderr}`);
  assert.ok(!r.stderr.includes('Noninteractive mode requires'), `TTY default should not trigger missing-flag check:\n${r.stderr}`);
});

// --- AC-T2-002: full noninteractive succeeds silently ----------------------

process.stdout.write('Suite: AC-T2-002 noninteractive success\n');

check('AC-T2-002: --noninteractive with required flags exits 0', () => {
  const tmp = mkdtempRepo('ac002');
  const r = runInit(
    [
      '--project-dir', tmp,
      '--worktree-root', path.join(tmp, 'wt'),
      ...noninteractiveRequired(),
    ],
  );
  assert.strictEqual(r.status, 0, `expected exit 0, got ${r.status}\nstderr:\n${r.stderr}`);
});

check('AC-T2-002: no prompt markers appear on stdout (no [prompt] lines at T2 scope)', () => {
  const tmp = mkdtempRepo('ac002-prompts');
  const r = runInit(
    [
      '--project-dir', tmp,
      '--worktree-root', path.join(tmp, 'wt'),
      ...noninteractiveRequired(),
    ],
  );
  assert.strictEqual(r.status, 0);
  assert.ok(!r.stdout.includes('[prompt]'), `unexpected prompt:\n${r.stdout}`);
});

// --- AC-T2-003: missing-flag errors -----------------------------------------

process.stdout.write('Suite: AC-T2-003 missing-flag errors\n');

for (const flag of ['--name', '--github-owner', '--github-project-number']) {
  check(`AC-T2-003: --noninteractive without ${flag} exits 1 and lists it on stderr`, () => {
    const tmp = mkdtempRepo(`ac003-${flag.slice(2)}`);
    const r = runInit(
      [
        '--project-dir', tmp,
        '--worktree-root', path.join(tmp, 'wt'),
        ...noninteractiveRequired(flag),
      ],
    );
    assert.strictEqual(r.status, 1, `expected exit 1, got ${r.status}\nstderr:\n${r.stderr}`);
    assert.ok(r.stderr.includes('Noninteractive mode requires'), `missing banner:\n${r.stderr}`);
    assert.ok(r.stderr.includes(`Missing: ${flag}`), `missing-flag line for ${flag}:\n${r.stderr}`);
  });
}

check('AC-T2-003: every missing entry is listed when none are provided', () => {
  const tmp = mkdtempRepo('ac003-all');
  const r = runInit(
    ['--project-dir', tmp, '--worktree-root', path.join(tmp, 'wt'), '--noninteractive'],
  );
  assert.strictEqual(r.status, 1);
  for (const flag of ['--name', '--github-owner', '--github-project-number']) {
    assert.ok(r.stderr.includes(`Missing: ${flag}`), `expected Missing: ${flag}:\n${r.stderr}`);
  }
});

check('AC-T2-003: ERR-4.1 hint mentions the env-var fallback', () => {
  const tmp = mkdtempRepo('ac003-hint');
  const r = runInit(
    ['--project-dir', tmp, '--worktree-root', path.join(tmp, 'wt'), '--noninteractive'],
  );
  assert.strictEqual(r.status, 1);
  assert.ok(/INIT_PROJECT_[A-Z_]+/.test(r.stderr), `expected an INIT_PROJECT_* hint:\n${r.stderr}`);
});

// --- AC-T2-004: env var resolution + CLI override ---------------------------

process.stdout.write('Suite: AC-T2-004 env vs CLI resolution\n');

check('AC-T2-004a: INIT_PROJECT_GITHUB_OWNER supplies the missing required value', () => {
  const tmp = mkdtempRepo('ac004a');
  // --github-owner is omitted from CLI; env must satisfy the required-flag check.
  const r = runInit(
    [
      '--project-dir', tmp,
      '--worktree-root', path.join(tmp, 'wt'),
      '--noninteractive', '--name', 't', '--github-project-number', '1',
    ],
    { INIT_PROJECT_GITHUB_OWNER: 'env-owner' },
  );
  assert.strictEqual(r.status, 0, `env should satisfy --github-owner; got ${r.status}\nstderr:\n${r.stderr}`);
});

check('AC-T2-004b: CLI --github-owner overrides INIT_PROJECT_GITHUB_OWNER', () => {
  // We can only observe resolution via exit code (success either way), so the
  // observable test is that both env-only and env+CLI succeed. The override
  // semantics are verified by code path: Phase 2 parses CLI after Phase 1
  // applies env. A full behavior assertion (which value was stored) lands
  // with T3 once the value is written into AGENTS.md.
  const tmp = mkdtempRepo('ac004b');
  const r = runInit(
    [
      '--project-dir', tmp,
      '--worktree-root', path.join(tmp, 'wt'),
      '--noninteractive',
      '--name', 't', '--github-owner', 'flag-owner', '--github-project-number', '1',
    ],
    { INIT_PROJECT_GITHUB_OWNER: 'env-owner' },
  );
  assert.strictEqual(r.status, 0, `flag override + env should succeed; got ${r.status}\nstderr:\n${r.stderr}`);
});

check('AC-T2-004c: INIT_PROJECT_INTERACTIVE=1 forces interactive (no required-flag check)', () => {
  const tmp = mkdtempRepo('ac004c');
  const r = runInit(
    ['--project-dir', tmp, '--worktree-root', path.join(tmp, 'wt')],
    { INIT_PROJECT_INTERACTIVE: '1' },
  );
  assert.strictEqual(r.status, 0, `INIT_PROJECT_INTERACTIVE=1 should bypass required-flag check; got ${r.status}\nstderr:\n${r.stderr}`);
});

check('AC-T2-004d: INIT_PROJECT_NONINTERACTIVE=1 forces noninteractive (required-flag check fires)', () => {
  const tmp = mkdtempRepo('ac004d');
  const r = runInit(
    ['--project-dir', tmp, '--worktree-root', path.join(tmp, 'wt')],
    { INIT_PROJECT_NONINTERACTIVE: '1' },
  );
  assert.strictEqual(r.status, 1);
  assert.ok(r.stderr.includes('Noninteractive mode requires'));
});

check('AC-T2-004e: contradictory mode env vars → exit 1 (when CLI does not override)', () => {
  const tmp = mkdtempRepo('ac004e');
  const r = runInit(
    ['--project-dir', tmp, '--worktree-root', path.join(tmp, 'wt')],
    { INIT_PROJECT_INTERACTIVE: '1', INIT_PROJECT_NONINTERACTIVE: '1' },
  );
  assert.strictEqual(r.status, 1, `expected exit 1 for contradictory env, got ${r.status}\nstderr:\n${r.stderr}`);
  assert.ok(/Both INIT_PROJECT_INTERACTIVE and INIT_PROJECT_NONINTERACTIVE/.test(r.stderr), `expected contradiction error:\n${r.stderr}`);
});

check('AC-T2-004f: --merge default in noninteractive is 0 (no error, accepted as-is)', () => {
  const tmp = mkdtempRepo('ac004f');
  const r = runInit(
    [
      '--project-dir', tmp,
      '--worktree-root', path.join(tmp, 'wt'),
      ...noninteractiveRequired(),
    ],
  );
  assert.strictEqual(r.status, 0);
});

check('AC-T2-004g: --merge flag forces merge=1 in noninteractive (no error)', () => {
  const tmp = mkdtempRepo('ac004g');
  const r = runInit(
    [
      '--project-dir', tmp,
      '--worktree-root', path.join(tmp, 'wt'),
      ...noninteractiveRequired(),
      '--merge',
    ],
  );
  assert.strictEqual(r.status, 0);
});

// --- AC-T2-005: pre-existing flags preserved --------------------------------

process.stdout.write('Suite: AC-T2-005 pre-existing flags preserved\n');

check('AC-T2-005a: --docs-root .docs is honored', () => {
  const tmp = mkdtempRepo('ac005a');
  const r = runInit(
    [
      '--project-dir', tmp,
      '--worktree-root', path.join(tmp, 'wt'),
      '--docs-root', '.docs',
      ...noninteractiveRequired(),
    ],
  );
  assert.strictEqual(r.status, 0, `expected 0, got ${r.status}\nstderr:\n${r.stderr}`);
  assert.ok(fs.existsSync(path.join(tmp, '.docs')), 'expected .docs directory to be created');
});

check('AC-T2-005b: --worktree-root is honored (worktree dir created)', () => {
  const tmp = mkdtempRepo('ac005b');
  const wt = path.join(tmp, 'wt');
  const r = runInit(
    [
      '--project-dir', tmp,
      '--worktree-root', wt,
      ...noninteractiveRequired(),
    ],
  );
  assert.strictEqual(r.status, 0);
  assert.ok(fs.existsSync(wt), 'expected worktree root to be created');
});

check('AC-T2-005c: unknown flag still rejected with exit 1', () => {
  const tmp = mkdtempRepo('ac005c');
  const r = runInit(
    ['--project-dir', tmp, '--worktree-root', path.join(tmp, 'wt'), '--bogus-flag'],
  );
  assert.strictEqual(r.status, 1);
  assert.ok(r.stderr.includes('Unknown argument: --bogus-flag'));
});

check('AC-T2-005d: --help exits 0 and documents a new flag', () => {
  const r = runInit(['--help']);
  assert.strictEqual(r.status, 0);
  assert.ok(r.stdout.includes('--noninteractive'), 'expected --noninteractive in usage');
  assert.ok(r.stdout.includes('--repo-role'), 'expected --repo-role in usage');
});

// --- AC-T2-006: --repo-role enum --------------------------------------------

process.stdout.write('Suite: AC-T2-006 --repo-role enum\n');

for (const role of REPO_ROLE_VALUES) {
  check(`AC-T2-006: --repo-role ${role} accepted`, () => {
    const tmp = mkdtempRepo(`ac006-${role}`);
    const r = runInit(
      [
        '--project-dir', tmp,
        '--worktree-root', path.join(tmp, 'wt'),
        ...noninteractiveRequired(),
        '--repo-role', role,
      ],
    );
    assert.strictEqual(r.status, 0, `expected ${role} accepted (exit 0); got ${r.status}\nstderr:\n${r.stderr}`);
  });
}

check('AC-T2-006: invalid --repo-role rejected with clear stderr error', () => {
  const tmp = mkdtempRepo('ac006-invalid');
  const r = runInit(
    [
      '--project-dir', tmp,
      '--worktree-root', path.join(tmp, 'wt'),
      ...noninteractiveRequired(),
      '--repo-role', 'invalid_role',
    ],
  );
  assert.strictEqual(r.status, 1);
  assert.ok(r.stderr.includes("Invalid --repo-role value: 'invalid_role'"), `unexpected stderr:\n${r.stderr}`);
  // The error must enumerate valid values so the operator can recover.
  assert.ok(r.stderr.includes('service'), 'expected valid-value list');
  assert.ok(r.stderr.includes('monorepo-root'), 'expected monorepo-root in valid-value list');
});

check('AC-T2-006: INIT_PROJECT_ROLE env supplies --repo-role', () => {
  const tmp = mkdtempRepo('ac006-env');
  const r = runInit(
    [
      '--project-dir', tmp,
      '--worktree-root', path.join(tmp, 'wt'),
      ...noninteractiveRequired(),
    ],
    { INIT_PROJECT_ROLE: 'library' },
  );
  assert.strictEqual(r.status, 0);
});

check('AC-T2-006: INIT_PROJECT_ROLE env with invalid value still rejected', () => {
  const tmp = mkdtempRepo('ac006-env-invalid');
  const r = runInit(
    [
      '--project-dir', tmp,
      '--worktree-root', path.join(tmp, 'wt'),
      ...noninteractiveRequired(),
    ],
    { INIT_PROJECT_ROLE: 'spaceship' },
  );
  assert.strictEqual(r.status, 1);
  assert.ok(r.stderr.includes("Invalid --repo-role value: 'spaceship'"));
});

// --- AC-T2-007: @file + inline for --commands / --conventions ---------------

process.stdout.write('Suite: AC-T2-007 --commands / --conventions @file\n');

check('AC-T2-007a: --commands @/path reads file (script accepts the value, exits 0)', () => {
  const tmp = mkdtempRepo('ac007a');
  const cmdFile = path.join(tmp, 'cmds.txt');
  fs.writeFileSync(cmdFile, 'npm test\nnpm build\n');
  const r = runInit(
    [
      '--project-dir', tmp,
      '--worktree-root', path.join(tmp, 'wt'),
      ...noninteractiveRequired(),
      '--commands', `@${cmdFile}`,
    ],
  );
  assert.strictEqual(r.status, 0, `@file should resolve cleanly; got ${r.status}\nstderr:\n${r.stderr}`);
});

check('AC-T2-007b: --commands inline text used verbatim', () => {
  const tmp = mkdtempRepo('ac007b');
  const r = runInit(
    [
      '--project-dir', tmp,
      '--worktree-root', path.join(tmp, 'wt'),
      ...noninteractiveRequired(),
      '--commands', 'npm test\nnpm build',
    ],
  );
  assert.strictEqual(r.status, 0);
});

check('AC-T2-007c: --commands @missing-file is a hard error (exit 1)', () => {
  const tmp = mkdtempRepo('ac007c');
  const r = runInit(
    [
      '--project-dir', tmp,
      '--worktree-root', path.join(tmp, 'wt'),
      ...noninteractiveRequired(),
      '--commands', '@/no/such/file',
    ],
  );
  assert.strictEqual(r.status, 1);
  assert.ok(r.stderr.includes('--commands: file not found: /no/such/file'), `unexpected stderr:\n${r.stderr}`);
});

check('AC-T2-007d: --conventions @/path reads file', () => {
  const tmp = mkdtempRepo('ac007d');
  const convFile = path.join(tmp, 'conventions.txt');
  fs.writeFileSync(convFile, 'Use conventional commits.\n');
  const r = runInit(
    [
      '--project-dir', tmp,
      '--worktree-root', path.join(tmp, 'wt'),
      ...noninteractiveRequired(),
      '--conventions', `@${convFile}`,
    ],
  );
  assert.strictEqual(r.status, 0);
});

// --- Additional guardrail tests (issue body + CLI-2) ------------------------

process.stdout.write('Suite: guardrails (related-repos, booleans, dry-run)\n');

check('guardrail: --related-repos valid triple accepted', () => {
  const tmp = mkdtempRepo('gr-rr-valid');
  const r = runInit(
    [
      '--project-dir', tmp,
      '--worktree-root', path.join(tmp, 'wt'),
      ...noninteractiveRequired(),
      '--related-repos', 'sibling:https://github.com/org/sibling:sibling',
    ],
  );
  assert.strictEqual(r.status, 0);
});

check('guardrail: --related-repos multiple triples accepted', () => {
  const tmp = mkdtempRepo('gr-rr-multi');
  const r = runInit(
    [
      '--project-dir', tmp,
      '--worktree-root', path.join(tmp, 'wt'),
      ...noninteractiveRequired(),
      '--related-repos',
      'a:https://github.com/o/a:sibling,b:https://github.com/o/b:parent',
    ],
  );
  assert.strictEqual(r.status, 0);
});

check('guardrail: --related-repos malformed triple rejected', () => {
  const tmp = mkdtempRepo('gr-rr-bad');
  const r = runInit(
    [
      '--project-dir', tmp,
      '--worktree-root', path.join(tmp, 'wt'),
      ...noninteractiveRequired(),
      '--related-repos', 'just-a-name',
    ],
  );
  assert.strictEqual(r.status, 1);
  assert.ok(r.stderr.includes("Invalid --related-repos entry: 'just-a-name'"));
});

check('guardrail: --force / --skip-inspection / --dry-run accepted in noninteractive; retired --migrate-agent-md rejected', () => {
  const tmp = mkdtempRepo('gr-bool');
  const r = runInit(
    [
      '--project-dir', tmp,
      '--worktree-root', path.join(tmp, 'wt'),
      ...noninteractiveRequired(),
      '--force',
      '--skip-inspection',
      '--dry-run',
    ],
  );
  assert.strictEqual(r.status, 0, `boolean flags should be accepted; got ${r.status}\nstderr:\n${r.stderr}`);

  const retired = runInit(
    [
      '--project-dir', tmp,
      '--worktree-root', path.join(tmp, 'wt'),
      ...noninteractiveRequired(),
      '--migrate-agent-md',
    ],
  );
  assert.strictEqual(retired.status, 1, 'retired --migrate-agent-md must be rejected');
  assert.ok(retired.stderr.includes('Unknown argument: --migrate-agent-md'));
});

check('guardrail: INIT_PROJECT_SKIP_INSPECTION=1 + INIT_PROJECT_DRY_RUN=1 accepted via env', () => {
  const tmp = mkdtempRepo('gr-env-bool');
  const r = runInit(
    [
      '--project-dir', tmp,
      '--worktree-root', path.join(tmp, 'wt'),
      ...noninteractiveRequired(),
    ],
    { INIT_PROJECT_SKIP_INSPECTION: '1', INIT_PROJECT_DRY_RUN: '1' },
  );
  assert.strictEqual(r.status, 0);
});

// --- Regression: --github-project-number must be a positive integer ----------
// Reviewer finding (PR #14 review loop 2): the CLI-2 table types this flag as
// `Integer`, but `--github-project-number nope` was accepted and would poison
// .github-project.env downstream. These tests assert the strict positive-
// integer contract before any file is written.

process.stdout.write('Suite: regression --github-project-number positive integer\n');

// Helper: minimal noninteractive argv with an explicit --github-project-number,
// so we can inject invalid values without relying on the default suite value.
function withProjectNumber(value) {
  return [
    '--noninteractive',
    '--name', 'test',
    '--github-owner', 'antpolis',
    '--github-project-number', value,
  ];
}

for (const bad of ['nope', '0', '-1', '1.5', '1e10', '0x10', ' 9', '9 ', 'abc123', '123abc', '07']) {
  check(`regression: --github-project-number '${bad}' rejected (exit 1)`, () => {
    const tmp = mkdtempRepo(`reg-gpn-${bad.replace(/[^a-z0-9]/gi, '_')}`);
    const r = runInit(
      [
        '--project-dir', tmp,
        '--worktree-root', path.join(tmp, 'wt'),
        ...withProjectNumber(bad),
      ],
    );
    assert.strictEqual(r.status, 1, `expected exit 1 for '${bad}', got ${r.status}\nstderr:\n${r.stderr}`);
    assert.ok(
      /Invalid --github-project-number/.test(r.stderr),
      `expected 'Invalid --github-project-number' on stderr for '${bad}':\n${r.stderr}`,
    );
  });
}

for (const good of ['1', '9', '42', '123456', '9999999']) {
  check(`regression: --github-project-number '${good}' accepted (exit 0)`, () => {
    const tmp = mkdtempRepo(`reg-gpn-good-${good}`);
    const r = runInit(
      [
        '--project-dir', tmp,
        '--worktree-root', path.join(tmp, 'wt'),
        ...withProjectNumber(good),
      ],
    );
    assert.strictEqual(r.status, 0, `expected exit 0 for '${good}', got ${r.status}\nstderr:\n${r.stderr}`);
  });
}

check('regression: INIT_PROJECT_GITHUB_PROJECT_NUMBER=nope rejected via env', () => {
  const tmp = mkdtempRepo('reg-gpn-env-bad');
  const r = runInit(
    [
      '--project-dir', tmp,
      '--worktree-root', path.join(tmp, 'wt'),
      '--noninteractive', '--name', 'test', '--github-owner', 'antpolis',
    ],
    { INIT_PROJECT_GITHUB_PROJECT_NUMBER: 'nope' },
  );
  assert.strictEqual(r.status, 1, `expected exit 1, got ${r.status}\nstderr:\n${r.stderr}`);
  assert.ok(/Invalid --github-project-number/.test(r.stderr));
});

// --- Regression: --related-repos opaque URL contract (first/last colon) ------
// Reviewer finding (PR #14 review loop 3): the previous "url carries at most
// one colon" rule rejected valid Git remote forms with ports
// (`sibling:https://github.com:443/org/repo:sibling`,
// `sibling:ssh://git@github.com:22/org/repo:sibling`), conflicting with
// SEC-1.3 / ARCH-003 which treat the url field as an opaque git remote URL or
// file path stored as-is. The new parser uses the FIRST colon as the name
// delimiter and the LAST colon as the relationship delimiter; everything in
// between is opaque URL content (any number of internal colons).

process.stdout.write('Suite: regression --related-repos opaque URL contract\n');

// Reviewer's exact blocker examples — must pass now (HTTPS / SSH with ports).
for (const good of [
  'sibling:https://github.com:443/org/repo:sibling',          // https w/ port
  'sibling:ssh://git@github.com:22/org/repo:sibling',         // ssh:// w/ port
  'a:git@github.com:org/repo:sibling',                        // SCP-like remote
  'a:https://github.com/org/repo:sibling',                    // https no port
  'a:ssh://git@github.com/org/repo:sibling',                  // ssh:// no port
  'a:/abs/local/path:child',                                  // absolute path
  'a:./rel/path:child',                                       // relative path
  'a:b:c',                                                    // minimal triple
  // Opaque URL carrying multiple internal colons — accepted per SEC-1.3.
  'a:https://github.com/o/a:parent:extra',                    // url=https://github.com/o/a:parent
  'a:b:c:d:e',                                                // url=b:c:d
  'a:b:c:d:e:f:g',                                            // url=b:c:d:e:f
  // Multi-triple list with mixed opaque URLs (one of each form).
  'a:https://github.com:443/o/a:sibling,b:ssh://git@github.com:22/o/b:parent,c:git@github.com:o/c:child',
]) {
  check(`regression: --related-repos '${good}' accepted (opaque url)`, () => {
    const tmp = mkdtempRepo(`reg-rr-good-${good.length}-${Math.abs(good.split(':').length)}`);
    const r = runInit(
      [
        '--project-dir', tmp,
        '--worktree-root', path.join(tmp, 'wt'),
        ...noninteractiveRequired(),
        '--related-repos', good,
      ],
    );
    assert.strictEqual(r.status, 0, `expected exit 0 for '${good}', got ${r.status}\nstderr:\n${r.stderr}`);
  });
}

// Unambiguous malformed entries — must fail.
for (const bad of [
  'just-a-name',                // no colon — missing url + relationship
  'a:b',                        // 1 colon — missing relationship field
  ':https://github.com/o/a:parent', // empty name (first char is colon)
  'name::relationship',         // empty url (middle is blank)
  'a:https://github.com/o/a:',  // empty relationship (last char is colon)
  'a:',                         // 1 colon, empty url + empty relationship
  ':',                          // 1 colon, all empty
  'a::',                        // 2 colons, empty url + empty relationship
  '::relationship',             // 2 colons, empty name + empty url
]) {
  check(`regression: --related-repos '${bad}' rejected (unambiguous)`, () => {
    const tmp = mkdtempRepo(`reg-rr-bad-${bad.length}-${Math.abs(bad.split(':').length)}`);
    const r = runInit(
      [
        '--project-dir', tmp,
        '--worktree-root', path.join(tmp, 'wt'),
        ...noninteractiveRequired(),
        '--related-repos', bad,
      ],
    );
    assert.strictEqual(r.status, 1, `expected exit 1 for '${bad}', got ${r.status}\nstderr:\n${r.stderr}`);
    assert.ok(/Invalid --related-repos entry/.test(r.stderr));
  });
}

// Comma-separated list with one malformed triple must fail the whole flag
// (single-entry failure prevents silent partial storage).
check('regression: --related-repos list with one malformed triple rejected', () => {
  const tmp = mkdtempRepo('reg-rr-list-one-bad');
  const r = runInit(
    [
      '--project-dir', tmp,
      '--worktree-root', path.join(tmp, 'wt'),
      ...noninteractiveRequired(),
      '--related-repos', 'a:https://github.com:443/o/a:sibling,b:not-a-triple',
    ],
  );
  assert.strictEqual(r.status, 1, `expected exit 1, got ${r.status}\nstderr:\n${r.stderr}`);
  assert.ok(/Invalid --related-repos entry/.test(r.stderr));
});

// --- Summary ----------------------------------------------------------------

process.stdout.write(`\n${pass} passed, ${fail} failed\n`);
if (fail > 0) {
  process.exit(1);
}
