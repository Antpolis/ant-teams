---
name: release-management
description: Use when preparing a release from a completed GitHub milestone, creating or correcting a GitHub Release, recording release evidence, changelog notes, merge completion, deployment readiness, or post-validation release records. Intended for delivery or release workflow roles; not for CPO, CTO, or product-owner drafting.
---

# Release Management

Use this skill after task approval and before/after production release.

Start release work from the GitHub milestone and its completed issues. The primary release artifact is the GitHub Release feature, with the canonical release tag attached to it.

## Release starting point

When release work begins:

1. Identify the GitHub milestone that represents the spec or deliverable being shipped.
2. Confirm the milestone's required issues are completed, approved, and not still blocked or in review.
3. Gather the completed issues, merged PRs, verification evidence, and milestone context that should appear in the release record.
4. Run the required pre-release tests for both frontend and backend, capture the commands and results, and stop if either side fails.
5. Create the release in GitHub Releases using the canonical tag format for this repository.
6. Update the milestone description, closeout notes, or linked release reference so the milestone clearly points to the GitHub Release that shipped it.

Do not start by writing only a local note or issue comment when the intent is to ship. Start by creating or correcting the GitHub Release itself.

## Release tag format

Use this repository release tag format:

- `VX.Y.Z-spN`

Interpret the segments like this:

- `V` is the literal version prefix.
- `X` is the major release number. Increment it when the release introduces a renewed release line, typically because frontend changes or new infrastructure are added to core features.
- `Y` is the spec increment. Increment it when a new spec is added.
- `Z` is the bug-fix increment. Increment it for bug-fix-only releases.
- `-spN` is the sprint patch suffix. Start at `-sp1` and increment it as needed. Use it to force a release for non-code or release-process needs, including cases where the release pipeline must still run.

Examples:

- `V1.1.0-sp1`: first release line, one new spec increment, no bug-fix increment, first sprint patch release trigger.
- `V2.0.0-sp1`: renewed release line because core frontend or infrastructure changed, first sprint patch release for that line.
- `V2.3.4-sp2`: established release line, third spec increment, fourth bug-fix increment, second sprint patch trigger for that base version.

Rules:

- Treat the `-spN` suffix as required for releases created through the GitHub release flow in this repository because all releases should trigger the release CI/CD pipeline.
- If an existing release or tag uses the wrong format, recreate or retag it into the canonical format and update the linked milestone or release records to point to the corrected tag.
- When a milestone or release note references a release identifier, use the full canonical tag, including the `-spN` suffix.

## GitHub Release rules

Use GitHub Releases as the canonical shipped-release record for this repository.

A release flow should:

- start from the milestone being shipped
- run frontend and backend tests before creating the final release
- create or correct the GitHub Release first
- attach the canonical tag to that GitHub Release
- summarize which milestone and issues the release includes
- explicitly list the issues resolved by the release
- link verification or deployment evidence from the release notes or nearby GitHub collaboration surface
- update milestone references so the shipped milestone points to the correct release tag and release URL

If the milestone is complete but no GitHub Release exists yet, create it.
If the GitHub Release exists but uses the wrong tag format, recreate or retag it into the canonical format and then repair the milestone linkage.

## Test gate before release

Before creating or finalizing a release:

- run the repository's frontend test suite
- run the repository's backend test suite
- capture the exact commands used
- capture whether each suite passed or failed
- if either suite fails, do not finalize the release until the failure is resolved or an explicit human release decision says otherwise

If the repository has more than one reasonable frontend or backend verification command, use the strongest standard pre-release command for each side rather than the fastest partial check.

## Release note test section

GitHub release notes must include a test-results section that records both frontend and backend verification.

Use a section like:

- `Frontend tests`: command and result
- `Backend tests`: command and result

If relevant, also include short notes about skipped tests, known limitations, or why an exception was approved.

## Release note resolved issues section

GitHub release notes must always include the issues resolved by the release.

Use a section like:

- `Resolved issues`
- one line per issue with the issue number and short title

If the release ships only part of a milestone, list only the issues actually resolved by that release rather than every issue in the milestone.

Release records should live in the appropriate GitHub collaboration surface, such as release notes, milestone closeout notes, issue comments, PR comments, or linked deployment evidence.

Release records must include:

- release ID
- spec/milestone and issue when relevant
- resolved issue list
- version or deployment identifier
- GitHub Release URL when available
- frontend test command and result
- backend test command and result
- evidence
- date

Release readiness should confirm:

- milestone exists and is the release starting point
- milestone issues required for the release are complete
- task is `Approved` or `Done`
- reviewer approved
- frontend tests passed
- backend tests passed
- lightweight smoke verification passed
- required checks passed
- GitHub collaboration record updated
- role memory updated if a durable lesson was learned
