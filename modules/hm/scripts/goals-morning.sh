#!/usr/bin/env bash
# 08:00: fold yesterday, then offer today's program. Exit 0 always.
#
# Persistent=true coalesces a missed window into one catch-up fire, so booting
# the laptop at 22:00 would otherwise deliver a morning brief at bedtime. The
# hour check is the guard: after noon, a morning brief is not a morning brief.
# %-H, not %H: an unpadded hour, because 08 is not a valid octal number.
set -u
hour=$(date +%-H)
[ "$hour" -ge 12 ] && exit 0

REPO="${GOALS_REPO:-$HOME/Projects/Perso/personal-goals}"
# Catches a skipped evening review: the fold is what keeps a self-report from
# evaporating, so it runs before anything is shown.
"$REPO/bin/cadence-fold" >/dev/null 2>&1 || true

# --action uses a comma; notify-send's = would silently send no actions at all.
# The action is named `default` so middle-click works: dunst 1.13.2 draws no
# in-notification buttons and this machine's dmenu path is broken. Never a
# digit -- on expiry dunstify prints the numeric close reason on this stdout.
# The stack tag makes each cadence notification replace the previous one.
# The process must block: dunst has no on-click exec, so blocking on dunstify
# and dispatching on stdout is the only way a click can reach us.
choice=$(dunstify --appname=cadence --urgency=low --timeout=60000 \
  --hint=string:x-dunst-stack-tag:cadence \
  --action="default,Open" \
  "Today's program" "Six chains and this week's three" 2>/dev/null)

[ "$choice" = "default" ] || exit 0
exec "$HOME/.local/share/bin/goals-open.sh" "$HOME/.local/share/bin/goals-today.sh"
