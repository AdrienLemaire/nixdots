{ inputs,  ... }:
let
  # Package declaration
  # ---------------------

  pkgs = import inputs.hydenix.inputs.hydenix-nixpkgs {
    inherit (inputs.hydenix.lib) system;
    config.allowUnfree = true;
    # Also make sure to enable cuda support in nixpkgs, otherwise transcription will
    # be painfully slow. But be prepared to let your computer build packages for 2-3 hours.
    config.cudaSupport = true;

    overlays = [
      inputs.hydenix.lib.overlays
      # Overlay to add userPkgs from unstable nixpkgs
      (final: prev: {
        userPkgs = import inputs.nixpkgs {
          inherit (inputs.hydenix.lib) system;
          config.allowUnfree = true;
        };
      })
    ];
  };
in {

  # Set pkgs for hydenix globally, any file that imports pkgs will use this
  nixpkgs.pkgs = pkgs;

  imports = [
    inputs.hydenix.inputs.home-manager.nixosModules.home-manager
    ./hardware-configuration.nix
    inputs.hydenix.lib.nixOsModules
    ./modules/system
    ./environment.nix
    ./services.nix
    ./systemd.nix
    ./nix-modules.nix

    # Hardware configurations
    inputs.hydenix.inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.hydenix.inputs.nixos-hardware.nixosModules.common-pc
    inputs.hydenix.inputs.nixos-hardware.nixosModules.common-pc-ssd
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };

    #! EDIT THIS USER (must match users defined below)
    users."dori" = { ... }: {
      imports = [
        inputs.hydenix.lib.homeModules
        ./modules/hm
        inputs.nix-index-database.homeModules.nix-index
      ];
    };
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
      grubExtraConfig = ""; # additional GRUB configuration
      kernelPackages = pkgs.linuxPackages; # zen kernel breaks suspend
    };
    gaming.enable = true; # enable gaming module
    hardware.enable = true; # enable hardware module
    network.enable = true; # enable network module
    nix.enable = true; # enable nix module
    sddm = {
      enable = true; # enable sddm module
      theme = "Corners"; # "Candy" or "Corners"
    };
    system.enable = true; # enable system module

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
      "input" # for whisper-overlay to use evedev
      # Add other groups as needed
    ];
    shell = pkgs.zsh; # pkgs.nushell
  };
}

