{ ... }:
# The 08:00 and 21:00 notifications.
#
# A timer must never open a window uninvited, so these post a notification and
# nothing more; clicking it opens the window and ignoring it costs nothing.
#
# WantedBy is timers.target, never graphical-session.target: that target never
# activates in this session (see hypridle-recycle.nix for the full story).
#
# Persistent = true so a powered-off morning still gets its brief when the
# laptop comes back. The scripts' own hour checks are what stop a catch-up fire
# arriving at the wrong end of the day. WakeSystem is deliberately unset: never
# wake the laptop to nag.
let
  notifier = name: description: calendar: {
    services.${name} = {
      Unit.Description = description;
      Service = {
        Type = "oneshot";
        # dunstify blocks until the notification is answered or expires -- the
        # only way dunst 1.13.2 can report a click. Bound it so a wedged dunst
        # cannot pin the unit open.
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

  morning = notifier "goals-morning" "Cadence morning program (08:00)" "08:00";
  evening = notifier "goals-evening" "Cadence evening review (21:00)" "21:00";
in
{
  systemd.user = {
    services = morning.services // evening.services;
    timers = morning.timers // evening.timers;
  };
}
