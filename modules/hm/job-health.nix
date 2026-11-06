{ ... }:
# Desktop notice when job-hunt's automation has a problem. GitHub Actions can't
# reach this laptop, so a timer polls instead. The script notifies once per
# problem and says nothing when all is well (job-hunt: scripts/job-health.sh).
#
# WantedBy is timers.target, never graphical-session.target: see goals-notify.nix.
{
  systemd.user = {
    services.job-health = {
      Unit.Description = "Check job-hunt automation for problems";
      Service = {
        Type = "oneshot";
        TimeoutStartSec = "60s";
        # A user unit's PATH doesn't include gh, jq or notify-send.
        Environment = "PATH=/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin";
        ExecStart = "%h/Projects/Perso/job-hunt/scripts/job-health.sh --notify";
      };
    };
    timers.job-health = {
      Unit.Description = "Check job-hunt automation every 30 minutes";
      Timer = {
        OnCalendar = [ "*:00,30" ];
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
