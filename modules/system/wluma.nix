# Adaptive brightness: the HM side (service + settings) is modules/hm/wluma.nix.
#
# nixpkgs still ships wluma 4.11.1. 5.x is what makes ALS-driven brightness
# livable here: it low-pass filters lux with real hysteresis (4.x flips at
# band edges), discovers outputs and hotplug by EDID, and adds the
# `wluma pause/resume/set/status` CLI. A system overlay because home-manager
# runs with useGlobalPkgs (see ./swww-compat.nix); drop it once nixpkgs >= 5.
{ pkgs, ... }:

{
  nixpkgs.overlays = [
    (final: prev: {
      wluma = prev.wluma.overrideAttrs (old: rec {
        version = "5.0.4";
        src = final.fetchFromGitHub {
          owner = "max-baz";
          repo = "wluma";
          tag = version;
          hash = "sha256-74DUlFkLK4RncESgKTmUfLH6aZPnDPzrISpJ8OKc0sg=";
        };
        cargoDeps = final.rustPlatform.fetchCargoVendor {
          inherit src;
          hash = "sha256-SQwtziGI8/RLynrj6dqTsqqmBlYFU/wfnBfrkyiYK0k=";
        };
        # 5.x adds a PipeWire screen-capture fallback.
        buildInputs = old.buildInputs ++ [ final.pipewire ];
      });
    })
  ];

  # Direct sysfs write access for the internal panel; without it wluma falls
  # back to logind's SetBrightness over D-Bus, which upstream says is too slow
  # for smooth transitions. Same rule as upstream's 90-wluma-backlight.rules,
  # which the nixpkgs package does not install. dori is already in `video`.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness"
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
  '';
}
