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


  services.safeeyes.enable = true;
}
