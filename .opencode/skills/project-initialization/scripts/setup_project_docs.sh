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
  .github-project.json

Notes:
  - Safe to rerun.
  - Does not overwrite existing README.md files.
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

if [[ ! -f ".github-project.json" ]]; then
  cat > ".github-project.json" <<'EOF'
{
  "owner": "your-github-owner",
  "owner_type": "org",
  "repo": "your-github-owner/your-repo",
  "project": {
    "number": 1,
    "id": "PVT_kwDOEXAMPLE"
  },
  "fields": {
    "status": "PVTSSF_EXAMPLE"
  },
  "status_options": {
    "todo": "todo-option-id",
    "in-progress": "in-progress-option-id",
    "in-review": "in-review-option-id",
    "done": "done-option-id"
  }
}
EOF
  echo "Created .github-project.json"
else
  echo "Exists  .github-project.json"
fi

echo "Project docs scaffolding ready under $doc_root"
