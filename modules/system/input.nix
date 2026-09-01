{ config, pkgs, ... }: {
  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [ fcitx5-mozc fcitx5-gtk catppuccin-fcitx5 ];
    };
  };

  # nixpkgs' i18n.inputMethod module ships no unit: it only installs the wrapped
  # package, the /etc/xdg/fcitx5 config and a D-Bus activation file. fcitx5 was
  # therefore an unsupervised Hyprland `exec-once`, and when it went away
  # (observed 2026-08-29: not running, no coredump, no OOM kill, ~12 days into
  # the session) nothing brought it back -- the keyboard kept emitting
  # Zenkaku_Hankaku into the void and Japanese input silently died.
  #
  # Restart=always, not on-failure: the likely exit path here is a clean one
  # rather than a crash. fcitx5 is a D-Bus peer, and dbus-broker fatally
  # disconnects uid-1000 peers once the per-user byte quota saturates -- the
  # same failure that crash-loops waybar, see modules/hm/hypridle-recycle.nix.
  # on-failure would not catch that exit(0). The start limit caps the blast
  # radius if it ever does wedge in a respawn loop.
  #
  # Deliberately NOT wantedBy graphical-session.target: HyDE never activates it
  # (verified inactive), so that would be a dead start path. The sole trigger is
  # the exec-once in modules/hm/default.nix, and it runs `restart`, not `start`:
  # Linger=yes keeps this user manager alive across logout, so an instance
  # surviving from a previous session would still be bound to the dead
  # compositor's Wayland socket and would serve no IME to the new one.
  systemd.user.services.fcitx5 = {
    description = "Fcitx5 input method editor";
    unitConfig = {
      StartLimitIntervalSec = 60;
      StartLimitBurst = 5;
    };
    # systemd.user.services pins a minimal PATH that omits the IME's own tools,
    # which would leave the tray menu's Configure entry unable to find
    # fcitx5-configtool.
    path = [ config.i18n.inputMethod.package ];
    serviceConfig = {
      Type = "simple";
      # -r (replace) is load-bearing, not a leftover from the old exec-once:
      # fcitx5 that loses the org.fcitx.Fcitx5 name race logs "Is there another
      # fcitx already running?" and exits *0*, so without it any competing
      # instance -- a leftover, or one spawned through the D-Bus activation file
      # nixpkgs installs -- would pin this unit in a 2s respawn loop that
      # Restart=always cannot break. Verified 2026-08-29.
      # No -d: systemd supervises the process, so it must stay in the foreground.
      ExecStart = "${config.i18n.inputMethod.package}/bin/fcitx5 -r";
      Restart = "always";
      RestartSec = 2;
    };
  };
}
