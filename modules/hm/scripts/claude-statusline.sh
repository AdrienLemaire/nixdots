#!/usr/bin/env bash
# Claude Code statusline: colored account badge + model + cwd + git branch.
# Both accounts point their settings.json at this script; the account is
# detected from CLAUDE_CONFIG_DIR (unset = default ~/.claude account), and
# the badge shows the logged-in email prefix so sessions are telling apart
# at a glance: green = ~/.claude, magenta = ~/.claude-account2.

input=$(cat)

# The default account keeps its state in ~/.claude.json; alternate config
# dirs keep it inside the dir.
cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
state="$cfg/.claude.json"
[ "$cfg" = "$HOME/.claude" ] && state="$HOME/.claude.json"
email=$(jq -r '.oauthAccount.emailAddress // empty' "$state" 2>/dev/null)
name="${email%%@*}"

if [ "$cfg" = "$HOME/.claude" ]; then
  badge=$'\e[30;42;1m'" ${name:-account1} "$'\e[0m' # green
else
  badge=$'\e[30;45;1m'" ${name:-account2} "$'\e[0m' # magenta
fi

model=$(jq -r '.model.display_name // empty' <<<"$input")
dir=$(jq -r '.workspace.current_dir // .cwd // empty' <<<"$input")

branch=$(git -C "$dir" branch --show-current 2>/dev/null)

printf '%s %s  %s' "$badge" "$model" "${dir/#$HOME/\~}"
[ -n "$branch" ] && printf '  (%s)' "$branch"
