#!/usr/bin/env bash
# Sunday 18:00: offer the weekly review. Exit 0 always.
#
# Persistent=true means a laptop that was off on Sunday evening fires this the
# next time it boots, so the weekday check is the guard: a weekly review
# offered on Tuesday is noise. %u is 7 on Sunday. The hour check catches the
# other direction -- a Sunday-morning boot replaying last Sunday's window.
#
# 18:00, not 21:00: the daily evening review already fires at 21:00, and two
# notifications three seconds apart are one notification and one annoyance.
set -u
[ "$(date +%u)" -eq 7 ] || exit 0
[ "$(date +%-H)" -ge 12 ] || exit 0

BIN="$HOME/.local/share/bin"
# shellcheck source=/dev/null
. "$BIN/goals-lib.sh"
wait_for_dunst || exit 0

# This one opens Claude rather than a window: the weekly review writes markdown
# -- mission names and due dates from enfants-missions.md, next week's three,
# the Sunday section -- which is the part a GUI cannot sensibly do.
choice=$(dunstify --appname=cadence --urgency=low --timeout=60000 \
  --hint=string:x-dunst-stack-tag:cadence-sunday \
  --action="default,Open" \
  "Weekly review" "Ten minutes, when you have them" 2>/dev/null)

[ "$choice" = "default" ] || exit 0
exec "$BIN/goals-open.sh" "$BIN/goals-claude.sh"
