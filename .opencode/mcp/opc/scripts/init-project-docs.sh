#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/init-project-docs.sh [--project-dir PATH] [--docs-root docs]

Copy the company docs into a project repo and create the local workflow-state folder structure.

This command copies the company docs into the project and creates the local
workflow-state folder structure. It is meant for project-specific overrides
that sit alongside the global company defaults.

Use project-local workflow state by running workflow scripts from the project
repo with `DOC_ROOT=docs` (or `DOC_ROOT=.docs` if you chose the hidden docs tree).

Examples:
  scripts/init-project-docs.sh
  scripts/init-project-docs.sh --project-dir ~/projects/my-app
  scripts/init-project-docs.sh --project-dir ~/projects/my-app --docs-root .docs
USAGE
}

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_dir="$(pwd)"
docs_root="docs"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-dir)
      project_dir="${2:-}"
      shift 2
      ;;
    --docs-root)
      docs_root="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

project_dir="$(mkdir -p "$project_dir" && cd "$project_dir" && pwd)"
docs_root="${docs_root%/}"

mkdir -p "$project_dir/$docs_root"
if [[ -d "$script_root/docs" ]]; then
  cp -Rn "$script_root/docs"/. "$project_dir/$docs_root"/
fi

mkdir -p \
  "$project_dir/$docs_root/adr" \
  "$project_dir/$docs_root/gov" \
  "$project_dir/$docs_root/arch" \
  "$project_dir/$docs_root/spec" \
  "$project_dir/$docs_root/runbook" \
  "$project_dir/$docs_root/qa" \
  "$project_dir/$docs_root/memory" \
  "$project_dir/$docs_root/proj-management/tasks" \
  "$project_dir/$docs_root/proj-management/communication" \
  "$project_dir/$docs_root/proj-management/templates"

echo "Created project docs folders under $project_dir/$docs_root"
echo "Use DOC_ROOT=$docs_root when running workflow scripts for this project."
