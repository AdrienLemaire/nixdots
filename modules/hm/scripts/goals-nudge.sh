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
# dmenu fix in Task 4. Never name an action with a digit: when no action is
# chosen dunstify prints the numeric close reason on this same stdout, and
# the case below tells the two apart by name.
# The stack tag makes each nudge replace the previous one, so three windows
# can never pile into three notifications.
# The process must block: dunst has no on-click exec, and `script =` fires on
# arrival rather than on click.
choice=$(dunstify --appname=cadence --urgency=low --timeout=30000 \
  --hint=string:x-dunst-stack-tag:cadence-nudge \
  --action="default,Mark done" --action="snooze,Snooze" \
  "$summary" "$body" 2>/dev/null)
rc=$?

# With no action chosen, dunstify prints the close reason as a number:
#   1  expired    -- the 30 seconds ran out; nobody was at the screen
#   2  dismissed  -- the owner closed it
#   3  closed     -- a CloseNotification call: dunstctl, the stack tag being
#                    reused by the next nudge, the session ending
# Only 2 is an answer. Counting 1 and 3 as dismissals is what spent the day's
# cap by 13:00 every day from 3 Sep: two windows nobody was in front of ended
# the day. 1 and 3 do nothing at all -- the goal is already in `nudged`, so
# the rotation moves on to the next one at the next window either way.
#
# rc is still checked on the path that counts: dunst dying mid-wait, or
# dunstify failing to launch, prints nothing and is not a dismissal either.
case "$choice" in
  default) "$REPO/bin/cadence-record" "$id" ;;
  snooze)  "$REPO/bin/cadence-record" "$id" snooze ;;
  2)       [ "$rc" -eq 0 ] && "$REPO/bin/cadence-nudge" --dismissed ;;
  *)       : ;;
esac
exit 0
