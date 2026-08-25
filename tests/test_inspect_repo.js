#!/usr/bin/env node
'use strict';

/*
 * tests/test_inspect_repo.js — SPEC-001-T1 unit tests.
 *
 * Runs `templates/scripts/init-project/inspect_repo.js` (the engine support
 * asset since the 2026-08 tooling-path migration) against
 * every fixture under tests/fixtures/ and compares the JSON evidence record
 * against the canonical expected record under tests/expected/.
 *
 * Comparison rules (TEST-1.3):
 *   - `observed` fields are compared with deep equality.
 *   - `inferred` fields are validated for presence and array shape, not exact
 *     content (heuristic derivations may evolve without breaking tests).
 *   - `ambiguities` are compared by length and by sorted `category` list, so
 *     reworded messages do not break tests but missing or extra categories do.
 *
 * The runner also exercises:
 *   - AC-T1-006: traversal must skip node_modules, .git, target, build, dist,
 *     __pycache__.
 *   - AC-T1-002: bare repo (TEST-1.2: README.md + docs/ + .git/) reports
 *     docs_root detected and every other absent category as "not detected" /
 *     empty / false with no stderr.
 *   - Error path: a non-existent --project-dir must exit 1 with stderr.
 *
 * No external npm dependencies. Uses only node:child_process, node:fs,
 * node:path, node:assert.
 */

const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const assert = require('assert');

const REPO_ROOT = path.resolve(__dirname, '..');
const SCRIPT = path.join(
  REPO_ROOT,
  'templates/scripts/init-project/inspect_repo.js'
);
const FIXTURES_DIR = path.join(REPO_ROOT, 'tests', 'fixtures');
const EXPECTED_DIR = path.join(REPO_ROOT, 'tests', 'expected');

const FIXTURES = [
  'repo-node-npm',
  'repo-go',
  'repo-monorepo',
  'repo-bare',
  'repo-legacy-init',
  'repo-multi-pm',
];

const SKIP_DIRS = ['node_modules', '.git', 'target', 'build', 'dist', '__pycache__'];

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

function runInspect(fixtureDir, opts = {}) {
  const stdio = ['ignore', 'pipe', 'pipe'];
  const result = { stdout: '', stderr: '', status: 0, error: null };
  try {
    result.stdout = execFileSync('node', [SCRIPT, '--project-dir', fixtureDir], {
      encoding: 'utf8',
      stdio,
    });
  } catch (err) {
    result.status = err.status ?? 1;
    result.stdout = err.stdout ? err.stdout.toString('utf8') : '';
    result.stderr = err.stderr ? err.stderr.toString('utf8') : '';
    result.error = err;
  }
  if (opts.expectSuccess !== false && result.status === 0 && result.stderr === '') {
    // pass
  }
  return result;
}

function runInspectJson(fixtureDir) {
  const { stdout, stderr, status } = runInspect(fixtureDir);
  assert.strictEqual(status, 0, `inspect exited non-zero for ${fixtureDir}`);
  assert.strictEqual(stderr, '', `unexpected stderr for ${fixtureDir}: ${stderr}`);
  assert.ok(stdout.trim().length > 0, `empty stdout for ${fixtureDir}`);
  return JSON.parse(stdout);
}

function deepStrictEqualActualVsExpected(actual, expected, label) {
  assert.deepStrictEqual(
    actual,
    expected,
    `${label}: observed mismatch.\n  actual:   ${JSON.stringify(actual)}\n  expected: ${JSON.stringify(expected)}`
  );
}

// --- Pre-flight: every fixture has an expected record ------------------------

function testExpectedRecordsExist() {
  process.stdout.write('Suite: expected records present\n');
  for (const fx of FIXTURES) {
    check(`${fx}: expected record exists`, () => {
      const p = path.join(EXPECTED_DIR, `${fx}.json`);
      assert.ok(fs.existsSync(p), `missing expected record: ${p}`);
      JSON.parse(fs.readFileSync(p, 'utf8')); // must be valid JSON
    });
  }
}

// --- Per-fixture: observed fields match expected exactly ---------------------

function testFixtureObservedFields() {
  process.stdout.write('Suite: observed fields match expected records\n');
  for (const fx of FIXTURES) {
    process.stdout.write(`  Fixture: ${fx}\n`);
    const fixtureDir = path.join(FIXTURES_DIR, fx);
    const expected = JSON.parse(
      fs.readFileSync(path.join(EXPECTED_DIR, `${fx}.json`), 'utf8')
    );

    let actual;
    check(`${fx}: inspect runs cleanly`, () => {
      actual = runInspectJson(fixtureDir);
    });
    if (!actual) continue;

    for (const category of Object.keys(expected)) {
      if (category === 'ambiguities') continue;
      const expectedEntry = expected[category] || {};
      const actualEntry = actual[category] || {};
      check(`${fx}: ${category}.observed`, () => {
        assert.ok(
          'observed' in actualEntry,
          `${fx}.${category} missing observed field`
        );
        deepStrictEqualActualVsExpected(
          actualEntry.observed,
          expectedEntry.observed,
          `${fx}.${category}.observed`
        );
      });
      check(`${fx}: ${category}.evidence`, () => {
        // evidence order is not load-bearing for downstream consumers; sort
        // both sides before comparing so additions do not churn tests.
        const a = (actualEntry.evidence || []).slice().sort();
        const e = (expectedEntry.evidence || []).slice().sort();
        deepStrictEqualActualVsExpected(a, e, `${fx}.${category}.evidence`);
      });
      if ('inferred' in expectedEntry) {
        check(`${fx}: ${category}.inferred present + array`, () => {
          assert.ok(
            'inferred' in actualEntry,
            `${fx}.${category} missing inferred field`
          );
          assert.ok(
            Array.isArray(actualEntry.inferred),
            `${fx}.${category}.inferred must be an array`
          );
        });
      }
    }
  }
}

// --- Ambiguity comparison (length + categories) ------------------------------

function testAmbiguities() {
  process.stdout.write('Suite: ambiguities\n');
  for (const fx of FIXTURES) {
    const expected = JSON.parse(
      fs.readFileSync(path.join(EXPECTED_DIR, `${fx}.json`), 'utf8')
    );
    const actual = runInspectJson(path.join(FIXTURES_DIR, fx));
    check(`${fx}: ambiguity count matches`, () => {
      assert.strictEqual(
        actual.ambiguities.length,
        expected.ambiguities.length,
        `${fx}: expected ${expected.ambiguities.length} ambiguities, got ${actual.ambiguities.length}`
      );
    });
    check(`${fx}: ambiguity categories match`, () => {
      const a = actual.ambiguities.map((x) => x.category).sort();
      const e = expected.ambiguities.map((x) => x.category).sort();
      assert.deepStrictEqual(
        a,
        e,
        `${fx}: ambiguity categories mismatch.\n  actual:   ${JSON.stringify(a)}\n  expected: ${JSON.stringify(e)}`
      );
    });
    for (const amb of actual.ambiguities) {
      check(`${fx}: ambiguity[${amb.category}] has signals + message`, () => {
        assert.ok(Array.isArray(amb.signals) && amb.signals.length > 0, `${fx}: ambiguity ${amb.category} missing signals`);
        assert.ok(typeof amb.message === 'string' && amb.message.length > 0, `${fx}: ambiguity ${amb.category} missing message`);
      });
    }
  }
}

// --- AC-T1-001: node-npm satisfies the headline checks -----------------------

function testAcT1001NodeNpm() {
  process.stdout.write('Suite: AC-T1-001 (repo-node-npm headline)\n');
  const actual = runInspectJson(path.join(FIXTURES_DIR, 'repo-node-npm'));
  check('AC-T1-001: language includes Node.js', () => {
    assert.ok(
      Array.isArray(actual.language.observed)
        ? actual.language.observed.includes('Node.js')
        : actual.language.observed === 'Node.js',
      `language.observed=${JSON.stringify(actual.language.observed)}`
    );
  });
  check('AC-T1-001: package_manager includes npm', () => {
    const pm = actual.package_manager.observed;
    assert.ok(
      Array.isArray(pm) ? pm.includes('npm') : pm === 'npm',
      `package_manager.observed=${JSON.stringify(pm)}`
    );
  });
  check('AC-T1-001: docs_root includes docs', () => {
    const dr = actual.docs_root.observed;
    assert.ok(
      Array.isArray(dr) ? dr.includes('docs') : dr === 'docs',
      `docs_root.observed=${JSON.stringify(dr)}`
    );
  });
  check('AC-T1-001: test_infrastructure includes vitest', () => {
    assert.ok(
      actual.test_infrastructure.observed.includes('vitest'),
      `test_infrastructure.observed=${JSON.stringify(actual.test_infrastructure.observed)}`
    );
  });
}

// --- AC-T1-002: bare repo, all other absent categories "not detected" --------
// Per canonical SPEC-001 TEST-1.2, repo-bare contains README.md, docs/, and
// .git/. docs_root is therefore detected; all other absent categories must
// still be "not detected" / empty / false. See issue #2 comment for the
// minimal AC-T1-002 wording reconciliation.

function testAcT1002BareRepo() {
  process.stdout.write('Suite: AC-T1-002 (repo-bare absent categories not detected)\n');
  const fixtureDir = path.join(FIXTURES_DIR, 'repo-bare');
  const result = runInspect(fixtureDir);
  check('AC-T1-002: exit status 0', () => {
    assert.strictEqual(result.status, 0, `status=${result.status}`);
  });
  check('AC-T1-002: stderr empty', () => {
    assert.strictEqual(result.stderr, '', `stderr=${result.stderr}`);
  });
  const actual = JSON.parse(result.stdout);
  check('AC-T1-002: docs_root.observed == ["docs"] (TEST-1.2 fixture)', () => {
    assert.deepStrictEqual(
      actual.docs_root.observed,
      ['docs'],
      `docs_root.observed=${JSON.stringify(actual.docs_root.observed)}`
    );
  });
  const emptyCategories = [
    'language',
    'package_manager',
    'repo_origin',
  ];
  for (const c of emptyCategories) {
    check(`AC-T1-002: ${c}.observed == "not detected"`, () => {
      assert.strictEqual(actual[c].observed, 'not detected', `${c}.observed=${JSON.stringify(actual[c].observed)}`);
    });
  }
  const listCategories = ['agent_guidance', 'test_infrastructure', 'cicd', 'opencode_config', 'app_boundaries'];
  for (const c of listCategories) {
    check(`AC-T1-002: ${c}.observed empty`, () => {
      assert.deepStrictEqual(actual[c].observed, [], `${c}.observed=${JSON.stringify(actual[c].observed)}`);
    });
  }
  check('AC-T1-002: github_project_env.observed false', () => {
    assert.strictEqual(actual.github_project_env.observed, false);
  });
  check('AC-T1-002: ambiguities empty', () => {
    assert.deepStrictEqual(actual.ambiguities, []);
  });
}

// --- AC-T1-003: multi-pm reports ambiguity -----------------------------------

function testAcT1003MultiPm() {
  process.stdout.write('Suite: AC-T1-003 (repo-multi-pm ambiguity)\n');
  const actual = runInspectJson(path.join(FIXTURES_DIR, 'repo-multi-pm'));
  check('AC-T1-003: ambiguities array non-empty', () => {
    assert.ok(actual.ambiguities.length >= 1, 'expected at least one ambiguity');
  });
  check('AC-T1-003: language ambiguity present', () => {
    assert.ok(
      actual.ambiguities.some((a) => a.category === 'language'),
      'no language ambiguity in ' + JSON.stringify(actual.ambiguities)
    );
  });
  check('AC-T1-003: language signals reference go.mod + package.json', () => {
    const amb = actual.ambiguities.find((a) => a.category === 'language');
    assert.ok(amb.signals.includes('go.mod'));
    assert.ok(amb.signals.includes('package.json'));
  });
}

// --- AC-T1-004: legacy-init detection ----------------------------------------

function testAcT1004LegacyInit() {
  process.stdout.write('Suite: AC-T1-004 (repo-legacy-init detection)\n');
  const actual = runInspectJson(path.join(FIXTURES_DIR, 'repo-legacy-init'));
  check('AC-T1-004: .github-project.env not detected (no env file)', () => {
    assert.strictEqual(actual.github_project_env.observed, false);
  });
  check('AC-T1-004: .opencode/opencode.json detected', () => {
    assert.ok(
      actual.opencode_config.observed.includes('.opencode/opencode.json'),
      `opencode_config=${JSON.stringify(actual.opencode_config.observed)}`
    );
  });
}

// --- AC-T1-006: skip directories are not traversed ---------------------------

function testAcT1006SkipDirs() {
  process.stdout.write('Suite: AC-T1-006 (skip-dir traversal)\n');
  // Build a throwaway fixture that contains node_modules, .git, target, build,
  // dist, __pycache__ as top-level dirs, each with a manifest that would be
  // picked up if traversal ignored the skip rule. Assert that none of those
  // manifests appear in app_boundaries.
  const tmpRoot = fs.mkdtempSync(path.join(require('os').tmpdir(), 'inspect-skip-'));
  try {
    fs.mkdirSync(path.join(tmpRoot, 'src'), { recursive: true });
    for (const d of SKIP_DIRS) {
      const dir = path.join(tmpRoot, d);
      fs.mkdirSync(dir, { recursive: true });
      // Plant a fake package.json inside each skip dir.
      fs.writeFileSync(
        path.join(dir, 'package.json'),
        JSON.stringify({ name: `fake-${d}` })
      );
    }
    // Plant a real root manifest so the inspect call is meaningful.
    fs.writeFileSync(
      path.join(tmpRoot, 'package.json'),
      JSON.stringify({ name: 'skip-dir-root' })
    );

    const actual = runInspectJson(tmpRoot);
    check('AC-T1-006: app_boundaries exclude skip dirs', () => {
      const paths = actual.app_boundaries.observed.map((b) => b.path);
      for (const d of SKIP_DIRS) {
        assert.ok(
          !paths.includes(d),
          `skip dir ${d} should not appear in app_boundaries; got ${JSON.stringify(paths)}`
        );
      }
    });
    check('AC-T1-006: language observed does not leak from skip dirs', () => {
      // Root manifest is Node.js; nothing else should bump the count.
      const langs = actual.language.observed;
      assert.ok(
        Array.isArray(langs) && langs.length === 1 && langs[0] === 'Node.js',
        `language.observed=${JSON.stringify(langs)}`
      );
    });
  } finally {
    fs.rmSync(tmpRoot, { recursive: true, force: true });
  }
}

// --- Error path: missing project dir exits 1 ---------------------------------

function testErrorPath() {
  process.stdout.write('Suite: error handling\n');
  check('missing --project-dir exits 1 with stderr', () => {
    const result = runInspect('/this/path/does/not/exist/xyz', { expectSuccess: false });
    assert.notStrictEqual(result.status, 0, `status=${result.status}`);
    assert.ok(result.stderr.length > 0, 'expected non-empty stderr');
  });
  check('missing flag exits 1', () => {
    let status = 0;
    let stderr = '';
    try {
      execFileSync('node', [SCRIPT], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
    } catch (err) {
      status = err.status ?? 1;
      stderr = err.stderr ? err.stderr.toString('utf8') : '';
    }
    assert.notStrictEqual(status, 0);
    assert.ok(stderr.length > 0);
  });
}

// --- Valid JSON to stdout, errors to stderr ----------------------------------

function testStreams() {
  process.stdout.write('Suite: stdout/stderr contract\n');
  const result = runInspect(path.join(FIXTURES_DIR, 'repo-node-npm'));
  check('stdout is valid JSON', () => {
    JSON.parse(result.stdout);
  });
  check('stderr is empty on success', () => {
    assert.strictEqual(result.stderr, '');
  });
}

// --- Runner ------------------------------------------------------------------

function main() {
  if (!fs.existsSync(SCRIPT)) {
    process.stderr.write(`[error] inspect_repo.js not found at ${SCRIPT}\n`);
    process.exit(1);
  }

  testExpectedRecordsExist();
  testFixtureObservedFields();
  testAmbiguities();
  testAcT1001NodeNpm();
  testAcT1002BareRepo();
  testAcT1003MultiPm();
  testAcT1004LegacyInit();
  testAcT1006SkipDirs();
  testErrorPath();
  testStreams();

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
