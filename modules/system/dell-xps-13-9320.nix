{ config, lib, pkgs, modulesPath, ... }:

let
  # Custom IVSC firmware for IPU6 webcam (essential for 9320's OVTI01A0 sensor)
  ivsc-firmware = with pkgs; stdenv.mkDerivation {
    pname = "ivsc-firmware";
    version = "main";
    src = fetchFromGitHub {
      owner = "intel";
      repo = "ivsc-firmware";
      rev = "10c214fea5560060d387fbd2fb8a1af329cb6232";
      sha256 = "sha256-kEoA0yeGXuuB+jlMIhNm+SBljH+Ru7zt3PzGb+EPBPw=";
    };
    installPhase = ''
      mkdir -p $out/lib/firmware/vsc/soc_a1_prod
      cp firmware/ivsc_pkg_ovti01a0_0.bin $out/lib/firmware/vsc/soc_a1_prod/ivsc_pkg_ovti01a0_0_a1_prod.bin
      cp firmware/ivsc_skucfg_ovti01a0_0_1.bin $out/lib/firmware/vsc/soc_a1_prod/ivsc_skucfg_ovti01a0_0_1_a1_prod.bin
      cp firmware/ivsc_fw.bin $out/lib/firmware/vsc/soc_a1_prod/ivsc_fw_a1_prod.bin
    '';
  };
in
{
  # Hardware detection and boot params
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
  boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "usb_storage" "usbhid" "sd_mod" "i915" ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.kernelParams = [ "i915.enable_psr=0" ];  # Fixes Iris Xe graphics tearing on 9320

  # Network: Use DHCP on all interfaces (fixes your breakage—overrides any laptop-specific conflicts)
  networking.useDHCP = lib.mkDefault true;
  networking.networkmanager.enable = true;  # Enables Wi-Fi, Ethernet, etc., without overrides

  # Graphics: Intel modesetting (preferred over legacy xf86videointel on 24.11+)
  services.xserver.videoDrivers = [ "modesetting" ];
  services.xserver.deviceSection = ''
    Option "DRI" "3"
    Option "TearFree" "true"
  '';

  # IPU6 Webcam (9320-specific; use libcamera for apps like Cheese/Zoom)
  hardware.ipu6.enable = true;
  hardware.ipu6.platform = "ipu6ep";
  hardware.enableRedistributableFirmware = true;
  hardware.firmware = [ ivsc-firmware ];

  # Audio: PipeWire with init fix
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  # Run `alsactl init` post-install to fix initial no-sound issue

  # Power management for laptop efficiency
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Allow unfree for IPU6 bins
  nixpkgs.config.allowUnfree = true;
}
