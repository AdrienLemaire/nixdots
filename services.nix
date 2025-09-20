{ pkgs, inputs, ... }: {
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
  services.xserver.xkb.extraLayouts."qwerty-fr" = {
    languages = [ "eng" "fra" ];
    symbolsFile = "${pkgs.qwerty-fr}/share/X11/xkb/symbols/us_qwerty-fr";
    description = "make qwerty-fr accessible as a layout in nixos";
  };

  # services.nordvpn.enable = true;

  # services.chromadb.enable = true;
  # services.chromadb = {
  #   # needed by vectorcode
  #   enable = true;
  #   package = pkgs.userPkgs.python3Packages.chromadb;
  # };

  # Start the service and expose the port to your local network.
  # services.realtime-stt-server.enable = true;
  # services.realtime-stt-server.openFirewall = true;

  # If you are running this system-wide on your local machine,
  # Add the whisper-overlay package so you can start the overlayit manually.
  # Alternatively add it to the autostart of your display environment or window manager.
  # environment.systemPackages = [pkgs.whisper-overlay];

  services.safeeyes.enable = true;
}
