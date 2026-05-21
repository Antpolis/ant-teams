# State Transitions

Use these as default transition rules for the GitHub Project board.

## States

- `Inbox`
- `Shaping`
- `Ready`
- `In Progress`
- `In Review`
- `Blocked`
- `Done`

## Transition Rules

### Inbox -> Shaping

Allowed when:

- the idea has enough substance to evaluate

Typical owner:

- strategist

### Shaping -> Ready

Allowed when:

- founder direction is clear
- spec is written or linked
- tech-lead says the scope is technically viable
- initial task shape is clear enough to execute

Typical owner:

- strategist or tech-lead

### Ready -> In Progress

Allowed when:

- the issue has acceptance criteria
- dependencies are not blocking
- a builder is taking ownership

Typical owner:

- builder

### In Progress -> In Review

Allowed when:

- implementation is complete for the approved scope
- evidence is attached
- builder reports any known risks honestly

Typical owner:

- builder

### In Review -> In Progress

Allowed when:

- validator finds actionable issues
- the issue is not blocked on outside input

Typical owner:

- validator

### Any State -> Blocked

Allowed when:

- a dependency, decision, credential, permission, or external condition prevents safe progress

Typical owner:

- any role, with a durable blocker note

### Blocked -> Prior State

Allowed when:

- the blocking condition is resolved
- the next responsible role is explicit

Typical owner:

- role that clears the blocker or receives the clarified next step

### In Review -> Done

Allowed when:

- validator finds no blocking issues
- smoke verification is acceptable for the task
- required approvals are recorded

Typical owner:

- validator

## Rules Of Restraint

- Do not move work to `Done` because it looks close.
- Do not move work to `Ready` if the spec is still argument-shaped instead of execution-shaped.
- Do not leave work in `Blocked` without saying what is needed to unblock it.
- Do not bounce work between `In Progress` and `In Review` indefinitely; escalate recurring architectural rework.
