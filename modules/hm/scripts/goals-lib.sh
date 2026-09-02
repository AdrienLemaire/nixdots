# Sourced, not executed: shared helpers for the goals-* notification scripts.
#
# dunst is started by Hyprland's exec-once, which runs later than
# timers.target. A Persistent=true timer's catch-up fire on a fresh boot can
# therefore land before dunst is listening, and dunstify would post into the
# void with nothing to read the click. wait_for_dunst is the guard: give
# dunst a chance to come up before the first notification of the session.

# wait_for_dunst: poll for org.freedesktop.Notifications having a live owner
# on the session bus, once a second, up to $GOALS_DUNST_WAIT seconds
# (default 30, overridable for tests). Returns 0 once it appears, 1 on
# timeout.
#
# `busctl --user list` alone would also match an *activatable* name -- one a
# .service file merely offers, whether or not anything currently owns it --
# so a bus with dunst's service file installed but dunst not yet running
# would pass immediately, which is exactly the race this guards against.
# `--acquired` restricts the listing to names with a live owner.
wait_for_dunst() {
  local waited=0
  local budget="${GOALS_DUNST_WAIT:-30}"
  while [ "$waited" -lt "$budget" ]; do
    if busctl --user list --acquired 2>/dev/null \
        | grep -q '^org\.freedesktop\.Notifications\b'; then
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done
  return 1
}
