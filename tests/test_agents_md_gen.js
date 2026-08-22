#!/usr/bin/env node
'use strict';

/*
 * tests/test_agents_md_gen.js — SPEC-001-T3 unit tests.
 *
 * Drives `.opencode/skills/project-initialization/scripts/init_project_docs.sh`
 * through the AGENTS.md generation surface added by issue #4:
 *
 *   - AC-T3-001: interactive mode on repo-bare generates AGENTS.md with
 *                Repository Identity + Commands + Local Configuration Files.
 *   - AC-T3-002: interactive mode accepts all-blank responses and omits
 *                empty sections (FR-3.3 / DM-2.3).
 *   - AC-T3-003: preview is displayed before writing; operator can confirm
 *                or abort (FR-3.4).
 *   - AC-T3-004: noninteractive mode with all flags generates AGENTS.md
 *                with zero prompts (FR-4 / AC-SPEC-003).
 *   - AC-T3-005: AGENTS.md line 1 is the generation timestamp comment
 *                (DM-2.1 / AC-SPEC-012).
 *   - AC-T3-006: every claim in generated AGENTS.md is traceable to
 *                inspection evidence or operator input (FR-5.3 / AC-SPEC-006).
 *   - AC-T3-007: pre-existing AGENTS.md without --force preserved; with
 *                --force creates .bak backup (FR-5.5 / ERR-3.2).
 *   - AC-T3-008: --force --merge appends new sections without removing
 *                existing content (FR-5.5).
 *
 * Also asserts DM-2 structure guarantees:
 *   - DM-2.2: standard H2 headings
 *   - DM-2.3: empty sections omitted
 *   - DM-2.4: "Local Configuration Files" always present
 *   - FR-5.3: no placeholder text, no fabricated facts
 *
 * Interactive tests use piped stdin to simulate operator responses. Each
 * prompt accepts blank = default per FR-3.3. The preview-confirm prompt
 * accepts Y/n.
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
const BARE_FIXTURE = path.join(REPO_ROOT, 'tests', 'fixtures', 'repo-bare');
const NODE_FIXTURE = path.join(REPO_ROOT, 'tests', 'fixtures', 'repo-node-npm');

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
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), `agents-md-${prefix}-`));
  fs.mkdirSync(path.join(dir, '.git'), { recursive: true });
  return dir;
}

// Copy a fixture repo into a temp dir so we can run init against it without
// polluting the real fixture. Includes dotfiles.
function cloneFixture(fixturePath, prefix) {
  const tmp = mkdtempRepo(prefix);
  fs.rmSync(path.join(tmp, '.git'), { recursive: true, force: true });
  const entries = fs.readdirSync(fixturePath, { withFileTypes: true });
  for (const e of entries) {
    const src = path.join(fixturePath, e.name);
    const dst = path.join(tmp, e.name);
    fs.cpSync(src, dst, { recursive: true });
  }
  fs.mkdirSync(path.join(tmp, '.git'), { recursive: true });
  return tmp;
}

// Runs the init script with given argv + stdin string. Returns {stdout, stderr, status}.
function runInit(argv, opts = {}) {
  const result = { stdout: '', stderr: '', status: 0 };
  try {
    result.stdout = execFileSync('bash', [INIT_SCRIPT, ...argv], {
      encoding: 'utf8',
      stdio: [opts.input != null ? 'pipe' : 'ignore', 'pipe', 'pipe'],
      input: opts.input,
      env: { ...process.env, ...(opts.env || {}) },
      timeout: opts.timeout || 30000,
    });
  } catch (err) {
    result.status = err.status ?? 1;
    result.stdout = err.stdout ? err.stdout.toString('utf8') : '';
    result.stderr = err.stderr ? err.stderr.toString('utf8') : '';
  }
  return result;
}

// Interactive-mode invocation helper. Sends `responses` lines as stdin, with
// a final "y" for the confirm prompt unless `confirm` is explicitly set.
function runInteractive(projectDir, responses, opts = {}) {
  const lines = [...responses];
  // Confirm write prompt — default "y" unless caller overrides.
  if (opts.confirm !== undefined) {
    lines.push(opts.confirm);
  } else {
    lines.push('y');
  }
  const input = lines.join('\n') + '\n';
  return runInit(
    ['--interactive', '--project-dir', projectDir, '--worktree-root', path.join(projectDir, 'wt')],
    { input }
  );
}

// Noninteractive invocation helper with the required identity flags.
function runNoninteractive(projectDir, extraArgs = [], opts = {}) {
  return runInit(
    [
      '--noninteractive',
      '--project-dir', projectDir,
      '--worktree-root', path.join(projectDir, 'wt'),
      '--name', opts.name || 'test',
      '--github-owner', opts.githubOwner || 'antpolis',
      '--github-project-number', String(opts.githubProjectNumber || 9),
      ...extraArgs,
    ],
    { env: opts.env }
  );
}

// --- Pre-flight -------------------------------------------------------------

process.stdout.write('Suite: preflight\n');

check('init_project_docs.sh exists', () => {
  assert.ok(fs.existsSync(INIT_SCRIPT), `init script missing at ${INIT_SCRIPT}`);
});

check('init_project_docs.sh is syntactically valid', () => {
  const { spawnSync } = require('child_process');
  const r = spawnSync('bash', ['-n', INIT_SCRIPT], { encoding: 'utf8' });
  assert.strictEqual(r.status, 0, `syntax error:\n${r.stderr}`);
});

check('INIT_PROJECT_VERSION is 0.3.0 (T3 bump)', () => {
  const text = fs.readFileSync(INIT_SCRIPT, 'utf8');
  assert.ok(/readonly INIT_PROJECT_VERSION="0\.3\.0"/.test(text), 'expected version 0.3.0');
});

// --- AC-T3-005: generation timestamp on line 1 ------------------------------

process.stdout.write('Suite: AC-T3-005 generation timestamp\n');

check('AC-T3-005: noninteractive AGENTS.md line 1 is the generation comment', () => {
  const tmp = mkdtempRepo('ac005');
  runNoninteractive(tmp);
  const agents = fs.readFileSync(path.join(tmp, 'AGENTS.md'), 'utf8');
  const line1 = agents.split('\n')[0];
  assert.ok(
    /^<!-- Generated by init-project v0\.3\.0 on \d{4}-\d{2}-\d{2}T/.test(line1),
    `line 1 mismatch: ${line1}`
  );
  assert.ok(/— edit freely -->$/.test(line1), `line 1 missing "edit freely": ${line1}`);
});

check('AC-T3-005: matches head -1 | grep contract from issue verification', () => {
  const tmp = mkdtempRepo('ac005-grep');
  runNoninteractive(tmp);
  const agents = fs.readFileSync(path.join(tmp, 'AGENTS.md'), 'utf8');
  const line1 = agents.split('\n')[0];
  assert.ok(/Generated by init-project/.test(line1), 'head -1 | grep contract');
});

// --- DM-2 structural guarantees ---------------------------------------------

process.stdout.write('Suite: DM-2 structure\n');

check('DM-2.2: standard H2 headings used', () => {
  const tmp = mkdtempRepo('dm22');
  runNoninteractive(tmp, [], {
    name: 'svc',
    githubOwner: 'org',
    githubProjectNumber: 3,
  });
  const agents = fs.readFileSync(path.join(tmp, 'AGENTS.md'), 'utf8');
  // Check that headings use ## (H2), not # (H1) or ### (H3).
  const h2Matches = agents.match(/^## .+$/gm) || [];
  assert.ok(h2Matches.length > 0, 'expected at least one H2 heading');
  for (const h of h2Matches) {
    assert.ok(h.startsWith('## '), `heading should be H2: ${h}`);
    assert.ok(!h.startsWith('### '), `heading should not be H3: ${h}`);
  }
});

check('DM-2.3: empty sections omitted (no empty H2 followed immediately by another H2)', () => {
  const tmp = mkdtempRepo('dm23');
  // No --conventions, no --related-repos, no --description → those sections
  // should be absent entirely, not present with empty bodies.
  runNoninteractive(tmp);
  const agents = fs.readFileSync(path.join(tmp, 'AGENTS.md'), 'utf8');
  const lines = agents.split('\n');
  for (let i = 0; i < lines.length - 1; i++) {
    if (lines[i].startsWith('## ')) {
      // The next non-blank line must not be another H2 (that would indicate
      // an empty section).
      let j = i + 1;
      while (j < lines.length && lines[j].trim() === '') j++;
      if (j < lines.length && lines[j].startsWith('## ')) {
        assert.fail(`empty section detected: "${lines[i]}" followed by "${lines[j]}"`);
      }
    }
  }
});

check('DM-2.4: "Local Configuration Files" section always present', () => {
  const tmp = mkdtempRepo('dm24');
  runNoninteractive(tmp);
  const agents = fs.readFileSync(path.join(tmp, 'AGENTS.md'), 'utf8');
  assert.ok(/## Local Configuration Files/.test(agents), 'Local Configuration Files missing');
  // Must list AGENTS.md itself.
  assert.ok(/`AGENTS\.md`/.test(agents), 'AGENTS.md not listed in Local Configuration Files');
  // Must list .github-project.env.
  assert.ok(/`\.github-project\.env`/.test(agents), '.github-project.env not listed');
});

check('DM-2.4: Local Configuration Files lists all created artifacts', () => {
  const tmp = mkdtempRepo('dm24-list');
  runNoninteractive(tmp);
  const agents = fs.readFileSync(path.join(tmp, 'AGENTS.md'), 'utf8');
  for (const entry of [
    'AGENTS.md',
    '.github-project.env',
    '.opencode/skills/github-issues-projects-cli/',
    '.opencode/skills/do-task/',
    '.opencode/skills/project-initialization/',
  ]) {
    assert.ok(agents.includes(`\`${entry}\``), `expected "${entry}" in Local Configuration Files`);
  }
});

// --- AC-T3-006: no fabricated facts -----------------------------------------

process.stdout.write('Suite: AC-T3-006 traceable claims / no fabrication\n');

check('AC-T3-006: no placeholder text ("TODO", "fill this in", "your-project-name")', () => {
  const tmp = mkdtempRepo('ac006');
  runNoninteractive(tmp, [], { name: 'real-service' });
  const agents = fs.readFileSync(path.join(tmp, 'AGENTS.md'), 'utf8');
  const forbidden = [/TODO/i, /fill this in/i, /your-project-name/i, /placeholder/i, /lorem ipsum/i];
  for (const re of forbidden) {
    assert.ok(!re.test(agents), `forbidden placeholder text matched by ${re}: present in output`);
  }
});

check('AC-T3-006: operator-provided purpose appears verbatim', () => {
  const tmp = mkdtempRepo('ac006-purpose');
  runNoninteractive(tmp, ['--description', 'A custom service for testing.']);
  const agents = fs.readFileSync(path.join(tmp, 'AGENTS.md'), 'utf8');
  assert.ok(agents.includes('A custom service for testing.'), 'purpose not in output');
});

check('AC-T3-006: operator-provided conventions appear verbatim', () => {
  const tmp = mkdtempRepo('ac006-conv');
  runNoninteractive(tmp, ['--conventions', 'Use conventional commits.']);
  const agents = fs.readFileSync(path.join(tmp, 'AGENTS.md'), 'utf8');
  assert.ok(agents.includes('Use conventional commits.'), 'conventions not in output');
  assert.ok(/## Working Conventions/.test(agents), 'Working Conventions section missing');
});

check('AC-T3-006: detected stack from inspection appears (node-npm fixture)', () => {
  const tmp = cloneFixture(NODE_FIXTURE, 'ac006-stack');
  runNoninteractive(tmp);
  const agents = fs.readFileSync(path.join(tmp, 'AGENTS.md'), 'utf8');
  assert.ok(/Node\.js/.test(agents), 'expected Node.js in stack');
  assert.ok(/npm/.test(agents), 'expected npm in stack');
});

check('AC-T3-006: detected commands from package.json scripts (node-npm fixture)', () => {
  const tmp = cloneFixture(NODE_FIXTURE, 'ac006-cmds');
  runNoninteractive(tmp);
  const agents = fs.readFileSync(path.join(tmp, 'AGENTS.md'), 'utf8');
  assert.ok(/npm run test/.test(agents), 'expected "npm run test" in commands');
  assert.ok(/npm run build/.test(agents), 'expected "npm run build" in commands');
});

check('AC-T3-006: repo-bare fixture omits stack section (no fabricated stack)', () => {
  const tmp = cloneFixture(BARE_FIXTURE, 'ac006-bare');
  runNoninteractive(tmp);
  const agents = fs.readFileSync(path.join(tmp, 'AGENTS.md'), 'utf8');
  assert.ok(!/## Stack/.test(agents), 'Stack section must be absent for bare repo (no detection)');
});

// --- AC-T3-004: noninteractive mode with all flags --------------------------

process.stdout.write('Suite: AC-T3-004 noninteractive zero prompts\n');

check('AC-T3-004: noninteractive generates AGENTS.md with zero [prompt] lines', () => {
  const tmp = mkdtempRepo('ac004');
  const r = runNoninteractive(tmp, ['--description', 'Test service.']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  assert.ok(!r.stdout.includes('[prompt]'), `unexpected prompt in stdout:\n${r.stdout}`);
  assert.ok(fs.existsSync(path.join(tmp, 'AGENTS.md')), 'AGENTS.md not created');
});

check('AC-T3-004: noninteractive with all identity + content flags succeeds', () => {
  const tmp = mkdtempRepo('ac004-all');
  const r = runNoninteractive(tmp, [
    '--description', 'Full service.',
    '--repo-role', 'service',
    '--conventions', 'Use conventional commits.',
    '--commands', 'npm test',
    '--related-repos', 'api:https://github.com/org/api:sibling',
    '--scratch-dir', './scratch/',
  ]);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const agents = fs.readFileSync(path.join(tmp, 'AGENTS.md'), 'utf8');
  assert.ok(/Full service\./.test(agents));
  assert.ok(/Role: service/.test(agents));
  assert.ok(/Use conventional commits\./.test(agents));
  assert.ok(/npm test/.test(agents));
  assert.ok(/`api`/.test(agents) && /sibling/.test(agents));
  assert.ok(/\.\/scratch\//.test(agents));
});

check('AC-T3-004: noninteractive env vars resolve identically to flags', () => {
  const tmp = mkdtempRepo('ac004-env');
  const r = runInit(
    [
      '--noninteractive',
      '--project-dir', tmp,
      '--worktree-root', path.join(tmp, 'wt'),
    ],
    {
      env: {
        INIT_PROJECT_NAME: 'env-svc',
        INIT_PROJECT_GITHUB_OWNER: 'env-org',
        INIT_PROJECT_GITHUB_PROJECT_NUMBER: '5',
        INIT_PROJECT_DESCRIPTION: 'From env.',
      },
    }
  );
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const agents = fs.readFileSync(path.join(tmp, 'AGENTS.md'), 'utf8');
  assert.ok(/From env\./.test(agents));
  assert.ok(/env-org/.test(agents));
});

// --- AC-T3-001: interactive on repo-bare fixture ----------------------------

process.stdout.write('Suite: AC-T3-001 interactive repo-bare\n');

check('AC-T3-001: interactive on repo-bare with operator commands → Identity + Commands + Local Config', () => {
  const tmp = cloneFixture(BARE_FIXTURE, 'ac001');
  // Provide purpose + commands; leave conventions/related blank.
  const r = runInteractive(tmp, [
    'Test bare repo service.',   // Q1 purpose
    '',                           // Q2 conventions (blank → omit)
    'npm test',                   // Q3 commands
    '',                           // Q4 related repos (blank → omit)
    '',                           // Q5 scratch dir (default)
    '',                           // Q6 github owner (default)
    '',                           // Q6 github project number (default)
  ]);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstdout:\n${r.stdout}\nstderr:\n${r.stderr}`);
  const agents = fs.readFileSync(path.join(tmp, 'AGENTS.md'), 'utf8');

  // Repository Identity present.
  assert.ok(/## Repository Identity/.test(agents), 'Repository Identity missing');
  assert.ok(/Test bare repo service\./.test(agents), 'purpose not in output');

  // Commands present (operator-provided).
  assert.ok(/## Build, Test, and Run Commands/.test(agents), 'Commands section missing');
  assert.ok(/npm test/.test(agents), 'operator commands not rendered');

  // Local Configuration Files always present.
  assert.ok(/## Local Configuration Files/.test(agents), 'Local Configuration Files missing');

  // Working Conventions omitted (blank response per AC-T3-002-style rule).
  assert.ok(!/## Working Conventions/.test(agents), 'Working Conventions should be omitted');
});

check('AC-T3-001: interactive prompts produce [prompt] lines on stdout', () => {
  const tmp = cloneFixture(BARE_FIXTURE, 'ac001-prompts');
  const r = runInteractive(tmp, ['', '', '', '', '', '', '']);
  // Every prompt should emit at least one [prompt] line on stdout.
  const promptLines = (r.stdout.match(/^\[prompt\]/gm) || []).length;
  assert.ok(promptLines >= 6, `expected at least 6 [prompt] lines, got ${promptLines}\nstdout:\n${r.stdout}`);
});

// --- AC-T3-002: blank responses → omit empty sections -----------------------

process.stdout.write('Suite: AC-T3-002 blank responses omit empty sections\n');

check('AC-T3-002: all-blank interactive → Identity + Doc + Scratch + Local Config only', () => {
  const tmp = cloneFixture(BARE_FIXTURE, 'ac002');
  const r = runInteractive(tmp, ['', '', '', '', '', '', '']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstdout:\n${r.stdout}\nstderr:\n${r.stderr}`);
  const agents = fs.readFileSync(path.join(tmp, 'AGENTS.md'), 'utf8');

  // Repository Identity: default purpose is "<repo-name>" (no language detected
  // on repo-bare). The section must be present with a non-empty body.
  assert.ok(/## Repository Identity/.test(agents), 'Repository Identity should be present (default purpose)');
  const idSection = agents.match(/## Repository Identity\n\n([\s\S]*?)(?=\n## |$)/);
  assert.ok(idSection && idSection[1].trim().length > 0, 'Repository Identity body should be non-empty');

  // Commands: no operator input + no detected commands on repo-bare → omitted.
  assert.ok(!/## Build, Test, and Run Commands/.test(agents), 'Commands should be omitted (no input, no detection)');

  // Working Conventions: blank → omitted.
  assert.ok(!/## Working Conventions/.test(agents), 'Working Conventions should be omitted');

  // Repository Relationships: blank → omitted (no monorepo boundaries on bare).
  assert.ok(!/## Repository Relationships/.test(agents), 'Relationships should be omitted');

  // Stack: nothing detected → omitted.
  assert.ok(!/## Stack/.test(agents), 'Stack should be omitted');

  // Documentation, Scratch, Local Config: always present (defaults).
  assert.ok(/## Documentation/.test(agents), 'Documentation should be present');
  assert.ok(/## Scratch and Log Directories/.test(agents), 'Scratch should be present');
  assert.ok(/## Local Configuration Files/.test(agents), 'Local Configuration Files should be present');
});

// --- AC-T3-003: preview displayed + confirm/abort ---------------------------

process.stdout.write('Suite: AC-T3-003 preview + confirm\n');

check('AC-T3-003: preview displayed before writing (interactive)', () => {
  const tmp = cloneFixture(BARE_FIXTURE, 'ac003-preview');
  const r = runInteractive(tmp, ['', '', '', '', '', '', '']);
  assert.strictEqual(r.status, 0);
  assert.ok(/--- AGENTS\.md preview ---/.test(r.stdout), 'preview header missing');
  assert.ok(/--- end preview ---/.test(r.stdout), 'preview footer missing');
  // The preview must include the generation comment.
  const previewBlock = r.stdout.split('--- AGENTS.md preview ---')[1];
  assert.ok(previewBlock, 'preview block missing');
  assert.ok(/Generated by init-project/.test(previewBlock), 'preview must contain generation comment');
});

check('AC-T3-003: operator declines → AGENTS.md NOT written', () => {
  const tmp = cloneFixture(BARE_FIXTURE, 'ac003-decline');
  const r = runInteractive(tmp, ['', '', '', '', '', '', ''], { confirm: 'n' });
  assert.strictEqual(r.status, 0);
  assert.ok(/Operator declined/.test(r.stdout), 'expected decline message');
  assert.ok(!fs.existsSync(path.join(tmp, 'AGENTS.md')), 'AGENTS.md must NOT be written after decline');
});

check('AC-T3-003: confirm "Y" (uppercase) writes file', () => {
  const tmp = cloneFixture(BARE_FIXTURE, 'ac003-upper');
  const r = runInteractive(tmp, ['', '', '', '', '', '', ''], { confirm: 'Y' });
  assert.strictEqual(r.status, 0);
  assert.ok(fs.existsSync(path.join(tmp, 'AGENTS.md')), 'AGENTS.md should be written after Y');
});

check('AC-T3-003: confirm blank (default = y) writes file', () => {
  const tmp = cloneFixture(BARE_FIXTURE, 'ac003-default');
  // Use a custom confirm that's just a newline (empty response → default y).
  const r = runInteractive(tmp, ['', '', '', '', '', '', ''], { confirm: '' });
  assert.strictEqual(r.status, 0);
  assert.ok(fs.existsSync(path.join(tmp, 'AGENTS.md')), 'AGENTS.md should be written after blank (= default y)');
});

// --- AC-T3-007: pre-existing AGENTS.md handling -----------------------------

process.stdout.write('Suite: AC-T3-007 pre-existing AGENTS.md\n');

check('AC-T3-007: noninteractive without --force skips existing AGENTS.md', () => {
  const tmp = mkdtempRepo('ac007-skip');
  fs.writeFileSync(path.join(tmp, 'AGENTS.md'), '# Pre-existing\n\nHand-written content.\n');
  const r = runNoninteractive(tmp);
  assert.strictEqual(r.status, 0);
  // Output should indicate skip.
  assert.ok(/skipped/i.test(r.stdout), `expected skip message:\n${r.stdout}`);
  // Content preserved.
  const after = fs.readFileSync(path.join(tmp, 'AGENTS.md'), 'utf8');
  assert.strictEqual(after, '# Pre-existing\n\nHand-written content.\n');
  // No backup created.
  const backups = fs.readdirSync(tmp).filter((n) => n.startsWith('AGENTS.md.bak'));
  assert.strictEqual(backups.length, 0, `unexpected backups: ${backups}`);
});

check('AC-T3-007: --force creates .bak.<ts> backup and overwrites', () => {
  const tmp = mkdtempRepo('ac007-force');
  fs.writeFileSync(path.join(tmp, 'AGENTS.md'), 'hand-written');
  const r = runNoninteractive(tmp, ['--force']);
  assert.strictEqual(r.status, 0);
  // Backup created with timestamp pattern.
  const backups = fs.readdirSync(tmp).filter((n) => /^AGENTS\.md\.bak\.\d{8}T\d{6}Z$/.test(n));
  assert.strictEqual(backups.length, 1, `expected 1 backup, got ${backups}`);
  // Backup preserves original content.
  assert.strictEqual(fs.readFileSync(path.join(tmp, backups[0]), 'utf8'), 'hand-written');
  // AGENTS.md overwritten with generated content.
  const after = fs.readFileSync(path.join(tmp, 'AGENTS.md'), 'utf8');
  assert.ok(/^<!-- Generated by init-project/.test(after), 'should start with generation comment');
  assert.notStrictEqual(after, 'hand-written');
  // Console mentions backup.
  assert.ok(/backup of previous AGENTS\.md/.test(r.stdout), `expected backup mention:\n${r.stdout}`);
});

check('AC-T3-007: interactive asks when AGENTS.md exists; skip preserves file', () => {
  const tmp = cloneFixture(BARE_FIXTURE, 'ac007-int-skip');
  fs.writeFileSync(path.join(tmp, 'AGENTS.md'), 'pre-existing\n');
  // After the 6 interactive prompts, the existing-file prompt asks for o/m/s.
  // We send "s" to skip, then the confirm is irrelevant (skipped before preview).
  const r = runInit(
    ['--interactive', '--project-dir', tmp, '--worktree-root', path.join(tmp, 'wt')],
    {
      input: [
        '', '', '', '', '', '', '',  // 7 prompt responses (defaults)
        's',                           // existing-file action: skip
      ].join('\n') + '\n',
    }
  );
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstdout:\n${r.stdout}\nstderr:\n${r.stderr}`);
  // File preserved.
  const after = fs.readFileSync(path.join(tmp, 'AGENTS.md'), 'utf8');
  assert.strictEqual(after, 'pre-existing\n');
  // No backup.
  const backups = fs.readdirSync(tmp).filter((n) => n.startsWith('AGENTS.md.bak'));
  assert.strictEqual(backups.length, 0);
});

check('AC-T3-007: interactive asks when AGENTS.md exists; overwrite creates backup', () => {
  const tmp = cloneFixture(BARE_FIXTURE, 'ac007-int-ow');
  fs.writeFileSync(path.join(tmp, 'AGENTS.md'), 'pre-existing\n');
  const r = runInit(
    ['--interactive', '--project-dir', tmp, '--worktree-root', path.join(tmp, 'wt')],
    {
      input: [
        '', '', '', '', '', '', '',  // 7 prompt responses (defaults)
        'o',                           // existing-file action: overwrite
        'y',                           // confirm write
      ].join('\n') + '\n',
    }
  );
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstdout:\n${r.stdout}`);
  // Backup created.
  const backups = fs.readdirSync(tmp).filter((n) => /^AGENTS\.md\.bak\.\d{8}T\d{6}Z$/.test(n));
  assert.strictEqual(backups.length, 1, `expected 1 backup, got ${backups}`);
  // AGENTS.md overwritten.
  const after = fs.readFileSync(path.join(tmp, 'AGENTS.md'), 'utf8');
  assert.ok(/^<!-- Generated by init-project/.test(after));
});

// --- AC-T3-008: --force --merge appends new sections ------------------------

process.stdout.write('Suite: AC-T3-008 --force --merge\n');

check('AC-T3-008: --force --merge preserves existing sections + appends new ones', () => {
  const tmp = mkdtempRepo('ac008-merge');
  // Pre-existing AGENTS.md with a custom section + a section that the
  // generator would also produce (Repository Identity).
  fs.writeFileSync(
    path.join(tmp, 'AGENTS.md'),
    [
      '<!-- Generated by init-project v0.1.0 on 2020-01-01T00:00:00Z — edit freely -->',
      '',
      '## Repository Identity',
      '',
      'Custom hand-written identity.',
      '',
      '## Custom Operator Section',
      '',
      'This section must survive the merge.',
      '',
    ].join('\n') + '\n'
  );
  const r = runNoninteractive(tmp, ['--force', '--merge', '--description', 'New generated purpose.']);
  assert.strictEqual(r.status, 0, `exit ${r.status}\nstderr:\n${r.stderr}`);
  const after = fs.readFileSync(path.join(tmp, 'AGENTS.md'), 'utf8');

  // Backup created.
  const backups = fs.readdirSync(tmp).filter((n) => /^AGENTS\.md\.bak\./.test(n));
  assert.strictEqual(backups.length, 1, `expected backup, got ${backups}`);

  // Custom section preserved verbatim (FR-5.5: existing content preserved).
  assert.ok(/## Custom Operator Section/.test(after), 'custom section should be preserved');
  assert.ok(/This section must survive the merge\./.test(after), 'custom section body should be preserved');

  // Existing Repository Identity section preserved (not overwritten by merge).
  const idMatches = after.match(/## Repository Identity[\s\S]*?(?=\n## |$)/g) || [];
  assert.strictEqual(idMatches.length, 1, `expected exactly 1 Repository Identity section, got ${idMatches.length}`);
  assert.ok(/Custom hand-written identity\./.test(after), 'existing identity content must be preserved');
  // The new generator's purpose must NOT replace the existing identity body.
  assert.ok(!/New generated purpose\./.test(after), 'merge must not overwrite existing section body');

  // New sections that didn't exist in the original are appended.
  assert.ok(/## Documentation/.test(after), 'new Documentation section should be appended');
  assert.ok(/## Scratch and Log Directories/.test(after), 'new Scratch section should be appended');
  assert.ok(/## Local Configuration Files/.test(after), 'new Local Configuration Files should be appended');

  // Line 1 is the new generation comment (refreshed by merge).
  const line1 = after.split('\n')[0];
  assert.ok(/^<!-- Generated by init-project v0\.3\.0 on/.test(line1), 'line 1 should be refreshed generation comment');
});

check('AC-T3-008: --force --merge does not duplicate sections already present', () => {
  const tmp = mkdtempRepo('ac008-nodup');
  fs.writeFileSync(
    path.join(tmp, 'AGENTS.md'),
    [
      '<!-- Generated by init-project v0.1.0 on 2020-01-01T00:00:00Z — edit freely -->',
      '',
      '## Documentation',
      '',
      'Existing docs section.',
      '',
      '## Local Configuration Files',
      '',
      '- `AGENTS.md` — pre-existing',
      '',
    ].join('\n') + '\n'
  );
  const r = runNoninteractive(tmp, ['--force', '--merge']);
  assert.strictEqual(r.status, 0);
  const after = fs.readFileSync(path.join(tmp, 'AGENTS.md'), 'utf8');
  // Each section appears exactly once.
  const docMatches = after.match(/^## Documentation$/gm) || [];
  assert.strictEqual(docMatches.length, 1, `Documentation should appear once, got ${docMatches.length}`);
  const lcfMatches = after.match(/^## Local Configuration Files$/gm) || [];
  assert.strictEqual(lcfMatches.length, 1, `Local Configuration Files should appear once, got ${lcfMatches.length}`);
  // Existing bodies preserved.
  assert.ok(/Existing docs section\./.test(after), 'existing docs body should be preserved');
  assert.ok(/pre-existing/.test(after), 'existing local config body should be preserved');
});

// --- Regression: existing fixture compatibility ------------------------------

process.stdout.write('Suite: fixture regressions\n');

check('regression: repo-node-npm fixture produces stack + commands sections', () => {
  const tmp = cloneFixture(NODE_FIXTURE, 'reg-node');
  const r = runNoninteractive(tmp);
  assert.strictEqual(r.status, 0);
  const agents = fs.readFileSync(path.join(tmp, 'AGENTS.md'), 'utf8');
  assert.ok(/## Stack/.test(agents), 'Stack section expected for node-npm');
  assert.ok(/Node\.js/.test(agents));
  assert.ok(/npm/.test(agents));
  assert.ok(/## Build, Test, and Run Commands/.test(agents));
});

check('regression: agent.md (legacy) is never deleted by AGENTS.md generation', () => {
  const tmp = cloneFixture(BARE_FIXTURE, 'reg-agent-md');
  // Plant a legacy agent.md (lowercase) to verify coexistence (FR-6.1 / AC-SPEC-011).
  fs.writeFileSync(path.join(tmp, 'agent.md'), '# Legacy agent.md\n\nMust survive.\n');
  const r = runNoninteractive(tmp);
  assert.strictEqual(r.status, 0);
  // agent.md must survive.
  assert.ok(fs.existsSync(path.join(tmp, 'agent.md')), 'agent.md must not be deleted');
  assert.strictEqual(fs.readFileSync(path.join(tmp, 'agent.md'), 'utf8'), '# Legacy agent.md\n\nMust survive.\n');
  // AGENTS.md created alongside.
  assert.ok(fs.existsSync(path.join(tmp, 'AGENTS.md')), 'AGENTS.md should be created');
});

// --- Summary ----------------------------------------------------------------

process.stdout.write(`\n${pass} passed, ${fail} failed\n`);
if (fail > 0) {
  process.stderr.write('\nFailures:\n');
  for (const f of failures) {
    process.stderr.write(`  - ${f.name}: ${f.message}\n`);
  }
  process.exit(1);
}
process.exit(0);
