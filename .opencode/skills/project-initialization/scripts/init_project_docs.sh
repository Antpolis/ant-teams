#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ./.opencode/skills/project-initialization/scripts/init_project_docs.sh [--project-dir PATH] [--docs-root docs] [--worktree-root PATH]

Copy the company docs into a project repo and create the local workflow-state folder structure.

This command copies the company docs into the project and creates the local
workflow-state folder structure. It is meant for project-specific overrides
that sit alongside the global company defaults.

Use project-local workflow state by running workflow scripts from the project
repo with `DOC_ROOT=docs` (or `DOC_ROOT=.docs` if you chose the hidden docs tree).

Examples:
  ./.opencode/skills/project-initialization/scripts/init_project_docs.sh
  ./.opencode/skills/project-initialization/scripts/init_project_docs.sh --project-dir ~/projects/my-app
  ./.opencode/skills/project-initialization/scripts/init_project_docs.sh --project-dir ~/projects/my-app --docs-root .docs
  ./.opencode/skills/project-initialization/scripts/init_project_docs.sh --project-dir ~/projects/my-app --worktree-root ~/Projects/worktree/my-app
USAGE
}

expand_path() {
  local path="$1"
  case "$path" in
    "~") printf '%s\n' "$HOME" ;;
    "~/"*) printf '%s/%s\n' "$HOME" "${path#~/}" ;;
    *) printf '%s\n' "$path" ;;
  esac
}

ensure_opencode_config() {
  local project_dir="$1"
  local worktree_root="$2"
  local external_pattern="${worktree_root%/}/**"
  local config_path=""

  if [[ -f "$project_dir/opencode.jsonc" ]]; then
    config_path="$project_dir/opencode.jsonc"
  elif [[ -f "$project_dir/opencode.json" ]]; then
    config_path="$project_dir/opencode.json"
  else
    config_path="$project_dir/opencode.jsonc"
    cat > "$config_path" <<'EOF'
{
  "permission": {
    "external_directory": {}
  }
}
EOF
    echo "Created repo config at $config_path"
  fi

  node - "$config_path" "$external_pattern" <<'NODE'
const fs = require("fs");

const [configPath, externalPattern] = process.argv.slice(2);
const raw = fs.readFileSync(configPath, "utf8");
const stripped = stripJsonComments(raw);

let parsed;
try {
  parsed = JSON.parse(removeTrailingCommas(stripped));
} catch (error) {
  console.error(`Failed to parse ${configPath}: ${error.message}`);
  process.exit(1);
}

if (!parsed.permission || typeof parsed.permission !== "object" || Array.isArray(parsed.permission)) {
  parsed.permission = {};
}
if (!parsed.permission.external_directory || typeof parsed.permission.external_directory !== "object" || Array.isArray(parsed.permission.external_directory)) {
  parsed.permission.external_directory = {};
}

if (parsed.permission.external_directory[externalPattern] === "allow") {
  process.exit(0);
}

parsed.permission.external_directory[externalPattern] = "allow";
fs.writeFileSync(configPath, JSON.stringify(parsed, null, 2) + "\n");

function stripJsonComments(input) {
  let output = "";
  let inString = false;
  let stringChar = "";
  let escaping = false;

  for (let i = 0; i < input.length; i += 1) {
    const char = input[i];
    const next = input[i + 1];

    if (inString) {
      output += char;
      if (escaping) {
        escaping = false;
      } else if (char === "\\") {
        escaping = true;
      } else if (char === stringChar) {
        inString = false;
        stringChar = "";
      }
      continue;
    }

    if (char === '"' || char === "'") {
      inString = true;
      stringChar = char;
      output += char;
      continue;
    }

    if (char === "/" && next === "/") {
      while (i < input.length && input[i] !== "\n") i += 1;
      output += "\n";
      continue;
    }

    if (char === "/" && next === "*") {
      i += 2;
      while (i < input.length && !(input[i] === "*" && input[i + 1] === "/")) i += 1;
      i += 1;
      continue;
    }

    output += char;
  }

  return output;
}

function removeTrailingCommas(input) {
  return input.replace(/,\s*([}\]])/g, "$1");
}
NODE

  echo "Ensured external directory permission in $config_path"
}

# FR-7.4 / AC-T4-006: ensure `.opencode/.gitignore` exists with a `node_modules`
# entry so generated dependencies are never committed accidentally. Existing
# entries are preserved verbatim; only the missing `node_modules` line is added.
ensure_opencode_gitignore() {
  local opencode_dir="$1"
  local gitignore_path="$opencode_dir/.gitignore"
  local required_entry="node_modules"

  mkdir -p "$opencode_dir"

  if [[ ! -f "$gitignore_path" ]]; then
    printf '%s\n' "$required_entry" > "$gitignore_path"
    echo "[writing] .opencode/.gitignore"
    return 0
  fi

  if ! grep -Fxq "$required_entry" "$gitignore_path" 2>/dev/null; then
    printf '%s\n' "$required_entry" >> "$gitignore_path"
    echo "[writing] .opencode/.gitignore (node_modules entry added)"
  fi
}

# FR-7.1 / FR-7.2 / FR-7.3 / SEC-3.2: copy the three required script-bearing
# skills (github-issues-projects-cli, do-task, project-initialization) from the
# source repo into the project-local `.opencode/skills/` directory. Copy is a
# per-file merge: every regular source file is copied when absent at target and
# preserved when already present (this is what protects project-customized
# SKILL.md files). Execute bits travel with the source via `cp -p`. No other
# skill is ever copied.
copy_required_skills() {
  local project_dir="$1"
  local repo_root="$2"
  local source_skills_dir="$repo_root/.opencode/skills"
  local target_skills_dir="$project_dir/.opencode/skills"
  local -a required_skills=(
    "github-issues-projects-cli"
    "do-task"
    "project-initialization"
  )
  local -a excluded_skills=(
    "skill-creator"
    "webapp-testing"
    "doc-coauthoring"
    "frontend-design"
  )

  mkdir -p "$target_skills_dir"
  ensure_opencode_gitignore "$project_dir/.opencode"

  local total_copied=0
  local total_merged=0

  for skill_name in "${required_skills[@]}"; do
    local src_skill_dir="$source_skills_dir/$skill_name"
    local tgt_skill_dir="$target_skills_dir/$skill_name"

    if [[ ! -d "$src_skill_dir" ]]; then
      echo "[warning] Required skill source not found: $src_skill_dir" >&2
      continue
    fi

    mkdir -p "$tgt_skill_dir"

    while IFS= read -r -d '' src_file; do
      local rel="${src_file#"$src_skill_dir"/}"
      local tgt_file="$tgt_skill_dir/$rel"

      if [[ -e "$tgt_file" ]]; then
        # FR-7.3: merge, do not overwrite. Protects customized SKILL.md and
        # any other project-local override.
        total_merged=$((total_merged + 1))
        continue
      fi

      mkdir -p "$(dirname "$tgt_file")"
      # SEC-3.2: `cp -p` preserves the source execute bit.
      cp -p "$src_file" "$tgt_file"
      echo "[writing] .opencode/skills/$skill_name/$rel"
      total_copied=$((total_copied + 1))
    done < <(find "$src_skill_dir" -type f -print0)
  done

  # FR-7.2: defensive check that no excluded skill directory is present at
  # target. We never write them; this only catches pre-existing stray dirs
  # that would otherwise masquerade as initializer output.
  for excluded in "${excluded_skills[@]}"; do
    if [[ -d "$target_skills_dir/$excluded" ]]; then
      echo "[warning] Excluded skill already present in target: .opencode/skills/$excluded" >&2
    fi
  done

  echo "[writing] .opencode/skills/ (${#required_skills[@]} required skills, $total_copied copied, $total_merged merged)"
}

ensure_github_project_config() {
  local project_dir="$1"
  local worktree_root="$2"
  local config_path="$project_dir/.github-project.json"

  if [[ ! -f "$config_path" ]]; then
    cat > "$config_path" <<EOF
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
  },
  "worktreeRoot": "$worktree_root"
}
EOF
    echo "Created .github-project.json"
    return 0
  fi

  node - "$config_path" "$worktree_root" <<'NODE'
const fs = require("fs");

const [configPath, worktreeRoot] = process.argv.slice(2);
const parsed = JSON.parse(fs.readFileSync(configPath, "utf8"));

if (!parsed.worktreeRoot) {
  parsed.worktreeRoot = worktreeRoot;
  fs.writeFileSync(configPath, JSON.stringify(parsed, null, 2) + "\n");
}
NODE

  echo "Ensured worktreeRoot in .github-project.json"
}

skill_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo_root="$(cd "$skill_root/../../.." && pwd)"
project_dir="$(pwd)"
docs_root="docs"
worktree_root=""

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
    --worktree-root)
      worktree_root="${2:-}"
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
repo_name="$(basename "$project_dir")"

if [[ -z "$worktree_root" ]]; then
  worktree_root="$HOME/Projects/worktree/$repo_name"
fi

worktree_root="$(expand_path "$worktree_root")"

mkdir -p "$worktree_root"
ensure_github_project_config "$project_dir" "$worktree_root"
ensure_opencode_config "$project_dir" "$worktree_root"
copy_required_skills "$project_dir" "$repo_root"

mkdir -p "$project_dir/$docs_root"
if [[ -d "$repo_root/docs" ]]; then
  cp -Rn "$repo_root/docs"/. "$project_dir/$docs_root"/
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
echo "Issue worktrees will default to $worktree_root"
