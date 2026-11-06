{ ... }:

{
  imports = [
    ./camera.nix
    ./audio.nix
    ./sof-audio-resume.nix
    ./printing.nix
    ./settings.nix
    ./memory.nix
    ./display.nix
    ./swww-compat.nix
    ./wluma.nix
    ./bibata-cursor.nix
    ./safeeyes-croniter.nix
    ./aquamarine-hotplug.nix
    ./claude-desktop.nix
    ./protect-recordings.nix
  ];
  # ./networking.nix  # for sunshine & android moonlight laptop/phone connection
  # # ./dell-xps-13-9320.nix 

  environment.systemPackages = [];
}
