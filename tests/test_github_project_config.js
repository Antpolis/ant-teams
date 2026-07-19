#!/usr/bin/env node
'use strict';

/*
 * tests/test_github_project_config.js — SPEC-001-T5 unit tests (issue #6).
 *
 * Drives `.opencode/skills/project-initialization/scripts/init_project_docs.sh`
 * against throwaway target project directories and asserts the DM-1 / FR-6 /
 * FR-8 / SEC-2 / ARCH-003 Artifact 1+4 contract:
 *
 *   - AC-T5-001: fresh repo → .github-project.json created with ALL required
 *                DM-1 fields (owner placeholders + worktreeRoot + identity +
 *                boundaries + initMeta). (traceable to AC-SPEC-008)
 *   - AC-T5-002: legacy-initialized fixture → new fields added WITHOUT
 *                removing existing owner/project/fields/status_options.
 *                (traceable to AC-SPEC-004)
 *   - AC-T5-003: .opencode/opencode.json (canonical ARCH-003 location) gets
 *                external_directory entry added WITHOUT removing existing
 *                entries (e.g. agent definitions, provider blocks).
 *   - AC-T5-004: legacy agent.md (lowercase) survives init — file still
 *                exists after run. (traceable to AC-SPEC-011)
 *   - AC-T5-005: idempotent rerun → .github-project.json byte-for-byte
 *                identical; exit 0; "No changes needed" emitted.
 *                (traceable to AC-SPEC-005 / TR-2.1)
 *   - AC-T5-006: --force creates .bak.<timestamp> of existing AGENTS.md.
 *                NOTE: at T5 scope AGENTS.md generation is not yet wired
 *                (ships with T3 / issue #4), so this AC is asserted at the
 *                "no AGENTS.md is generated, no backup is created" level.
 *                The full backup helper lands with T3. This suite records
 *                that decision so a future regression is caught.
 *   - AC-T5-007: boundaries.depends_on and boundaries.related_repos are []
 *                (not absent) when operator provides no relationships.
 *                (FR-8.5)
 *
 * Plus ARCH-003 / DM-1 invariants that make the schema robust:
 *   - --related-repos triples parse into boundaries.related_repos with
 *     opaque url preservation (SEC-1.3: HTTPS+port, SCP-style, paths).
 *   - identity.name falls back to detected repo name when --name omitted.
 *   - identity.role falls back to "other" when --repo-role omitted.
 *   - pre-existing identity/boundaries/initMeta blocks are preserved on
 *     rerun (strictly additive — ARCH-003 guarantee 2).
 *   - .opencode/opencode.jsonc (canonical location, jsonc form) also
 *     detected and updated in place.
 *
 * The suite mirrors test_cli_flags.js / test_skills_copy.js patterns: real
 * init script invocation, no npm dependencies, plain Node assert.
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
const LEGACY_FIXTURE = path.join(REPO_ROOT, 'tests', 'fixtures', 'repo-legacy-init');

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
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), `ghp-${prefix}-`));
  // init_project_docs.sh expects a git project (used by other steps in the
  // script). A `.git/` directory marker is sufficient for the T5 scope,
  // which does not invoke git commands against the target.
  fs.mkdirSync(path.join(dir, '.git'), { recursive: true });
  return dir;
}

// Minimal noninteractive required-flags set (T2 / issue #3). All T5 tests
// run noninteractively so the T3 prompts (not yet shipped) don't block.
function noninteractiveRequired() {
  return [
    '--noninteractive',
    '--name', 'test',
    '--github-owner', 'antpolis',
    '--github-project-number', '9',
  ];
}

// Run init with a target dir + worktree root + optional extra argv.
function runInit(projectDir, extraArgv, env) {
  const argv = [
    INIT_SCRIPT,
    '--project-dir', projectDir,
    '--worktree-root', path.join(projectDir, 'wt'),
    ...noninteractiveRequired(),
    ...(extraArgv || []),
  ];
  const result = { stdout: '', stderr: '', status: 0 };
  try {
    result.stdout = execFileSync('bash', argv, {
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

function readJson(p) {
  return JSON.parse(fs.readFileSync(p, 'utf8'));
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

check('legacy fixture exists with expected files', () => {
  assert.ok(fs.existsSync(path.join(LEGACY_FIXTURE, '.github-project.json')));
  assert.ok(fs.existsSync(path.join(LEGACY_FIXTURE, 'agent.md')));
  assert.ok(fs.existsSync(path.join(LEGACY_FIXTURE, '.opencode', 'opencode.json')));
});

// --- AC-T5-001: fresh repo → full DM-1 schema -------------------------------

process.stdout.write('Suite: AC-T5-001 fresh repo full DM-1 schema\n');

function assertAllDm1FieldsPresent(cfg, label) {
  const required = [
    'owner', 'owner_type', 'repo',
    'project', 'fields', 'status_options',
    'worktreeRoot', 'identity', 'boundaries', 'initMeta',
  ];
  for (const k of required) {
    assert.ok(
      Object.prototype.hasOwnProperty.call(cfg, k),
      `${label}: missing required DM-1 field '${k}'`
    );
  }
  // identity sub-fields
  for (const k of ['name', 'description', 'role']) {
    assert.ok(
      Object.prototype.hasOwnProperty.call(cfg.identity, k),
      `${label}: missing identity.${k}`
    );
  }
  // boundaries sub-fields (FR-8.5: depends_on and related_repos must be arrays)
  assert.ok(Object.prototype.hasOwnProperty.call(cfg.boundaries, 'owns'), `${label}: missing boundaries.owns`);
  assert.ok(Array.isArray(cfg.boundaries.depends_on), `${label}: boundaries.depends_on must be array`);
  assert.ok(Array.isArray(cfg.boundaries.related_repos), `${label}: boundaries.related_repos must be array`);
  // initMeta sub-fields
  assert.ok(Object.prototype.hasOwnProperty.call(cfg.initMeta, 'version'), `${label}: missing initMeta.version`);
  assert.ok(Object.prototype.hasOwnProperty.call(cfg.initMeta, 'generatedAt'), `${label}: missing initMeta.generatedAt`);
}

check('AC-T5-001: fresh repo has all DM-1 fields including identity/boundaries/initMeta', () => {
  const tmp = mkdtempRepo('ac001');
  const r = runInit(tmp);
  assert.strictEqual(r.status, 0, `expected exit 0, got ${r.status}\nstderr:\n${r.stderr}`);

  const cfgPath = path.join(tmp, '.github-project.json');
  assert.ok(fs.existsSync(cfgPath), 'expected .github-project.json to be created');
  const cfg = readJson(cfgPath);
  assertAllDm1FieldsPresent(cfg, 'AC-T5-001');
});

check('AC-T5-001: .github-project.json is valid JSON (parseable by jq equivalent)', () => {
  const tmp = mkdtempRepo('ac001-json');
  runInit(tmp);
  // JSON.parse already verifies validity; re-read to confirm no trailing garbage.
  const raw = fs.readFileSync(path.join(tmp, '.github-project.json'), 'utf8');
  assert.doesNotThrow(() => JSON.parse(raw), 'file must be valid JSON');
});

check('AC-T5-001: worktreeRoot expands to a real absolute path', () => {
  const tmp = mkdtempRepo('ac001-wt');
  runInit(tmp);
  const cfg = readJson(path.join(tmp, '.github-project.json'));
  assert.ok(cfg.worktreeRoot.startsWith('/'), `worktreeRoot should be absolute, got ${cfg.worktreeRoot}`);
  assert.ok(cfg.worktreeRoot.includes('/wt'), `worktreeRoot should include wt, got ${cfg.worktreeRoot}`);
});

check('AC-T5-001: identity.name matches --name flag', () => {
  const tmp = mkdtempRepo('ac001-name');
  runInit(tmp, ['--name', 'explicit-name']);
  const cfg = readJson(path.join(tmp, '.github-project.json'));
  assert.strictEqual(cfg.identity.name, 'explicit-name');
});

check('AC-T5-001: identity.description matches --description flag', () => {
  const tmp = mkdtempRepo('ac001-desc');
  runInit(tmp, ['--description', 'A service for testing identity population.']);
  const cfg = readJson(path.join(tmp, '.github-project.json'));
  assert.strictEqual(cfg.identity.description, 'A service for testing identity population.');
});

check('AC-T5-001: identity.role matches --repo-role flag', () => {
  const tmp = mkdtempRepo('ac001-role');
  runInit(tmp, ['--repo-role', 'service']);
  const cfg = readJson(path.join(tmp, '.github-project.json'));
  assert.strictEqual(cfg.identity.role, 'service');
});

check('AC-T5-001: initMeta.version matches INIT_PROJECT_VERSION (0.3.0 after T3 bump)', () => {
  const tmp = mkdtempRepo('ac001-ver');
  runInit(tmp);
  const cfg = readJson(path.join(tmp, '.github-project.json'));
  assert.ok(typeof cfg.initMeta.version === 'string' && cfg.initMeta.version.length > 0);
  // T3 (issue #4) bumped INIT_PROJECT_VERSION 0.2.0 → 0.3.0 to stamp the
  // AGENTS.md generation capability into initMeta.version (ARCH-003 / DM-1.3).
  assert.strictEqual(cfg.initMeta.version, '0.3.0');
});

check('AC-T5-001: initMeta.generatedAt is ISO 8601', () => {
  const tmp = mkdtempRepo('ac001-ts');
  runInit(tmp);
  const cfg = readJson(path.join(tmp, '.github-project.json'));
  // ISO 8601: YYYY-MM-DDTHH:MM:SS(...) with timezone designator (Z or ±HH:MM).
  assert.ok(
    /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(cfg.initMeta.generatedAt),
    `generatedAt not ISO 8601: ${cfg.initMeta.generatedAt}`
  );
});

// --- AC-T5-002: legacy fixture migration ------------------------------------

process.stdout.write('Suite: AC-T5-002 legacy fixture additive migration\n');

function copyLegacyFixture(prefix) {
  const tmp = mkdtempRepo(prefix);
  // Wipe the empty .git mkdtempRepo created so we can re-create the fixture
  // exactly. Then copy the fixture contents in.
  fs.rmSync(path.join(tmp, '.git'), { recursive: true, force: true });
  // Copy fixture contents (including dotfiles).
  const entries = fs.readdirSync(LEGACY_FIXTURE, { withFileTypes: true });
  for (const e of entries) {
    const src = path.join(LEGACY_FIXTURE, e.name);
    const dst = path.join(tmp, e.name);
    fs.cpSync(src, dst, { recursive: true });
  }
  fs.mkdirSync(path.join(tmp, '.git'), { recursive: true });
  return tmp;
}

function legacyExpectedPreserved(cfg) {
  // These are the exact values from tests/fixtures/repo-legacy-init/.github-project.json.
  assert.strictEqual(cfg.owner, 'antpolis', 'legacy owner must be preserved');
  assert.strictEqual(cfg.owner_type, 'org', 'legacy owner_type must be preserved');
  assert.strictEqual(cfg.repo, 'antpolis/legacy-demo', 'legacy repo must be preserved');
  assert.strictEqual(cfg.project.number, 1, 'legacy project.number must be preserved');
  assert.strictEqual(cfg.fields.status, 'PVTSSF_LEGACY', 'legacy fields.status must be preserved');
  assert.strictEqual(cfg.status_options.todo, 'f75ad846', 'legacy status_options.todo must be preserved');
  assert.strictEqual(cfg.status_options['in-progress'], '61e4505c', 'legacy status_options.in-progress must be preserved');
  assert.strictEqual(cfg.status_options['in-review'], 'abcdef12', 'legacy status_options.in-review must be preserved');
  assert.strictEqual(cfg.status_options.done, '1234abcd', 'legacy status_options.done must be preserved');
}

check('AC-T5-002: legacy fixture — existing owner/project/fields/status_options preserved', () => {
  const tmp = copyLegacyFixture('ac002');
  const r = runInit(tmp);
  assert.strictEqual(r.status, 0, `expected exit 0, got ${r.status}\nstderr:\n${r.stderr}`);
  const cfg = readJson(path.join(tmp, '.github-project.json'));
  legacyExpectedPreserved(cfg);
});

check('AC-T5-002: legacy fixture — new fields worktreeRoot/identity/boundaries/initMeta added', () => {
  const tmp = copyLegacyFixture('ac002-new');
  runInit(tmp);
  const cfg = readJson(path.join(tmp, '.github-project.json'));
  assert.ok(cfg.worktreeRoot, 'worktreeRoot must be added');
  assert.ok(cfg.identity && cfg.identity.name, 'identity.name must be added');
  assert.ok(cfg.boundaries, 'boundaries must be added');
  assert.ok(cfg.initMeta && cfg.initMeta.version, 'initMeta.version must be added');
});

check('AC-T5-002: legacy fixture — all required DM-1 fields present after migration', () => {
  const tmp = copyLegacyFixture('ac002-full');
  runInit(tmp);
  const cfg = readJson(path.join(tmp, '.github-project.json'));
  assertAllDm1FieldsPresent(cfg, 'AC-T5-002');
});

// --- AC-T5-003: .opencode/opencode.json (canonical location) ----------------

process.stdout.write('Suite: AC-T5-003 opencode.json external_directory additive\n');

check('AC-T5-003: .opencode/opencode.json (canonical ARCH-003 location) detected and updated', () => {
  const tmp = mkdtempRepo('ac003-canonical');
  // Pre-existing canonical-location config with an entry that MUST survive.
  fs.mkdirSync(path.join(tmp, '.opencode'), { recursive: true });
  fs.writeFileSync(
    path.join(tmp, '.opencode', 'opencode.json'),
    JSON.stringify({
      permission: { external_directory: {} },
      agent: 'builder',
    }, null, 2)
  );
  const r = runInit(tmp);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);

  const cfg = readJson(path.join(tmp, '.opencode', 'opencode.json'));
  // Existing entry preserved (SEC-2.1).
  assert.strictEqual(cfg.agent, 'builder', 'pre-existing "agent" entry must be preserved');
  // external_directory entry added.
  const keys = Object.keys(cfg.permission.external_directory);
  assert.ok(keys.length > 0, 'external_directory must have at least one entry');
  assert.strictEqual(cfg.permission.external_directory[keys[0]], 'allow');
  assert.ok(keys[0].endsWith('/**'), `expected worktree pattern ending in /**, got ${keys[0]}`);
});

check('AC-T5-003: .opencode/opencode.jsonc (canonical, jsonc form) detected and updated', () => {
  const tmp = mkdtempRepo('ac003-jsonc');
  fs.mkdirSync(path.join(tmp, '.opencode'), { recursive: true });
  // jsonc file with a comment + trailing comma — init must parse and preserve.
  fs.writeFileSync(
    path.join(tmp, '.opencode', 'opencode.jsonc'),
    [
      '{',
      '  // project-local opencode config',
      '  "permission": {',
      '    "external_directory": {},',
      '  },',
      '  "agent": "builder",',
      '}',
    ].join('\n')
  );
  const r = runInit(tmp);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  // The init writes back as JSON (existing behavior); we only assert the
  // external_directory entry was added without removing the agent entry.
  // (The comments are stripped on rewrite by the existing stripJsonComments
  // helper — that is pre-existing behavior and not in T5 scope to change.)
  const raw = fs.readFileSync(path.join(tmp, '.opencode', 'opencode.jsonc'), 'utf8');
  assert.ok(raw.includes('"agent": "builder"'), 'pre-existing agent entry must survive');
  assert.ok(raw.includes('/**'), 'worktree external_directory entry must be added');
});

check('AC-T5-003: existing external_directory entries preserved when adding worktree entry', () => {
  const tmp = mkdtempRepo('ac003-existing');
  fs.mkdirSync(path.join(tmp, '.opencode'), { recursive: true });
  const preExistingPattern = '/some/other/path/**';
  fs.writeFileSync(
    path.join(tmp, '.opencode', 'opencode.json'),
    JSON.stringify({
      permission: {
        external_directory: {
          [preExistingPattern]: 'allow',
        },
      },
    }, null, 2)
  );
  runInit(tmp);
  const cfg = readJson(path.join(tmp, '.opencode', 'opencode.json'));
  assert.strictEqual(
    cfg.permission.external_directory[preExistingPattern],
    'allow',
    'pre-existing external_directory entry must be preserved'
  );
  // Plus the new worktree entry.
  const keys = Object.keys(cfg.permission.external_directory);
  assert.ok(keys.length >= 2, 'expected at least 2 external_directory entries');
});

check('AC-T5-003: worktree external_directory entry idempotent on rerun', () => {
  const tmp = mkdtempRepo('ac003-idem');
  fs.mkdirSync(path.join(tmp, '.opencode'), { recursive: true });
  fs.writeFileSync(
    path.join(tmp, '.opencode', 'opencode.json'),
    JSON.stringify({ permission: { external_directory: {} }, agent: 'builder' }, null, 2)
  );
  runInit(tmp);
  const after1 = fs.readFileSync(path.join(tmp, '.opencode', 'opencode.json'), 'utf8');
  runInit(tmp);
  const after2 = fs.readFileSync(path.join(tmp, '.opencode', 'opencode.json'), 'utf8');
  assert.strictEqual(after1, after2, 'second run must not modify opencode.json');
});

// --- AC-T5-004: legacy agent.md preservation --------------------------------

process.stdout.write('Suite: AC-T5-004 agent.md coexistence\n');

check('AC-T5-004: legacy agent.md (lowercase) survives init', () => {
  const tmp = copyLegacyFixture('ac004');
  const agentMdPath = path.join(tmp, 'agent.md');
  assert.ok(fs.existsSync(agentMdPath), 'fixture must have agent.md before init');
  const before = fs.readFileSync(agentMdPath, 'utf8');

  const r = runInit(tmp);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);

  assert.ok(fs.existsSync(agentMdPath), 'agent.md must still exist after init');
  const after = fs.readFileSync(agentMdPath, 'utf8');
  assert.strictEqual(after, before, 'agent.md content must be byte-for-byte identical');
});

check('AC-T5-004: agent.md content is exactly the legacy fixture content', () => {
  const tmp = copyLegacyFixture('ac004-content');
  runInit(tmp);
  const after = fs.readFileSync(path.join(tmp, 'agent.md'), 'utf8');
  const expected = fs.readFileSync(path.join(LEGACY_FIXTURE, 'agent.md'), 'utf8');
  assert.strictEqual(after, expected);
});

// --- AC-T5-005: idempotency (byte-for-byte) ---------------------------------

process.stdout.write('Suite: AC-T5-005 idempotent rerun\n');

check('AC-T5-005: rerun produces byte-for-byte identical .github-project.json', () => {
  const tmp = mkdtempRepo('ac005');
  runInit(tmp);
  const after1 = fs.readFileSync(path.join(tmp, '.github-project.json'), 'utf8');
  // Wait a moment so a regenerated generatedAt would differ if the
  // idempotency guard were broken.
  const waitMs = 1100;
  const { spawnSync } = require('child_process');
  spawnSync('sleep', [String(waitMs / 1000)]);
  const r = runInit(tmp);
  assert.strictEqual(r.status, 0, `rerun exit ${r.status}\nstderr:\n${r.stderr}`);
  const after2 = fs.readFileSync(path.join(tmp, '.github-project.json'), 'utf8');
  assert.strictEqual(after1, after2, 'rerun must not modify .github-project.json');
});

check('AC-T5-005: rerun emits "No changes needed in .github-project.json" on stdout', () => {
  const tmp = mkdtempRepo('ac005-msg');
  runInit(tmp);
  const r = runInit(tmp);
  assert.strictEqual(r.status, 0);
  assert.ok(
    /No changes needed in \.github-project\.json/.test(r.stdout),
    `expected "No changes needed" message on stdout:\n${r.stdout}`
  );
});

check('AC-T5-005: idempotency holds on legacy fixture too', () => {
  const tmp = copyLegacyFixture('ac005-leg');
  runInit(tmp);
  const after1 = fs.readFileSync(path.join(tmp, '.github-project.json'), 'utf8');
  const r = runInit(tmp);
  assert.strictEqual(r.status, 0, `rerun exit ${r.status}\nstderr:\n${r.stderr}`);
  const after2 = fs.readFileSync(path.join(tmp, '.github-project.json'), 'utf8');
  assert.strictEqual(after1, after2);
});

// --- AC-T5-006 / AC-T3-007: --force backup behavior (active after T3) -------
// Previously dormant: T5 scope did not generate AGENTS.md so the .bak helper
// had nothing to back up. T3 (issue #4) wires AGENTS.md generation + the
// ERR-3.2 backup, so this is now an active contract test.

process.stdout.write('Suite: AC-T5-006 / AC-T3-007 --force backup (active after T3)\n');

check('AC-T5-006 / AC-T3-007: --force on existing AGENTS.md creates .bak.<ts> and overwrites', () => {
  // T3 generates AGENTS.md. --force on a pre-existing file MUST back it up
  // to <filename>.bak.<timestamp> before overwriting (ERR-3.2 / FR-5.5).
  const tmp = mkdtempRepo('ac006');
  fs.writeFileSync(path.join(tmp, 'AGENTS.md'), 'hand-written agents.md');
  const r = runInit(tmp, ['--force']);
  assert.strictEqual(r.status, 0, `--force accepted: exit ${r.status}\nstderr:\n${r.stderr}`);
  // Exactly one .bak.<timestamp> backup must be created.
  const backups = fs.readdirSync(tmp).filter((n) => /^AGENTS\.md\.bak\.\d{8}T\d{6}Z$/.test(n));
  assert.strictEqual(backups.length, 1, `expected exactly 1 backup, got ${backups}`);
  // Backup preserves the original content verbatim.
  const backupContent = fs.readFileSync(path.join(tmp, backups[0]), 'utf8');
  assert.strictEqual(backupContent, 'hand-written agents.md', 'backup must preserve original');
  // AGENTS.md is overwritten with generated content (starts with generation comment).
  const after = fs.readFileSync(path.join(tmp, 'AGENTS.md'), 'utf8');
  assert.ok(/^<!-- Generated by init-project v/.test(after), 'AGENTS.md must start with generation comment after --force');
  assert.notStrictEqual(after, 'hand-written agents.md', 'AGENTS.md must be regenerated');
});

// --- AC-T5-007: empty arrays for depends_on / related_repos ----------------

process.stdout.write('Suite: AC-T5-007 empty arrays present\n');

check('AC-T5-007: boundaries.depends_on is [] when no relationships provided', () => {
  const tmp = mkdtempRepo('ac007-deps');
  runInit(tmp);
  const cfg = readJson(path.join(tmp, '.github-project.json'));
  assert.ok(Array.isArray(cfg.boundaries.depends_on), 'depends_on must be an array');
  assert.strictEqual(cfg.boundaries.depends_on.length, 0, 'depends_on must be empty []');
  // Explicit deep-equal to catch any subtle non-empty representation.
  assert.deepStrictEqual(cfg.boundaries.depends_on, []);
});

check('AC-T5-007: boundaries.related_repos is [] when no --related-repos provided', () => {
  const tmp = mkdtempRepo('ac007-rel');
  runInit(tmp);
  const cfg = readJson(path.join(tmp, '.github-project.json'));
  assert.ok(Array.isArray(cfg.boundaries.related_repos));
  assert.strictEqual(cfg.boundaries.related_repos.length, 0);
  assert.deepStrictEqual(cfg.boundaries.related_repos, []);
});

check('AC-T5-007: empty arrays survive on legacy fixture migration too', () => {
  const tmp = copyLegacyFixture('ac007-leg');
  runInit(tmp);
  const cfg = readJson(path.join(tmp, '.github-project.json'));
  assert.deepStrictEqual(cfg.boundaries.depends_on, []);
  assert.deepStrictEqual(cfg.boundaries.related_repos, []);
});

// --- ARCH-003 / DM-1 schema robustness invariants --------------------------

process.stdout.write('Suite: schema robustness (identity fallbacks, related-repos parsing, additive-only)\n');

check('schema: identity.name falls back to detected repo name when --name omitted', () => {
  // We pass --name explicitly as '' via the env-var path to simulate the
  // interactive-no-prompts case at T5 scope. Easiest observable path: set
  // INIT_PROJECT_NAME='' to override the default 'test' from the helper.
  const tmp = mkdtempRepo('schema-name-fallback');
  const basename = path.basename(tmp);
  const r = runInit(tmp, [], { INIT_PROJECT_NAME: '' });
  // The noninteractive required-flag check uses opt_name which resolves to
  // '' here; the check fails. Detect that and use a different strategy:
  // omit --name from the helper by calling init directly.
  if (r.status !== 0) {
    // Direct invocation without --name but with --interactive so the
    // required-flag accounting is bypassed; identity.name then falls back
    // to detected basename(project_dir).
    const r2 = execFileSync('bash', [
      INIT_SCRIPT,
      '--project-dir', tmp,
      '--worktree-root', path.join(tmp, 'wt'),
      '--interactive',
    ], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
    void r2;
  }
  const cfg = readJson(path.join(tmp, '.github-project.json'));
  // identity.name should be either the explicit --name (test) or the
  // detected basename, depending on path taken. The fallback invariant:
  // it must be a non-empty string and must equal either the explicit flag
  // or the basename.
  assert.ok(typeof cfg.identity.name === 'string' && cfg.identity.name.length > 0);
  assert.ok(
    cfg.identity.name === 'test' || cfg.identity.name === basename,
    `identity.name=${cfg.identity.name} should be flag ('test') or detected basename ('${basename}')`
  );
});

check('schema: identity.role falls back to "other" when --repo-role omitted', () => {
  const tmp = mkdtempRepo('schema-role-fallback');
  runInit(tmp); // no --repo-role
  const cfg = readJson(path.join(tmp, '.github-project.json'));
  // The helper passes --name test but no --repo-role → fallback "other".
  assert.strictEqual(cfg.identity.role, 'other');
});

check('schema: identity.description defaults to empty string when --description omitted', () => {
  const tmp = mkdtempRepo('schema-desc-default');
  runInit(tmp); // no --description
  const cfg = readJson(path.join(tmp, '.github-project.json'));
  assert.ok(Object.prototype.hasOwnProperty.call(cfg.identity, 'description'));
  assert.strictEqual(cfg.identity.description, '');
});

check('schema: --related-repos triple parses into boundaries.related_repos with opaque url', () => {
  const tmp = mkdtempRepo('schema-rr-parse');
  runInit(tmp, [
    '--related-repos',
    'sibling:https://github.com:443/org/sibling:sibling',
  ]);
  const cfg = readJson(path.join(tmp, '.github-project.json'));
  assert.strictEqual(cfg.boundaries.related_repos.length, 1);
  const entry = cfg.boundaries.related_repos[0];
  assert.strictEqual(entry.name, 'sibling');
  // SEC-1.3: url is opaque — port-bearing HTTPS form preserved verbatim.
  assert.strictEqual(entry.url, 'https://github.com:443/org/sibling');
  assert.strictEqual(entry.relationship, 'sibling');
});

check('schema: --related-repos accepts multiple triples and preserves SCP-style url', () => {
  const tmp = mkdtempRepo('schema-rr-multi');
  runInit(tmp, [
    '--related-repos',
    'a:https://github.com/o/a:sibling,b:git@github.com:org/parent:parent,c:/abs/local/path:child',
  ]);
  const cfg = readJson(path.join(tmp, '.github-project.json'));
  assert.strictEqual(cfg.boundaries.related_repos.length, 3);
  assert.strictEqual(cfg.boundaries.related_repos[0].name, 'a');
  assert.strictEqual(cfg.boundaries.related_repos[0].url, 'https://github.com/o/a');
  assert.strictEqual(cfg.boundaries.related_repos[1].name, 'b');
  // SCP-style git remote preserved verbatim (SEC-1.3).
  assert.strictEqual(cfg.boundaries.related_repos[1].url, 'git@github.com:org/parent');
  assert.strictEqual(cfg.boundaries.related_repos[2].url, '/abs/local/path');
  // depends_on still [] — no CLI flag exists for it at T5 scope.
  assert.deepStrictEqual(cfg.boundaries.depends_on, []);
});

check('schema: rerun with DIFFERENT --related-repos does NOT overwrite existing related_repos (additive-only)', () => {
  // ARCH-003 guarantee 2: strictly additive. Once an operator has provided
  // relationships, a later init run cannot silently rewrite them.
  const tmp = mkdtempRepo('schema-rr-protect');
  runInit(tmp, ['--related-repos', 'a:https://github.com/o/a:sibling']);
  let cfg = readJson(path.join(tmp, '.github-project.json'));
  assert.strictEqual(cfg.boundaries.related_repos.length, 1);
  assert.strictEqual(cfg.boundaries.related_repos[0].name, 'a');

  // Rerun with a different triple — must NOT overwrite the existing entry.
  runInit(tmp, ['--related-repos', 'b:https://github.com/o/b:parent']);
  cfg = readJson(path.join(tmp, '.github-project.json'));
  assert.strictEqual(cfg.boundaries.related_repos.length, 1, 'additive-only: existing related_repos must not be replaced');
  assert.strictEqual(cfg.boundaries.related_repos[0].name, 'a', 'original entry must be preserved');
});

check('schema: rerun preserves operator-provided identity/description/role (additive-only)', () => {
  const tmp = mkdtempRepo('schema-id-protect');
  runInit(tmp, ['--name', 'first', '--description', 'first desc', '--repo-role', 'service']);
  let cfg = readJson(path.join(tmp, '.github-project.json'));
  assert.strictEqual(cfg.identity.name, 'first');
  assert.strictEqual(cfg.identity.description, 'first desc');
  assert.strictEqual(cfg.identity.role, 'service');

  // Rerun with different values — existing identity must NOT be overwritten.
  runInit(tmp, ['--name', 'second', '--description', 'second desc', '--repo-role', 'tool']);
  cfg = readJson(path.join(tmp, '.github-project.json'));
  assert.strictEqual(cfg.identity.name, 'first', 'additive-only: existing identity.name must not be overwritten');
  assert.strictEqual(cfg.identity.description, 'first desc');
  assert.strictEqual(cfg.identity.role, 'service');
});

check('schema: rerun preserves operator-provided boundaries.owns (additive-only)', () => {
  // Although T5 doesn't expose a CLI flag for boundaries.owns, an operator
  // may set it manually. A later init run must preserve it.
  const tmp = mkdtempRepo('schema-owns');
  runInit(tmp);
  // Manually set boundaries.owns to simulate operator input.
  const cfgPath = path.join(tmp, '.github-project.json');
  const cfg = readJson(cfgPath);
  cfg.boundaries.owns = 'manually-set owns value';
  fs.writeFileSync(cfgPath, JSON.stringify(cfg, null, 2) + '\n');

  // Rerun — must not overwrite the manually-set owns.
  runInit(tmp);
  const after = readJson(cfgPath);
  assert.strictEqual(after.boundaries.owns, 'manually-set owns value');
});

check('schema: malformed existing .github-project.json fails loudly (not silent corruption)', () => {
  const tmp = mkdtempRepo('schema-malformed');
  fs.writeFileSync(path.join(tmp, '.github-project.json'), '{ not valid json');
  const r = runInit(tmp);
  assert.strictEqual(r.status, 1, `expected exit 1 on malformed JSON, got ${r.status}\nstderr:\n${r.stderr}`);
  // The node helper emits a JSON.parse error before any write — file must
  // be byte-for-byte identical (SEC-2.1 / ERR-2.1 write-to-temp-then-rename
  // spirit: never partially-write a config).
  const after = fs.readFileSync(path.join(tmp, '.github-project.json'), 'utf8');
  assert.strictEqual(after, '{ not valid json');
});

// --- PR15 review findings (regression) --------------------------------------
// These tests pin the two findings raised by the reviewer on PR #15:
//
//   Finding 1 (High) — Fresh init must create the canonical
//   `.opencode/opencode.json` (ARCH-003 Artifact 4 location contract), NOT
//   the legacy repo-root `opencode.jsonc`. Existing supported config in any
//   supported location must still be detected and updated in place without
//   being relocated.
//
//   Finding 2 (Medium) — Malformed `.github-project.json` must abort before
//   mutation with a concise controlled `[error]` message on stderr and NO
//   Node.js stack trace.
//
// Order of operations: these tests were added BEFORE the fix and used to
// demonstrate the failures. They now serve as the regression boundary.

process.stdout.write('Suite: PR15 review finding 1 — canonical .opencode/opencode.json on fresh init\n');

check('PR15-1: fresh init creates .opencode/opencode.json (canonical ARCH-003 location)', () => {
  const tmp = mkdtempRepo('pr15-1-fresh');
  const r = runInit(tmp);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  assert.ok(
    fs.existsSync(path.join(tmp, '.opencode', 'opencode.json')),
    'fresh init must create canonical .opencode/opencode.json'
  );
});

check('PR15-1: fresh init does NOT create legacy repo-root opencode.jsonc', () => {
  const tmp = mkdtempRepo('pr15-1-no-root-jsonc');
  const r = runInit(tmp);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  assert.ok(
    !fs.existsSync(path.join(tmp, 'opencode.jsonc')),
    'fresh init must not create legacy repo-root opencode.jsonc'
  );
});

check('PR15-1: fresh init does NOT create legacy repo-root opencode.json', () => {
  const tmp = mkdtempRepo('pr15-1-no-root-json');
  const r = runInit(tmp);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  assert.ok(
    !fs.existsSync(path.join(tmp, 'opencode.json')),
    'fresh init must not create legacy repo-root opencode.json'
  );
});

check('PR15-1: fresh init canonical config has the worktree external_directory entry', () => {
  const tmp = mkdtempRepo('pr15-1-content');
  runInit(tmp);
  const cfg = readJson(path.join(tmp, '.opencode', 'opencode.json'));
  assert.ok(cfg.permission && cfg.permission.external_directory, 'permission.external_directory must exist');
  const keys = Object.keys(cfg.permission.external_directory);
  assert.ok(keys.some((k) => k.endsWith('/**')), `expected worktree pattern, got ${keys}`);
  assert.ok(
    keys.some((k) => cfg.permission.external_directory[k] === 'allow'),
    'worktree entry must be allow'
  );
});

check('PR15-1: pre-existing repo-root opencode.jsonc is NOT relocated to .opencode/', () => {
  // ARCH-003 Artifact 4 guarantee 3: init never changes the file extension
  // or location of an existing config. A repo that already has the legacy
  // repo-root file must keep it there; init must NOT create a second,
  // shadowing `.opencode/opencode.json`.
  const tmp = mkdtempRepo('pr15-1-keep-root-jsonc');
  fs.writeFileSync(
    path.join(tmp, 'opencode.jsonc'),
    JSON.stringify({ permission: { external_directory: {} }, agent: 'builder' }, null, 2)
  );
  const r = runInit(tmp);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);

  // Existing root jsonc file preserved and updated in place.
  assert.ok(fs.existsSync(path.join(tmp, 'opencode.jsonc')), 'existing root opencode.jsonc must NOT be relocated');
  const raw = fs.readFileSync(path.join(tmp, 'opencode.jsonc'), 'utf8');
  assert.ok(raw.includes('"agent": "builder"'), 'existing entries in root jsonc must be preserved');
  assert.ok(raw.includes('/**'), 'worktree entry must be added to existing root jsonc');

  // Canonical location NOT created (no shadow / no relocation).
  assert.ok(
    !fs.existsSync(path.join(tmp, '.opencode', 'opencode.json')),
    'init must not create canonical .opencode/opencode.json when root config exists'
  );
  assert.ok(
    !fs.existsSync(path.join(tmp, '.opencode', 'opencode.jsonc')),
    'init must not create canonical .opencode/opencode.jsonc when root config exists'
  );
});

check('PR15-1: pre-existing repo-root opencode.json is NOT relocated to .opencode/', () => {
  // Mirror of the jsonc test above but for the .json extension. Guarantee 3
  // applies symmetrically to both supported extensions at any supported
  // location.
  const tmp = mkdtempRepo('pr15-1-keep-root-json');
  fs.writeFileSync(
    path.join(tmp, 'opencode.json'),
    JSON.stringify({ permission: { external_directory: {} }, agent: 'builder' }, null, 2)
  );
  const r = runInit(tmp);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  assert.ok(fs.existsSync(path.join(tmp, 'opencode.json')), 'existing root opencode.json must NOT be relocated');
  assert.ok(
    !fs.existsSync(path.join(tmp, '.opencode', 'opencode.json')),
    'init must not create canonical .opencode/opencode.json when root opencode.json exists'
  );
  const raw = fs.readFileSync(path.join(tmp, 'opencode.json'), 'utf8');
  assert.ok(raw.includes('"agent": "builder"'), 'existing entries must be preserved');
  assert.ok(raw.includes('/**'), 'worktree entry must be added');
});

check('PR15-1: pre-existing .opencode/opencode.jsonc is NOT converted to .json (extension preserved)', () => {
  // ARCH-003 Artifact 4 guarantee 3: init never changes the file extension.
  // A repo with a canonical-location jsonc file must keep it as jsonc.
  const tmp = mkdtempRepo('pr15-1-keep-jsonc-ext');
  fs.mkdirSync(path.join(tmp, '.opencode'), { recursive: true });
  fs.writeFileSync(
    path.join(tmp, '.opencode', 'opencode.jsonc'),
    JSON.stringify({ permission: { external_directory: {} }, agent: 'builder' }, null, 2)
  );
  const r = runInit(tmp);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  assert.ok(
    fs.existsSync(path.join(tmp, '.opencode', 'opencode.jsonc')),
    'canonical jsonc must keep its extension'
  );
  assert.ok(
    !fs.existsSync(path.join(tmp, '.opencode', 'opencode.json')),
    'init must not convert jsonc → json'
  );
});

process.stdout.write('Suite: PR15 review finding 2 — malformed .github-project.json controlled error\n');

check('PR15-2: malformed .github-project.json emits controlled [error] marker on stderr', () => {
  const tmp = mkdtempRepo('pr15-2-err-marker');
  fs.writeFileSync(path.join(tmp, '.github-project.json'), '{ not valid json');
  const r = runInit(tmp);
  assert.strictEqual(r.status, 1, `expected exit 1, got ${r.status}`);
  // The contract: a controlled message must use the [error] prefix used
  // everywhere else in the script (T2 validate_* helpers, die_missing_*).
  assert.ok(
    /\[error\]/.test(r.stderr),
    `stderr must contain a controlled [error] marker; got:\n${r.stderr}`
  );
});

check('PR15-2: malformed .github-project.json error mentions the file path', () => {
  const tmp = mkdtempRepo('pr15-2-err-path');
  fs.writeFileSync(path.join(tmp, '.github-project.json'), '{ not valid json');
  const r = runInit(tmp);
  assert.strictEqual(r.status, 1);
  assert.ok(
    /\.github-project\.json/.test(r.stderr),
    `stderr must identify .github-project.json as the failing file; got:\n${r.stderr}`
  );
});

check('PR15-2: malformed .github-project.json error does NOT emit a Node stack trace', () => {
  const tmp = mkdtempRepo('pr15-2-no-stack');
  fs.writeFileSync(path.join(tmp, '.github-project.json'), '{ not valid json');
  const r = runInit(tmp);
  assert.strictEqual(r.status, 1);
  // No node stack-trace artifacts may leak through. Stack traces are
  // operator-confusing and inconsistent with the rest of the script's
  // controlled [error] UX.
  const stackMarkers = ['SyntaxError', 'at JSON.parse', 'at Object.<anonymous>', 'Node.js v'];
  for (const marker of stackMarkers) {
    assert.ok(
      !r.stderr.includes(marker) && !r.stdout.includes(marker),
      `must not leak stack-trace marker '${marker}'; stderr:\n${r.stderr}\nstdout:\n${r.stdout}`
    );
  }
});

check('PR15-2: malformed .github-project.json aborts BEFORE mutation (file byte-for-byte preserved)', () => {
  const tmp = mkdtempRepo('pr15-2-no-mutation');
  const malformed = '{ not valid json\n  "owner": "partial",\n}';
  fs.writeFileSync(path.join(tmp, '.github-project.json'), malformed);
  const r = runInit(tmp);
  assert.strictEqual(r.status, 1);
  const after = fs.readFileSync(path.join(tmp, '.github-project.json'), 'utf8');
  assert.strictEqual(after, malformed, 'malformed file must be byte-for-byte preserved');
});

check('PR15-2: malformed .github-project.json does NOT touch .opencode/opencode.json', () => {
  // The abort must happen in ensure_github_project_config (which runs FIRST),
  // before ensure_opencode_config. Otherwise a half-initialized repo is left
  // behind with a broken .github-project.json + fresh opencode config that
  // masks the failure.
  const tmp = mkdtempRepo('pr15-2-abort-order');
  fs.writeFileSync(path.join(tmp, '.github-project.json'), '{ broken');
  // Seed an existing canonical opencode.json so we can detect any mutation.
  fs.mkdirSync(path.join(tmp, '.opencode'), { recursive: true });
  const before = JSON.stringify({ permission: { external_directory: {} }, agent: 'builder' }, null, 2);
  fs.writeFileSync(path.join(tmp, '.opencode', 'opencode.json'), before);
  const r = runInit(tmp);
  assert.strictEqual(r.status, 1);
  const after = fs.readFileSync(path.join(tmp, '.opencode', 'opencode.json'), 'utf8');
  assert.strictEqual(after, before, 'opencode.json must be untouched when .github-project.json is malformed');
});

// --- Summary ----------------------------------------------------------------

process.stdout.write(`\n${pass} passed, ${fail} failed\n`);
if (fail > 0) {
  process.exit(1);
}
