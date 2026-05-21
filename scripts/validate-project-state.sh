#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

board="$(pm_board_file)"
errors=0
[[ -f "$board" ]] || { echo "Missing board: $board" >&2; exit 1; }

while IFS='|' read -r _ spec task title status owner branch pr loop blocker updated _rest; do
  spec="$(printf '%s' "$spec" | xargs)"; task="$(printf '%s' "$task" | xargs)"; status="$(printf '%s' "$status" | xargs)"; loop="$(printf '%s' "$loop" | xargs)"
  [[ -z "$spec" || "$spec" == "Spec" || "$spec" == "---" ]] && continue
  if ! pm_valid_status "$status"; then echo "Invalid status for $spec/$task: $status" >&2; errors=$((errors+1)); fi
  if [[ ! -f "$(pm_spec_file "$spec")" ]]; then echo "Missing spec for $spec" >&2; errors=$((errors+1)); fi
  if ! pm_task_exists "$spec" "$task"; then echo "Missing task section for $spec/$task" >&2; errors=$((errors+1)); fi
  if [[ ! "$loop" =~ ^[0-8]/8$ ]]; then echo "Invalid loop count for $spec/$task: $loop" >&2; errors=$((errors+1)); fi
  if [[ "$status" == "Done" && ! -f "$(pm_communication_log "$spec")" ]]; then echo "Done task missing communication log: $spec/$task" >&2; errors=$((errors+1)); fi
done < "$board"

if (( errors > 0 )); then
  echo "Project state invalid: $errors issue(s)" >&2
  exit 1
fi
echo "Project state valid"
