#!/usr/bin/env bash
#
# record-communication.sh — record and list agent communication event files in
# the central Obsidian project folder.
#
# Implements the record/list MVP of the agent-communication-log convention:
# one Markdown file per communication event, created from the APPROVED
# "Agent Communication Template" in the central vault. The event format is
# owned by that template and the agent-communication-log skill; this helper
# never invents or alters the format.
#
# Boundaries (by design):
#   - Obsidian-only writes: files are created only under
#     $ANT_TEAM_DOCS_PROJECT_PATH/agent-communication/. This helper never
#     posts GitHub comments, never calls gh, and never writes role memory
#     (agent-memory files are append-only records owned by their roles).
#   - ./.github-project.env must be sourced from the initialized project root
#     (the current directory) to resolve the vault and project paths.
#   - If the approved template is missing, the helper stops and says so; it
#     does not fall back to an embedded format.
#
# Usage:
#   record-communication.sh record --issue <number> | --milestone <slug>
#                                  --from <role> --to <role> --type <type>
#                                  --title <title>
#                                  [--status open|closed] [--pr <number|url>]
#                                  [--state <state>] [--summary <text>]
#   record-communication.sh list --issue <number> | --milestone <slug> | --all
#
# Event filename (fixed by the convention): YYYY-MM-DD-<from>-<title-slug>-<status>.md
# with a title of five words or fewer.
#
# Exit codes:
#   0  success
#   1  usage error, missing environment, missing template, or invalid input
#   2  the target event file already exists (never overwritten)
#
set -euo pipefail

TEMPLATE_RELPATH="01-Architecture-Meta/Templates/Agent Communication Template.md"

usage() {
  cat <<'USAGE'
Usage:
  record-communication.sh record --issue <number> | --milestone <slug>
                                 --from <role> --to <role> --type <type>
                                 --title <title>
                                 [--status open|closed] [--pr <number|url>]
                                 [--state <state>] [--summary <text>]
  record-communication.sh list --issue <number> | --milestone <slug> | --all

Records or lists agent communication events under
$ANT_TEAM_DOCS_PROJECT_PATH/agent-communication/ using the approved central
vault template. Run from the initialized project root (requires
./.github-project.env). Obsidian-only writes; no GitHub comment writes.
USAGE
}

die() {
  echo "record-communication: $1" >&2
  exit "${2:-1}"
}

# ---------------------------------------------------------------------------
# Environment resolution (project root = current directory).
# ---------------------------------------------------------------------------

load_project_env() {
  local env_file="$PWD/.github-project.env"
  if [[ ! -f "$env_file" ]]; then
    die "no ./.github-project.env found in $PWD — run from the initialized project root (see scripts/init-project.sh)"
  fi
  # shellcheck disable=SC1091
  source "$env_file"

  if [[ -z "${ANT_TEAM_DOCS_VAULT_PATH:-}" || -z "${ANT_TEAM_DOCS_PROJECT_PATH:-}" ]]; then
    die "ANT_TEAM_DOCS_VAULT_PATH / ANT_TEAM_DOCS_PROJECT_PATH are not set in .github-project.env — re-run project initialization"
  fi
  if [[ ! -d "$ANT_TEAM_DOCS_VAULT_PATH" ]]; then
    die "ANT_TEAM_DOCS_VAULT_PATH is not a directory: $ANT_TEAM_DOCS_VAULT_PATH"
  fi
  if [[ ! -d "$ANT_TEAM_DOCS_PROJECT_PATH" ]]; then
    die "ANT_TEAM_DOCS_PROJECT_PATH is not a directory: $ANT_TEAM_DOCS_PROJECT_PATH"
  fi
}

template_path() {
  printf '%s/%s' "$ANT_TEAM_DOCS_VAULT_PATH" "$TEMPLATE_RELPATH"
}

# ---------------------------------------------------------------------------
# Input normalization and validation.
# ---------------------------------------------------------------------------

slugify() {
  local s="$1"
  s="$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
  printf '%s' "$s"
}

validate_slug() {
  local value="$1" label="$2"
  [[ "$value" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "--$label must be lowercase letters, digits, and hyphens (got: $value)"
}

# ---------------------------------------------------------------------------
# record — create one event file from the approved template.
# ---------------------------------------------------------------------------

cmd_record() {
  local issue="" milestone="" from="" to="" type="" title="" status="open" pr="" state="" summary=""

  # Resolve the project environment first: GitHub URL construction below reads
  # the ANT_TEAM_* exports from ./.github-project.env.
  load_project_env

  # require_value FLAG — die with a clear message when a flag value is missing.
  require_value() {
    [[ $# -ge 2 && -n "$2" ]] || die "missing value for $1"
  }

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --issue) require_value "$@"; issue="$2"; shift 2 ;;
      --milestone) require_value "$@"; milestone="$2"; shift 2 ;;
      --from) require_value "$@"; from="$2"; shift 2 ;;
      --to) require_value "$@"; to="$2"; shift 2 ;;
      --type) require_value "$@"; type="$2"; shift 2 ;;
      --title) require_value "$@"; title="$2"; shift 2 ;;
      --status) require_value "$@"; status="$2"; shift 2 ;;
      --pr) require_value "$@"; pr="$2"; shift 2 ;;
      --state) require_value "$@"; state="$2"; shift 2 ;;
      --summary) require_value "$@"; summary="$2"; shift 2 ;;
      *) usage >&2; exit 1 ;;
    esac
  done

  [[ -n "$issue" || -n "$milestone" ]] || { usage >&2; exit 1; }
  if [[ -n "$issue" && -n "$milestone" ]]; then
    die "pass either --issue or --milestone, not both"
  fi
  [[ -n "$from" ]] || die "--from is required (stable lowercase role name)"
  [[ -n "$to" ]] || die "--to is required (stable lowercase role name)"
  [[ -n "$type" ]] || die "--type is required (e.g. handoff, review, blocker, decision)"
  [[ -n "$title" ]] || die "--title is required (five words or fewer)"
  [[ "$status" == "open" || "$status" == "closed" ]] || die "--status must be open or closed (got: $status)"
  [[ -z "$issue" || "$issue" =~ ^[0-9]+$ ]] || die "--issue must be a GitHub issue number (got: $issue)"

  from="$(slugify "$from")"
  to="$(slugify "$to")"
  type="$(slugify "$type")"
  validate_slug "$from" "from"
  validate_slug "$to" "to"
  validate_slug "$type" "type"

  local title_slug
  title_slug="$(slugify "$title")"
  [[ -n "$title_slug" ]] || die "--title must contain at least one letter or digit"
  local word_count
  word_count="$(printf '%s' "$title_slug" | awk -F'-' '{ print NF }')"
  (( word_count <= 5 )) || die "--title must be five words or fewer (got $word_count words: $title_slug)"

  if [[ -n "$milestone" ]]; then
    milestone="$(slugify "$milestone")"
    validate_slug "$milestone" "milestone"
  fi

  local github_issue_value="" github_pr_value=""
  if [[ -n "$issue" && -n "${ANT_TEAM_GITHUB_REPO:-}" ]]; then
    github_issue_value="https://github.com/$ANT_TEAM_GITHUB_REPO/issues/$issue"
  fi
  if [[ -n "$pr" ]]; then
    if [[ "$pr" =~ ^https?:// ]]; then
      github_pr_value="$pr"
    elif [[ "$pr" =~ ^[0-9]+$ ]]; then
      github_pr_value="https://github.com/${ANT_TEAM_GITHUB_REPO:-<repo>}/pull/$pr"
    else
      die "--pr must be a PR number or URL (got: $pr)"
    fi
  fi

  local template scope_dir scope_tag event_date target
  template="$(template_path)"
  [[ -f "$template" ]] || die "approved Agent Communication template not found: $template — request one before recording (do not invent the format)"

  if [[ -n "$issue" ]]; then
    scope_dir="issues/issue-$issue"
    scope_tag="issue/$issue"
  else
    scope_dir="milestones/$milestone"
    scope_tag="milestone/$milestone"
  fi

  event_date="$(date +%Y-%m-%d)"
  local comm_root="$ANT_TEAM_DOCS_PROJECT_PATH/agent-communication"
  target="$comm_root/$scope_dir/${event_date}-${from}-${title_slug}-${status}.md"

  # Boundary guard: the event file must stay inside the communication root.
  case "$target" in
    "$comm_root"/*) ;;
    *) die "resolved target escapes the communication root: $target" ;;
  esac

  if [[ -e "$target" ]]; then
    die "event file already exists (never overwritten): $target" 2
  fi

  mkdir -p "$(dirname "$target")"

  # Fill the approved template. Values pass through the environment (read via
  # ENVIRON) so user text is substituted literally, never as regex parts.
  EV_TITLE="$title" \
  EV_DATE="$event_date" \
  EV_PROJECT="${ANT_TEAM_DOCS_PROJECT_NAME:-}" \
  EV_ISSUE="$issue" \
  EV_MILESTONE="$milestone" \
  EV_FROM="$from" EV_TO="$to" EV_TYPE="$type" EV_STATUS="$status" \
  EV_GH_ISSUE="$github_issue_value" EV_GH_PR="$github_pr_value" \
  EV_STATE="$state" EV_SUMMARY="$summary" EV_SCOPE_TAG="$scope_tag" \
  awk '
    function str_replace(s, find, repl,   out, i) {
      out = ""
      while ((i = index(s, find)) > 0) {
        out = out substr(s, 1, i - 1) repl
        s = substr(s, i + length(find))
      }
      return out s
    }
    function fill(line, key, value) {
      if (line == key && value != "") { print key " " value; return 1 }
      return 0
    }
    {
      line = $0
      line = str_replace(line, "{{title}}", ENVIRON["EV_TITLE"])
      line = str_replace(line, "\"{{date:YYYY-MM-DD}}\"", ENVIRON["EV_DATE"])
      line = str_replace(line, "{{date:YYYY-MM-DD}}", ENVIRON["EV_DATE"])
      if (fill(line, "project:", ENVIRON["EV_PROJECT"])) next
      if (fill(line, "issue:", ENVIRON["EV_ISSUE"])) next
      if (fill(line, "milestone:", ENVIRON["EV_MILESTONE"])) next
      if (fill(line, "from_role:", ENVIRON["EV_FROM"])) next
      if (fill(line, "to_role:", ENVIRON["EV_TO"])) next
      if (fill(line, "communication_type:", ENVIRON["EV_TYPE"])) next
      if (line == "status: open" && ENVIRON["EV_STATUS"] != "") { print "status: " ENVIRON["EV_STATUS"]; next }
      if (fill(line, "github_issue:", ENVIRON["EV_GH_ISSUE"])) next
      if (fill(line, "github_pr:", ENVIRON["EV_GH_PR"])) next
      if (fill(line, "Role:", ENVIRON["EV_FROM"])) next
      if (fill(line, "Target Role:", ENVIRON["EV_TO"])) next
      if (fill(line, "State:", ENVIRON["EV_STATE"])) next
      if (fill(line, "Spec / Milestone:", ENVIRON["EV_MILESTONE"])) next
      if (fill(line, "Task / Issue:", ENVIRON["EV_ISSUE"] != "" ? "#" ENVIRON["EV_ISSUE"] : "")) next
      if (fill(line, "Branch / PR:", ENVIRON["EV_GH_PR"])) next
      if (line == "  - agent-communication") {
        print line
        if (ENVIRON["EV_SCOPE_TAG"] != "") print "  - " ENVIRON["EV_SCOPE_TAG"]
        next
      }
      if (line == "Summary:") { in_summary = 1; print line; next }
      if (in_summary && line ~ /^- /) {
        if (!summary_filled && ENVIRON["EV_SUMMARY"] != "") {
          print "- " ENVIRON["EV_SUMMARY"]
          summary_filled = 1
          next
        }
        in_summary = 0
      }
      print line
    }
  ' "$template" > "$target"

  echo "$target"
  echo "Recorded. Complete the remaining event sections in Obsidian; GitHub still needs its final-decision or closure comment when applicable." >&2
}

# ---------------------------------------------------------------------------
# list — print recorded events with their key frontmatter values.
# ---------------------------------------------------------------------------

fm_value() {
  # fm_value FILE KEY — first frontmatter value for ^key:, quotes stripped.
  local file="$1" key="$2" value
  value="$(awk -F': ' -v k="$key" 'index($0, "---") == 1 { fm++; next } fm == 1 && $1 == k { print substr($0, length(k) + 3); exit }' "$file" | tr -d '"')"
  printf '%s' "$value"
}

print_event() {
  local file="$1"
  printf '%s  %s -> %s  %s  %s  %s\n' \
    "$(fm_value "$file" "date")" \
    "$(fm_value "$file" "from_role")" \
    "$(fm_value "$file" "to_role")" \
    "$(fm_value "$file" "communication_type")" \
    "$(fm_value "$file" "status")" \
    "$file"
}

cmd_list() {
  local issue="" milestone="" all=0 scope_count=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --issue) issue="${2:-}"; shift 2 ;;
      --milestone) milestone="${2:-}"; shift 2 ;;
      --all) all=1; shift ;;
      *) usage >&2; exit 1 ;;
    esac
  done

  [[ "$issue" != "" || -n "$milestone" || "$all" == "1" ]] || { usage >&2; exit 1; }
  [[ "$all" == "0" || ( -z "$issue" && -z "$milestone" ) ]] || die "pass either --issue, --milestone, or --all"
  [[ "$issue" =~ ^[0-9]*$ ]] || die "--issue must be a GitHub issue number (got: $issue)"
  if [[ -n "$milestone" ]]; then
    milestone="$(slugify "$milestone")"
    validate_slug "$milestone" "milestone"
  fi

  load_project_env

  local comm_root="$ANT_TEAM_DOCS_PROJECT_PATH/agent-communication"
  local -a files=()

  if [[ -n "$issue" ]]; then
    while IFS= read -r f; do files+=("$f"); done < <(find "$comm_root/issues/issue-$issue" -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort)
  elif [[ -n "$milestone" ]]; then
    while IFS= read -r f; do files+=("$f"); done < <(find "$comm_root/milestones/$milestone" -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort)
  else
    while IFS= read -r f; do files+=("$f"); done < <(find "$comm_root" -type f -name '*.md' 2>/dev/null | sort)
  fi

  if [[ ${#files[@]} -eq 0 ]]; then
    echo "No communication events recorded." >&2
    return 0
  fi

  local f
  for f in "${files[@]}"; do
    print_event "$f"
  done
}

# ---------------------------------------------------------------------------
# Entry point.
# ---------------------------------------------------------------------------

case "${1:-}" in
  record) shift; cmd_record "$@" ;;
  list) shift; cmd_list "$@" ;;
  -h|--help|help) usage ;;
  *) usage >&2; exit 1 ;;
esac
