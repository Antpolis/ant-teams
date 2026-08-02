#!/usr/bin/env bash
#
# sync-managed-skills.sh — Managed, non-destructive sync of repository-owned
# skills and command-derived skills into ~/.agents/skills/.
#
# Single implementation owner of SPEC-002 FR-2 through FR-11. See:
#   - docs/spec/SPEC-002-managed-global-skill-sync-and-command-derived-skills.md
#   - docs/arch/ARCH-004-managed-skill-sync-architecture.md
#
# Exit codes (CLI-1.2):
#   0  Success (or dry-run with no structural errors)
#   1  Usage error, or a source file was skipped due to error (ERR-1.2/ERR-2.1)
#   2  Boundary violation (attempted write to an unmanaged/out-of-bounds path)
#   3  Source ambiguity (duplicate source names)
#   4  Missing dependency (sha256sum/shasum, or node)
#   5  File-system error (permission denied, disk full, etc.)
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Paths and constants
# ---------------------------------------------------------------------------
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_SKILLS_DIR="$REPO_ROOT/.opencode/skills"
SOURCE_COMMANDS_DIR="$REPO_ROOT/.opencode/commands"

# Exit codes (CLI-1.2)
EX_OK=0
EX_USAGE=1
EX_BOUNDARY=2
EX_AMBIGUITY=3
EX_DEP=4
EX_FS=5

# Flags
FORCE=0
DRY_RUN=0

# Counters (one per emitted action line, per OBS-2)
COUNT_INSTALL=0
COUNT_UPDATE=0
COUNT_NOOP=0
COUNT_SKIP_MODIFIED=0
COUNT_SKIP_ORPHAN=0
COUNT_SKIP_COLLISION=0
COUNT_FORCE=0
COUNT_ERROR=0

# Set when any source file could not be read (ERR-1.2 / ERR-2.1) -> final exit 1.
HAD_SOURCE_ERROR=0

# Number of entries written into the new manifest.
TOTAL_MANAGED=0
# Running count of managed entries (works in dry-run too, where NEW_TSV is empty).
MANAGED_ENTRIES_COUNT=0
# 1 when a valid prior manifest was read, 0 when missing/corrupt (DM-1.2/ERR-5).
MANIFEST_PRESENT=0

# Temporary directory (cleaned on exit).
TEMP_DIR=""

cleanup() {
  if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Output helpers (OBS-1, OBS-3, OBS-4)
# ---------------------------------------------------------------------------
say() {
  # Emit an action line to stdout; prefix [DRY-RUN] in dry-run (OBS-3.1).
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[DRY-RUN] %s\n' "$*"
  else
    printf '%s\n' "$*"
  fi
}

say_err() {
  # Emit a skip/force action line to stderr (OBS-1.1 routing); prefix [DRY-RUN].
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[DRY-RUN] %s\n' "$*" >&2
  else
    printf '%s\n' "$*" >&2
  fi
}

warn() {
  # Non-fatal [WARNING] to stderr (OBS-1.1). Prefixed in dry-run.
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[DRY-RUN] [WARNING] %s\n' "$*" >&2
  else
    printf '[WARNING] %s\n' "$*" >&2
  fi
}

err() {
  # [ERROR] to stderr (OBS-4.1). Prefixed in dry-run.
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[DRY-RUN] [ERROR] %s\n' "$*" >&2
  else
    printf '[ERROR] %s\n' "$*" >&2
  fi
  COUNT_ERROR=$((COUNT_ERROR + 1))
}

die_usage()     { err "$*"; exit "$EX_USAGE"; }
die_boundary()  { err "$*"; exit "$EX_BOUNDARY"; }
die_ambiguity() { err "$*"; exit "$EX_AMBIGUITY"; }
die_dep()       { err "$*"; exit "$EX_DEP"; }
die_fs()        { err "$*"; exit "$EX_FS"; }

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
  cat <<'USAGE'
Usage:
  scripts/sync-managed-skills.sh [--force] [--dry-run]

Managed, non-destructive sync of repository-owned skills and command-derived
skills into ~/.agents/skills/.

Flags:
  --force       Overwrite locally modified managed entries instead of preserving them.
  --dry-run     Report planned actions without writing any files.

Exit codes:
  0  Success (or dry-run completed with no structural errors)
  1  Usage error (invalid flag, missing dependency, or a source file was skipped)
  2  Boundary violation (attempted write to unmanaged path)
  3  Source ambiguity (duplicate source names)
  4  Missing dependency (e.g. sha256sum not found)
  5  File-system error (permission denied, disk full, etc.)
USAGE
}

# ---------------------------------------------------------------------------
# Dependency detection (TR-1.2). sha256sum with shasum -a 256 fallback.
# node is already a repository runtime dependency (sync-company.sh requires it)
# and is used here only for reliable JSON validate/serialize (DM-4.2).
# ---------------------------------------------------------------------------
SHA_CMD=""
if command -v sha256sum >/dev/null 2>&1; then
  SHA_CMD=sha256sum
elif command -v shasum >/dev/null 2>&1; then
  SHA_CMD=shasum
fi

NODE_BIN=""
if command -v node >/dev/null 2>&1; then
  NODE_BIN=node
fi

# ---------------------------------------------------------------------------
# Hashing — normalize to lowercase hex (TR-2.1, macOS fallback).
# ---------------------------------------------------------------------------
compute_hash() {
  # Print lowercase hex SHA-256 of $1 to stdout.
  local f="$1"
  if [[ "$SHA_CMD" == "sha256sum" ]]; then
    sha256sum "$f" 2>/dev/null | awk '{print tolower($1)}'
  else
    shasum -a 256 "$f" 2>/dev/null | awk '{print tolower($1)}'
  fi
}

# ---------------------------------------------------------------------------
# Manifest I/O helpers (node-backed). TSV wire format, 7 tab-separated columns,
# one line per managed file:
#   name \t type \t source_path \t installed_at \t file_key \t hash \t target_path
# ---------------------------------------------------------------------------
write_node_helper() {
  cat > "$1" <<'NODE_SCRIPT'
"use strict";
const fs = require("fs");
const mode = process.argv[2];

if (mode === "read") {
  const path = process.argv[3];
  if (!path || !fs.existsSync(path)) {
    process.stdout.write("MANIFEST_MISSING\n");
    process.exit(0);
  }
  let raw;
  try {
    raw = fs.readFileSync(path, "utf8");
  } catch (e) {
    process.stdout.write("MANIFEST_CORRUPT\n");
    process.exit(0);
  }
  let obj;
  try {
    obj = JSON.parse(raw);
  } catch (e) {
    process.stdout.write("MANIFEST_CORRUPT\n");
    process.exit(0);
  }
  // DM-4.2: must be an object with version===1 and a managed_entries object.
  if (typeof obj !== "object" || obj === null ||
      obj.version !== 1 ||
      typeof obj.managed_entries !== "object" || obj.managed_entries === null) {
    process.stdout.write("MANIFEST_CORRUPT\n");
    process.exit(0);
  }
  process.stdout.write("MANIFEST_OK\n");
  for (const name of Object.keys(obj.managed_entries)) {
    const e = obj.managed_entries[name] || {};
    const type = typeof e.type === "string" ? e.type : "";
    const sp = typeof e.source_path === "string" ? e.source_path : "";
    const ia = typeof e.installed_at === "string" ? e.installed_at : "";
    const files = (e.files && typeof e.files === "object") ? e.files : {};
    const fkeys = Object.keys(files);
    if (fkeys.length === 0) {
      // Keep file-less entries visible for orphan detection.
      process.stdout.write([name, type, sp, ia, "", "", ""].join("\t") + "\n");
    } else {
      for (const fk of fkeys) {
        const frec = files[fk] || {};
        const hash = typeof frec.hash === "string" ? frec.hash.replace(/[^a-f0-9]/g, "") : "";
        const tp = typeof frec.target_path === "string" ? frec.target_path : "";
        process.stdout.write([name, type, sp, ia, fk, hash, tp].join("\t") + "\n");
      }
    }
  }
  process.exit(0);
}

if (mode === "write") {
  const inTsv = process.argv[3];
  const outPath = process.argv[4];
  const lastSync = process.argv[5];
  const sourceRepo = process.argv[6] || "";
  const manifest = {
    version: 1,
    source_repo: sourceRepo,
    last_sync: lastSync,
    managed_entries: {}
  };
  const raw = fs.readFileSync(inTsv, "utf8");
  for (const line of raw.split("\n")) {
    if (line === "") continue;
    const parts = line.split("\t");
    if (parts.length < 7) continue;
    const [name, type, sp, ia, fk, hash, tp] = parts;
    if (fk === "") continue; // skip file-less placeholder rows on write
    if (!manifest.managed_entries[name]) {
      manifest.managed_entries[name] = { type, source_path: sp, installed_at: ia, files: {} };
    }
    manifest.managed_entries[name].files[fk] = { hash, target_path: tp };
  }
  // Deterministic output (TR-4.1): fixed top-level key order + sorted entries
  // and sorted file keys, so idempotent re-runs are byte-identical except
  // last_sync (FR-10.1, TR-4.3).
  const sorted = {};
  for (const name of Object.keys(manifest.managed_entries).sort()) {
    const e = manifest.managed_entries[name];
    const sf = {};
    for (const fk of Object.keys(e.files).sort()) sf[fk] = e.files[fk];
    sorted[name] = {
      type: e.type,
      source_path: e.source_path,
      installed_at: e.installed_at,
      files: sf
    };
  }
  manifest.managed_entries = sorted;
  fs.writeFileSync(outPath, JSON.stringify(manifest, null, 2) + "\n");
  process.exit(0);
}

process.stderr.write("[ERROR] manifest_io: unknown mode " + mode + "\n");
process.exit(1);
NODE_SCRIPT
}

# ---------------------------------------------------------------------------
# Command -> SKILL.md transformation (FR-4, ARCH-004 Component 4)
# Fields emitted in fixed order: name, description, disable-model-invocation.
# Body preserved byte-for-byte from the first non-frontmatter line.
# ---------------------------------------------------------------------------
generate_command_skill() {
  local src="$1" name="$2" out="$3"
  local body_start=1 desc=""
  local first_line close_ln

  first_line="$(head -n1 "$src" 2>/dev/null || true)"
  if [[ "$first_line" == "---" ]]; then
    close_ln="$(awk 'NR>1 && $0=="---"{print NR; exit}' "$src")"
    if [[ -z "$close_ln" ]]; then
      # ERR-1.1: unclosed frontmatter — warn, default description, body from line 2.
      warn "Malformed frontmatter in $src (unclosed '---'); defaulting description to empty."
      desc=""
      body_start=2
    else
      desc="$(awk -v cl="$close_ln" '
        NR>=2 && NR<cl && $0 ~ /^description:/ {
          sub(/^description:[ ]?/, "")
          print
          exit
        }
      ' "$src")"
      body_start=$((close_ln + 1))
    fi
  else
    # INT-2.2d: no frontmatter — body is the whole file, description "".
    desc=""
    body_start=1
  fi

  {
    printf '%s\n' '---'
    printf 'name: %s\n' "$name"
    printf 'description: %s\n' "$desc"
    printf '%s\n' 'disable-model-invocation: true'
    printf '%s\n' '---'
    # Body preserved byte-for-byte from the first non-frontmatter line (FR-4.1c).
    tail -n +"$body_start" "$src"
  } > "$out"

  # FR-4.1d: ensure a trailing newline.
  if [[ -n "$(tail -c1 "$out" 2>/dev/null || true)" ]]; then
    printf '\n' >> "$out"
  fi
}

# ---------------------------------------------------------------------------
# Target path validation (SEC-1)
# ---------------------------------------------------------------------------
assert_target_within_managed() {
  local tgt="$1"
  case "$tgt" in
    "$TARGET_DIR"/*) ;;
    *) die_boundary "refusing to write outside $TARGET_DIR: $tgt" ;;
  esac
  local rel="${tgt#"$TARGET_DIR"/}"
  case "$rel" in
    *..*) die_boundary "path traversal detected in target: $tgt" ;;
  esac
}

# ---------------------------------------------------------------------------
# Managed write-path ancestor check (FR-11.4 / SEC-5.1 / SEC-5.2).
#
# A non-directory anywhere along the directory chain leading to a target file
# (e.g., a stray regular file where an intermediate directory is expected)
# would make `mkdir -p` abort with "File exists". SPEC-002 treats that as an
# unmanaged collision: warn + skip the file, never a filesystem abort.
#
# SEC-5.2 additionally forbids following ANY symlink in the managed target
# ancestor chain: a symlinked ancestor (even a symlink-to-dir) would redirect
# the later mkdir/write OUTSIDE ~/.agents/skills, escaping the managed subtree.
#
# Returns 0 (true) when the write path is BLOCKED -- i.e. any existing ancestor
# is a symlink (to a dir, file, or broken target) or any non-directory (regular
# file, device, etc.). Returns 1 (false) when every existing ancestor is a real
# directory (or absent, meaning mkdir -p can create the chain cleanly without
# ever crossing a symlink).
# ---------------------------------------------------------------------------
target_path_blocked() {
  local tgt="$1" dir rel cur comp rest
  dir="$(dirname "$tgt")"
  # Only chain under TARGET_DIR; boundary itself is enforced by
  # assert_target_within_managed at the call site.
  case "$dir" in
    "$TARGET_DIR") return 1 ;;
    "$TARGET_DIR"/*) ;;
    *) return 1 ;;
  esac
  rel="${dir#"$TARGET_DIR"/}"
  cur="$TARGET_DIR"
  rest="$rel"
  while [[ -n "$rest" ]]; do
    comp="${rest%%/*}"
    if [[ "$comp" == "$rest" ]]; then
      rest=""
    else
      rest="${rest#*/}"
    fi
    cur="$cur/$comp"
    # SEC-5.2: never follow a symlink in the ancestor chain. -L catches
    # symlinks regardless of what they point at (dir/file/broken), so a
    # symlink-to-dir ancestor is rejected here rather than silently followed
    # by the later mkdir -p. A real non-directory ancestor is also a block.
    if [[ -L "$cur" ]] || [[ -e "$cur" && ! -d "$cur" ]]; then
      return 0
    fi
  done
  return 1
}

# ---------------------------------------------------------------------------
# Permission helpers (SEC-3).
# ---------------------------------------------------------------------------
# Portable read of a file's permission bits as the octal string printed by
# stat (e.g. "644", "755"). GNU coreutils uses `-c %a`; BSD/macOS uses `-f
# %Lp`. Returns non-zero (empty output) when stat is unavailable or fails.
file_mode() {
  local f="$1"
  if stat -c %a "$f" 2>/dev/null; then
    return 0
  fi
  stat -f %Lp "$f" 2>/dev/null
}

# Write a single file from a staged/source path (SEC-3, TR-4.2).
#
# Permission policy (SEC-3.1 governs install; SEC-3.2 governs update):
#   * Fresh install (target did not exist) or --force  -> source-derived mode
#     (0644, or 0755 if the source file is executable).                (SEC-3.1)
#   * Update of an existing managed file (no --force)  -> preserve the
#     operator's prior mode UNLESS it is more permissive than 0644, in
#     which case tighten to exactly 0644 (e.g. 0666 -> 0644, 0777 -> 0644,
#     0755 -> 0644). Modes at or below 0644 (0600, 0640, 0644, 0444 ...) are
#     preserved as-is. The exec bit stripped from an updated executable script
#     is restored by the next force/fresh install (SEC-3.1).           (SEC-3.2)
# Directories are created 0755 via umask (SEC-3.1).
# ---------------------------------------------------------------------------
write_target_file() {
  local src="$1" tgt="$2" src_mode="0644"
  assert_target_within_managed "$tgt"
  if [[ -L "$tgt" ]]; then
    # SEC-5.2: refuse to follow/replace a symlink at a managed target.
    die_fs "refusing to overwrite symlink at managed target: $tgt"
  fi
  if [[ -x "$src" ]]; then
    src_mode="0755"
  fi

  # Capture prior mode BEFORE overwriting so SEC-3.2 preserve-on-update can
  # apply it (cp may otherwise reset the destination mode).
  local prior_oct=""
  if [[ -e "$tgt" ]]; then
    prior_oct="$(file_mode "$tgt")"
  fi

  mkdir -p "$(dirname "$tgt")" || die_fs "cannot create directory for $tgt"
  cp "$src" "$tgt" 2>/dev/null || die_fs "cannot write $tgt"

  if [[ "$FORCE" == "1" || -z "$prior_oct" ]]; then
    # Fresh install or explicit --force: source-derived mode (SEC-3.1).
    chmod "$src_mode" "$tgt" 2>/dev/null || die_fs "cannot chmod $tgt"
  else
    # Update (no force): SEC-3.2 literal -- preserve prior mode unless it is
    # more permissive than 0644, in which case tighten to 0644.
    # `0$prior_oct` forces bash to read stat's octal output as octal; ~0644
    # isolates any access bit outside the rw-r--r-- baseline.
    local prior_dec extra_dec
    prior_dec=$(( 0$prior_oct ))
    extra_dec=$(( prior_dec & ~0644 ))
    if [[ "$extra_dec" -ne 0 ]]; then
      chmod 0644 "$tgt" 2>/dev/null || die_fs "cannot chmod $tgt"
    else
      chmod "$prior_oct" "$tgt" 2>/dev/null || die_fs "cannot chmod $tgt"
    fi
  fi
}

# ---------------------------------------------------------------------------
# Parse flags (CLI-1)
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit "$EX_OK" ;;
    *) err "Unknown argument: $1"; usage >&2; exit "$EX_USAGE" ;;
  esac
done

# Enforce dependencies after flag parse so --help works offline.
if [[ -z "$SHA_CMD" ]]; then
  die_dep "sha256sum (or 'shasum -a 256' on macOS) is required but was not found."
fi
if [[ -z "$NODE_BIN" ]]; then
  die_dep "node is required for manifest JSON I/O but was not found."
fi

# ---------------------------------------------------------------------------
# Resolve target (TR-1.3: expand ~ via $HOME, never rely on tilde expansion).
# ---------------------------------------------------------------------------
if [[ -z "${HOME:-}" ]]; then
  die_usage "\$HOME is not set; cannot resolve ~/.agents/skills."
fi
TARGET_DIR="${HOME%/}/.agents/skills"
MANIFEST_PATH="$TARGET_DIR/.manifest.json"

if [[ ! -d "$SOURCE_SKILLS_DIR" ]]; then
  die_usage "source skills directory not found: $SOURCE_SKILLS_DIR"
fi
if [[ ! -d "$SOURCE_COMMANDS_DIR" ]]; then
  die_usage "source commands directory not found: $SOURCE_COMMANDS_DIR"
fi

# Predictable umask so created directories are 0755 (SEC-3.1).
umask 022

# Scratch space for this run (SEC-3.3, TR-5).
TEMP_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t syncmanaged)"
NODE_HELPER="$TEMP_DIR/manifest_io.js"
write_node_helper "$NODE_HELPER"

# Source inventory TSV. Columns:
#   entry_name \t entry_type \t entry_source_path \t file_subpath \t file_key \t source_abs
SOURCE_FILES_TSV="$TEMP_DIR/source_files.tsv"
: > "$SOURCE_FILES_TSV"

shopt -s nullglob

# Per-directory name lists (one name per source directory) for ambiguity checks.
SKILL_NAMES_RAW="$TEMP_DIR/skill_names_raw.txt"
: > "$SKILL_NAMES_RAW"

# --- Component 1, step 1: discover source skill directories (FR-2.2a) -------
{
  for skill_dir in "$SOURCE_SKILLS_DIR"/*/; do
    name="$(basename "$skill_dir")"
    printf '%s\n' "$name" >> "$SKILL_NAMES_RAW"
    # Enumerate every file recursively; exclude in-skill .gitignore (INT-1.2).
    while IFS= read -r src_abs; do
      rel="${src_abs#"$skill_dir"}"
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$name" "source_skill" ".opencode/skills/$name/" "$rel" ".opencode/skills/$name/$rel" "$src_abs"
    done < <(find "$skill_dir" -type f -not -name '.gitignore')
  done
} >> "$SOURCE_FILES_TSV"

# --- Source skill name ambiguity check (FR-11.2) ----------------------------
# Detect duplicate directory names (impossible on a single filesystem, but the
# spec requires the check). Names are collected per-directory, not per-file.
SKILL_NAMES_FILE="$TEMP_DIR/skill_names.txt"
sort -u "$SKILL_NAMES_RAW" > "$SKILL_NAMES_FILE"
_dup="$(sort "$SKILL_NAMES_RAW" | uniq -d)"
if [[ -n "$_dup" ]]; then
  die_ambiguity "duplicate source skill name(s) detected: $_dup"
fi
unset _dup

# --- Command staging + discovery (FR-2.2b, FR-4) ----------------------------
COMMAND_STAGE="$TEMP_DIR/cmd_stage"
mkdir -p "$COMMAND_STAGE"
COMMAND_NAMES_FILE="$TEMP_DIR/command_names.txt"
: > "$COMMAND_NAMES_FILE"

for cmd_file in "$SOURCE_COMMANDS_DIR"/*.md; do
  name="$(basename "$cmd_file" .md)"
  staged="$COMMAND_STAGE/$name/SKILL.md"
  mkdir -p "$(dirname "$staged")"
  generate_command_skill "$cmd_file" "$name" "$staged"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$name" "command_derived" ".opencode/commands/$name.md" "SKILL.md" ".opencode/commands/$name.md" "$staged" \
    >> "$SOURCE_FILES_TSV"
  printf '%s\n' "$name" >> "$COMMAND_NAMES_FILE"
done

# --- Command name ambiguity check (FR-11.3) ---------------------------------
_cmd_dup="$(sort "$COMMAND_NAMES_FILE" | uniq -d)"
if [[ -n "$_cmd_dup" ]]; then
  die_ambiguity "duplicate command-derived name(s) detected: $_cmd_dup"
fi
unset _cmd_dup

# --- FR-11.1: source skills win over command-derived on name collision -----
COLLISION_CMDS_FILE="$TEMP_DIR/collision_cmds.txt"
: > "$COLLISION_CMDS_FILE"
if [[ -s "$COMMAND_NAMES_FILE" ]]; then
  comm -12 "$SKILL_NAMES_FILE" <(sort "$COMMAND_NAMES_FILE") > "$COLLISION_CMDS_FILE"
fi
while IFS= read -r _colliding; do
  [[ -z "$_colliding" ]] && continue
  warn "Name collision: source skill '$_colliding' takes precedence; command-derived '$_colliding' skipped."
  say_err "[SKIP collision] $_colliding (source skill wins over command-derived)"
  COUNT_SKIP_COLLISION=$((COUNT_SKIP_COLLISION + 1))
done < "$COLLISION_CMDS_FILE"
unset _colliding

# Build the set of command-derived names that survived collision resolution.
ACTIVE_COMMAND_NAMES_FILE="$TEMP_DIR/active_command_names.txt"
if [[ -s "$COLLISION_CMDS_FILE" ]]; then
  sort "$COMMAND_NAMES_FILE" > "$TEMP_DIR/cmd_names_sorted.txt"
  sort "$COLLISION_CMDS_FILE" > "$TEMP_DIR/collision_sorted.txt"
  comm -23 "$TEMP_DIR/cmd_names_sorted.txt" "$TEMP_DIR/collision_sorted.txt" > "$ACTIVE_COMMAND_NAMES_FILE"
else
  sort "$COMMAND_NAMES_FILE" > "$ACTIVE_COMMAND_NAMES_FILE"
fi

# Ordered list of entry names to process (deterministic iteration).
ENTRY_NAMES_FILE="$TEMP_DIR/entry_names.txt"
cat "$SKILL_NAMES_FILE" "$ACTIVE_COMMAND_NAMES_FILE" | sort -u > "$ENTRY_NAMES_FILE"

# Active source inventory: drop command-derived rows whose name collided with a
# source skill (FR-11.1 — the source skill owns that name). Per-entry file
# iteration reads this filtered TSV so the losing command-derived SKILL.md is
# never written over the winning source skill copy.
ACTIVE_SOURCE_FILES_TSV="$TEMP_DIR/active_source_files.tsv"
if [[ -s "$COLLISION_CMDS_FILE" ]]; then
  awk -F '\t' -v collfile="$COLLISION_CMDS_FILE" '
    BEGIN {
      while ((getline line < collfile) > 0) coll[line]=1
      close(collfile)
    }
    { if (!($2 == "command_derived" && coll[$1])) print }
  ' "$SOURCE_FILES_TSV" > "$ACTIVE_SOURCE_FILES_TSV"
else
  cp "$SOURCE_FILES_TSV" "$ACTIVE_SOURCE_FILES_TSV"
fi

# ---------------------------------------------------------------------------
# Read existing manifest (DM-1, DM-4, ERR-3). Recover corrupt -> empty.
# ---------------------------------------------------------------------------
OLD_TSV="$TEMP_DIR/old_manifest.tsv"
MANIFEST_READ_OUTPUT="$TEMP_DIR/read_status.txt"
"$NODE_BIN" "$NODE_HELPER" read "$MANIFEST_PATH" > "$MANIFEST_READ_OUTPUT" || die_fs "manifest read failed"
read -r _manifest_status < "$MANIFEST_READ_OUTPUT"
case "$_manifest_status" in
  MANIFEST_OK)
    MANIFEST_PRESENT=1
    tail -n +2 "$MANIFEST_READ_OUTPUT" > "$OLD_TSV"
    ;;
  MANIFEST_MISSING)
    : > "$OLD_TSV"
    ;;
  MANIFEST_CORRUPT)
    # ERR-3.1: move corrupt manifest aside with a timestamp, proceed empty.
    _corrupt_ts="$(date -u +%Y%m%dT%H%M%SZ)"
    _corrupt_dest="$MANIFEST_PATH.corrupt.$_corrupt_ts"
    if [[ "$DRY_RUN" != "1" ]]; then
      mv "$MANIFEST_PATH" "$_corrupt_dest" 2>/dev/null || true
    fi
    warn "Manifest at $MANIFEST_PATH was corrupt or schema-invalid; moved to $_corrupt_dest and proceeding as if no manifest exists."
    : > "$OLD_TSV"
    ;;
  *)
    die_fs "unexpected manifest read status: $_manifest_status"
    ;;
esac
unset _manifest_status _corrupt_ts _corrupt_dest

# Helper: is a name present in the old manifest?
# (awk: `exit` runs END, so use a flag and decide the exit status in END only.)
is_managed_name() {
  awk -F '\t' -v n="$1" 'BEGIN{f=1} $1==n {f=0; exit} END{exit f}' "$OLD_TSV"
}
# Helper: old entry field ($2 = field number 2..4) for name $1.
old_entry_field() {
  awk -F '\t' -v n="$1" -v f="$2" '$1==n && $(f)!="" {print $(f); exit}' "$OLD_TSV"
}

# ---------------------------------------------------------------------------
# New manifest accumulator TSV (same 7-column wire format).
# ---------------------------------------------------------------------------
NEW_TSV="$TEMP_DIR/new_manifest.tsv"
: > "$NEW_TSV"

NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Process each entry.
while IFS= read -r name; do
  [[ -z "$name" ]] && continue

  entry_type="$(awk -F '\t' -v n="$name" '$1==n {print $2; exit}' "$ACTIVE_SOURCE_FILES_TSV")"
  entry_source_path="$(awk -F '\t' -v n="$name" '$1==n {print $3; exit}' "$ACTIVE_SOURCE_FILES_TSV")"
  entry_dir="$TARGET_DIR/$name"

  # --- SEC-5.2: symlink at managed target entry dir -> skip ----------------
  if [[ -L "$entry_dir" ]]; then
    warn "Symlink detected at managed target $entry_dir; skipping entry '$name'."
    say_err "[SKIP collision] $name (symlink at managed target)"
    COUNT_SKIP_COLLISION=$((COUNT_SKIP_COLLISION + 1))
    continue
  fi

  # --- FR-11.4: unmanaged regular file at target entry name -> skip --------
  # A non-directory entry (e.g., a stray regular file) at the managed target
  # name would make the later mkdir fail; warn + skip the entry rather than
  # aborting the whole sync (SEC-5.1 unmanaged-content protection).
  if [[ -e "$entry_dir" && ! -d "$entry_dir" ]]; then
    warn "Unmanaged file (not a directory) occupies target name: $entry_dir; skipping '$name'."
    say_err "[SKIP collision] $name (unmanaged regular file occupies target name)"
    COUNT_SKIP_COLLISION=$((COUNT_SKIP_COLLISION + 1))
    continue
  fi

  # --- Existing directory at target name: collision vs recovery ------------
  # FR-11.4/SEC-5.1: with a manifest present and the entry not recorded, an
  # existing directory is genuine unmanaged content -> skip (never inspected).
  # DM-1.2/ERR-5.1a: with the manifest MISSING, a directory whose name matches
  # a current source entry is recovered managed content -> reclaim it by
  # reconciling against source (it is never treated as an unmanaged collision).
  RECLAIM=0
  if [[ -d "$entry_dir" ]] && ! is_managed_name "$name"; then
    if [[ "$MANIFEST_PRESENT" == "1" ]]; then
      say_err "[SKIP collision] $name (unmanaged entry already occupies target name)"
      warn "Unmanaged content occupies $entry_dir; skipping '$name' to avoid overwrite."
      COUNT_SKIP_COLLISION=$((COUNT_SKIP_COLLISION + 1))
      continue
    fi
    RECLAIM=1
  fi

  # --- Upfront readability check (ERR-1.2 / ERR-2.1): skip whole entry -----
  _unreadable=""
  while IFS=$'\t' read -r _n _t _sp _sub _fk _src; do
    [[ "$_n" != "$name" ]] && continue
    if [[ ! -r "$_src" ]]; then
      _unreadable="$_src"
      break
    fi
  done < "$ACTIVE_SOURCE_FILES_TSV"
  if [[ -n "$_unreadable" ]]; then
    err "Source file unreadable for entry '$name': $_unreadable; skipping entry."
    HAD_SOURCE_ERROR=1
    continue
  fi
  unset _unreadable _n _t _sp _sub _fk _src

  # Entry passed collision/symlink checks -> it is (or will be) managed.
  MANAGED_ENTRIES_COUNT=$((MANAGED_ENTRIES_COUNT + 1))

  # Determine carried-forward installed_at for NOOP/modified entries.
  old_installed_at="$(old_entry_field "$name" 4)"
  # Recovered (manifest-missing) entries have no prior installed_at; record NOW
  # so the rebuilt manifest carries a real timestamp (DM-1.2 recovery).
  if [[ -z "$old_installed_at" ]]; then
    old_installed_at="$NOW"
  fi

  # Track per-entry outcomes for NOOP aggregation.
  entry_files_total=0
  entry_files_noop=0
  # Capture emitted per-file action lines for this entry.
  : > "$TEMP_DIR/entry_lines.txt"

  # Iterate over every source file for this entry.
  while IFS=$'\t' read -r _n _t _sp subpath file_key src_abs; do
    [[ "$_n" != "$name" ]] && continue
    entry_files_total=$((entry_files_total + 1))

    source_hash="$(compute_hash "$src_abs")"
    target_file="$entry_dir/$subpath"

    # Validate target path before any write decision (SEC-1.3, FR-7).
    assert_target_within_managed "$target_file"

    # FR-11.4 / SEC-5.1 / SEC-5.2: a symlink or non-directory anywhere along
    # the managed write path (e.g., a stray regular file OR a symlinked
    # intermediate dir) is an unmanaged collision -> warn + skip this file,
    # never a mkdir abort and never a write that follows the symlink out of the
    # managed subtree. Re-running after the operator clears/replaces it
    # installs the file via the normal UPDATE/INSTALL path.
    if target_path_blocked "$target_file"; then
      warn "Symlink or non-directory on managed write path: $(dirname "$target_file"); skipping $name/$subpath."
      say_err "[SKIP collision] $name/$subpath (symlink or non-directory ancestor in managed write path)"
      COUNT_SKIP_COLLISION=$((COUNT_SKIP_COLLISION + 1))
      continue
    fi

    in_manifest=0
    manifest_hash=""
    manifest_target=""
    if is_managed_name "$name"; then
      _row="$(awk -F '\t' -v n="$name" -v fk="$file_key" '$1==n && $5==fk {print $6"\t"$7; exit}' "$OLD_TSV")"
      if [[ -n "$_row" ]]; then
        in_manifest=1
        manifest_hash="${_row%%$'\t'*}"
        manifest_target="${_row#*$'\t'}"
      fi
    fi
    # DM-1.2 / ERR-5.1a manifest-missing reclaim: a directory that matches a
    # current source entry is recovered managed content. Treat the current
    # source hash as the recovered manifest hash so an existing file reconciles
    # as NOOP (matches source) or modified (differs), instead of being
    # clobbered as a fresh install. Missing files still install fresh.
    if [[ "$RECLAIM" == "1" && "$in_manifest" == "0" && -e "$target_file" && ! -L "$target_file" ]]; then
      in_manifest=1
      manifest_hash="$source_hash"
      manifest_target="$target_file"
    fi
    unset _row

    if [[ "$in_manifest" == "1" && -e "$target_file" && ! -L "$target_file" ]]; then
      current_hash="$(compute_hash "$target_file")"
      if [[ "$current_hash" == "$manifest_hash" ]]; then
        # Target not locally modified (FR-5).
        if [[ "$source_hash" == "$manifest_hash" ]]; then
          # Source unchanged -> NOOP for this file.
          entry_files_noop=$((entry_files_noop + 1))
          if [[ "$DRY_RUN" != "1" ]]; then
            printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
              "$name" "$entry_type" "$entry_source_path" "$old_installed_at" "$file_key" "$source_hash" "$target_file" >> "$NEW_TSV"
          fi
          continue
        else
          # Source changed -> UPDATE (FR-6.1b).
          if [[ "$DRY_RUN" != "1" ]]; then
            write_target_file "$src_abs" "$target_file"
          fi
          printf '%s\n' "[UPDATE] $name/$subpath ($entry_type)" >> "$TEMP_DIR/entry_lines.txt"
          COUNT_UPDATE=$((COUNT_UPDATE + 1))
        fi
      else
        # Target locally modified (FR-5.1 / FR-5.2).
        if [[ "$FORCE" == "1" ]]; then
          if [[ "$DRY_RUN" != "1" ]]; then
            write_target_file "$src_abs" "$target_file"
          fi
          printf '%s\n' "[FORCE overwrite] $name/$subpath (replaced from source)" >> "$TEMP_DIR/entry_lines.txt"
          COUNT_FORCE=$((COUNT_FORCE + 1))
        else
          # Preserve locally modified managed file (FR-6.1c).
          warn "Locally modified managed file preserved: $target_file"
          printf '%s\n' "[SKIP modified] $name/$subpath (preserved local changes)" >> "$TEMP_DIR/entry_lines.txt"
          COUNT_SKIP_MODIFIED=$((COUNT_SKIP_MODIFIED + 1))
          # Keep prior manifest record as-is so it remains trackable.
          if [[ "$DRY_RUN" != "1" ]]; then
            printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
              "$name" "$entry_type" "$entry_source_path" "$old_installed_at" "$file_key" "$manifest_hash" "$manifest_target" >> "$NEW_TSV"
          fi
          continue
        fi
      fi
    elif [[ "$in_manifest" == "1" && ! -e "$target_file" ]]; then
      # Managed record exists but file missing on disk (partial run / manual del).
      # Re-install from source (ERR-5 recovery, non-destructive: only writes the
      # managed path it already owns).
      if [[ "$DRY_RUN" != "1" ]]; then
        write_target_file "$src_abs" "$target_file"
      fi
      printf '%s\n' "[UPDATE] $name/$subpath ($entry_type, restored missing managed file)" >> "$TEMP_DIR/entry_lines.txt"
      COUNT_UPDATE=$((COUNT_UPDATE + 1))
    else
      # New install (entry not in manifest, or file not previously recorded).
      if [[ "$DRY_RUN" != "1" ]]; then
        write_target_file "$src_abs" "$target_file"
      fi
      printf '%s\n' "[INSTALL] $name/$subpath ($entry_type)" >> "$TEMP_DIR/entry_lines.txt"
      COUNT_INSTALL=$((COUNT_INSTALL + 1))
    fi

    # Record the freshly written file with current source hash + target path.
    if [[ "$DRY_RUN" != "1" ]]; then
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$name" "$entry_type" "$entry_source_path" "$NOW" "$file_key" "$source_hash" "$target_file" >> "$NEW_TSV"
    fi
  done < "$ACTIVE_SOURCE_FILES_TSV"

  # Emit entry-level output. Per OBS-1.1: INSTALL/UPDATE/NOOP -> stdout;
  # SKIP modified / FORCE overwrite -> stderr.
  if [[ "$entry_files_total" -gt 0 && "$entry_files_noop" == "$entry_files_total" ]]; then
    say "[NOOP] $name (all $entry_files_total file(s) unchanged)"
    COUNT_NOOP=$((COUNT_NOOP + 1))
  else
    while IFS= read -r _line; do
      [[ -z "$_line" ]] && continue
      case "$_line" in
        "[INSTALL]"*|"[UPDATE]"*) say "$_line" ;;
        *) say_err "$_line" ;;
      esac
    done < "$TEMP_DIR/entry_lines.txt"
  fi
  unset _line
done < "$ENTRY_NAMES_FILE"

# ---------------------------------------------------------------------------
# Orphan detection (FR-6.1d): entries in old manifest with no current source.
# Preserve them verbatim (ERR-5.2: never delete); emit [SKIP orphan].
# ---------------------------------------------------------------------------
ORPHAN_NAMES_FILE="$TEMP_DIR/orphans.txt"
: > "$ORPHAN_NAMES_FILE"
if [[ -s "$OLD_TSV" ]]; then
  comm -23 <(awk -F '\t' '{print $1}' "$OLD_TSV" | sort -u) "$ENTRY_NAMES_FILE" > "$ORPHAN_NAMES_FILE"
fi
while IFS= read -r orphan; do
  [[ -z "$orphan" ]] && continue
  warn "Managed orphan preserved (source no longer exists): $orphan"
  say_err "[SKIP orphan] $orphan (source no longer exists)"
  COUNT_SKIP_ORPHAN=$((COUNT_SKIP_ORPHAN + 1))
  MANAGED_ENTRIES_COUNT=$((MANAGED_ENTRIES_COUNT + 1))
  # Carry forward orphan's manifest rows unchanged.
  if [[ "$DRY_RUN" != "1" ]]; then
    awk -F '\t' -v n="$orphan" '$1==n {print}' "$OLD_TSV" >> "$NEW_TSV"
  fi
done < "$ORPHAN_NAMES_FILE"
unset orphan

# ---------------------------------------------------------------------------
# Write manifest atomically (DM-4.1, TR-5.1): temp file + rename. Last write.
# ---------------------------------------------------------------------------
if [[ "$DRY_RUN" != "1" ]]; then
  mkdir -p "$TARGET_DIR" || die_fs "cannot create $TARGET_DIR"
  MANIFEST_TMP="$TEMP_DIR/.manifest.json.tmp"
  "$NODE_BIN" "$NODE_HELPER" write "$NEW_TSV" "$MANIFEST_TMP" "$NOW" "$REPO_ROOT" || die_fs "manifest serialization failed"
  chmod 0644 "$MANIFEST_TMP" 2>/dev/null || true
  mv -f "$MANIFEST_TMP" "$MANIFEST_PATH" || die_fs "cannot commit manifest to $MANIFEST_PATH"
fi

TOTAL_MANAGED="$MANAGED_ENTRIES_COUNT"

# ---------------------------------------------------------------------------
# Summary (OBS-2 / OBS-3)
# ---------------------------------------------------------------------------
if [[ "$DRY_RUN" == "1" ]]; then
  printf '%s\n' "=== Dry-Run Summary (no files written) ==="
else
  printf '%s\n' "=== Managed Sync Summary ==="
fi
printf 'Installed:           %d\n' "$COUNT_INSTALL"
printf 'Updated:             %d\n' "$COUNT_UPDATE"
printf 'Skipped (modified):  %d\n' "$COUNT_SKIP_MODIFIED"
printf 'Skipped (orphan):    %d\n' "$COUNT_SKIP_ORPHAN"
printf 'Skipped (collision): %d\n' "$COUNT_SKIP_COLLISION"
printf 'Force overwritten:   %d\n' "$COUNT_FORCE"
printf 'No-op:               %d\n' "$COUNT_NOOP"
printf 'Errors:              %d\n' "$COUNT_ERROR"
printf 'Total managed entries: %d\n' "$TOTAL_MANAGED"

if [[ "$HAD_SOURCE_ERROR" == "1" ]]; then
  exit "$EX_USAGE"
fi
exit "$EX_OK"
