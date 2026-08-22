#!/usr/bin/env node
'use strict';

/*
 * tests/test_idempotency.js — SPEC-001-T6 unit tests (issue #7).
 *
 * Asserts the TR-2 idempotency contract and ERR-3.2 backup behavior. Drives
 * `.opencode/skills/project-initialization/scripts/init_project_docs.sh`
 * against throwaway target project directories.
 *
 * Coverage:
 *   - AC-T6-006: idempotent rerun (no --force) → exit 0, "No changes needed",
 *                no file modifications (traceable to AC-SPEC-005 / TR-2.1).
 *   - AC-T6-007: --force rerun creates .bak of a GENUINELY-changed AGENTS.md;
 *                the new AGENTS.md is structurally identical to a second
 *                --force with the same inputs (traceable to TR-2.2).
 *   - AC-T6-008: interrupt (simulated by removing AGENTS.md) leaves the repo
 *                in a safe state; rerun detects the missing artifact and
 *                regenerates it.
 *   - TR-2.2:    two consecutive --force runs with identical inputs produce
 *                byte-for-byte identical AGENTS.md (the issue body's exact
 *                verification command).
 *   - ERR-2.1:   atomic writes leave no partial files; a real run produces a
 *                valid AGENTS.md whose line 1 is the generation comment.
 *
 * No external npm dependencies — Node built-ins only.
 */

const { execFileSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const assert = require('assert');

const REPO_ROOT = path.resolve(__dirname, '..');
const INIT_SCRIPT = path.join(
  REPO_ROOT,
  '.opencode/skills/project-initialization/scripts/init_project_docs.sh'
);

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
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), `t6-idem-${prefix}-`));
  fs.mkdirSync(path.join(dir, '.git'), { recursive: true });
  return dir;
}

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

function noninteractive(extra) {
  return [
    '--noninteractive',
    '--project-dir', extra.projectDir,
    '--worktree-root', path.join(extra.projectDir, 'wt'),
    '--name', extra.name || 'test',
    '--github-owner', extra.githubOwner || 'antpolis',
    '--github-project-number', String(extra.githubProjectNumber || 9),
    ...(extra.description ? ['--description', extra.description] : []),
    ...(extra.force ? ['--force'] : []),
    ...(extra.merge ? ['--merge'] : []),
  ];
}

function hashFile(p) {
  // Stable file hash independent of mtime — used for byte-for-byte idempotency.
  const crypto = require('crypto');
  return crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
}

// --- Pre-flight --------------------------------------------------------------

process.stdout.write('Suite: preflight\n');

check('init_project_docs.sh exists', () => {
  assert.ok(fs.existsSync(INIT_SCRIPT), `init script missing at ${INIT_SCRIPT}`);
});

check('init_project_docs.sh is syntactically valid', () => {
  const { spawnSync } = require('child_process');
  const r = spawnSync('bash', ['-n', INIT_SCRIPT], { encoding: 'utf8' });
  assert.strictEqual(r.status, 0, `syntax error:\n${r.stderr}`);
});

// --- AC-T6-006: idempotent rerun (no --force) -------------------------------

process.stdout.write('Suite: AC-T6-006 idempotent rerun without --force\n');

check('AC-T6-006a: second run exits 0', () => {
  const tmp = mkdtempRepo('ac006a');
  runInit(noninteractive({ projectDir: tmp }));
  const r2 = runInit(noninteractive({ projectDir: tmp }));
  assert.strictEqual(r2.status, 0, `second run failed: ${r2.stderr}`);
});

check('AC-T6-006b: second run emits idempotent no-change wording', () => {
  const tmp = mkdtempRepo('ac006b');
  runInit(noninteractive({ projectDir: tmp }));
  const r2 = runInit(noninteractive({ projectDir: tmp }));
  assert.ok(/already up to date|no changes needed/i.test(r2.stdout),
    `expected idempotent no-change wording on stdout:\n${r2.stdout}`);
});

check('AC-T6-006c: .github-project.env is byte-for-byte identical across reruns', () => {
  const tmp = mkdtempRepo('ac006c');
  runInit(noninteractive({ projectDir: tmp }));
  const h1 = hashFile(path.join(tmp, '.github-project.env'));
  runInit(noninteractive({ projectDir: tmp }));
  const h2 = hashFile(path.join(tmp, '.github-project.env'));
  assert.strictEqual(h1, h2, '.github-project.env changed on idempotent rerun');
});

check('AC-T6-006d: AGENTS.md is byte-for-byte identical across reruns (no --force)', () => {
  const tmp = mkdtempRepo('ac006d');
  runInit(noninteractive({ projectDir: tmp }));
  const h1 = hashFile(path.join(tmp, 'AGENTS.md'));
  runInit(noninteractive({ projectDir: tmp }));
  const h2 = hashFile(path.join(tmp, 'AGENTS.md'));
  assert.strictEqual(h1, h2, 'AGENTS.md changed on idempotent rerun (no --force)');
});

check('AC-T6-006e: no new .bak files created on idempotent rerun', () => {
  const tmp = mkdtempRepo('ac006e');
  runInit(noninteractive({ projectDir: tmp }));
  runInit(noninteractive({ projectDir: tmp }));
  const baks = fs.readdirSync(tmp).filter((f) => f.includes('.bak'));
  assert.deepStrictEqual(baks, [], `unexpected .bak files on idempotent rerun: ${baks.join(', ')}`);
});

// --- AC-T6-007 / TR-2.2: --force idempotency + .bak on genuine change --------

process.stdout.write('Suite: AC-T6-007 --force idempotency + .bak\n');

check('AC-T6-007a: --force on a GENUINELY changed AGENTS.md creates exactly one .bak', () => {
  const tmp = mkdtempRepo('ac007a');
  // First init creates AGENTS.md with description A.
  runInit(noninteractive({ projectDir: tmp, description: 'Original purpose text' }));
  // --force with description B → genuine change → exactly one new .bak.
  const r = runInit(noninteractive({ projectDir: tmp, description: 'Changed purpose text', force: true }));
  const baks = fs.readdirSync(tmp).filter((f) => f.startsWith('AGENTS.md.bak'));
  assert.strictEqual(baks.length, 1, `expected exactly 1 .bak, got ${baks.length}:\n${r.stdout}`);
  // The new AGENTS.md should carry the changed text.
  const agents = fs.readFileSync(path.join(tmp, 'AGENTS.md'), 'utf8');
  assert.ok(agents.includes('Changed purpose text'), 'AGENTS.md not updated to changed text');
});

check('AC-T6-007b: TR-2.2 — two consecutive --force runs produce identical AGENTS.md', () => {
  const tmp = mkdtempRepo('ac007b');
  // First --force (creates AGENTS.md from scratch — no prior file, no .bak).
  runInit(noninteractive({ projectDir: tmp, force: true }));
  const first = path.join(tmp, 'AGENTS.md');
  const snapshot = fs.readFileSync(first, 'utf8');
  // Second --force with identical inputs → must be byte-for-byte identical
  // (no timestamp churn). This is the issue body's exact verification command.
  runInit(noninteractive({ projectDir: tmp, force: true }));
  const second = fs.readFileSync(first, 'utf8');
  assert.strictEqual(second, snapshot, 'AGENTS.md differs across --force reruns (TR-2.2 violation)');
});

check('AC-T6-007c: idempotent --force does NOT create a new .bak', () => {
  const tmp = mkdtempRepo('ac007c');
  runInit(noninteractive({ projectDir: tmp, description: 'Stable purpose', force: true }));
  const baksAfterFirst = fs.readdirSync(tmp).filter((f) => f.startsWith('AGENTS.md.bak')).length;
  // Second --force with identical inputs → no genuine change → no new .bak.
  runInit(noninteractive({ projectDir: tmp, description: 'Stable purpose', force: true }));
  const baksAfterSecond = fs.readdirSync(tmp).filter((f) => f.startsWith('AGENTS.md.bak')).length;
  assert.strictEqual(baksAfterSecond, baksAfterFirst,
    `idempotent --force created new .bak files (${baksAfterFirst} → ${baksAfterSecond})`);
});

check('AC-T6-007d: idempotent --force emits "no changes needed" (not a spurious write)', () => {
  const tmp = mkdtempRepo('ac007d');
  runInit(noninteractive({ projectDir: tmp, description: 'Stable purpose', force: true }));
  const r2 = runInit(noninteractive({ projectDir: tmp, description: 'Stable purpose', force: true }));
  assert.ok(/no changes needed|idempotent/i.test(r2.stdout),
    `expected idempotent no-op wording on second --force:\n${r2.stdout}`);
});

// --- AC-T6-008: interruption safety (atomic write, rerun detects) -----------

process.stdout.write('Suite: AC-T6-008 interruption safety\n');

check('AC-T6-008a: removing AGENTS.md (simulated interrupt) → rerun regenerates it', () => {
  const tmp = mkdtempRepo('ac008a');
  runInit(noninteractive({ projectDir: tmp }));
  assert.ok(fs.existsSync(path.join(tmp, 'AGENTS.md')), 'precondition: AGENTS.md should exist');
  // Simulate an interrupt that left AGENTS.md absent.
  fs.rmSync(path.join(tmp, 'AGENTS.md'), { force: true });
  // Rerun with --force regenerates (rerun detects incomplete state).
  const r = runInit(noninteractive({ projectDir: tmp, force: true }));
  assert.strictEqual(r.status, 0, `rerun failed: ${r.stderr}`);
  assert.ok(fs.existsSync(path.join(tmp, 'AGENTS.md')), 'AGENTS.md not regenerated after simulated interrupt');
  // Line 1 must still be the generation comment (ERR-2.1: valid file, not partial).
  const line1 = fs.readFileSync(path.join(tmp, 'AGENTS.md'), 'utf8').split('\n')[0];
  assert.ok(/^<!-- Generated by init-project/.test(line1), `line 1 not a generation comment: ${line1}`);
});

check('AC-T6-008b: AGENTS.md never partial — atomic write produces a complete file', () => {
  const tmp = mkdtempRepo('ac008b');
  runInit(noninteractive({ projectDir: tmp }));
  const agents = fs.readFileSync(path.join(tmp, 'AGENTS.md'), 'utf8');
  // Must end with a non-empty body section (atomic write完整性 — no truncation).
  assert.ok(/## Local Configuration Files/.test(agents), 'AGENTS.md missing required final section');
  assert.ok(agents.trimEnd().length > 0, 'AGENTS.md is empty or whitespace-only');
});

// --- ERR-2.3: temp cleanup --------------------------------------------------

process.stdout.write('Suite: ERR-2.3 temp cleanup\n');

check('ERR-2.3: no leaked temp files in target dir after a normal run', () => {
  const tmp = mkdtempRepo('err23');
  runInit(noninteractive({ projectDir: tmp }));
  // Atomic-write temps are hidden files matching .AGENTS.md.* / .github-project.env.*
  // in the target dir. They MUST be renamed away (mv -f) on successful completion.
  const leaked = fs.readdirSync(tmp).filter(
    (f) => f.startsWith('.AGENTS.md.') || f.startsWith('.github-project.env.'),
  );
  assert.deepStrictEqual(leaked, [], `leaked atomic-write temps: ${leaked.join(', ')}`);
});

check('ERR-2.3: no leaked temp files after a --force --merge run', () => {
  const tmp = mkdtempRepo('err23-merge');
  runInit(noninteractive({ projectDir: tmp, description: 'first' }));
  runInit(noninteractive({ projectDir: tmp, description: 'second', force: true, merge: true }));
  const leaked = fs.readdirSync(tmp).filter(
    (f) => f.startsWith('.AGENTS.md.') || f.startsWith('.github-project.env.'),
  );
  assert.deepStrictEqual(leaked, [], `leaked atomic-write temps after merge: ${leaked.join(', ')}`);
});

// --- Summary -----------------------------------------------------------------

process.stdout.write(`\n${pass} passed, ${fail} failed\n`);
if (fail > 0) {
  process.exit(1);
}
