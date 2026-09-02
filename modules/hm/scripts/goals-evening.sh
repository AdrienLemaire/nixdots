#!/usr/bin/env bash
# 21:00: offer the evening review. Exit 0 always.
#
# The mirror of the morning guard: a catch-up fire at 08:00 the next day would
# ask you to review a day that already ended.
# Budget: up to 30s waiting for dunst + up to 60s for the notification is
# comfortably under the unit's 120s TimeoutStartSec.
set -u
hour=$(date +%-H)
[ "$hour" -lt 20 ] && exit 0

. "$HOME/.local/share/bin/goals-lib.sh"
wait_for_dunst || exit 0

# Same mechanics as the morning: comma-separated action named `default`, the
# cadence stack tag so nothing piles up, blocking so the click can be read.
choice=$(dunstify --appname=cadence --urgency=low --timeout=60000 \
  --hint=string:x-dunst-stack-tag:cadence \
  --action="default,Open" \
  "Evening review" "What happened today" 2>/dev/null)

[ "$choice" = "default" ] || exit 0
exec "$HOME/.local/share/bin/goals-open.sh" "$HOME/.local/share/bin/goals-review.sh"
