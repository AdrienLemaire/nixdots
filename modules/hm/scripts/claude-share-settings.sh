#!/usr/bin/env bash
# Apply the shared settings base to a Claude Code settings.json.
#
# Usage: claude-share-settings.sh BASE_JSON SETTINGS_JSON...
#
# Each top-level key of BASE_JSON replaces the same key in the file (shallow,
# so an entry removed from the base disappears); every other key is left as
# Claude Code wrote it. When a file changes, its shared-key drift is printed,
# the previous version is kept as settings.json.bak-<timestamp>, and the new
# one is written through a temp file + mv so a live session never reads half.
set -uo pipefail

base="$1"
shift
if [ ! -f "$base" ]; then
  echo "claude-share-settings: no shared base at $base, skipped" >&2
  exit 0
fi
stamp="$(date +%Y%m%d-%H%M%S)"

apply() {
  local file="$1" tmp
  [ -f "$file" ] || echo '{}' >"$file"
  tmp=$(mktemp "$file.XXXXXX") || return 1
  jq --slurpfile base "$base" '. + $base[0]' "$file" >"$tmp" || { rm -f "$tmp"; return 1; }
  if jq -e --slurpfile new "$tmp" '. == $new[0]' "$file" >/dev/null; then
    rm -f "$tmp"
    return 0
  fi
  echo "claude-share-settings: $file drifted from the shared base, resetting:"
  diff <(jq -S --slurpfile base "$base" 'with_entries(select(.key | in($base[0])))' "$file") \
    <(jq -S . "$base") | sed 's/^/  /' || true
  cp -a -- "$file" "$file.bak-$stamp"
  chmod --reference="$file" "$tmp"
  mv -- "$tmp" "$file"
}

for file in "$@"; do
  apply "$file" || echo "claude-share-settings: $file: failed, left as is" >&2
done
