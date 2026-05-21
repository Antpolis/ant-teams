#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/update-company.sh [--mode global|project] [--global-root PATH] [--project-dir PATH] [--docs-root docs]

Refresh the one-person-company install from this source tree.

Modes:
  global   Update the global opencode company install.
  project  Update a project repo install.

Examples:
  scripts/update-company.sh
  scripts/update-company.sh --mode global
  scripts/update-company.sh --mode project --project-dir ~/projects/my-app
USAGE
}

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mode=""
global_root="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
project_dir="$(pwd)"
docs_root="docs"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      mode="${2:-}"
      shift 2
      ;;
    --global-root)
      global_root="${2:-}"
      shift 2
      ;;
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

if [[ -z "$mode" ]]; then
  mode="global"
fi

global_root="$(mkdir -p "$global_root" && cd "$global_root" && pwd)"
project_dir="$(mkdir -p "$project_dir" && cd "$project_dir" && pwd)"

copy_tree_overwrite() {
  local source="$1"
  local destination="$2"

  if [[ ! -e "$source" ]]; then
    return 0
  fi

  mkdir -p "$destination"
  cp -R "$source"/. "$destination"/
}

copy_file_overwrite() {
  local source="$1"
  local destination="$2"

  if [[ -f "$source" ]]; then
    mkdir -p "$(dirname "$destination")"
    cp "$source" "$destination"
  fi
}

echo "Source: $script_root"
echo "Mode: $mode"

case "$mode" in
  global)
    echo "Global root: $global_root"
    copy_tree_overwrite "$script_root/.opencode/tools" "$global_root/tools"
    copy_tree_overwrite "$script_root/.opencode/skills" "$global_root/skills"
    copy_tree_overwrite "$script_root/.opencode/plugins" "$global_root/plugins"
    copy_tree_overwrite "$script_root/.opencode/commands" "$global_root/commands"
    copy_tree_overwrite "$script_root/docs" "$global_root/docs"
    copy_tree_overwrite "$script_root/scripts" "$global_root/scripts"
    rm -rf "$global_root/agents"
    rm -f "$global_root/package.json"
    copy_file_overwrite "$script_root/.opencode/opencode.json" "$global_root/opencode.json"
    copy_file_overwrite "$script_root/README.md" "$global_root/README.md"
    copy_file_overwrite "$script_root/.gitignore" "$global_root/.gitignore"
    bash "$global_root/scripts/setup-doc-structure.sh" "$global_root/docs"
    echo "Updated global company workflow."
    ;;
  project)
    echo "Project root: $project_dir"
    copy_tree_overwrite "$script_root/.opencode/tools" "$project_dir/.opencode/tools"
    copy_tree_overwrite "$script_root/.opencode/skills" "$project_dir/.opencode/skills"
    copy_tree_overwrite "$script_root/.opencode/plugins" "$project_dir/.opencode/plugins"
    copy_tree_overwrite "$script_root/.opencode/commands" "$project_dir/.opencode/commands"
    copy_tree_overwrite "$script_root/docs" "$project_dir/$docs_root"
    copy_tree_overwrite "$script_root/scripts" "$project_dir/scripts"
    rm -rf "$project_dir/.opencode/agents"
    rm -f "$project_dir/.opencode/package.json"
    copy_file_overwrite "$script_root/.opencode/opencode.json" "$project_dir/.opencode/opencode.json"
    copy_file_overwrite "$script_root/README.md" "$project_dir/README.md"
    copy_file_overwrite "$script_root/.gitignore" "$project_dir/.gitignore"
    bash "$project_dir/scripts/setup-doc-structure.sh" "$docs_root"
    echo "Updated project company workflow."
    ;;
  *)
    echo "Invalid mode: $mode" >&2
    usage >&2
    exit 1
    ;;
esac
