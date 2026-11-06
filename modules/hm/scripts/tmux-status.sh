#!/usr/bin/env bash
# Reflect Claude's activity in the tmux window list via the per-pane user option
# @claude_pane_status; @claude_circle in modules/hm/tmux.nix shows the most urgent.
# Driven by Claude Code hooks, registered in ~/.claude/settings.json and
# ~/.claude-account2/settings.json:
#   working → 🟡   waiting-for-you → 🟢   needs-input/permission → 🔴
# No-op when not running inside tmux. Same script as the Hetzner box's
# ~/.claude/tmux-status.sh.
#
# Usage: tmux-status.sh <working|waiting|input|clear>
[ -z "$TMUX_PANE" ] && exit 0

case "$1" in
  working) status="🟡 " ;;
  waiting) status="🟢 " ;;
  input)   status="🔴 " ;;
  *)       status="" ;;
esac

tmux set-option -p -t "$TMUX_PANE" @claude_pane_status "$status" 2>/dev/null || true
exit 0
