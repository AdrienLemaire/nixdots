#!/usr/bin/env bash
# One nudge window (09:00 / 13:00 / 17:00). Exit 0 always.
#
# Shell drives, Python decides. cadence-nudge applies the four circuit
# breakers -- pause, 19:00 cutoff, dismissal cap, snooze-once -- picks at most
# one thing, marks it nudged and prints one TAB-separated line. Nothing to say
# prints nothing, which is the normal case and costs one fork.
#
# The wait comes before the ask, so a nudge is never spent on a boot where
# dunst had not started yet: nothing is marked until there is somewhere to
# post it.
set -u
REPO="${GOALS_REPO:-$HOME/Projects/Perso/personal-goals}"
BIN="$HOME/.local/share/bin"

# shellcheck source=/dev/null
. "$BIN/goals-lib.sh"
wait_for_dunst || exit 0

line=$("$REPO/bin/cadence-nudge" 2>/dev/null) || exit 0
[ -n "$line" ] || exit 0

# Tab is whitespace in IFS, so consecutive tabs would collapse and shift the
# fields left. cadence-nudge guarantees all four are non-empty for exactly
# this reason; the guard below is a belt to that brace.
IFS=$'\t' read -r kind id summary body <<<"$line"
[ -n "${summary:-}" ] && [ -n "${body:-}" ] || exit 0

# A note is the weekly ceiling speaking. Low urgency, no actions, nothing to
# answer: on that goal the system's job is to stop you, not start you.
# dunstify only blocks when it has actions, so this returns at once.
if [ "$kind" = "note" ]; then
  dunstify --appname=cadence --urgency=low --timeout=30000 \
    --hint=string:x-dunst-stack-tag:cadence-nudge \
    "$summary" "$body" >/dev/null 2>&1
  exit 0
fi

# --action uses a comma; notify-send's = would silently send the notification
# with no actions at all. `default` fires on middle-click, which is the only
# path dunst 1.13.2 offers with certainty -- the left-click menu needs the
# dmenu fix in Task 4. Never name an action with a digit: on expiry dunstify
# prints the numeric close reason on this same stdout, which is exactly what
# the fallthrough below reads as "unanswered".
# The stack tag makes each nudge replace the previous one, so three windows
# can never pile into three notifications.
# The process must block: dunst has no on-click exec, and `script =` fires on
# arrival rather than on click.
choice=$(dunstify --appname=cadence --urgency=low --timeout=30000 \
  --hint=string:x-dunst-stack-tag:cadence-nudge \
  --action="default,Mark done" --action="snooze,Snooze" \
  "$summary" "$body" 2>/dev/null)
rc=$?

# An empty choice means "expired unanswered" only when dunstify actually ran
# the notification. dunst dying mid-wait, or dunstify itself failing to
# launch, also leaves $choice empty but with a non-zero rc -- that is a
# notification nobody ever saw, not one that was dismissed, so it must not
# count against the dismissal cap.
case "$choice" in
  default) "$REPO/bin/cadence-record" "$id" ;;
  snooze)  "$REPO/bin/cadence-record" "$id" snooze ;;
  *)       [ "$rc" -eq 0 ] && "$REPO/bin/cadence-nudge" --dismissed ;;
esac
exit 0
