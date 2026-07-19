# Demo Bare Repository

Fixture repository for the SPEC-001-T1 inspection engine test suite (TEST-1.2
`repo-bare`). Represents a repository with no code: only a `README.md`, a
`docs/` folder, and a `.git/` directory.

Note on `.git/`: a real `.git/` directory cannot be tracked inside a fixture
because git silently ignores nested `.git/` directories. The inspect script's
`repo_origin` detection independently guards against fixtures leaking the
parent repo's remotes (it requires `git rev-parse --show-toplevel` to equal the
fixture path), so `repo_origin` is reported as `not detected` for this fixture
regardless. This README documents the `.git/` representation rather than
materializing a misleading placeholder.
