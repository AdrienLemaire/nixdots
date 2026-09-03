{ lib, ... }:
# The cadence timers: the two daily notifications, three nudge windows, the
# Anki backlog sweep and the Sunday review.
#
# A timer must never open a window uninvited, so these post a notification and
# nothing more; clicking it opens the window and ignoring it costs nothing.
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
  notifier = name: description: calendar: {
    services.${name} = {
      Unit.Description = description;
      Service = {
        Type = "oneshot";
        # dunstify blocks until the notification is answered or expires -- the
        # only way dunst 1.13.2 can report a click. Bound it so a wedged dunst
        # cannot pin the unit open. It also covers the notification-bus wait
        # (30s) and anki-review's wait for Anki to come up (25s).
        TimeoutStartSec = "120s";
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
    (notifier "goals-morning" "Cadence morning program (08:00)" "08:00")
    (notifier "goals-nudge"
      "Cadence nudge windows (09:00/13:00/17:00)" "09,13,17:00")
    (notifier "goals-anki-review"
      "Anki backlog sweep (2-hourly, 09:00-17:00)" "09,11,13,15,17:00")
    (notifier "goals-evening" "Cadence evening review (21:00)" "21:00")
    (notifier "goals-sunday" "Cadence weekly review (Sun 18:00)" "Sun 18:00")
  ];
  merge = attr: lib.foldl' (acc: unit: acc // unit.${attr}) { } units;
in
{
  systemd.user = {
    services = merge "services";
    timers = merge "timers";
  };
}
