# TODO - Fix Integrations Later

## Removed Integrations to Fix and Re-add

### AI/Audio Tools

- [ ] **Whisper Overlay** - Re-add whisper-overlay input and packages when
      transcription issues are resolved
  - Add back `whisper-overlay` input to flake.nix
  - Add back `inputs.whisper-overlay.nixosModules.default` to config.nix
    imports
  - Add back whisper packages to environment.nix
  - Re-enable realtime-stt-server service when working

- [ ] **OpenAI Whisper** - Re-add `openai-whisper` package to environment.nix
      when performance is acceptable

### Development Tools

- [ ] **LazyVim** - Move LazyVim configuration to dotfiles
- [ ] **Tectonic** - Re-add tectonic package for LaTeX support in vim when
      working properly
- [ ] **Vectorcode** - Fix and re-enable vectorcode with chromadb integration
  - Re-enable chromadb service in services.nix
  - Add back vectorcode packages to environment.nix

### System Services

- [ ] **NordVPN** - Fix NordVPN integration and re-add nordvpn.nix import
  - Test custom NordVPN package implementation
  - Re-enable service configuration
  - Add back to config.nix imports

### Hardware Configurations

- [ ] **Hardware Overrides** - Recreate hardware-specific configurations if needed
  - Dell XPS 13 Plus specific webcam/audio fixes
  - IPU6 drivers configuration
  - Power management optimizations
- [ ] confirm that kernelParams `i915.enable_dc=0` fixes firefox crashes

### Kernel Issues

- [ ] **Zen Kernel** - Fix suspend issues with zen kernel
  - Test and re-enable `pkgs.linuxPackages_zen` when suspend works properly
  - Remove current workaround comment
