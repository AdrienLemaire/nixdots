#!/usr/bin/env bash
# Make every project's memory folder in the secondary Claude account a symlink
# to the primary account's folder, so both accounts read and write one memory.
#
# Usage: claude-share-memory.sh PRIMARY_DIR SECONDARY_DIR
#   e.g. ~/.claude-adrien ~/.claude-founders
#
# Covers the union of projects: a project first opened in the secondary account
# gets its primary folder created. A real secondary folder is merged into the
# primary first (missing files copied, MEMORY.md entries appended by link
# target; on a content conflict the primary copy wins) and then renamed to
# memory.bak-<timestamp> beside the new link -- never deleted.
# Idempotent; a failing project warns and does not stop the others.
set -uo pipefail

primary="$1"
secondary="$2"
stamp="$(date +%Y%m%d-%H%M%S)"

warn() { echo "claude-share-memory: $*" >&2; }

# Append the secondary index lines whose link target the primary index lacks.
merge_index() {
  local src="$1" dst="$2" line target
  [ -f "$src" ] || return 0
  touch "$dst"
  while IFS= read -r line; do
    target=$(sed -nE 's/.*\]\(([^)]+)\).*/\1/p' <<<"$line")
    [ -n "$target" ] || continue
    grep -qF "($target)" "$dst" || printf '%s\n' "$line" >>"$dst"
  done <"$src"
}

# Copy secondary files into the primary folder without overwriting any.
merge_files() {
  local src="$1" dst="$2" project="$3" f name
  for f in "$src"/* "$src"/.[!.]*; do
    [ -e "$f" ] || continue
    name=$(basename -- "$f")
    if [ "$name" = MEMORY.md ]; then
      merge_index "$f" "$dst/MEMORY.md"
    elif [ ! -e "$dst/$name" ]; then
      cp -a -- "$f" "$dst/$name"
    elif ! cmp -s -- "$f" "$dst/$name"; then
      warn "$project: $name differs, kept primary copy (secondary copy in backup)"
    fi
  done
}

link_project() {
  local project="$1"
  local src="$secondary/projects/$project/memory"
  local dst="$primary/projects/$project/memory"

  mkdir -p -- "$dst" "$secondary/projects/$project" || return 1
  if [ -L "$src" ]; then
    [ "$(readlink -- "$src")" = "$dst" ] && return 0
    rm -- "$src" || return 1
  elif [ -d "$src" ]; then
    merge_files "$src" "$dst" "$project" || return 1
    mv -- "$src" "$src.bak-$stamp" || return 1
    echo "claude-share-memory: $project merged, old folder at memory.bak-$stamp"
  fi
  ln -s -- "$dst" "$src"
}

projects() {
  local root
  for root in "$primary" "$secondary"; do
    for d in "$root"/projects/*/memory; do
      [ -e "$d" ] && basename -- "$(dirname -- "$d")"
    done
  done | sort -u
}

while IFS= read -r project; do
  link_project "$project" || warn "$project: failed, left as is"
done < <(projects)
