{ config, pkgs, inputs, ... }: {
  services.hardware.bolt.enable = true;

  # Enable firmware updates through fwupd
  services.fwupd.enable = true;

  services.pcscd.enable = true;

  services.locate = {
    enable = true;
    package = pkgs.plocate;
  };
  services.ollama.enable = true;

  services.xserver.videoDrivers = [ "intel" ];
  services.xserver.deviceSection = ''
    Option "DRI" "2"
    Option "TearFree" "true"
  '';
  # The attribute name IS the layout name: it becomes symbols/<name> in the
  # merged xkb tree, so it must match the kb_layout used in modules/hm.
  # AltGr+S gives á/Á instead of æ/Æ (æ stays reachable via Compose a e).
  services.xserver.xkb.extraLayouts."us_qwerty-fr" = {
    languages = [ "eng" "fra" ];
    symbolsFile = pkgs.runCommand "us_qwerty-fr" { } ''
      sed '/key <AC02>/s/ae, *AE /aacute, Aacute/' \
        ${pkgs.qwerty-fr}/share/X11/xkb/symbols/us_qwerty-fr > $out
      grep -q 'key <AC02>.*aacute, Aacute' $out
    '';
    description = "make qwerty-fr accessible as a layout in nixos";
  };
  # JIS keyboards: keep the printed JIS legends, add qwerty-fr accents on AltGr.
  # Includes us_qwerty-fr(qwerty-fr) above, which lands in the same merged tree.
  services.xserver.xkb.extraLayouts."jp_qwerty-fr" = {
    languages = [ "jpn" "fra" ];
    symbolsFile = ./xkb/jp_qwerty-fr;
    description = "JIS layout with qwerty-fr AltGr accents";
  };

  # Login screen. SDDM's wayland greeter runs weston, and NixOS generates its
  # weston.ini keymap_* straight from services.xserver.xkb.*. Hyprland sets its
  # own per-device kb_layout, so this only affects the greeter, not the session.
  # Laptop layout first: the MX Keys Mini is Bluetooth and is usually not paired
  # yet at the login screen. Alt+Shift switches to the JIS group once it is.
  services.xserver.xkb.layout = "us_qwerty-fr,jp_qwerty-fr";
  services.xserver.xkb.options = "terminate:ctrl_alt_bksp,grp:alt_shift_toggle";

  # extra-layouts.nix exports XKB_CONFIG_ROOT to *user sessions* only, so the
  # display-manager unit cannot resolve the custom layouts without this.
  systemd.services.display-manager.environment.XKB_CONFIG_ROOT =
    config.services.xserver.xkb.dir;


  services.safeeyes.enable = true;

  # Backs the waybar power-profiles-daemon module (dropped silently without
  # the service) and HyDE's powerprofilesctl calls. No TLP/auto-cpufreq here.
  services.power-profiles-daemon.enable = true;
}
