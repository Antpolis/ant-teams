#!/usr/bin/env node
'use strict';

/*
 * inspect_repo.js — SPEC-001-T1 repository inspection engine.
 *
 * Inspects a target repository directory and emits a structured JSON evidence
 * record to stdout. Inspection is read-only and side-effect-free.
 *
 * Output schema (FR-2.2):
 *   {
 *     language:               { observed, evidence, inferred },
 *     package_manager:        { observed, evidence, inferred },
 *     docs_root:              { observed, evidence },
 *     agent_guidance:         { observed, evidence },
 *     test_infrastructure:    { observed, evidence },
 *     cicd:                   { observed, evidence },
 *     opencode_config:        { observed, evidence },
 *     github_project_env:      { observed, evidence },
 *     repo_origin:            { observed, evidence },
 *     app_boundaries:         { observed, evidence },
 *     ambiguities:            [ { category, message, signals } ]
 *   }
 *
 * "observed" fields contain direct detection results (files / dirs / git output).
 * "inferred" fields contain heuristically derived facts (e.g. TypeScript from
 * tsconfig.json). "ambiguities" flags contradictory root-level signals so the
 * downstream AGENTS.md generator does not silently pick one.
 *
 * Constraints (per issue #2 tech-lead guardrails):
 *   - Node.js built-ins only (fs, path, child_process). No npm packages.
 *   - Directory traversal must skip node_modules, .git, target, build, dist,
 *     __pycache__ (FR-2 / TR-1.3).
 *   - Both go.mod and package.json at repo root is an ambiguity, NOT a silent
 *     pick of either (FR-2.4).
 */

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const SKIP_DIRS = new Set([
  'node_modules',
  '.git',
  'target',
  'build',
  'dist',
  '__pycache__',
]);

const NOT_DETECTED = 'not detected';

// --- CLI ---------------------------------------------------------------------

function parseArgs(argv) {
  const args = { projectDir: null };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--project-dir') {
      args.projectDir = argv[++i];
    } else if (a.startsWith('--project-dir=')) {
      args.projectDir = a.slice('--project-dir='.length);
    } else if (a === '-h' || a === '--help') {
      process.stdout.write(
        'Usage: inspect_repo.js --project-dir <path>\n' +
          '  Inspects <path> and writes a JSON evidence record to stdout.\n'
      );
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${a}`);
    }
  }
  if (!args.projectDir) {
    throw new Error('Missing required flag: --project-dir <path>');
  }
  return args;
}

// --- FS helpers --------------------------------------------------------------

function safeReadDir(dir) {
  try {
    return fs.readdirSync(dir, { withFileTypes: true });
  } catch (_err) {
    return [];
  }
}

function exists(absPath) {
  try {
    fs.statSync(absPath);
    return true;
  } catch (_err) {
    return false;
  }
}

function isDirectory(entry) {
  return entry.isDirectory();
}

// Top-level entries of the target project, with skip dirs filtered out.
function topEntries(projectDir) {
  return safeReadDir(projectDir).filter((e) => !SKIP_DIRS.has(e.name));
}

// Top-level directory entries of the target project (skip dirs filtered).
function topDirs(projectDir) {
  return topEntries(projectDir).filter(isDirectory);
}

// Read package.json as plain text (caller parses defensively).
function readPackageJson(projectDir) {
  const p = path.join(projectDir, 'package.json');
  if (!exists(p)) return null;
  try {
    return JSON.parse(fs.readFileSync(p, 'utf8'));
  } catch (_err) {
    return null;
  }
}

// --- Detection: language / runtime stack -------------------------------------

const LANG_FILE_SIGNALS = [
  { file: 'package.json', language: 'Node.js' },
  { file: 'go.mod', language: 'Go' },
  { file: 'Cargo.toml', language: 'Rust' },
  { file: 'pyproject.toml', language: 'Python' },
  { file: 'requirements.txt', language: 'Python' },
  { file: 'Pipfile', language: 'Python' },
  { file: 'pom.xml', language: 'Java' },
  { file: 'Gemfile', language: 'Ruby' },
  { file: 'composer.json', language: 'PHP' },
  { file: 'tsconfig.json', language: 'TypeScript' },
];

// `build.gradle*` is a glob; checked separately because fs is literal.
const BUILD_GRADLE_LANG = 'Java';

function detectLanguage(projectDir) {
  const observed = [];
  const evidence = [];
  for (const sig of LANG_FILE_SIGNALS) {
    if (exists(path.join(projectDir, sig.file))) {
      if (!observed.includes(sig.language)) observed.push(sig.language);
      evidence.push(sig.file);
    }
  }
  // build.gradle / build.gradle.kts
  const gradleFiles = safeReadDir(projectDir)
    .filter((e) => e.isFile() && /^build\.gradle(\.kts)?$/.test(e.name))
    .map((e) => e.name);
  if (gradleFiles.length > 0) {
    if (!observed.includes(BUILD_GRADLE_LANG)) observed.push(BUILD_GRADLE_LANG);
    evidence.push(...gradleFiles);
  }

  // tsconfig.json is treated as an inferred TypeScript signal unless it is the
  // only signal (in which case it is the primary language). The "Node.js +
  // TypeScript" pair is common and not contradictory, so we keep Node.js as
  // observed primary and surface TypeScript as inferred when both are present.
  const inferred = [];
  if (
    observed.includes('TypeScript') &&
    (observed.includes('Node.js') || observed.length > 1)
  ) {
    inferred.push('TypeScript');
    const idx = observed.indexOf('TypeScript');
    if (idx >= 0) observed.splice(idx, 1);
    const evIdx = evidence.indexOf('tsconfig.json');
    if (evIdx >= 0) evidence.splice(evIdx, 1);
  }

  return {
    observed: observed.length === 0 ? NOT_DETECTED : observed,
    evidence,
    inferred,
  };
}

// --- Detection: package manager ----------------------------------------------

const PM_FILE_SIGNALS = [
  { file: 'package-lock.json', pm: 'npm' },
  { file: 'pnpm-lock.yaml', pm: 'pnpm' },
  { file: 'yarn.lock', pm: 'yarn' },
  { file: 'Cargo.lock', pm: 'cargo' },
  { file: 'Cargo.toml', pm: 'cargo' },
  { file: 'go.mod', pm: 'go modules' },
  { file: 'go.sum', pm: 'go modules' },
  { file: 'pyproject.toml', pm: 'pip' },
  { file: 'poetry.lock', pm: 'poetry' },
  { file: 'Pipfile.lock', pm: 'pipenv' },
  { file: 'pom.xml', pm: 'maven' },
  { file: 'Gemfile', pm: 'bundler' },
  { file: 'Gemfile.lock', pm: 'bundler' },
  { file: 'composer.json', pm: 'composer' },
  { file: 'composer.lock', pm: 'composer' },
];

function detectPackageManager(projectDir) {
  const observed = [];
  const evidence = [];
  for (const sig of PM_FILE_SIGNALS) {
    if (exists(path.join(projectDir, sig.file))) {
      if (!observed.includes(sig.pm)) observed.push(sig.pm);
      evidence.push(sig.file);
    }
  }
  // build.gradle / build.gradle.kts → gradle
  const gradleFiles = safeReadDir(projectDir)
    .filter((e) => e.isFile() && /^build\.gradle(\.kts)?$/.test(e.name))
    .map((e) => e.name);
  if (gradleFiles.length > 0) {
    if (!observed.includes('gradle')) observed.push('gradle');
    evidence.push(...gradleFiles);
  }

  // package.json without a lockfile implies npm (inferred, not observed).
  const inferred = [];
  if (
    exists(path.join(projectDir, 'package.json')) &&
    !observed.includes('npm')
  ) {
    inferred.push('npm');
  }

  return {
    observed: observed.length === 0 ? NOT_DETECTED : observed,
    evidence,
    inferred,
  };
}

// --- Detection: docs root ----------------------------------------------------

function detectDocsRoot(projectDir) {
  const evidence = [];
  const found = [];
  if (exists(path.join(projectDir, 'docs'))) {
    found.push('docs');
    evidence.push('docs/');
  }
  if (exists(path.join(projectDir, '.docs'))) {
    found.push('.docs');
    evidence.push('.docs/');
  }
  return {
    observed: found.length === 0 ? NOT_DETECTED : found,
    evidence,
  };
}

// --- Detection: existing agent guidance --------------------------------------

const AGENT_GUIDANCE_FILES = [
  'AGENTS.md',
  'agent.md',
  '.cursorrules',
  '.windsurfrules',
  'CLAUDE.md',
  'CODEX.md',
];

function detectAgentGuidance(projectDir) {
  const observed = [];
  for (const f of AGENT_GUIDANCE_FILES) {
    if (exists(path.join(projectDir, f))) observed.push(f);
  }
  return { observed, evidence: observed.slice() };
}

// --- Detection: test infrastructure ------------------------------------------

const TEST_DIR_NAMES = ['test', 'tests', 'spec', '__tests__'];

const TEST_CONFIG_GLOBS = [
  { re: /^vitest\.config\./, framework: 'vitest' },
  { re: /^vitest\.workspace\./, framework: 'vitest' },
  { re: /^jest\.config\./, framework: 'jest' },
  { re: /^mocha\.*/, framework: 'mocha' },
  { re: /^\.mocharc\./, framework: 'mocha' },
  { re: /^pytest\.ini$/, framework: 'pytest' },
  { re: /^conftest\.py$/, framework: 'pytest' },
  { re: /^pyproject\.toml$/, framework: null }, // inspected for [tool.pytest]
  { re: /^tox\.ini$/, framework: 'pytest' },
  { re: /^rspec$/, framework: 'rspec' },
  { re: /^\.rspec$/, framework: 'rspec' },
  { re: /^phpunit\.(xml|dist)$/, framework: 'phpunit' },
  { re: /^pom\.xml$/, framework: null }, // inspected for surefire
];

function detectTestInfrastructure(projectDir) {
  const observed = [];
  const evidence = [];

  // 1. Test directories at the root.
  for (const d of TEST_DIR_NAMES) {
    if (exists(path.join(projectDir, d))) {
      const label = `${d}/`;
      evidence.push(label);
      // Directories alone do not name a framework; record as infra presence.
      if (!observed.includes(d)) observed.push(d);
    }
  }

  // 2. Test framework config files at the root.
  const rootFiles = safeReadDir(projectDir).filter((e) => e.isFile());
  for (const entry of rootFiles) {
    for (const g of TEST_CONFIG_GLOBS) {
      if (g.re.test(entry.name)) {
        evidence.push(entry.name);
        if (g.framework && !observed.includes(g.framework)) {
          observed.push(g.framework);
        }
        break;
      }
    }
  }

  // 3. pyproject.toml [tool.pytest] or [tool.poetry] test deps.
  const pyprojectPath = path.join(projectDir, 'pyproject.toml');
  if (exists(pyprojectPath)) {
    const text = safeReadText(pyprojectPath);
    if (text && /^\[tool\.pytest\b/m.test(text) && !observed.includes('pytest')) {
      observed.push('pytest');
    }
  }

  // 4. package.json scripts.test content.
  const pkg = readPackageJson(projectDir);
  if (pkg && pkg.scripts && typeof pkg.scripts.test === 'string') {
    const testScript = pkg.scripts.test;
    evidence.push('package.json:scripts.test');
    for (const fw of ['vitest', 'jest', 'mocha']) {
      if (testScript.includes(fw) && !observed.includes(fw)) observed.push(fw);
    }
  }

  // 5. Makefile test target.
  const makefilePath = path.join(projectDir, 'Makefile');
  if (exists(makefilePath)) {
    const text = safeReadText(makefilePath);
    if (text && /^test\s*:/m.test(text)) {
      evidence.push('Makefile:test target');
      if (!observed.includes('make-test')) observed.push('make-test');
    }
  }

  return { observed, evidence };
}

function safeReadText(p) {
  try {
    return fs.readFileSync(p, 'utf8');
  } catch (_err) {
    return null;
  }
}

// --- Detection: CI/CD --------------------------------------------------------

const CICD_PATHS = [
  { rel: '.github/workflows', type: 'dir', label: '.github/workflows/' },
  { rel: '.gitlab-ci.yml', type: 'file', label: '.gitlab-ci.yml' },
  { rel: 'Jenkinsfile', type: 'file', label: 'Jenkinsfile' },
  { rel: 'Dockerfile', type: 'file', label: 'Dockerfile' },
];

const CICD_DOCKER_COMPOSE_RE = /^docker-compose(.*)\.ya?ml$/;

function detectCicd(projectDir) {
  const observed = [];
  const evidence = [];
  for (const c of CICD_PATHS) {
    if (exists(path.join(projectDir, c.rel))) {
      observed.push(c.label);
      evidence.push(c.label);
    }
  }
  // docker-compose*.yml at root
  for (const entry of safeReadDir(projectDir)) {
    if (entry.isFile() && CICD_DOCKER_COMPOSE_RE.test(entry.name)) {
      observed.push(entry.name);
      evidence.push(entry.name);
    }
  }
  return { observed, evidence };
}

// --- Detection: opencode config ----------------------------------------------

const OPENCODE_CONFIG_PATHS = [
  '.opencode/opencode.json',
  '.opencode/opencode.jsonc',
  'opencode.jsonc',
];

function detectOpencodeConfig(projectDir) {
  const observed = [];
  for (const p of OPENCODE_CONFIG_PATHS) {
    if (exists(path.join(projectDir, p))) observed.push(p);
  }
  return { observed, evidence: observed.slice() };
}

// --- Detection: .github-project.env -------------------------------------------

function detectGithubProjectEnv(projectDir) {
  const rel = '.github-project.env';
  const found = exists(path.join(projectDir, rel));
  return {
    observed: found,
    evidence: found ? [rel] : [],
  };
}

// --- Detection: repo origin --------------------------------------------------

function detectRepoOrigin(projectDir) {
  // Only treat the target dir as a git repo if it IS the work-tree root.
  // Fixtures under tests/fixtures/ are not independent git repos, so this
  // gracefully reports "not detected" for them without leaking the parent
  // repository's remotes.
  let toplevel;
  try {
    toplevel = execFileSync('git', ['-C', projectDir, 'rev-parse', '--show-toplevel'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
  } catch (_err) {
    return { observed: NOT_DETECTED, evidence: [] };
  }

  const resolvedProject = path.resolve(projectDir);
  if (toplevel !== resolvedProject) {
    return { observed: NOT_DETECTED, evidence: [] };
  }

  let remoteOut;
  try {
    remoteOut = execFileSync('git', ['-C', projectDir, 'remote', '-v'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
  } catch (_err) {
    return { observed: NOT_DETECTED, evidence: [] };
  }

  if (!remoteOut) {
    return { observed: NOT_DETECTED, evidence: [] };
  }

  const remotes = remoteOut
    .split('\n')
    .map((line) => {
      const parts = line.split(/\s+/);
      return { name: parts[0], url: parts[1], type: parts[2] || '' };
    })
    .filter((r) => r.name && r.url);

  const origin = remotes.find((r) => r.name === 'origin') || remotes[0];
  const inferredName = inferRepoName(origin ? origin.url : '');

  return {
    observed: {
      remotes,
      inferred_name: inferredName || '',
    },
    evidence: ['git remote -v'],
  };
}

function inferRepoName(url) {
  if (!url) return '';
  // SSH style: git@github.com:owner/repo.git
  const sshMatch = url.match(/:([^/]+)\/([^/]+?)(?:\.git)?$/);
  if (sshMatch) return sshMatch[2];
  // HTTPS style: https://github.com/owner/repo(.git)
  const httpsMatch = url.match(/\/([^/]+)\/([^/]+?)(?:\.git)?$/);
  if (httpsMatch) return httpsMatch[2];
  return '';
}

// --- Detection: app / service boundaries (monorepo, optional) ---------------

const BOUNDARY_MANIFESTS = ['package.json', 'go.mod', 'Cargo.toml'];
const MONOREPO_LAYOUT_DIRS = new Set(['apps', 'services', 'packages']);

function boundaryAt(projectDir, relDir) {
  // Returns the first manifest found directly inside `relDir`, or null.
  for (const manifest of BOUNDARY_MANIFESTS) {
    const rel = path.join(relDir, manifest);
    if (exists(path.join(projectDir, rel))) {
      return { manifest, rel };
    }
  }
  return null;
}

function detectAppBoundaries(projectDir) {
  const observed = [];
  const evidence = [];

  const seenPaths = new Set();
  const addBoundary = (b) => {
    if (seenPaths.has(b.path)) return;
    seenPaths.add(b.path);
    observed.push(b);
    evidence.push(b.manifest);
  };

  for (const dir of topDirs(projectDir)) {
    // Conventional monorepo layout dirs: each immediate child is a workspace.
    if (MONOREPO_LAYOUT_DIRS.has(dir.name)) {
      for (const child of safeReadDir(path.join(projectDir, dir.name))) {
        if (SKIP_DIRS.has(child.name) || !isDirectory(child)) continue;
        const hit = boundaryAt(projectDir, path.join(dir.name, child.name));
        if (hit) {
          addBoundary({
            path: path.join(dir.name, child.name),
            manifest: hit.rel,
          });
        }
      }
      continue;
    }

    // Top-level dir with its own manifest (one level deep).
    const hit = boundaryAt(projectDir, dir.name);
    if (hit) {
      addBoundary({ path: dir.name, manifest: hit.rel });
    }
  }

  return { observed, evidence };
}

// --- Ambiguity detection -----------------------------------------------------

function detectAmbiguities(projectDir, languageResult, packageManagerResult) {
  const ambiguities = [];

  // Root-level coexistence of go.mod and package.json (without a clear monorepo
  // layout) is the canonical ambiguity called out in FR-2.4. Monorepo fixtures
  // keep their nested manifests under top-level subdirs, so this remains a
  // root-level signal.
  const hasGoMod = exists(path.join(projectDir, 'go.mod'));
  const hasPackageJson = exists(path.join(projectDir, 'package.json'));
  if (hasGoMod && hasPackageJson) {
    ambiguities.push({
      category: 'language',
      message:
        'Both go.mod and package.json detected at the repository root; primary language cannot be inferred automatically.',
      signals: ['go.mod', 'package.json'],
    });
    ambiguities.push({
      category: 'package_manager',
      message:
        'Multiple root-level package ecosystems detected (go modules and npm); primary package manager cannot be inferred automatically.',
      signals: ['go.mod', 'package.json'],
    });
  }

  // Multiple JS package manager lockfiles at the root.
  const jsLocks = [];
  for (const f of ['package-lock.json', 'pnpm-lock.yaml', 'yarn.lock']) {
    if (exists(path.join(projectDir, f))) jsLocks.push(f);
  }
  if (jsLocks.length > 1) {
    ambiguities.push({
      category: 'package_manager',
      message:
        'Multiple JavaScript package manager lockfiles detected at the repository root.',
      signals: jsLocks,
    });
  }

  // docs/ and .docs/ both present.
  if (
    exists(path.join(projectDir, 'docs')) &&
    exists(path.join(projectDir, '.docs'))
  ) {
    ambiguities.push({
      category: 'docs_root',
      message:
        'Both docs/ and .docs/ directories detected; canonical documentation root is ambiguous.',
      signals: ['docs', '.docs'],
    });
  }

  return ambiguities;
}

// --- Orchestration -----------------------------------------------------------

function inspect(projectDir) {
  const resolved = path.resolve(projectDir);
  if (!exists(resolved)) {
    throw new Error(`Target project directory does not exist: ${resolved}`);
  }
  if (!fs.statSync(resolved).isDirectory()) {
    throw new Error(`Target project path is not a directory: ${resolved}`);
  }

  const language = detectLanguage(resolved);
  const package_manager = detectPackageManager(resolved);
  const docs_root = detectDocsRoot(resolved);
  const agent_guidance = detectAgentGuidance(resolved);
  const test_infrastructure = detectTestInfrastructure(resolved);
  const cicd = detectCicd(resolved);
  const opencode_config = detectOpencodeConfig(resolved);
  const github_project_env = detectGithubProjectEnv(resolved);
  const repo_origin = detectRepoOrigin(resolved);
  const app_boundaries = detectAppBoundaries(resolved);
  const ambiguities = detectAmbiguities(resolved, language, package_manager);

  return {
    language,
    package_manager,
    docs_root,
    agent_guidance,
    test_infrastructure,
    cicd,
    opencode_config,
    github_project_env,
    repo_origin,
    app_boundaries,
    ambiguities,
  };
}

function main() {
  let args;
  try {
    args = parseArgs(process.argv.slice(2));
  } catch (err) {
    process.stderr.write(`[error] ${err.message}\n`);
    process.exit(1);
  }

  let result;
  try {
    result = inspect(args.projectDir);
  } catch (err) {
    process.stderr.write(`[error] ${err.message}\n`);
    process.exit(1);
  }

  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
}

if (require.main === module) {
  main();
}

module.exports = { inspect, SKIP_DIRS, NOT_DETECTED };
