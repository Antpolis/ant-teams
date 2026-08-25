#!/usr/bin/env node
'use strict';

/*
 * tests/test_skills_copy.js — SPEC-001-T4 unit tests.
 *
 * Drives `templates/scripts/init-project.sh` (the engine since the 2026-08
 * tooling-path migration) against throwaway target project directories and
 * asserts the FR-7 / AC-T4 contract:
 *
 *   - AC-T4-001: github-issues-projects-cli/scripts/gh_project_helper.sh
 *                exists with execute permission.
 *   - AC-T4-002: do-task/scripts/create_task_worktree.sh and
 *                cleanup_task_worktree.sh exist WITH execute permission.
 *   - AC-T4-003: the retired project-initialization skill is NOT copied
 *                (the engine lives at $ANT_TEAM_SCRIPTS/init-project.sh and
 *                is not re-installed into targets).
 *   - AC-T4-004: skill-creator/, webapp-testing/, doc-coauthoring/,
 *                frontend-design/ are NOT copied.
 *   - AC-T4-005: a project-customized SKILL.md is preserved verbatim
 *                (merge, not overwrite).
 *   - AC-T4-006: .opencode/.gitignore exists with a node_modules entry.
 *
 * Plus idempotency (TR-2.1) and ARCH-003 guarantee 4 / SEC-3.2: every shell
 * script under `.opencode/skills/<skill>/scripts/` carries the execute bit at
 * source AND at target after init. The positive iteration over every copied
 * `.sh` is what reconciles the reviewer finding on PR #13 — equality-only
 * checks against an already-executable script could not detect the original
 * failure mode (do-task scripts landing at mode 664 from a non-executable
 * source).
 *
 * Tests use the real source skill tree from templates/opencode/skills/
 * (resolved by the engine as the sibling skills root of a source-checkout
 * run) so the assertion reflects what production init would actually emit.
 * No external npm dependencies.
 */

const { execFileSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const assert = require('assert');

const REPO_ROOT = path.resolve(__dirname, '..');
const INIT_SCRIPT = path.join(
  REPO_ROOT,
  'templates/scripts/init-project.sh'
);
const SOURCE_SKILLS_DIR = path.join(REPO_ROOT, 'templates/opencode/skills');

const REQUIRED_SKILLS = [
  'github-issues-projects-cli',
  'do-task',
];

const EXCLUDED_SKILLS = [
  'skill-creator',
  'webapp-testing',
  'doc-coauthoring',
  'frontend-design',
];

// Every shell script that ARCH-003 (Artifact 3, "Required scripts" table) and
// AC-SPEC-007 require to land in the target's `.opencode/skills/<skill>/scripts/`.
// This is the positive invariant — each entry MUST be executable at source AND
// at target after init (ARCH-003 guarantee 4: "Shell scripts under `scripts/`
// have execute permission").
const REQUIRED_SCRIPT_PATHS = [
  'github-issues-projects-cli/scripts/gh_project_helper.sh',
  'do-task/scripts/create_task_worktree.sh',
  'do-task/scripts/cleanup_task_worktree.sh',
];

// Lists every `.sh` file under `<skillsRoot>/<required-skill>/scripts/`.
// Callers pass the source root (templates/opencode/skills — canonical since
// the 3bb6ec4 restructure) or a target project's .opencode/skills.
// Used for positive exec-bit assertions that iterate over the full set instead
// of cherry-picking one script — this is what catches the original failure
// (do-task scripts landing at mode 664) where the previous equality-only check
// on `gh_project_helper.sh` could not.
function listShellScriptsInRequiredSkillDirs(skillsRoot) {
  const out = [];
  for (const skill of REQUIRED_SKILLS) {
    const scriptsDir = path.join(skillsRoot, skill, 'scripts');
    let entries;
    try {
      entries = fs.readdirSync(scriptsDir, { withFileTypes: true });
    } catch {
      continue;
    }
    for (const e of entries) {
      if (e.isFile() && e.name.endsWith('.sh')) {
        out.push(path.join(scriptsDir, e.name));
      }
    }
  }
  return out.sort();
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
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), `skills-copy-${prefix}-`));
  // init-project.sh expects a git project (used by other steps in the
  // script); a `.git/` directory marker is sufficient for our skills-copy
  // scope. Use a real `git init` so the script does not break on future
  // preflight additions.
  fs.mkdirSync(path.join(dir, '.git'), { recursive: true });
  return dir;
}

function runInit(projectDir) {
  const result = { stdout: '', stderr: '', status: 0 };
  // T2 (issue #3) added noninteractive required-flag accounting (ERR-4.1 /
  // AC-T2-002). This suite exercises the skills-copy code path, not mode
  // detection, so we pass --noninteractive plus the three required identity
  // flags to keep the focus on FR-7 / AC-T4-* behavior. Without these flags
  // the script would now exit 1 with the missing-flag error, masking the
  // real skills-copy assertions.
  try {
    result.stdout = execFileSync(
      'bash',
      [
        INIT_SCRIPT,
        '--project-dir', projectDir,
        '--worktree-root', path.join(projectDir, 'wt'),
        '--noninteractive',
        '--name', 'test',
        '--github-owner', 'antpolis',
        '--github-project-number', '9',
      ],
      { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }
    );
  } catch (err) {
    result.status = err.status ?? 1;
    result.stdout = err.stdout ? err.stdout.toString('utf8') : '';
    result.stderr = err.stderr ? err.stderr.toString('utf8') : '';
  }
  return result;
}

function listFilesRecursive(dir) {
  const out = [];
  const stack = [dir];
  while (stack.length) {
    const cur = stack.pop();
    let entries;
    try {
      entries = fs.readdirSync(cur, { withFileTypes: true });
    } catch {
      continue;
    }
    for (const e of entries) {
      const full = path.join(cur, e.name);
      if (e.isDirectory()) {
        stack.push(full);
      } else if (e.isFile()) {
        out.push(path.relative(dir, full));
      }
    }
  }
  return out.sort();
}

function assertExecutable(p, label) {
  const st = fs.statSync(p);
  const mode = st.mode & 0o111;
  assert.notStrictEqual(mode, 0, `${label}: expected execute bit, got mode ${st.mode.toString(8)}`);
}

// --- Pre-flight: source skills are present in the worktree -------------------

function testSourcePreflight() {
  process.stdout.write('Suite: source preflight\n');
  for (const s of REQUIRED_SKILLS) {
    check(`source skill present: ${s}`, () => {
      assert.ok(fs.existsSync(path.join(SOURCE_SKILLS_DIR, s, 'SKILL.md')), `missing source skill ${s}`);
    });
  }

  // ARCH-003 guarantee 4 / SEC-3.2 source invariant: every required shell
  // script under source `.opencode/skills/<skill>/scripts/` carries the execute bit.
  // `cp -p` only preserves what already exists — if a source script loses its
  // exec bit, every downstream target silently inherits a non-runnable script.
  // Asserting here makes the source the single point of truth for executability
  // and catches regressions before any init runs.
  for (const rel of REQUIRED_SCRIPT_PATHS) {
    check(`source required script is executable: ${rel}`, () => {
      assertExecutable(path.join(SOURCE_SKILLS_DIR, rel), `source ${rel}`);
    });
  }

  // Defensive sweep: walk every `.sh` under source required-skill scripts/
  // dirs (not only the known required paths) so a newly-added shell script
  // cannot silently ship without an execute bit.
  check('source sweep: every .sh under required-skill scripts/ is executable', () => {
    const scripts = listShellScriptsInRequiredSkillDirs(SOURCE_SKILLS_DIR);
    assert.ok(scripts.length >= REQUIRED_SCRIPT_PATHS.length, `unexpected source script count ${scripts.length}`);
    for (const p of scripts) {
      assertExecutable(p, `source sweep ${path.relative(REPO_ROOT, p)}`);
    }
  });
}

// --- AC-T4-001 / AC-T4-002 / AC-T4-003: required scripts exist & executable --

function testRequiredScriptsPresent(projectDir) {
  process.stdout.write('Suite: AC-T4-001/002/003 required scripts exist & executable\n');

  check('AC-T4-001: github-issues-projects-cli/scripts/gh_project_helper.sh exists', () => {
    const p = path.join(projectDir, '.opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh');
    assert.ok(fs.existsSync(p), `missing ${p}`);
  });
  check('AC-T4-001: gh_project_helper.sh has execute permission', () => {
    assertExecutable(
      path.join(projectDir, '.opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh'),
      'AC-T4-001'
    );
  });
  check('AC-T4-001: github-issues-projects-cli/SKILL.md exists', () => {
    assert.ok(
      fs.existsSync(path.join(projectDir, '.opencode/skills/github-issues-projects-cli/SKILL.md')),
      'missing github-issues-projects-cli/SKILL.md'
    );
  });

  check('AC-T4-002: do-task/scripts/create_task_worktree.sh exists', () => {
    assert.ok(
      fs.existsSync(path.join(projectDir, '.opencode/skills/do-task/scripts/create_task_worktree.sh')),
      'missing do-task/scripts/create_task_worktree.sh'
    );
  });
  check('AC-T4-002: create_task_worktree.sh has execute permission', () => {
    assertExecutable(
      path.join(projectDir, '.opencode/skills/do-task/scripts/create_task_worktree.sh'),
      'AC-T4-002 create_task_worktree.sh'
    );
  });
  check('AC-T4-002: do-task/scripts/cleanup_task_worktree.sh exists', () => {
    assert.ok(
      fs.existsSync(path.join(projectDir, '.opencode/skills/do-task/scripts/cleanup_task_worktree.sh')),
      'missing do-task/scripts/cleanup_task_worktree.sh'
    );
  });
  check('AC-T4-002: cleanup_task_worktree.sh has execute permission', () => {
    assertExecutable(
      path.join(projectDir, '.opencode/skills/do-task/scripts/cleanup_task_worktree.sh'),
      'AC-T4-002 cleanup_task_worktree.sh'
    );
  });
}

// --- AC-T4-003: retired project-initialization skill is NOT copied -----------

function testRetiredSkillNotCopied(projectDir) {
  process.stdout.write('Suite: AC-T4-003 retired project-initialization not copied\n');
  check('AC-T4-003: project-initialization/ not copied into targets', () => {
    const p = path.join(projectDir, '.opencode/skills/project-initialization');
    assert.ok(!fs.existsSync(p), `retired skill was copied: ${p}`);
  });
}

// --- AC-T4-004: excluded skills are absent -----------------------------------

function testExcludedSkillsAbsent(projectDir) {
  process.stdout.write('Suite: AC-T4-004 excluded skills absent\n');
  for (const s of EXCLUDED_SKILLS) {
    check(`AC-T4-004: ${s}/ not copied`, () => {
      const p = path.join(projectDir, '.opencode/skills', s);
      assert.ok(!fs.existsSync(p), `excluded skill was copied: ${p}`);
    });
  }
}

// --- AC-T4-005: customized SKILL.md is preserved -----------------------------

function testCustomizedSkillMdPreserved(projectDir) {
  process.stdout.write('Suite: AC-T4-005 customized SKILL.md preserved\n');
  const target = path.join(projectDir, '.opencode/skills/github-issues-projects-cli/SKILL.md');
  const marker = '<!-- project-local customization marker - do not overwrite -->\n';
  const customBody = `${marker}# Custom project-local SKILL.md\n\nEdited by the project operator.\n`;
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, customBody, 'utf8');

  const before = fs.readFileSync(target, 'utf8');
  const beforeMtime = fs.statSync(target).mtimeMs;
  runInit(projectDir);
  const after = fs.readFileSync(target, 'utf8');
  const afterMtime = fs.statSync(target).mtimeMs;

  check('AC-T4-005: customized SKILL.md content preserved verbatim', () => {
    assert.strictEqual(after, before, 'customized SKILL.md was modified by init');
  });
  check('AC-T4-005: customized SKILL.md mtime unchanged', () => {
    assert.strictEqual(afterMtime, beforeMtime, 'customized SKILL.md was rewritten by init');
  });
  check('AC-T4-005: marker line still present', () => {
    assert.ok(after.includes(marker), 'customization marker lost from SKILL.md');
  });
}

// --- AC-T4-006: .opencode/.gitignore with node_modules -----------------------

function testGitignorePresent(projectDir) {
  process.stdout.write('Suite: AC-T4-006 .opencode/.gitignore\n');
  const p = path.join(projectDir, '.opencode/.gitignore');
  check('AC-T4-006: .opencode/.gitignore exists', () => {
    assert.ok(fs.existsSync(p), `missing ${p}`);
  });
  check('AC-T4-006: node_modules entry present', () => {
    const lines = fs.readFileSync(p, 'utf8').split(/\r?\n/);
    assert.ok(lines.includes('node_modules'), `.opencode/.gitignore missing node_modules line; got ${JSON.stringify(lines)}`);
  });
}

// --- AC-T4-006 additivity: existing .gitignore entries preserved -------------

function testGitignorePreservesExistingEntries(projectDir) {
  process.stdout.write('Suite: AC-T4-006 additivity\n');
  const p = path.join(projectDir, '.opencode/.gitignore');
  fs.mkdirSync(path.dirname(p), { recursive: true });
  fs.writeFileSync(p, 'custom-entry\n.env\n', 'utf8');

  runInit(projectDir);
  const lines = fs.readFileSync(p, 'utf8').split(/\r?\n/);
  check('AC-T4-006: pre-existing custom-entry preserved', () => {
    assert.ok(lines.includes('custom-entry'), `custom-entry lost; got ${JSON.stringify(lines)}`);
  });
  check('AC-T4-006: pre-existing .env preserved', () => {
    assert.ok(lines.includes('.env'), `.env lost; got ${JSON.stringify(lines)}`);
  });
  check('AC-T4-006: node_modules appended exactly once', () => {
    const count = lines.filter((l) => l === 'node_modules').length;
    assert.strictEqual(count, 1, `expected exactly one node_modules line; got ${count}`);
  });
}

// --- Idempotency: TR-2.1 — rerun produces no file changes --------------------

function testIdempotency(projectDir) {
  process.stdout.write('Suite: TR-2.1 idempotency\n');
  const before = listFilesRecursive(projectDir);
  const beforeHashes = before.map((rel) => {
    const p = path.join(projectDir, rel);
    const st = fs.statSync(p);
    return { rel, size: st.size, mode: st.mode, mtime: st.mtimeMs };
  });

  runInit(projectDir);

  const after = listFilesRecursive(projectDir);
  check('TR-2.1: file set unchanged after rerun', () => {
    assert.deepStrictEqual(after, before, 'rerun changed file set');
  });
  check('TR-2.1: file sizes / modes unchanged after rerun', () => {
    const afterHashes = after.map((rel) => {
      const p = path.join(projectDir, rel);
      const st = fs.statSync(p);
      return { rel, size: st.size, mode: st.mode };
    });
    const beforeComparable = beforeHashes.map(({ rel, size, mode }) => ({ rel, size, mode }));
    assert.deepStrictEqual(afterHashes, beforeComparable, 'rerun changed file size or mode');
  });
}

// --- ARCH-003 guarantee 4 / SEC-3.2: every copied shell script is executable --

// Reconciles with the reviewer finding on PR #13: the previous test only
// checked that `gh_project_helper.sh` (already 0755 at source) preserved its
// bits, so it could not detect the original failure where `cp -p` faithfully
// copied the do-task scripts at mode 0664 from a non-executable source. This
// suite walks every `.sh` file the init actually emitted into the target's
// required-skill `scripts/` directories and asserts BOTH (a) the execute bit
// is set positively, and (b) the target mode matches the source mode. The
// positive assertion is what catches the original bug; the equality assertion
// keeps SEC-3.2's preservation contract honest.
function testAllCopiedShellScriptsExecutable(projectDir) {
  process.stdout.write('Suite: ARCH-003 g4 / SEC-3.2 every copied .sh is executable\n');

  const targetScripts = listShellScriptsInRequiredSkillDirs(path.join(projectDir, '.opencode/skills'));
  check('init copied at least the required shell scripts', () => {
    const requiredCount = REQUIRED_SCRIPT_PATHS.length;
    assert.ok(
      targetScripts.length >= requiredCount,
      `expected at least ${requiredCount} shell scripts under target required-skill scripts/; got ${targetScripts.length}`
    );
  });

  for (const tgt of targetScripts) {
    const rel = path.relative(path.join(projectDir, '.opencode', 'skills'), tgt);
    check(`target shell script is executable: ${rel}`, () => {
      assertExecutable(tgt, `target ${rel}`);
    });
    const src = path.join(SOURCE_SKILLS_DIR, rel);
    if (fs.existsSync(src)) {
      check(`target execute bits match source: ${rel}`, () => {
        const srcMode = fs.statSync(src).mode & 0o777;
        const tgtMode = fs.statSync(tgt).mode & 0o777;
        assert.strictEqual(
          tgtMode & 0o111,
          srcMode & 0o111,
          `execute bits differ: source=${srcMode.toString(8)} target=${tgtMode.toString(8)}`
        );
      });
    }
  }
}

// --- FR-7.3 merge accounting: pre-existing files counted, not overwritten ----

function testMergeDoesNotOverwriteArbitraryFiles(projectDir) {
  process.stdout.write('Suite: FR-7.3 merge does not overwrite arbitrary files\n');
  const target = path.join(projectDir, '.opencode/skills/do-task/scripts/create_task_worktree.sh');
  fs.mkdirSync(path.dirname(target), { recursive: true });
  const sentinel = '# project-local sentinel — init must not overwrite this file\n';
  fs.writeFileSync(target, sentinel, 'utf8');

  runInit(projectDir);
  check('FR-7.3: pre-existing local script preserved verbatim', () => {
    assert.strictEqual(fs.readFileSync(target, 'utf8'), sentinel, 'init overwrote an existing local script');
  });
}

// --- Console contract: [writing] lines emitted for skills copy --------------

function testConsoleContract() {
  process.stdout.write('Suite: OBS-1 console contract for skills copy\n');
  const dir = mkdtempRepo('console-');
  try {
    const result = runInit(dir);
    check('init exits 0', () => {
      assert.strictEqual(result.status, 0, `status=${result.status} stderr=${result.stderr}`);
    });
    check('console emits at least one [writing] .opencode/skills/ line', () => {
      assert.ok(/\[writing\]\s+\.opencode\/skills\//.test(result.stdout), `expected [writing] line for skills copy; got:\n${result.stdout}`);
    });
    check('console emits skills copy summary line', () => {
      assert.ok(/\.opencode\/skills\/ \(2 required skills, \d+ copied, \d+ merged\)/.test(result.stdout), `expected skills summary; got:\n${result.stdout}`);
    });
    check('console emits [writing] .opencode/.gitignore line', () => {
      assert.ok(/\[writing\]\s+\.opencode\/\.gitignore/.test(result.stdout), `expected gitignore writing line; got:\n${result.stdout}`);
    });
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

// --- Runner ------------------------------------------------------------------

function main() {
  if (!fs.existsSync(INIT_SCRIPT)) {
    process.stderr.write(`[error] init-project.sh not found at ${INIT_SCRIPT}\n`);
    process.exit(1);
  }

  testSourcePreflight();
  testConsoleContract();

  // AC-T4-001/002/003/004/006 + idempotency + SEC-3.2 share one throwaway repo
  // built by a single init run.
  const fresh = mkdtempRepo('fresh-');
  let freshInit;
  try {
    freshInit = runInit(fresh);
    check('fresh project init exits 0', () => {
      assert.strictEqual(freshInit.status, 0, `status=${freshInit.status}\nstdout=${freshInit.stdout}\nstderr=${freshInit.stderr}`);
    });
    if (freshInit.status === 0) {
      testRequiredScriptsPresent(fresh);
      testRetiredSkillNotCopied(fresh);
      testExcludedSkillsAbsent(fresh);
      testGitignorePresent(fresh);
      testAllCopiedShellScriptsExecutable(fresh);
      testIdempotency(fresh);
      testMergeDoesNotOverwriteArbitraryFiles(fresh);
    }
  } finally {
    fs.rmSync(fresh, { recursive: true, force: true });
  }

  // AC-T4-005 customized SKILL.md preservation needs a repo where init has
  // already run, then we plant a customized file, then rerun.
  const custom = mkdtempRepo('custom-');
  try {
    const seeded = runInit(custom);
    check('custom-suite init exits 0', () => {
      assert.strictEqual(seeded.status, 0, `status=${seeded.status}\nstderr=${seeded.stderr}`);
    });
    if (seeded.status === 0) {
      testCustomizedSkillMdPreserved(custom);
    }
  } finally {
    fs.rmSync(custom, { recursive: true, force: true });
  }

  // AC-T4-006 additivity needs an empty target with a pre-existing
  // .opencode/.gitignore containing operator-managed entries.
  const gi = mkdtempRepo('gitignore-');
  try {
    testGitignorePreservesExistingEntries(gi);
  } finally {
    fs.rmSync(gi, { recursive: true, force: true });
  }

  process.stdout.write(`\n${pass} passed, ${fail} failed\n`);
  if (fail > 0) {
    process.stderr.write('\nFailures:\n');
    for (const f of failures) {
      process.stderr.write(`  - ${f.name}: ${f.message}\n`);
    }
    process.exit(1);
  }
  process.exit(0);
}

main();
