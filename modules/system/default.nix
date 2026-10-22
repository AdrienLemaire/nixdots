{ ... }:

{
  imports = [
    ./camera.nix
    ./audio.nix
    ./printing.nix
    ./settings.nix
    ./memory.nix
    ./display.nix
    ./swww-compat.nix
    ./bibata-cursor.nix
    ./safeeyes-croniter.nix
    ./claude-desktop.nix
  ];
  # ./networking.nix  # for sunshine & android moonlight laptop/phone connection
  # # ./dell-xps-13-9320.nix 

  environment.systemPackages = [];
}
