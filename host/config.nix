{ inputs, pkgs, ... }:
{
  imports = [
    inputs.hydenix.inputs.home-manager.nixosModules.home-manager
    inputs.hydenix.nixosModules.default
    ../modules/system
    ./hardware-configuration.nix

    ./environment.nix
    ./services.nix
    ./systemd.nix
    ../modules/system/input.nix
    ../modules/system/development.nix
    ../modules/system/security.nix

    # Hardware configurations
    inputs.nixos-hardware.nixosModules.common-cpu-intel # Intel CPUs
    inputs.nixos-hardware.nixosModules.common-hidpi # High-DPI displays
    inputs.nixos-hardware.nixosModules.common-pc
    # inputs.nixos-hardware.nixosModules.common-pc-laptop # Laptops
    inputs.nixos-hardware.nixosModules.common-pc-ssd # SSD storage
];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };

    #! EDIT THIS USER (must match users defined below)
    users."dori" = { ... }: {
      imports = [
        inputs.hydenix.homeModules.default
        ../modules/hm
      ];
    };
  };

  boot = {
    kernelParams = [ "i915.enable_psr=0" "i915.force_probe=4680" "dell_laptop.rfkill=0" ]; # "resume_offset=106506240" ];
    kernelModules = [ "snd_soc_rt715_sdca" "snd_sof_pci_intel_tgl" "kvm-intel" "iwlwifi" ];
    loader.systemd-boot.configurationLimit = 5;
  };

  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
    settings.auto-optimise-store = true;
  };

  # IMPORTANT: Customize the following values to match your preferences
  hydenix = {
    enable = true; # Enable the Hydenix module

    #! EDIT THESE VALUES
    hostname = "xps13-9320"; # Change to your preferred hostname
    timezone = "Europe/Paris"; # Change to your timezone
    # timezone = "Asia/Tokyo"; # Change to your timezone
    locale = "en_US.UTF-8"; # Change to your preferred locale
    boot = {
      enable = true; # enable boot module
      useSystemdBoot = true; # disable for GRUB
      grubTheme = "Pochita"; # "Retroboot" or "Pochita"
      grubExtraConfig = "i915.enable_dc=0"; # additional GRUB configuration
      kernelPackages = pkgs.linuxPackages; # zen kernel breaks suspend
    };
    gaming.enable = false; # enable gaming module
    hardware.enable = true; # enable hardware module
    network.enable = true; # enable network module
    nix.enable = true;
    system.enable = true; # enable system module

  };

  networking = {
    networkmanager = {
      enable = true;
      wifi.powersave = false;
    };
    # wireless.enable = true;
  };


  #! EDIT THESE VALUES (must match users defined above)
  users.users.dori = {
    isNormalUser = true; # Regular user account
    initialPassword =
      "fandekasp"; # Default password (CHANGE THIS after first login with passwd)
    extraGroups = [
      "wheel" # For sudo access
      "networkmanager" # For network management
      "video" # For display/graphics access
      # "input" # for whisper-overlay to use evedev
      # Add other groups as needed
    ];
    shell = pkgs.zsh; # pkgs.nushell
    homeMode = "701";
  };

  # System Version - Don't change unless you know what you're doing (helps with system upgrades and compatibility)
  system.stateVersion = "25.05";
}

