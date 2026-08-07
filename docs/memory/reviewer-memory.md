# Reviewer Memory

## Active Lessons

### 2026-08-03 - SPEC-002 / #25 (PR #29, approval)

- Context: Reviewed docs-only PR #29 for the final SPEC-002 documentation task.
- Smoke Result: Pass; managed-sync regression suite, AGENTS.md structural validation, and docs/link checks all passed.
- Runtime Requirement: Use the PR worktree when checking doc links; the local default branch may be behind origin/master.
- Verification Command: `bash scripts/validate-agents-md.sh AGENTS.md`; `bash tests/run_sync_tests.sh`; path checks for `README.md`, `docs/DOCUMENT_INDEX.md`, and `docs/runbooks/RB-001-managed-skill-sync.md`.
- Known Gap: None.
- Related Docs: `docs/spec/SPEC-002-managed-global-skill-sync-and-command-derived-skills.md`, `docs/arch/ARCH-004-managed-skill-sync-architecture.md`, issue #25, PR #29.

### 2026-08-03 - SPEC-002 / #24 (PR #28, approval)

- Context: Re-reviewed commit 4852129 after the ERR-1.2 unreadable-command-source fix.
- Smoke Result: Pass; the unreadable-command test now emits [ERROR], skips the bad entry, continues to install the sibling command, and exits 1. Full sync suite and representative managed-sync smoke passed.
- Runtime Requirement: Run unreadable-source tests as a non-root user (chmod 000 is ineffective under root) and use a detached worktree / temp HOME for managed-sync smoke.
- Verification Command: `bash tests/test_sync_unit_source_errors.sh`; `bash tests/run_sync_tests.sh`; `bash tests/e2e/test_smoke_sync_managed_skills.sh`
- Known Gap: GitHub review approval API cannot approve a PR authored by the same account; record the explicit approval in a PR comment and move the project item to Ready to Merge.
- Related Docs: `docs/spec/SPEC-002-managed-global-skill-sync-and-command-derived-skills.md`, `docs/arch/ARCH-004-managed-skill-sync-architecture.md`, issue #24, PR #28.

### 2026-08-02 - SPEC-002 / #23 (PR #27, approval)

- Context: Reviewed PR #27 for sync-company integration.
- Smoke Result: Pass; canonical install diff clean, managed sync installed, default preserved tamper, --force restored tamper, canonical fail exited 1, managed fail exited 5, wrappers unchanged.
- Runtime Requirement: Use temp HOME for sync-company smoke to avoid touching real ~/.config/opencode and ~/.agents.
- Verification Command: `bash -n scripts/sync-company.sh scripts/init-company.sh scripts/update-company.sh scripts/sync-managed-skills.sh`; `for f in tests/test_*.js; do node "$f"; done`; `bash tests/run_e2e_tests.sh`; manual temp-HOME `scripts/sync-company.sh` smoke.
- Known Gap: None.
- Related Docs: SPEC-002, ARCH-004, issue #23, PR #27.

### 2026-08-02 - SPEC-002 / #22 (PR #26, re-review)

- Context: Re-reviewed commit 0482d30 after the nested non-directory ancestor collision fix.
- Smoke Result: Pass for syntax, the dedicated managed-sync smoke, and the SPEC-001 regression suite; blocker remains on a security/permission review.
- Runtime Requirement: Use a temp HOME or detached worktree for managed-sync smoke; add an explicit symlink-ancestor repro because symlink-to-dir ancestors are still followed.
- Verification Command: `bash -n scripts/sync-managed-skills.sh`; `tests/e2e/test_smoke_sync_managed_skills.sh`; `tests/run_e2e_tests.sh`; manual symlink-ancestor repro with an intermediate managed path replaced by a symlink.
- Known Gap: Nested non-directory ancestors now skip cleanly, but a symlink-to-dir ancestor still escapes the managed subtree; update permission handling also still needs explicit reconciliation with SPEC-002 SEC-3.2.
- Related Docs: `docs/spec/SPEC-002-managed-global-skill-sync-and-command-derived-skills.md`, `docs/arch/ARCH-004-managed-skill-sync-architecture.md`, PR #26, issue #22

### 2026-08-02 - SPEC-002 / #22

- Context: Reviewed PR #26 for the managed sync engine.
- Smoke Result: Mixed; fresh sync, idempotent rerun, dry-run, modified-preserve, and force-overwrite passed in a clean worktree, but manifest-missing recovery and unmanaged file collision failed.
- Runtime Requirement: Use a detached worktree or clean checkout for smoke; explicitly test both directory and file collisions under `~/.agents/skills`, and simulate missing `.manifest.json`.
- Verification Command: `bash -n scripts/sync-managed-skills.sh`; `HOME=<temp> bash scripts/sync-managed-skills.sh`; rerun after deleting `~/.agents/skills/.manifest.json`; create an unmanaged file at a managed target name and rerun.
- Known Gap: Manifest-less reruns currently skip all pre-existing managed-name directories as unmanaged collisions; unmanaged file collisions abort with exit 5 instead of warning+skip; managed-file permission handling still needs review against SEC-3.2.
- Related Docs: `docs/spec/SPEC-002-managed-global-skill-sync-and-command-derived-skills.md`, `docs/arch/ARCH-004-managed-skill-sync-architecture.md`, PR #26, issue #22

### 2026-07-19 - SPEC-001 / #2

- Context: Reviewed PR #12 for the repository inspection engine. Builder flagged a SPEC TEST-1.2 vs AC-T1-002 mismatch.
- Smoke Result: Unit tests passed (187/187) and representative CLI invocations returned valid JSON / expected ambiguity output in a clean PR worktree.
- Runtime Requirement: Use a clean worktree or detached checkout for verification; the main repo working tree may be dirty and should not be trusted for PR smoke runs.
- Verification Command: `node tests/test_inspect_repo.js`; `node .opencode/skills/project-initialization/scripts/inspect_repo.js --project-dir tests/fixtures/repo-node-npm | jq ...`
- Known Gap: `fixtures/repo-bare/` must be checked against SPEC-001 TEST-1.2 before approval; missing `docs/` is a spec-fidelity blocker, not a harmless fixture simplification.
- Related Docs: `docs/spec/SPEC-001-init-project-tailored-repo-bootstrap.md`, `docs/arch/ARCH-003-project-local-initialization-artifacts.md`
### 2026-07-19 - SPEC-001 / #2 (re-review approval)

- Context: Re-reviewed commit 8ab3431 after the repo-bare fixture was restored to SPEC-001 TEST-1.2 shape.
- Smoke Result: Pass; `node tests/test_inspect_repo.js` passed 187/187 and representative CLI checks for repo-node-npm, repo-bare, and repo-multi-pm matched expectations in a clean worktree.
- Runtime Requirement: Keep using a clean worktree or detached checkout for smoke verification; dirty repo roots can mislead review evidence.
- Verification Command: `node tests/test_inspect_repo.js`; `node .opencode/skills/project-initialization/scripts/inspect_repo.js --project-dir tests/fixtures/repo-{node-npm,bare,multi-pm} | jq ...`
- Known Gap: None after approval.
- Related Docs: `docs/spec/SPEC-001-init-project-tailored-repo-bootstrap.md`, `docs/arch/ARCH-003-project-local-initialization-artifacts.md`

### 2026-07-19 - SPEC-001 / #5 (PR #13, review loop 1)

- Context: Reviewed PR #13 for project-local skills copy.
- Smoke Result: Blocked; clean smoke init copied the required skills, but `do-task/scripts/create_task_worktree.sh` and `cleanup_task_worktree.sh` landed with mode `664`.
- Runtime Requirement: Use a clean temp repo or detached worktree for smoke verification; verify copied script modes explicitly, not just file existence.
- Verification Command: `node tests/test_skills_copy.js`; `node tests/test_inspect_repo.js`; `bash /tmp/opencode/pr13/.opencode/skills/project-initialization/scripts/init_project_docs.sh --project-dir <tmp> --worktree-root <tmp>/wt` plus `stat -c '%a %n' <tmp>/.opencode/skills/*/scripts/*`.
- Known Gap: ARCH-003 guarantee 4 requires shell scripts under `scripts/` to be executable; current copy behavior preserves source modes verbatim, so the do-task scripts are not runnable after init.
- Related Docs: `docs/spec/SPEC-001-init-project-tailored-repo-bootstrap.md`, `docs/arch/ARCH-003-project-local-initialization-artifacts.md`

### 2026-07-19 - SPEC-001 / #5 (PR #13, loop 2 — pending re-review)

- Context: Builder responded to loop-1 HIGH finding (review 4730838030) by correcting source modes for 3 scripts and reconciling tests; commit `6e9fdcb`. Re-review pending.
- Smoke Result: Pending reviewer re-run; builder evidence shows 53/53 skills-copy tests pass, 187/187 inspect-repo tests pass, and end-to-end smoke shows all 5 required scripts land at mode 755 in target.
- Runtime Requirement: For re-review, walk every `.sh` under target `.opencode/skills/<required-skill>/scripts/` and assert exec bit positively (not just equality). Pre-fix code reproduces 10 failures matching loop-1 finding; post-fix code is 53/53.
- Verification Command: `node tests/test_skills_copy.js`; revert source modes (`chmod 644` on the 3 fixed files) and re-run to confirm tests catch the regression; `stat -c '%a %n' <tmp>/.opencode/skills/*/scripts/*` after fresh smoke init.
- Known Gap: None open. Note for future reviewer attention: pre-existing inits done before `6e9fdcb` would have non-executable do-task/setup_project_docs scripts in target — a one-shot migration `chmod +x` may be needed for those, tracked as a potential follow-up for issue #8 (e2e/migration tests).
- Related Docs: `docs/spec/SPEC-001-init-project-tailored-repo-bootstrap.md` (SEC-3.1, SEC-3.2), `docs/arch/ARCH-003-project-local-initialization-artifacts.md` (Artifact 3 guarantee 4), PR #13 comment 5015979264.

### 2026-07-19 - SPEC-001 / #5 (PR #13, approval)

- Context: Re-reviewed commit 6e9fdcb after the source-mode fix for the required shell scripts.
- Smoke Result: Pass; `node tests/test_skills_copy.js` (53/53), `node tests/test_inspect_repo.js` (187/187), `bash -n .opencode/skills/project-initialization/scripts/init_project_docs.sh`, and a fresh smoke init all passed. The smoke repo showed all required copied shell scripts at mode 775, excluded skills absent, `.opencode/.gitignore` containing `node_modules`, and idempotency preserved.
- Runtime Requirement: Use a clean detached worktree or temp repo for init smoke; verify copied shell script execute bits explicitly rather than inferring from existence.
- Verification Command: `node tests/test_skills_copy.js`; `node tests/test_inspect_repo.js`; `bash -n .opencode/skills/project-initialization/scripts/init_project_docs.sh`; fresh smoke init + `stat -c '%a %n' <tmp>/.opencode/skills/*/scripts/*`.
- Known Gap: GitHub would not allow a formal self-approval review from the same account, so the approval was recorded as an explicit PR comment instead.
- Related Docs: `docs/spec/SPEC-001-init-project-tailored-repo-bootstrap.md`, `docs/arch/ARCH-003-project-local-initialization-artifacts.md`, PR #13 comment 5016000692, issue #5 comment 5016003336.
### 2026-07-19 - SPEC-001 / #3

- Context: Reviewed PR #14 for CLI flag expansion and mode detection.
- Smoke Result: Partial pass; focused tests passed, but manual smoke found validation gaps for `--github-project-number` and `--related-repos`.
- Runtime Requirement: Use a clean temp repo or detached worktree for smoke verification; `--dry-run` is still deferred and does not suppress writes in this task.
- Verification Command: `node tests/test_cli_flags.js`; `node tests/test_skills_copy.js`; `node tests/test_inspect_repo.js`; `bash -n .opencode/skills/project-initialization/scripts/init_project_docs.sh`; manual smoke with `--github-project-number nope` and malformed `--related-repos`.
- Known Gap: `--github-project-number` needs integer validation; `--related-repos` validation is too permissive and accepts extra-colon malformed entries.
- Related Docs: `docs/spec/SPEC-001-init-project-tailored-repo-bootstrap.md`, `docs/arch/ARCH-003-project-local-initialization-artifacts.md`

### 2026-07-19 - SPEC-001 / #3 (re-review)

- Context: Re-reviewed PR #14 commit dda6416 after builder fixed integer validation and stricter related-repos parsing.
- Smoke Result: Partial pass; focused CLI suite passed in a clean worktree, but manual smoke showed the new one-colon URL rule rejects realistic Git URLs with ports.
- Runtime Requirement: Use a clean detached worktree or temp repo for CLI smoke; include port-bearing Git URL cases, not just https and scp shapes.
- Verification Command: node tests/test_cli_flags.js; node tests/test_skills_copy.js; node tests/test_inspect_repo.js; bash -n .opencode/skills/project-initialization/scripts/init_project_docs.sh; manual smoke with https://host:443/... and ssh://git@host:22/... related-repos entries.
- Known Gap: --related-repos validation is still too narrow for realistic Git URL forms that include a port.
- Related Docs: docs/spec/SPEC-001-init-project-tailored-repo-bootstrap.md, docs/arch/ARCH-003-project-local-initialization-artifacts.md

### 2026-07-19 - SPEC-001 / #3 (PR #14, approval)

- Context: Re-reviewed commit 5ba6017 in a detached worktree after the opaque-URL parser change.
- Smoke Result: Pass; `node tests/test_cli_flags.js` (81/81), `node tests/test_skills_copy.js` (53/53), `node tests/test_inspect_repo.js` (187/187), `bash -n .opencode/skills/project-initialization/scripts/init_project_docs.sh`, and manual smoke on port-bearing Git remotes plus malformed entries all passed.
- Runtime Requirement: Use a clean detached worktree/temp repo for CLI smoke; include port-bearing `--related-repos` cases when the URL field is opaque.
- Verification Command: `node tests/test_cli_flags.js`; `node tests/test_skills_copy.js`; `node tests/test_inspect_repo.js`; `bash -n .opencode/skills/project-initialization/scripts/init_project_docs.sh`; manual smoke with `sibling:https://github.com:443/org/repo:sibling`, `sibling:ssh://git@github.com:22/org/repo:sibling`, and unambiguous malformed triples.
- Known Gap: None.
- Related Docs: `docs/spec/SPEC-001-init-project-tailored-repo-bootstrap.md`, `docs/arch/ARCH-003-project-local-initialization-artifacts.md`

### 2026-07-19 - SPEC-001 / #6

- Context: Reviewed PR #15 for `.github-project.json` additive migration and opencode config preservation.
- Smoke Result: Partial pass; focused regression suites passed, but review blocked on canonical `.opencode` location drift and uncaught malformed JSON handling.
- Runtime Requirement: Use a clean detached worktree or temp repo for init smoke; verify canonical `.opencode/opencode.json[ c]` paths explicitly, not just legacy root files.
- Verification Command: `node tests/test_github_project_config.js`; `node tests/test_inspect_repo.js`; `node tests/test_skills_copy.js`; `node tests/test_cli_flags.js`; `bash -n .opencode/skills/project-initialization/scripts/init_project_docs.sh`.
- Known Gap: Fresh init still creates repo-root `opencode.jsonc` instead of canonical project-local `.opencode/opencode.json[ c]`; malformed `.github-project.json` currently aborts with an uncaught Node SyntaxError rather than a controlled `[error]` path.
- Related Docs: `docs/spec/SPEC-001-init-project-tailored-repo-bootstrap.md`, `docs/arch/ARCH-003-project-local-initialization-artifacts.md`


### 2026-07-20 - SPEC-001 / #6 (PR #15, approval)

- Context: Re-reviewed commit cf3e831 after builder fixed the canonical `.opencode/opencode.json` location and malformed `.github-project.json` handling.
- Smoke Result: Pass; `node tests/test_github_project_config.js` (48/48), `node tests/test_inspect_repo.js` (187/187), `node tests/test_skills_copy.js` (53/53), `node tests/test_cli_flags.js` (81/81), `bash -n .opencode/skills/project-initialization/scripts/init_project_docs.sh`, plus manual smoke for fresh canonical location, supported-location preservation, and controlled malformed-JSON failure/no mutation.
- Runtime Requirement: Use a clean detached worktree for init smoke; manual spot-checks should include a fresh repo, a legacy root `opencode.jsonc` repo, and a malformed `.github-project.json` case.
- Verification Command: `node tests/test_github_project_config.js`; `node tests/test_inspect_repo.js`; `node tests/test_skills_copy.js`; `node tests/test_cli_flags.js`; `bash -n .opencode/skills/project-initialization/scripts/init_project_docs.sh`.
- Known Gap: None.
- Related Docs: `docs/spec/SPEC-001-init-project-tailored-repo-bootstrap.md`, `docs/arch/ARCH-003-project-local-initialization-artifacts.md`, PR #15, issue #6.

### 2026-07-20 - SPEC-001 / #6 (merged to Done)

- Context: PR #15 merged by tech-lead after final spec-alignment check confirmed the two review findings (canonical opencode config location, malformed JSON handling) were fixed. All ACs pass; DM-1 schema compliant; ARCH-003 guarantee 2 strict additivity verified.
- Smoke Result: N/A (reviewer approved in prior loop; tech-lead performed final check and merge).
- Runtime Requirement: N/A.
- Verification Command: N/A — the reviewer's approval comment on PR #15 (`5016406791`) was the final verification gate.
- Known Gap: None. The rejected-review state (no formal GitHub review API approval) was noted by tech-lead as a ruleset-configuration concern — the `github-agentic-delivery-flow` contract uses PR comments for approval, not the GitHub Review API.
- Related Docs: `docs/spec/SPEC-001-init-project-tailored-repo-bootstrap.md`, `docs/arch/ARCH-003-project-local-initialization-artifacts.md`, PR #15, issue #6.

### 2026-07-20 - SPEC-001 / #4 (PR #16)

- Context: Reviewed PR #16 for AGENTS.md generation (interactive + noninteractive).
- Smoke Result: Pass on focused suites and fixture smoke checks, but review blocked by scope drift.
- Runtime Requirement: Use a detached worktree or temp repo for smoke; interactive prompts are line-based stdin and need explicit newline responses in tests.
- Verification Command: `node tests/test_agents_md_gen.js`; `node tests/test_cli_flags.js`; `node tests/test_github_project_config.js`; manual interactive/noninteractive smoke on temp copies of `repo-bare` and `repo-node-npm`.
- Known Gap: PR #16 pulled in T5 `.github-project.json` additive-merge/idempotency implementation inside the T3 AGENTS.md issue, which issue #4 explicitly scoped out.
- Related Docs: `docs/spec/SPEC-001-init-project-tailored-repo-bootstrap.md`, `docs/arch/ARCH-003-project-local-initialization-artifacts.md`, PR #16, issue #4

### 2026-07-20 - SPEC-001 / #4

- Context: Re-reviewed PR #16 against current origin/master after builder clarification; earlier T5 scope finding was a base-content/diff misread, not actual diff scope.
- Smoke Result: Pass; focused suites and fixture smoke in detached worktree /tmp/opencode/ant-teams-pr16.
- Runtime Requirement: Use a detached worktree or temp clone for PR smoke when the main repo is dirty or the PR branch is not checked out.
- Verification Command: `bash -n .opencode/skills/project-initialization/scripts/init_project_docs.sh && node tests/test_agents_md_gen.js && node tests/test_cli_flags.js && node tests/test_github_project_config.js`
- Known Gap: None.
- Related Docs: `docs/spec/SPEC-001-init-project-tailored-repo-bootstrap.md`, `docs/arch/ARCH-003-project-local-initialization-artifacts.md`, PR #16, issue #4.

### 2026-07-20 - SPEC-001 / #4 (PR #16, merged to Done)

- Context: PR #16 merged by tech-lead into master at commit `6e9741f`. The earlier loop-1 scope concern (T5 code in T3 PR) was a diff-vs-file-content misread; the three-dot diff against merge-base `2fc81fc` contained only T3 AGENTS.md work. Reviewer re-approved after builder's diff-scope evidence.
- Smoke Result: Pass; 402/402 tests across all 5 suites. Interactive + noninteractive smoke on `repo-bare` and `repo-node-npm` fixtures confirmed DM-2 structure, traceable claims (FR-5.3), and backup/merge/skip policy (FR-5.5).
- Runtime Requirement: When reviewing a PR whose base branch has had related work merged mid-flight, always compare `git merge-base origin/master HEAD` against the PR base before filing scope findings. File-content-only inspection in the final file state can falsely attribute base-branch code to the PR diff.
- Verification Command: `bash -n .opencode/skills/project-initialization/scripts/init_project_docs.sh && node tests/test_agents_md_gen.js && node tests/test_cli_flags.js && node tests/test_github_project_config.js`
- Known Gap: None. All ACs pass. Deferred concerns (#7 dry-run/idempotency) are tracked separately.
- Related Docs: `docs/spec/SPEC-001-init-project-tailored-repo-bootstrap.md`, `docs/arch/ARCH-003-project-local-initialization-artifacts.md`, PR #16, issue #4.


### 2026-07-21 - SPEC-001 / #7 (PR #17, review loop 1)

- Context: Reviewed PR #17 for OBS/ERR/TR dry-run, idempotency, atomic writes, and interrupt safety.
- Smoke Result: Pass for focused/full test suites plus dry-run, non-git error, and interrupted-run smoke; no leaked temp files observed.
- Runtime Requirement: Use a clean detached worktree for init smoke; the main repo root may be dirty. GitHub will reject `--request-changes` on your own PR, so use a PR comment when the reviewer identity matches the author account.
- Verification Command: `node tests/test_dryrun.js`; `node tests/test_idempotency.js`; `for f in tests/test_*.js; do node "$f"; done`; manual dry-run/non-git/interruption smoke in a temp repo.
- Known Gap: PR #17 added two new test files despite the issue guardrail limiting edits to `init_project_docs.sh`; future reviews should check scope drift on test-only additions explicitly.
- Related Docs: `docs/spec/SPEC-001-init-project-tailored-repo-bootstrap.md`, `docs/arch/ARCH-003-project-local-initialization-artifacts.md`, PR #17, issue #7.

### 2026-07-21 - SPEC-001 / #7 (PR #17, guardrail clarification — test files valid)

- Context: Tech-lead resolved reviewer's scope/guardrail finding on PR #17. The two new test files (`tests/test_dryrun.js`, `tests/test_idempotency.js`) are VALID scoped verification artifacts, not guardrail violations.
- Smoke Result: N/A — guardrail interpretation decision only; no code change.
- Runtime Requirement: N/A.
- Verification Command: N/A.
- Known Gap: **Guardrail clarification for future reviews:** The "Modify: <file>" constraint in issue bodies controls *implementation file placement* — it prevents spreading implementation logic across multiple production files. Focused test files that follow the one-per-concern repo pattern are expected verification artifacts, not scope drift. When tech-lead pre-authorizes test files in the delegation comment (as done for #7 with `tests/test_idempotency.js` and/or `tests/test_dryrun.js`), those files are explicitly in scope. Flag test files only when they violate the established pattern (e.g., mixing concerns, bloating existing suites, or touching unrelated test infrastructure).
- Related Docs: PR #17 comment 5026004631, issue #7 comment 5026007164, architect memory 2026-07-21 entry, delegation comment 5012572130.
### 2026-07-21 - SPEC-001 / #7 (PR #17, approval)

- Context: Re-reviewed PR #17 after tech-lead clarified that focused test files are valid scoped verification artifacts. Verification ran in detached worktree `/tmp/opencode/ant-teams-pr17`.
- Smoke Result: Pass; full suite `for f in tests/test_*.js; do node "$f"; done` passed 432/432. Dry-run smoke wrote nothing, idempotency smoke kept AGENTS.md byte-identical on no-op rerun, and non-git / interrupt smokes passed.
- Runtime Requirement: Use a detached worktree for init smoke; confirm the project board uses the Workflow State field and move issue #7 to Ready to Merge before merge.
- Verification Command: `for f in tests/test_*.js; do node "$f"; done`; dry-run smoke in a temp repo with `.git` marker; idempotency smoke in a temp repo with `--force` rerun.
- Known Gap: None.
- Related Docs: PR #17 comment 5029689602, issue #7 comment 5029689671, `docs/arch/ARCH-003-project-local-initialization-artifacts.md`, `docs/spec/SPEC-001-init-project-tailored-repo-bootstrap.md`.


### 2026-07-21 - SPEC-001 / #9 (PR #18, approval)

- Context: Reviewed PR #18 for the AGENTS.md validator against SPEC-001 DM-2 / TEST-4.2 and ARCH-003, with a freshness check against current `master` (`7a91807`).
- Smoke Result: Pass; `bash -n scripts/validate-agents-md.sh`, `node tests/test_validate_agents_md.js` (34/34), and full regression on a clean merge-check worktree passed. A real init smoke confirmed `## Local Configuration Files` lists directories as well as files.
- Runtime Requirement: Use a detached/temporary worktree for merged-tree smoke when the repo root is dirty; compare the PR against current `master` before filing a stale-base finding.
- Verification Command: `bash -n scripts/validate-agents-md.sh`; `node tests/test_validate_agents_md.js`; `for f in tests/test_*.js; do node "$f" || exit 1; done`; manual init smoke in a temp repo.
- Known Gap: None.
- Related Docs: `docs/spec/SPEC-001-init-project-tailored-repo-bootstrap.md`, `docs/arch/ARCH-003-project-local-initialization-artifacts.md`, PR #18, issue #9

### 2026-07-21 - SPEC-001 / #9 (AGENTS.md validation script)

- Context: Reviewer review of PR #18 (AGENTS.md validation script) — loop 1/8, approved without findings.
- Smoke Result: pass
- Runtime Requirement: `bash` + `grep` + `sed` + `awk` only — no Node.js dependency in the validator itself. Node.js needed only for running the test suite.
- Verification Command: `bash -n scripts/validate-agents-md.sh`; `node tests/test_validate_agents_md.js`; manual smoke confirmed known-good AGENTS.md → exit 0, broken AGENTS.md → exit 1 with specific [FAIL] lines.
- Known Gap: The validator is intentionally structural-only — does not verify claim accuracy beyond file existence. Full accuracy still needs human review per issue body.
- Note: The `[[ -e ]]` check (vs guardrail `[[ -f ]]`) is correct — the init-project generator emits directory entries in LCF. Manual smoke confirmed real init output lists directories.
- Related Docs: SPEC-001 TEST-4.2, ARCH-003 DM-2, issue #9, PR #18
### 2026-07-31 - SPEC-001 / #8 (PR #19 approval)

- Context: Re-reviewed PR #19 at commit `0d5e2b8` after builder resume confirmation and loop-2 fixes.
- Smoke Result: Pass; `tests/run_e2e_tests.sh`, standalone `tests/e2e/test_e2e_idempotent.sh`, standalone `tests/e2e/test_smoke_ant_teams_dry_run.sh`, and `for f in tests/test_*.js; do node "$f"; done` all passed.
- Runtime Requirement: Use the issue-8 worktree for smoke; live-checkout dry-run smoke must compare tracked hashes, untracked-file lists, and direct hashes of init-managed artifacts because `.github-project.json` and `AGENTS.md` may be absent in the source checkout.
- Verification Command: `tests/run_e2e_tests.sh`; `tests/e2e/test_e2e_idempotent.sh`; `tests/e2e/test_smoke_ant_teams_dry_run.sh`; `for f in tests/test_*.js; do node "$f"; done`
- Known Gap: Live smoke treats missing `.github-project.json` / `AGENTS.md` as expected pending issue #11; metadata validation only runs when those files exist.
- Related Docs: `docs/spec/SPEC-001-init-project-tailored-repo-bootstrap.md`, `docs/arch/ARCH-003-project-local-initialization-artifacts.md`, PR #19, issue #8


### 2026-08-01 - SPEC-001 / #11

- Context: Reviewed PR #20 self-init against ARCH-003 and issue #11 handover.
- Smoke Result: Pass; ran `bash scripts/validate-agents-md.sh AGENTS.md` and `for f in tests/test_*.js; do node "$f"; done` in the PR worktree.
- Runtime Requirement: Run validator and suite from a full repo checkout/worktree; extracted single files fail path-existence checks because AGENTS.md references sibling repo-root artifacts.
- Verification Command: `bash scripts/validate-agents-md.sh AGENTS.md`; `for f in tests/test_*.js; do node "$f"; done`
- Known Gap: None.
- Related Docs: SPEC-001, ARCH-003, PR #20, issue #11.

### 2026-08-01 - SPEC-001 / #11 (PR #20, loop 1 — approved)

- Context: Reviewed PR #20 — self-initialization of ant-teams with upgraded init-project v0.3.0. 4 additive files. Verified validator, test suite, idempotency, and .github-project.json field retention.
- Smoke Result: Pass. `validate-agents-md.sh AGENTS.md` → 11/11. Full test suite → 466/466 assertions, 0 failures. Idempotent rerun → exit 0.
- Runtime Requirement: Worktree-based verification — run from a clean worktree at `~/Projects/worktree/ant-teams/issue-11`. Dry-run guardrail must be executed first.
- Verification Command: `bash scripts/validate-agents-md.sh AGENTS.md`; `for f in tests/test_*.js; do node "$f"; done`; `diff <(git show master:.github-project.json) .github-project.json`
- Known Gap: AC-T10-002 (Stack section) / AC-T10-004 (no extra skills) require spec-hierarchy interpretation — FR-5.3 + DM-2.3 allow Stack omission; FR-7.2/7.3 additive-only means source skills stay. Accepted under spec precedence.
- Related Docs: PR #20, issue #11, SPEC-001 FR-5.3/FR-7.2/7.3, ARCH-003
### 2026-08-01 - SPEC-001 / #10 (PR #21)

- Context: Reviewed docs-only PR #21 against SPEC-001 / ARCH-003 with full regression + validator smoke.
- Smoke Result: Pass for `bash scripts/validate-agents-md.sh AGENTS.md`, full JS suite, and `tests/run_e2e_tests.sh`; `scripts/validate-project-state.sh` failed on current repo-board/spec linkage and should not be treated as a PR regression without board sync.
- Runtime Requirement: Run review smoke from a clean/consistent repo state; `validate-project-state.sh` is sensitive to local board/spec path conventions.
- Verification Command: `bash scripts/validate-agents-md.sh AGENTS.md`; `for f in tests/test_*.js; do node "$f"; done`; `tests/run_e2e_tests.sh`; `bash scripts/validate-project-state.sh`
- Known Gap: No new durable memory beyond the board validator behavior.
- Related Docs: `docs/spec/SPEC-001-init-project-tailored-repo-bootstrap.md`, `docs/arch/ARCH-003-project-local-initialization-artifacts.md`, PR #21, issue #10

### 2026-08-01 - SPEC-001 / #10 (PR #21, approval)

- Context: Re-reviewed PR #21 after the README.md revert. Final diff stayed within the authorized docs-only files and the issue #10 review loop cleared.
- Smoke Result: Pass; PR-tree checks showed `README.md` absent from the net diff, `docs/DOCUMENT_INDEX.md` paths resolve, `bash scripts/validate-agents-md.sh AGENTS.md` passes, `for f in tests/test_*.js; do node "$f"; done` passes, and `tests/run_e2e_tests.sh` passes in the PR worktree.
- Runtime Requirement: Use a clean detached PR worktree for smoke verification when the main checkout contains unrelated untracked files; if the GitHub review API blocks self-approval, record approval as an explicit PR comment instead.
- Verification Command: `git diff --name-only master..pr-21`; `node -e "...DOCUMENT_INDEX path resolution against pr-21..."`; `bash scripts/validate-agents-md.sh AGENTS.md`; `for f in tests/test_*.js; do node "$f"; done`; `tests/run_e2e_tests.sh`
- Known Gap: None.
- Related Docs: `docs/spec/SPEC-001-init-project-tailored-repo-bootstrap.md`, `docs/arch/ARCH-003-project-local-initialization-artifacts.md`, PR #21, issue #10.

### 2026-08-01 - SPEC-001 / Milestone #1 closed

- Context: Milestone #1 closed by tech-lead after PR #21 merged and all 10 SPEC-001 execution issues (#2-#11) verified Done. All 12 spec-level acceptance criteria covered. Full regression suites green (466 unit + 10 e2e + 11 validator).
- Smoke Result: N/A — reviewer approved #10 in prior loop. Tech-lead performed final spec-alignment check, merge, and milestone closure.
- Runtime Requirement: N/A.
- Verification Command: N/A — the reviewer's approval comment on PR #21 was the final verification gate for issue #10. Milestone closure confirmed all issues Done.
- Known Gap: README.md remains stale (pre-init-upgrade description). Separate follow-up issue needed. `~/.agents` dual-home install is founder idea outside SPEC-001 scope.
- Related Docs: PR #21, issue #10, milestone #1, `docs/spec/SPEC-001-init-project-tailored-repo-bootstrap.md`, `docs/arch/ARCH-003-project-local-initialization-artifacts.md`

### 2026-08-02 - SPEC-002 / #22 (re-review)

- Context: Re-reviewed PR #26 after commit d328598. Provided smoke and repo regressions passed, but a targeted nested-path collision check still aborts when a non-directory occupies a managed subpath parent (for example `project-initialization/scripts` as a file).
- Smoke Result: Mixed; manifest-missing recovery, top-level unmanaged-file collision skip, permission floor, dry-run, idempotency, and SPEC-001 regressions passed; nested managed-subpath file collision still exits 5 from `mkdir -p`.
- Runtime Requirement: For managed-sync smoke, test both top-level unmanaged files and nested non-directory parents inside managed entry trees; the latter is a distinct collision class from entry-name collisions.
- Verification Command: `bash -n scripts/sync-managed-skills.sh`; `tests/e2e/test_smoke_sync_managed_skills.sh`; `tests/run_e2e_tests.sh`; targeted nested-collision repro with a file at `~/.agents/skills/project-initialization/scripts`.
- Known Gap: `write_target_file()` only guards the entry directory and the target file itself; a regular file in an intermediate managed path still causes a filesystem abort instead of a skip.
- Related Docs: `docs/spec/SPEC-002-managed-global-skill-sync-and-command-derived-skills.md`, `docs/arch/ARCH-004-managed-skill-sync-architecture.md`, PR #26, issue #22



### 2026-08-02 - SPEC-002 / #22 (PR #26, approval)

- Context: Approved commit b27bc4e after re-reviewing the managed-sync engine and the added regression smoke.
- Smoke Result: Pass; symlink-ancestor escape closed, SEC-3.2 literal permission tightening verified, and prior repo regressions remained green.
- Runtime Requirement: Run managed-sync smoke from a detached worktree with temp HOME; keep a separate escape-dir repro for symlink ancestry.
- Verification Command: `bash -n scripts/sync-managed-skills.sh`; `tests/e2e/test_smoke_sync_managed_skills.sh`; `bash scripts/validate-agents-md.sh AGENTS.md`; `for f in tests/test_*.js; do node "$f"; done`; `tests/run_e2e_tests.sh`.
- Known Gap: None open after approval.
- Related Docs: `docs/spec/SPEC-002-managed-global-skill-sync-and-command-derived-skills.md`, `docs/arch/ARCH-004-managed-skill-sync-architecture.md`, PR #26, issue #22

### 2026-08-02 - SPEC-002 / #22 (PR #26, merged to Done)

- Context: PR #26 merged by tech-lead after final spec-alignment check at commit `b27bc4e`. Reviewer approved on loop 4 without remaining blockers. No new durable memory — approval and merge were routine.
- Smoke Result: N/A — reviewer approved in prior loop; tech-lead performed final check and merge.
- Runtime Requirement: N/A
- Verification Command: N/A
- Known Gap: None — all 4 review loops resolved. SEC-5.2 symlink boundary closed, SEC-3.2 literal permission tightening verified. 70/70 regression smoke.
- Related Docs: PR #26, issue #22

### 2026-08-03 - SPEC-002 / #24 (PR #28, review loop 1)

- Context: Reviewed the SPEC-002-T3 managed-sync test-suite PR (#28). Test-only scope held: 31 new files under `tests/`, no `scripts/` or prior test/doc edits.
- Smoke Result: Pass; `bash tests/run_sync_tests.sh` passed 29/29 scenarios, and representative `test_sync_int_command_transform.sh` / `test_sync_int_boundary_enforcement.sh` passed.
- Runtime Requirement: Use a detached PR worktree with temp HOME; the suite’s helper copies the real sync script into a fixture repo and overrides HOME so real `~/.agents/skills` / `~/.config/opencode` are never touched.
- Verification Command: `bash tests/run_sync_tests.sh`; `bash tests/test_sync_int_command_transform.sh`; `bash tests/test_sync_int_boundary_enforcement.sh`.
- Known Gap: ERR-1.2 (unreadable command source) is still not covered by a passing test, so TEST-4.2 is not fully satisfied without a tech-lead/spec decision.
- Related Docs: `docs/spec/SPEC-002-managed-global-skill-sync-and-command-derived-skills.md`, `docs/arch/ARCH-004-managed-skill-sync-architecture.md`, PR #28, issue #24.


### 2026-08-03 - SPEC-002 / Milestone #2 closed

- Context: Milestone #2 (SPEC-002) closed by tech-lead after PR #29 merged and all 4 execution issues (#22-#25) verified Done. All 10 spec-level acceptance criteria covered. Full regression suites green (29 sync scenarios + 70 smoke assertions + 8 JS suites 466 assertions + AGENTS.md 11/11).
- Smoke Result: N/A — reviewer approved #25 (PR #29) in prior loop. Tech-lead performed final spec-alignment check, admin merge, and milestone closure.
- Runtime Requirement: N/A.
- Verification Command: N/A — the reviewer's approval comment on PR #29 was the final verification gate for issue #25. Milestone closure confirmed all issues Done.
- Known Gap: README Install Model bullet updated for managed sync; the broader README structure (Start Here steps) remains pre-SPEC-002. No README rewrite scope in this milestone.
- Related Docs: PR #29, issue #25, milestone #2, ARCH-004, SPEC-002, RB-001.
