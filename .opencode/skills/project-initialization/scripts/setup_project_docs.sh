#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  setup_project_docs.sh [DOC_ROOT]

Arguments:
  DOC_ROOT   Root documentation folder. Defaults to docs.

What it creates:
  <DOC_ROOT>/adr/README.md
  <DOC_ROOT>/architecture/README.md
  <DOC_ROOT>/governance/README.md
  agent.md
  .github-project.env (placeholder ANT_TEAM_* runtime config)

Notes:
  - Safe to rerun.
  - Does not overwrite existing README.md files.
  - Deprecated lightweight scaffold; prefer the canonical
    init-project-docs.sh initializer.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

doc_root="${1:-docs}"
skill_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "$doc_root/adr" "$doc_root/architecture" "$doc_root/governance"

copy_if_missing() {
  local src="$1"
  local dest="$2"
  if [[ ! -f "$dest" ]]; then
    cp "$src" "$dest"
    echo "Created $dest"
  else
    echo "Exists  $dest"
  fi
}

copy_if_missing "$skill_dir/assets/adr-folder-readme.md" "$doc_root/adr/README.md"
copy_if_missing "$skill_dir/assets/architecture-folder-readme.md" "$doc_root/architecture/README.md"
copy_if_missing "$skill_dir/assets/governance-folder-readme.md" "$doc_root/governance/README.md"

if [[ ! -f "agent.md" ]]; then
  DOC_ROOT_VALUE="$doc_root" perl -0pe 's/__DOC_ROOT__/$ENV{DOC_ROOT_VALUE}/g' \
    "$skill_dir/assets/agent-md-template.md" > "agent.md"
  echo "Created agent.md"
else
  echo "Exists  agent.md"
fi

if [[ ! -f ".github-project.env" ]]; then
  cat > ".github-project.env" <<'EOF'
# Project runtime configuration (ANT_TEAM_* exports) — the sole committed project config source.
# Seeded and updated by init-project: existing values are preserved, missing keys are filled.
# Edit values directly; re-running init-project never overwrites a value already set here.
# Safe to commit: shared project metadata only, no secrets.

export ANT_TEAM_GITHUB_OWNER='your-github-owner'
export ANT_TEAM_GITHUB_OWNER_TYPE='org'
export ANT_TEAM_GITHUB_REPO='your-github-owner/your-repo'
export ANT_TEAM_GITHUB_PROJECT_NUMBER='1'
export ANT_TEAM_GITHUB_PROJECT_ID='PVT_kwDOEXAMPLE'
export ANT_TEAM_GITHUB_WORKFLOW_STATE_FIELD_ID='workflow-state-field-id'
export ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_OPEN_ID='open-option-id'
export ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_BACKLOG_ID='backlog-option-id'
export ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_NEED_ATTENTIONS_ID='need-attentions-option-id'
export ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_READY_ID='ready-option-id'
export ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_IN_PROGRESS_ID='in-progress-option-id'
export ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_IN_REVIEW_ID='in-review-option-id'
export ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_READY_TO_MERGE_ID='ready-to-merge-option-id'
export ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_BLOCKED_ID='blocked-option-id'
export ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_DONE_ID='done-option-id'
EOF
  echo "Created .github-project.env"
else
  echo "Exists  .github-project.env"
fi

echo "Project docs scaffolding ready under $doc_root"
