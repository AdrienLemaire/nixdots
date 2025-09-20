{ lib, pkgs, ... }: {
  fileSystems."/" = lib.mkForce {
    # device = "/dev/disk/by-uuid/bf7761a1-df16-45b2-bbe9-737a15da6819";
    device = "/dev/disk/by-label/NIXROOT";
    fsType = "ext4";
  };

  fileSystems."/boot" = lib.mkForce {
    # device = "/dev/disk/by-uuid/46F1-6F0A";
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  # Fix Intel Iris Xe graphics issues
  boot.kernelParams = [ "i915.enable_psr=0" "i915.force_probe=4680" ];

  # Use zen kernel for better hardware support
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_zen;

  boot.loader.systemd-boot.configurationLimit = 10;

  # Perform garbage collection weekly to maintain low disk usage
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 1w";
  };

  # Optimize storage
  # You can also manually optimize the store via:
  #    nix-store --optimise
  # Refer to the following link for more details:
  # https://nixos.org/manual/nix/stable/command-ref/conf-file.html#conf-auto-optimise-store
  nix.settings.auto-optimise-store = true;

  # Enable the IPU6 drivers for Dell XPS 13 Plus webcam support
  hardware.ipu6 = lib.mkForce {
    enable = true;
    platform = "ipu6ep";
  };

  hardware.enableRedistributableFirmware = lib.mkForce true;

  # Disable PulseAudio in favor of PipeWire
  hardware.pulseaudio.enable = lib.mkForce false;

  # Add audio modules for XPS 13 Plus to existing modules
  boot.kernelModules =
    lib.mkBefore [ "snd_soc_rt715_sdca" "snd_sof_pci_intel_tgl" ];

  # Add firmware-related modules for webcam
  boot.initrd.availableKernelModules =
    lib.mkBefore [ "i915" "usb_storage" "usbhid" "sd_mod" ];

  powerManagement.cpuFreqGovernor = lib.mkForce "powersave";

  security.rtkit.enable = lib.mkForce true;
}
