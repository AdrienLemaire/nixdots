#!/usr/bin/env bash
# Tests for modules/hm/scripts/claude-accounts-check.sh. Needs bash and jq; no rebuild.
# Usage: tests/claude-accounts-check.test.sh
set -uo pipefail

here=$(cd -- "$(dirname -- "$0")" && pwd)
script="$here/../modules/hm/scripts/claude-accounts-check.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failures=0

# Builds primary/ and secondary/ accounts under $1 with shared rules and no plugins.
make_accounts() {
  local root="$1" a
  mkdir -p "$root/primary" "$root/secondary"
  : > "$root/primary/CLAUDE.md"
  ln -s "$root/primary/CLAUDE.md" "$root/secondary/CLAUDE.md"
  for a in primary secondary; do
    mkdir -p "$root/$a/plugins"
    echo '{}' > "$root/$a/settings.json"
    echo '{"version":2,"plugins":{}}' > "$root/$a/plugins/installed_plugins.json"
  done
}

# set_enabled ROOT ACCOUNT JSON_OBJECT
set_enabled() { echo "{\"enabledPlugins\":$3}" > "$1/$2/settings.json"; }

# install ROOT ACCOUNT KEY SCOPE [make_dir=yes|no]
install_plugin() {
  local root="$1" acct="$2" key="$3" scope="$4" mk="${5:-yes}"
  local path="$root/$acct/plugins/cache/$key"
  [ "$mk" = yes ] && mkdir -p "$path"
  local file="$root/$acct/plugins/installed_plugins.json"
  jq --arg k "$key" --arg s "$scope" --arg p "$path" \
    '.plugins[$k] += [{scope: $s, installPath: $p}]' "$file" > "$file.n" && mv "$file.n" "$file"
}

# run_case NAME EXPECTED_RC PATTERN_OR_EMPTY  (uses $root prepared by the caller)
run_case() {
  local name="$1" want="$2" pattern="$3" out rc
  out=$(bash "$script" "$root/primary" "$root/secondary" 2>&1); rc=$?
  if [ "$rc" != "$want" ]; then
    echo "not ok - $name (exit $rc, wanted $want)"; echo "$out"; failures=$((failures + 1)); return
  fi
  if [ -n "$pattern" ] && ! grep -Eq -- "$pattern" <<< "$out"; then
    echo "not ok - $name (output lacks /$pattern/)"; echo "$out"; failures=$((failures + 1)); return
  fi
  echo "ok - $name"
}

new_case() { root="$tmp/$1"; make_accounts "$root"; }

new_case enabled-installed
set_enabled "$root" primary '{"a@m":true}'; set_enabled "$root" secondary '{"a@m":true}'
install_plugin "$root" primary a@m user; install_plugin "$root" secondary a@m user
run_case "enabled and installed passes" 0 "^OK"

new_case enabled-missing
set_enabled "$root" primary '{"a@m":true}'; set_enabled "$root" secondary '{"b@m":true}'
install_plugin "$root" primary a@m user
run_case "missing in secondary fails naming account and plugin" 1 "secondary: plugin b@m"

new_case missing-primary
set_enabled "$root" primary '{"a@m":true}'
run_case "missing in primary fails naming account and plugin" 1 "primary: plugin a@m"

new_case skipped
set_enabled "$root" primary '{"off@m":false,"x@builtin":true}'
set_enabled "$root" secondary '{"off@m":false,"x@builtin":true}'
run_case "false and @builtin keys are skipped" 0 "^OK"

new_case stale-path
set_enabled "$root" secondary '{"a@m":true}'
install_plugin "$root" secondary a@m user no
run_case "stale installPath fails" 1 "secondary: plugin a@m"

new_case project-scope
set_enabled "$root" secondary '{"a@m":true}'
install_plugin "$root" secondary a@m project
run_case "project-scope install does not count" 1 "secondary: plugin a@m"

new_case no-installed-file
set_enabled "$root" primary '{"a@m":true}'
rm "$root/primary/plugins/installed_plugins.json"
run_case "missing installed_plugins.json fails" 1 "primary: plugin a@m"

[ "$failures" = 0 ] && echo "all passed"
exit "$failures"
