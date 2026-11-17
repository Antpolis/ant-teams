---
name: principle-prove-the-outcome
description: Apply before claiming a task, change, review, or verification is complete; inspect the actual artifact or behavior and report evidence and limits proportional to the claim and risk.
---

# Prove the Outcome

## Trigger

Apply before reporting that requested behavior works, a change is complete, or a finding has been verified. The evidence needed depends on what is claimed and the risk of being wrong; a documentation edit and a payment integration do not need the same checks.

## Rule

Verify the actual outcome as directly as practical. A successful build, a screenshot, a test assertion, or a delegate's summary only proves what it actually observes; do not infer the whole user-facing or integration behavior from a proxy. Prefer a focused, repeatable check when it provides useful evidence without unnecessary machinery.

## Apply

- Identify the claim and acceptance condition, then inspect the relevant artifact or exercise the actual path from input to observable result. For web work, use `webapp-testing` or another appropriate browser tool when running the UI is practical; a screenshot alone does not prove an interaction works.
- Check appropriate edge cases, failures, and integration boundaries in proportion to risk. For a bug fix, verify the reported reproduction and regression check when possible. For delegated work, inspect its actual diff, artifacts, and evidence rather than forwarding the delegate's claim.
- Keep existing security, accessibility, review, and verification requirements. During managed delivery, follow `pr-review-flow` and `task-completion` for reviewer ownership and gates; this principle does not introduce a new independent review requirement for ordinary work.
- Report what was observed, the command or artifact where useful, failures, skipped checks, and limitations. If the real path cannot be exercised, use the strongest practical evidence, clearly say what remains unverified, and do not claim completion of that check.

## Boundaries and examples

- A form change needs the relevant interaction exercised and its result observed; a successful compile or a screenshot of the form is not evidence that submission succeeds.
- For a documentation wording edit, reading the changed text and checking the diff may directly verify the claim; launching a browser or writing a test solely to satisfy this principle adds no useful evidence.
- Do not access production data, perform destructive actions, incur unauthorized cost, or bypass protections merely to obtain direct evidence. Use an authorized safe environment or report the verification gap.
