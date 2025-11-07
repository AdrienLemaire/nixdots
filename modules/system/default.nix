{ ... }:

{
  imports = [ ./camera.nix ./audio.nix ./settings.nix]; 
  # ./networking.nix  # for sunshine & android moonlight laptop/phone connection
  # # ./dell-xps-13-9320.nix 

  environment.systemPackages = [];
}
