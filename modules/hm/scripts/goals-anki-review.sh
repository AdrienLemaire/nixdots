#!/usr/bin/env bash
# The Anki backlog sweep. Exit 0 always.
#
# anki-review was built on 2 Sep and has never been on a timer; this is the
# scheduling it was missing and nothing else. It is silent under the threshold,
# while paused, and after the 19:00 cutoff -- all three checks are its own, and
# it reads the same paused-until file `cadence pause` writes. --no-launch is
# what makes this safe to schedule: with Anki closed, a sweep checks and says
# nothing rather than popping the window open unattended.
#
# No notification, so nothing to wait for: it opens Anki through hyprctl when
# it was already running and the backlog clears the threshold, or it does
# nothing at all.
set -u
REPO="${GOALS_REPO:-$HOME/Projects/Perso/personal-goals}"
exec "$REPO/bin/anki-review" --no-launch "${1:-10}"
