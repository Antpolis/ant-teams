#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/pm-lib.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/update-document-index.sh ID TITLE TYPE DOMAIN STATUS PATH SUMMARY KEYWORDS APPLIES_TO [RELATED_DOCS] [SUPERSEDES]
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ $# -lt 9 || $# -gt 11 ]]; then usage >&2; exit 1; fi

id="$1"; title="$2"; type="$3"; domain="$4"; status="$5"; path="$6"; summary="$7"; keywords="$8"; applies_to="$9"
related="${10:-}"; supersedes="${11:-}"; today="$(pm_today)"
index_file="$(pm_doc_root)/DOCUMENT_INDEX.md"

mkdir -p "$(dirname "$index_file")"
if [[ ! -f "$index_file" ]]; then
  cat > "$index_file" <<'EOF'
# Document Index

| ID | Title | Type | Domain | Status | Path | Summary | Keywords | Applies To | Related Docs | Supersedes | Last Updated |
|---|---|---|---|---|---|---|---|---|---|---|---|
EOF
fi

row="| $id | $title | $type | $domain | $status | $path | $summary | $keywords | $applies_to | $related | $supersedes | $today |"
if grep -q "^| $id |" "$index_file"; then
  ID="$id" ROW="$row" perl -0pi -e 'my @out; for my $line (split /\n/, $_, -1) { $line = $ENV{ROW} if $line =~ /^\| \Q$ENV{ID}\E \|/; push @out, $line } $_ = join "\n", @out;' "$index_file"
else
  printf '%s\n' "$row" >> "$index_file"
fi

echo "Updated $index_file"
