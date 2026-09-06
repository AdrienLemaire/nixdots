{ inputs, pkgs, ... }:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    inputs.hydenix.nixosModules.default
    ../modules/system
    ./hardware-configuration.nix

    ./environment.nix
    ./services.nix
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

    # hid-vivaldi costs ~3 s on every BLE keyboard reconnect. Its
    # vivaldi_feature_mapping() does a synchronous blocking feature-report read
    # once per function-row key during probe -- 12 keys, 12 GATT round trips
    # over the air, before the input device is registered. All twelve return
    # 0x000C0000 on the MX Keys Mini, so the remap data it buys is degenerate.
    # Measured: link->usable hid=3.17s with it, hid=0.11s without.
    # Falls back to hid-generic. See docs/bluetooth-reconnect-findings.md.
    blacklistedKernelModules = [ "hid_vivaldi" ];
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

  # These govern the INITIAL LE connection only. Verified by HCI trace
  # (docs/bt-trace.sh): the link comes up on these values, then ~165 ms later
  # the keyboard sends an L2CAP Connection Parameter Update Request and bluez
  # accepts it unconditionally -- the kernel only sanity-checks against spec
  # ranges, there is no policy hook. The MX Keys Mini pulls the link to
  # 22.5 ms / latency 20 / supervision 2100 ms and that is where it stays.
  #
  # So ConnectionSupervisionTimeout = 600 does NOT hold: 2100 ms is exactly the
  # value blamed for the Reason 0x08 Connection Timeout drops, and the keyboard
  # restores it within half a second of every connect. Keeping it because it
  # costs nothing and still covers the connection window, but do not count on
  # it -- see docs/bluetooth-reconnect-findings.md for the full trace analysis.
  #
  # The fast interval is likewise a setup-window optimisation, not a
  # steady-state one, which also means it is nearly free: enumeration is ATT
  # round-trip bound (184 PDUs, median 44 ms each) and only its first ~450 ms
  # runs at our interval. Measured gain 0.35 s of ~3.5 s. Units: intervals are
  # in 1.25 ms, ConnectionLatency counts intervals the peripheral may skip,
  # ConnectionSupervisionTimeout is in 10 ms.
  hardware.bluetooth.settings.LE = {
    MinConnectionInterval = 6;           # 7.5 ms
    MaxConnectionInterval = 12;          # 15 ms
    ConnectionLatency = 0;
    ConnectionSupervisionTimeout = 600;  # 6000 ms; keyboard resets it to 2100
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

