#!/usr/bin/env bash
# Check that the two Claude accounts share rules and memory.
# Usage: claude-accounts-check.sh PRIMARY_DIR SECONDARY_DIR
# Exits non-zero, listing each problem, when anything is not shared.
set -uo pipefail

primary="$1"
secondary="$2"
fail=0

problem() { echo "FAIL: $*"; fail=1; }

[ "$(readlink -f -- "$secondary/CLAUDE.md")" = "$(readlink -f -- "$primary/CLAUDE.md")" ] \
  || problem "$secondary/CLAUDE.md is not a link to $primary/CLAUDE.md"

for d in "$secondary"/projects/*/memory; do
  [ -e "$d" ] || [ -L "$d" ] || continue
  project=$(basename -- "$(dirname -- "$d")")
  if [ ! -L "$d" ]; then
    problem "$project: secondary memory is a real directory"
  elif [ "$(readlink -- "$d")" != "$primary/projects/$project/memory" ] || [ ! -d "$d" ]; then
    problem "$project: secondary memory link points to $(readlink -- "$d")"
  fi
done

for d in "$primary"/projects/*/memory; do
  [ -e "$d" ] || continue
  project=$(basename -- "$(dirname -- "$d")")
  [ -L "$secondary/projects/$project/memory" ] || problem "$project: no secondary memory link"
done

[ "$fail" = 0 ] && echo "OK: rules and memory are shared"
exit "$fail"
