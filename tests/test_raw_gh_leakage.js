#!/usr/bin/env node
'use strict';

/*
 * tests/test_raw_gh_leakage.js — raw `gh` CLI leakage gate (SPEC-003-T5,
 * issue #35, 2026-08). Traceability: spec success metric "Raw CLI leakage",
 * AC-04 (raw gh/GraphQL confined to the helper engine), AC-07 (regression
 * safety); spec Testing Strategy "raw-`gh` leakage search" over
 * templates/opencode/ and templates/scripts/.
 *
 * Fails when a raw `gh pr|release|workflow|run` or `gh api graphql`
 * invocation appears anywhere under templates/opencode/ or templates/scripts/
 * outside the canonical helper engine script. The allowlist is deliberately
 * exact (tech-lead guardrail: allowlist the engine path and any explicitly
 * documented internal GraphQL notes — no broad exception, never weaken the
 * gate to pass a leak; fix the leak instead):
 *
 *   LG-1  the canonical engine file exists and is the only whole-file
 *         exception, and it really carries the engine's internal raw `gh`
 *         usage (the exception is not vacuous)
 *   LG-2  clean tree: zero raw `gh pr|release|workflow|run` occurrences
 *         outside the engine (no prose exceptions — SPEC-003-T4 cleaned
 *         guidance to comply)
 *   LG-3  clean tree: zero `gh api graphql` occurrences outside the engine
 *         except the explicitly documented internal GraphQL notes (exact
 *         literal phrases, each excusing only its own file)
 *   LG-4  detection self-test: the scanner flags every gated subcommand in
 *         synthetic samples, including bash backslash line-continuations,
 *         so the gate provably FAILS when a leak is introduced
 *   LG-5  allowlist precision: phrases only excuse their own file, a
 *         non-phrase `gh api graphql` in an allowlisted file is still a
 *         leak, stale allowlist entries fail, and the legal raw fallbacks
 *         (`gh repo|issue|project`) stay ungated
 *
 * No external npm dependencies — Node built-ins only. No network access.
 */

const fs = require('fs');
const path = require('path');
const assert = require('assert');

const REPO_ROOT = path.resolve(__dirname, '..');

// Canonical helper engine — the ONLY whole-file exception. The thin sync
// wrapper templates/scripts/gh_project_helper.sh is NOT excepted: it must
// stay a pass-through with no raw `gh` of its own.
const ENGINE_PATH = path.join(
  'templates/opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh'
);

const SCAN_ROOTS = ['templates/opencode', 'templates/scripts'];

// Gated raw subcommands (case-sensitive, word-bounded). The separator class
// [\s\\]* tolerates spaces, tabs, and bash backslash line-continuations so a
// wrapped invocation cannot slip through.
const RAW_SUBCOMMAND_RE = /\bgh\b[\s\\]*(pr|release|workflow|run)\b/;
const GRAPHQL_RE = /\bgh\b[\s\\]*api[\s\\]*graphql\b/;

// Explicitly documented internal GraphQL notes — exact literal phrases only.
// Each phrase excuses only the named file, and only that literal text; every
// other `gh api graphql` occurrence outside the engine is a leak.
const DOCUMENTED_GRAPHQL_NOTES = {
  'templates/opencode/opencode.json': [
    // Helper-routing fallback sentence shared by the five role prompts,
    // routed by SPEC-003-T4 (PR #42).
    'Prefer common `gh` workflows such as `gh repo`, `gh issue`, `gh project`, and `gh api graphql` only when the simpler commands or repo wrapper do not cover the need.',
  ],
  'templates/opencode/skills/github-issues-projects-cli/SKILL.md': [
    '4. `gh api graphql` when GitHub Projects v2 mutations or richer joins are needed',
    'item updates often require `gh api graphql`',
    'use `gh api graphql` rather than inventing a brittle workaround',
  ],
  'templates/opencode/skills/github-issues-projects-cli/references/command-patterns.md': [
    // Prose note plus the two documented raw GraphQL query example blocks
    // in the engine skill's own reference appendix.
    'the same `gh api graphql` mutation shapes',
    "gh api graphql -f query='",
  ],
};

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

function read(rel) {
  return fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8');
}

function walkFiles(absDir, relDir, out = []) {
  for (const e of fs.readdirSync(absDir, { withFileTypes: true })) {
    const rel = path.join(relDir, e.name);
    if (e.isDirectory()) walkFiles(path.join(absDir, e.name), rel, out);
    else out.push(rel);
  }
  return out;
}

function lineOf(content, index) {
  return content.slice(0, index).split('\n').length;
}

// Remove every occurrence of the file's documented phrases so only
// undocumented `gh api graphql` text remains visible to the scanner.
function stripDocumentedPhrases(relPath, content) {
  let out = content;
  for (const phrase of DOCUMENTED_GRAPHQL_NOTES[relPath] || []) {
    out = out.split(phrase).join('');
  }
  return out;
}

// Scan one file's content. Returns { raw: [finding...], graphql: [finding...] }.
function scanContent(relPath, content) {
  const findings = { raw: [], graphql: [] };
  if (relPath === ENGINE_PATH) return findings; // canonical engine allowlist
  const rawRe = new RegExp(RAW_SUBCOMMAND_RE.source, 'g');
  let m;
  while ((m = rawRe.exec(content))) {
    findings.raw.push(`${relPath}:${lineOf(content, m.index)} raw \`${m[0]}\``);
  }
  const rest = stripDocumentedPhrases(relPath, content);
  const gqlRe = new RegExp(GRAPHQL_RE.source, 'g');
  while ((m = gqlRe.exec(rest))) {
    findings.graphql.push(
      `${relPath}: undocumented \`${m[0]}\` (not an allowed GraphQL note)`
    );
  }
  return findings;
}

function scanTree() {
  const findings = { raw: [], graphql: [], files: 0 };
  for (const root of SCAN_ROOTS) {
    for (const rel of walkFiles(path.join(REPO_ROOT, root), root)) {
      findings.files += 1;
      const one = scanContent(rel, read(rel));
      findings.raw.push(...one.raw);
      findings.graphql.push(...one.graphql);
    }
  }
  return findings;
}

function reportFindingList(header, items) {
  const shown = items.slice(0, 10).join('\n      ');
  const more = items.length > 10 ? `\n      ... and ${items.length - 10} more` : '';
  assert.fail(`${header} (${items.length}):\n      ${shown}${more}`);
}

// --- LG-1: engine allowlist targets the real engine ------------------------

check('LG-1: engine file exists and carries the internal raw gh usage', () => {
  const engine = read(ENGINE_PATH);
  assert.match(engine, RAW_SUBCOMMAND_RE);
  assert.match(engine, GRAPHQL_RE);
});

// --- LG-2 / LG-3: clean-tree gate -------------------------------------------

check('LG-2: no raw gh pr/release/workflow/run outside the engine', () => {
  const { raw, files } = scanTree();
  assert.ok(files > 0, 'scan roots produced no files');
  if (raw.length > 0) {
    reportFindingList('raw gh subcommand leaks outside the helper engine', raw);
  }
});

check('LG-3: no gh api graphql outside the engine except documented notes', () => {
  const { graphql } = scanTree();
  if (graphql.length > 0) {
    reportFindingList('undocumented gh api graphql leaks', graphql);
  }
});

// --- LG-4: the gate provably detects leaks ----------------------------------

check('LG-4: scanner flags every gated subcommand sample as a leak', () => {
  const rawSamples = [
    'run `gh pr create --title "x"` directly',
    'gh release list',
    'gh workflow run ci.yml',
    'gh run view 123',
    'gh \\\n  pr view 1', // bash backslash line-continuation
    'gh\tpr list',
  ];
  for (const sample of rawSamples) {
    const { raw } = scanContent('templates/opencode/skills/some-skill/SKILL.md', sample);
    assert.ok(raw.length === 1, `expected a raw leak in ${JSON.stringify(sample)}`);
  }
  const { graphql } = scanContent(
    'templates/opencode/skills/some-skill/SKILL.md',
    "just call gh api graphql -f query='...' here"
  );
  assert.ok(graphql.length === 1, 'expected a graphql leak in the synthetic sample');
});

// --- LG-5: allowlist precision — no broad exception -------------------------

check('LG-5: allowlist phrases are exact, file-scoped, and not stale', () => {
  for (const [rel, phrases] of Object.entries(DOCUMENTED_GRAPHQL_NOTES)) {
    const content = read(rel);
    for (const phrase of phrases) {
      assert.ok(
        content.includes(phrase),
        `stale allowlist entry: ${JSON.stringify(phrase)} no longer appears in ${rel} — remove it`
      );
    }
  }

  // A documented phrase does not excuse the same text in a different file.
  const [opencodePhrase] = DOCUMENTED_GRAPHQL_NOTES['templates/opencode/opencode.json'];
  const alien = scanContent('templates/opencode/skills/other/SKILL.md', opencodePhrase);
  assert.ok(alien.graphql.length === 1, 'phrase must not excuse any file but its own');

  // Inside an allowlisted file, only the exact phrase is excused.
  const mutated = scanContent(
    'templates/opencode/skills/github-issues-projects-cli/SKILL.md',
    'call gh api graphql now'
  );
  assert.ok(mutated.graphql.length === 1, 'non-phrase graphql text must stay a leak');

  // The documented sentence itself stays clean in its own file.
  const clean = scanContent('templates/opencode/opencode.json', opencodePhrase);
  assert.strictEqual(clean.graphql.length, 0);

  // Legal raw fallbacks remain ungated (spec: gh repo/issue/project fallback).
  const legal = scanContent(
    'templates/opencode/skills/some-skill/SKILL.md',
    'fallback: gh repo view, gh issue view 5, gh project item-list'
  );
  assert.strictEqual(legal.raw.length + legal.graphql.length, 0);
});

if (failed > 0) {
  console.error(`\n${passed} passed, ${failed} failed (raw gh leakage gate)`);
  process.exit(1);
}
console.log(`\n${passed} passed, 0 failed (raw gh leakage gate)`);
