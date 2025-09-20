# Dell XPS 13 Plus 9320 Webcam and Audio Configuration

This guide covers how to get webcam and audio working properly on a Dell XPS 13 Plus 9320 running NixOS.

## Webcam Configuration

The XPS 13 Plus uses an Intel IPU6 (Image Processing Unit) webcam that requires specific kernel support.

### Configuration Steps

1. **Enable IPU6 drivers in NixOS configuration**:
   
   In `hardware-overrides.nix`:
   ```nix
   hardware.ipu6 = {
     enable = true;
     platform = "ipu6ep";  # For Alder Lake-based systems
   };
   ```

2. **Ensure kernel modules are loaded**:
   
   Add essential modules to `boot.initrd.availableKernelModules`:
   ```nix
   boot.initrd.availableKernelModules = lib.mkBefore [ "i915" "usb_storage" "usbhid" "sd_mod" ];
   ```

3. **Install v4l-utils and required packages**:
   
   ```nix
   environment.systemPackages = with pkgs; [
     v4l-utils
     linuxKernel.packages.linux_zen.ipu6-drivers
   ];
   ```

4. **Testing the webcam**:
   
   After rebuilding and rebooting, test with:
   ```bash
   v4l2-ctl --list-devices
   # Should show Intel IPU6 MIPI CSI-2 webcam
   
   # Test video capture
   mpv av://v4l2:/dev/video0
   # or
   ffplay /dev/video0
   ```

## Audio Configuration

The XPS 13 Plus uses Sound Open Firmware (SOF) for audio and requires specific configurations.

### Configuration Steps

1. **Enable PipeWire for audio**:
   
   In `services.nix`:
   ```nix
   services.pipewire = {
     enable = true;
     alsa.enable = true;
     alsa.support32Bit = true;
     pulse.enable = true;
     jack.enable = true;
     
     extraConfig.pipewire = {
       "context.properties" = {
         "default.clock.rate" = 48000;
         "default.clock.quantum" = 256;
         "default.clock.min-quantum" = 256;
         "default.clock.max-quantum" = 256;
       };
     };
   };
   ```

2. **Disable PulseAudio in favor of PipeWire**:
   
   ```nix
   hardware.pulseaudio.enable = false;
   ```

3. **Load audio kernel modules**:
   
   ```nix
   boot.kernelModules = lib.mkBefore [
     "snd_soc_rt715_sdca"
     "snd_sof_pci_intel_tgl"
   ];
   ```

4. **Install SOF firmware**:
   
   ```nix
   environment.systemPackages = with pkgs; [
     sof-firmware
   ];
   ```

5. **Testing audio**:
   
   After rebuilding and rebooting:
   ```bash
   # List audio devices
   pactl list short sinks
   pactl list short sources
   
   # Play test sound
   paplay /usr/share/sounds/alsa/Front_Center.wav
   
   # Test microphone recording
   arecord -f cd -d 5 test.wav && aplay test.wav
   ```

## BIOS Settings

Several BIOS settings can affect webcam and audio functionality:

1. **Access BIOS**: Restart and press F2 during boot
2. **BIOS settings to check**:
   - Make sure IPU is enabled in BIOS
   - Ensure audio is not disabled
   - Check if "USB Security" allows webcam access
   - Verify that "Thunderbolt Security Level" is set appropriately

## Firmware Updates

Dell XPS firmware updates can fix hardware issues:

1. **Install fwupd**:
   ```nix
   environment.systemPackages = with pkgs; [
     fwupd
   ];
   services.fwupd.enable = true;
   ```

2. **Update firmware**:
   ```bash
   # List available firmware
   fwupdmgr get-devices
   
   # Check for updates
   fwupdmgr refresh
   fwupdmgr get-updates
   
   # Apply updates (requires reboot)
   fwupdmgr update
   ```

## Troubleshooting

### Webcam Issues
- Check if `/dev/video0` (or similar) exists
- Verify kernel modules are loaded: `lsmod | grep ipu`
- Check logs: `dmesg | grep -i ipu`
- Test with different applications (Firefox, Chromium, mpv)

### Audio Issues
- Check volume levels: `alsamixer` or `pavucontrol`
- Verify PipeWire is running: `systemctl --user status pipewire`
- Check kernel modules: `lsmod | grep sof`
- Check audio logs: `journalctl -b -k | grep -i sof`

## Known Issues and Limitations

1. **Microphone noise**: Some users report noise when using the microphone. This can sometimes be addressed with:
   ```nix
   services.pipewire.extraConfig.pipewire = {
     "context.modules" = [
       {
         name = "libpipewire-module-echo-cancel";
         args = {
           "aec.method" = "webrtc";
           "aec.args" = {
             "high_pass_filter" = true;
             "noise_suppression" = true;
           };
         };
       }
     ];
   };
   ```

2. **Webcam performance**: The webcam may show reduced performance under low light conditions. This is a hardware limitation.

3. **Suspending issues**: Some users report audio not working after suspend/resume. A temporary fix is to reload the module:
   ```bash
   sudo rmmod snd_sof_pci_intel_tgl
   sudo modprobe snd_sof_pci_intel_tgl
   ```
