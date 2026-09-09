#!/usr/bin/env bash
# 08:00: fold yesterday, then offer today's program. Exit 0 always.
#
# Persistent=true coalesces a missed window into one catch-up fire, so booting
# the laptop at 22:00 would otherwise deliver a morning brief at bedtime. The
# hour check is the guard: after noon, a morning brief is not a morning brief.
# %-H, not %H: an unpadded hour, because 08 is not a valid octal number.
# Budget: up to 30s waiting for dunst + the fold + ~10s for the brief (it
# re-reads the sources) + the notification, which stays until it is answered
# or 12:00 arrives -- under the unit's 5h TimeoutStartSec from the earliest
# fire that passes the hour guard. The fold is ~12s of buffer folding plus
# one Milanote board render (about 15-25s of headless Chrome, once per run
# however many days it records) plus a few seconds per captured day.
set -u

# GOALS_REPO is honoured via a unit Environment= or Hyprland's env=, never via goals-open.sh, which strips the environment.
REPO="${GOALS_REPO:-$HOME/Projects/Perso/personal-goals}"
BIN="$HOME/.local/share/bin"

# The fold is the data-safety step and needs no desktop: it runs whenever
# this fires, and the hour guards below gate only the notification. Catches
# a skipped evening review -- the fold is what keeps a self-report from
# evaporating -- regardless of whether dunst is up yet or what hour it is.
# Its stderr is the only account of a fetch or a capture that failed, so it
# is kept rather than discarded; the log is appended to, never rotated here.
mkdir -p "$HOME/.local/state/cadence"
"$REPO/bin/cadence-fold" >>"$HOME/.local/state/cadence/fold.log" 2>&1 || true

hour=$(date +%-H)
# A catch-up fire at 02:00 is not a morning brief either -- Persistent=true
# only coalesces a *missed* window, and a boot in the small hours is not one.
[ "$hour" -lt 6 ] && exit 0
[ "$hour" -ge 12 ] && exit 0

# dunst starts from Hyprland's exec-once, later than timers.target.
. "$BIN/goals-lib.sh"
wait_for_dunst || exit 0

# --action uses a comma; notify-send's = would silently send no actions at all.
# The action is named `default` so middle-click works: dunst 1.13.2 draws no
# in-notification buttons and this machine's dmenu path is broken. Never a
# digit -- on expiry dunstify prints the numeric close reason on this stdout.
# The stack tag makes each cadence notification replace the previous one.
# The process must block: dunst has no on-click exec, so blocking on dunstify
# and dispatching on stdout is the only way a click can reach us.
timeout=$(ms_until 12:00) || exit 0
# The body is the two-line morning brief -- what the day holds, then the
# sentence the evening session wrote for it -- printed by `cadence brief`
# so this script holds no goal logic. $(...) drops the trailing newline and
# keeps the one between the lines; dunst renders it. Nothing printed, or a
# failed command, falls back to the fixed body the brief replaced.
body=$("$REPO/bin/cadence" brief 2>/dev/null) || body=""
[ -n "$body" ] || body="Six chains and this week's three"
choice=$(dunstify --appname=cadence --urgency=low --timeout="$timeout" \
  --hint=string:x-dunst-stack-tag:cadence-morning \
  --action="default,Open" \
  "Today's program" "$body" 2>/dev/null)

[ "$choice" = "default" ] || exit 0
exec "$BIN/goals-open.sh" "$BIN/goals-today.sh"
