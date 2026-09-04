{ lib, ... }:
# The cadence timers: the two daily notifications, three nudge windows, the
# Anki backlog sweep and the Sunday review.
#
# A timer must never open a window uninvited. The four notifying units --
# morning, nudge, evening, sunday -- post a notification and wait; only a
# click opens anything, and ignoring it costs nothing. goals-anki-review is
# the exception: it posts no notification at all, and stays silent unless
# Anki is already open with a backlog at or above the threshold, in which
# case it raises the existing Anki window -- it never launches Anki itself
# when run from a timer (anki-review --no-launch).
#
# WantedBy is timers.target, never graphical-session.target: that target never
# activates in this session (see hypridle-recycle.nix for the full story).
#
# Persistent = true so a powered-off morning still gets its brief when the
# laptop comes back, and missed windows coalesce into one catch-up fire rather
# than one per window. Four guards stop a catch-up arriving at the wrong end of
# the day: the hour checks in goals-morning/goals-evening, the weekday check in
# goals-sunday, the 19:00 cutoff inside cadence-nudge, and anki-review's own.
# WakeSystem is deliberately unset: never wake the laptop to nag.
#
# Suspend/resume needs no Persistent -- the user manager survives sleep and
# fires on resume.
let
  notifier = name: description: calendar: timeout: {
    services.${name} = {
      Unit.Description = description;
      Service = {
        Type = "oneshot";
        # dunstify blocks until the notification is answered or expires -- the
        # only way dunst 1.13.2 can report a click. Bound it so a wedged dunst
        # cannot pin the unit open. The three offers (morning, evening,
        # Sunday) carry a deadline in the notification itself and may wait
        # hours; the nudge and Anki units need only the notification-bus wait
        # (30s) plus anki-review's wait for Anki to come up (25s).
        TimeoutStartSec = timeout;
        ExecStart = "%h/.local/share/bin/${name}.sh";
      };
    };
    timers.${name} = {
      Unit.Description = description;
      Timer = {
        OnCalendar = [ calendar ];
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };

  # OnCalendar takes a list in home-manager, and one string covers a whole
  # family of windows: "09,13,17:00" normalises to *-*-* 09,13,17:00:00.
  units = [
    (notifier "goals-morning" "Cadence morning program (08:00)" "08:00" "5h")
    (notifier "goals-nudge"
      "Cadence nudge windows (09:00/13:00/17:00)" "09,13,17:00" "120s")
    (notifier "goals-anki-review"
      "Anki backlog sweep (2-hourly, 09:00-17:00)" "09,11,13,15,17:00" "120s")
    (notifier "goals-evening" "Cadence evening review (21:00)" "21:00" "5h")
    (notifier "goals-sunday" "Cadence weekly review (Sun 18:00)" "Sun 18:00" "10h")
  ];
  merge = attr: lib.foldl' (acc: unit: acc // unit.${attr}) { } units;
in
{
  systemd.user = {
    services = merge "services";
    timers = merge "timers";
  };
}
