{ pkgs, ... }:
{
  # Mitigate the hypridle dbus-wedge bug (upstream hyprwm/hypridle#12,
  # Stremio/stremio-bugs#695): hypridle's single-threaded event loop
  # intermittently stops draining its D-Bus socket (it wedges on idle-inhibit
  # handling / a spawned on-timeout command). Normal-rate ScreenSaver
  # Inhibit/UnInhibit traffic then backs up in dbus-broker against hypridle's
  # peer until it consumes uid 1000's entire per-user byte quota (~263 MB,
  # observed accumulating over ~5.5 days uptime). Once the pool is full,
  # dbus-broker fatally disconnects other peers — killing xdg-desktop-portal
  # and crash-looping waybar (which then blocks 25s on the dead portal). See
  # the waybar-portal-crash-loop memory. Recycling hypridle well before the
  # quota saturates keeps the pool from ever filling; the killed backlog is
  # released the instant its peer disconnects.
  #
  # Launch-path note: HyDE starts hypridle as an unmanaged `exec-once = hypridle`
  # (its hyprland.conf), NOT via the package's hypridle.service, and this is a
  # non-systemd-managed session (graphical-session.target never activates). So
  # we recycle launch-path-agnostically: kill EVERY hypridle, then re-exec one
  # through the live Hyprland instance, exactly as HyDE does (single instance
  # afterward; exec-once won't re-fire). The instance signature is probed from
  # the runtime socket dir because Hyprland marks itself non-dumpable, and we
  # use the system hyprctl so the IPC version matches the compositor — same
  # approach as hypr-reload.nix.
  #
  # 8h cadence bounds worst-case accumulation to ~16 MB (<10% of the quota)
  # while being far too infrequent to perturb idle/lock/suspend timers.

  systemd.user.services.hypridle-recycle = {
    Unit.Description = "Recycle hypridle to bound its dbus-broker byte backlog";
    Service = {
      Type = "oneshot";
      ExecStart = toString (pkgs.writeShellScript "hypridle-recycle" ''
        set -u
        hyprctl=/run/current-system/sw/bin/hyprctl
        rt="''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}"
        his=""
        if [ -x "$hyprctl" ] && [ -d "$rt/hypr" ]; then
          for d in "$rt"/hypr/*/; do
            s=$(${pkgs.coreutils}/bin/basename "$d")
            if HYPRLAND_INSTANCE_SIGNATURE="$s" "$hyprctl" version >/dev/null 2>&1; then
              his="$s"; break
            fi
          done
        fi
        if [ -z "$his" ]; then
          echo "no live Hyprland instance; skipping recycle"
          exit 0
        fi
        echo "recycling hypridle (instance $his)"
        ${pkgs.procps}/bin/pkill -x hypridle || true
        ${pkgs.coreutils}/bin/sleep 1
        HYPRLAND_INSTANCE_SIGNATURE="$his" "$hyprctl" dispatch exec hypridle >/dev/null 2>&1 || true
      '');
    };
  };

  systemd.user.timers.hypridle-recycle = {
    Unit.Description = "Periodic hypridle recycle (dbus-quota guard)";
    Timer = {
      OnBootSec = "8h";
      OnUnitActiveSec = "8h";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
