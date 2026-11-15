#!/usr/bin/env bash
# Check that the two Claude accounts share rules and memory, and that every
# plugin enabled in an account's settings.json is installed at user scope there.
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

# Lists the plugin keys that are enabled (true) in DIR/settings.json, minus @builtin ones.
enabled_plugins() {
  jq -r '(.enabledPlugins // {}) | to_entries[]
    | select(.value == true and (.key | endswith("@builtin") | not)) | .key' "$1/settings.json"
}

# True when KEY has a user-scope record in DIR/plugins/installed_plugins.json
# whose installPath exists.
installed_at_user_scope() {
  local dir="$1" key="$2" path
  while IFS= read -r path; do
    [ -d "$path" ] && return 0
  done < <(jq -r --arg k "$key" '.plugins[$k][]? | select(.scope == "user") | .installPath // empty' \
    "$dir/plugins/installed_plugins.json" 2>/dev/null)
  return 1
}

check_plugins() {
  local dir="$1" key keys
  [ -f "$dir/settings.json" ] || return 0
  if ! keys=$(enabled_plugins "$dir"); then
    problem "$dir/settings.json: cannot read enabledPlugins"
    return 0
  fi
  while IFS= read -r key; do
    [ -n "$key" ] || continue
    installed_at_user_scope "$dir" "$key" \
      || problem "$dir: plugin $key is enabled but not installed at user scope"
  done <<< "$keys"
}

check_plugins "$primary"
check_plugins "$secondary"

[ "$fail" = 0 ] && echo "OK: rules and memory are shared, enabled plugins are installed"
exit "$fail"
