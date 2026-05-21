#!/usr/bin/env bash

pm_doc_root() {
  local root="${DOC_ROOT:-}"
  if [[ -n "$root" ]]; then
    printf '%s' "${root%/}"
    return
  fi

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  printf '%s' "$script_dir/docs"
}

pm_today() {
  date +%F
}

pm_spec_file() {
  printf '%s/spec/%s.md' "$(pm_doc_root)" "$1"
}

pm_tasks_file() {
  printf '%s/proj-management/tasks/%s-tasks.md' "$(pm_doc_root)" "$1"
}

pm_board_file() {
  printf '%s/proj-management/board.md' "$(pm_doc_root)"
}

pm_communication_log() {
  printf '%s/proj-management/communication/%s-communication.md' "$(pm_doc_root)" "$1"
}

pm_touch_spec() {
  local spec_file="$1"
  local today="$(pm_today)"

  [[ -f "$spec_file" ]] || return 0
  TODAY="$today" perl -0pi -e 's/(\| Last Updated \| )[^|]*( \|)/$1$ENV{TODAY}$2/g' "$spec_file"
}

pm_touch_task_file() {
  local tasks_file="$1"
  local today="$(pm_today)"

  [[ -f "$tasks_file" ]] || return 0
  TODAY="$today" perl -0pi -e 's/(\| Last Updated \| )[^|]*( \|)/$1$ENV{TODAY}$2/g' "$tasks_file"
}

pm_ensure_board() {
  local board_file="$(pm_board_file)"
  mkdir -p "$(dirname "$board_file")"
  if [[ ! -f "$board_file" ]]; then
    cat > "$board_file" <<'EOF'
# Project Board

| Spec | Task | Title | Status | Owner | Branch | PR | Loop | Blocker | Updated |
|---|---|---|---|---|---|---|---|---|---|
EOF
  fi
}

pm_update_board_row() {
  local spec_id="$1"
  local task_id="$2"
  local status="${3:-}"
  local branch="${4:-}"
  local pr="${5:-}"
  local loop="${6:-}"
  local blocker="${7:-}"
  local board_file="$(pm_board_file)"
  local today="$(pm_today)"

  pm_ensure_board
  if ! grep -q "| $spec_id | $task_id |" "$board_file"; then
    printf '| %s | %s |  | %s |  | %s | %s | %s | %s | %s |\n' \
      "$spec_id" "$task_id" "${status:-Ready}" "$branch" "$pr" "${loop:-0/8}" "${blocker:-none}" "$today" >> "$board_file"
    return 0
  fi

  SPEC_ID="$spec_id" TASK_ID="$task_id" STATUS="$status" BRANCH="$branch" PR="$pr" LOOP="$loop" BLOCKER="$blocker" TODAY="$today" perl -0pi -e '
    sub trim { my $v = shift; $v =~ s/^\s+|\s+$//g; return $v }
    my @out;
    for my $line (split /\n/, $_, -1) {
      if ($line =~ /^\|\s*\Q$ENV{SPEC_ID}\E\s*\|\s*\Q$ENV{TASK_ID}\E\s*\|/) {
        my @c = split /\|/, $line, -1;
        $c[4] = " $ENV{STATUS} " if $ENV{STATUS} ne "";
        $c[6] = " $ENV{BRANCH} " if $ENV{BRANCH} ne "";
        $c[7] = " $ENV{PR} " if $ENV{PR} ne "";
        $c[8] = " $ENV{LOOP} " if $ENV{LOOP} ne "";
        $c[9] = " $ENV{BLOCKER} " if $ENV{BLOCKER} ne "";
        $c[10] = " $ENV{TODAY} ";
        $line = join "|", @c;
      }
      push @out, $line;
    }
    $_ = join "\n", @out;
  ' "$board_file"
}

pm_valid_status() {
  case "$1" in
    Backlog|Ready|"In Development"|"PR Open"|"Architecture Review"|Rework|"QA Smoke"|"Loop Breaker"|Blocked|Deferred|Approved|Done)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

pm_require_valid_status() {
  local status="$1"
  if ! pm_valid_status "$status"; then
    echo "Invalid status: $status" >&2
    echo "Allowed: Backlog, Ready, In Development, PR Open, Architecture Review, Rework, QA Smoke, Loop Breaker, Blocked, Deferred, Approved, Done" >&2
    exit 1
  fi
}

pm_update_task_status() {
  local spec_id="$1"
  local task_id="$2"
  local status="$3"
  local tasks_file="$(pm_tasks_file "$spec_id")"

  [[ -f "$tasks_file" ]] || return 0
  TASK_ID="$task_id" STATUS="$status" perl -0pi -e '
    s/(^### \Q$ENV{TASK_ID}\E:.*?\n\nStatus: )[^\n]+/${1}$ENV{STATUS}/ms;
    my @out;
    for my $line (split /\n/, $_, -1) {
      if ($line =~ /^\|\s*\Q$ENV{TASK_ID}\E\s*\|/) {
        my @c = split /\|/, $line, -1;
        $c[4] = " $ENV{STATUS} ";
        $line = join "|", @c;
      }
      push @out, $line;
    }
    $_ = join "\n", @out;
  ' "$tasks_file"
}

pm_task_exists() {
  local spec_id="$1"
  local task_id="$2"
  local tasks_file="$(pm_tasks_file "$spec_id")"
  [[ -f "$tasks_file" ]] && grep -q "^### ${task_id}:" "$tasks_file"
}

pm_append_log() {
  local spec_id="$1"
  local heading="$2"
  local body="$3"
  local log_file="$(pm_communication_log "$spec_id")"

  mkdir -p "$(dirname "$log_file")"
  if [[ ! -f "$log_file" ]]; then
    cat > "$log_file" <<EOF
# Communication Log: $spec_id

## Agent Handoffs
EOF
  fi
  if ! grep -q "^## ${heading}$" "$log_file"; then
    printf '\n## %s\n' "$heading" >> "$log_file"
  fi
  printf '\n%s\n' "$body" >> "$log_file"
}

pm_update_all() {
  local spec_id="$1"
  local task_id="$2"
  local status="${3:-}"
  local branch="${4:-}"
  local pr="${5:-}"
  local loop="${6:-}"
  local blocker="${7:-}"

  pm_update_board_row "$spec_id" "$task_id" "$status" "$branch" "$pr" "$loop" "$blocker"
  pm_touch_spec "$(pm_spec_file "$spec_id")"
  pm_touch_task_file "$(pm_tasks_file "$spec_id")"
}
