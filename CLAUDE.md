# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## System Commands

- Build system: `sudo nixos-rebuild switch --flake .#hydenix`
- Test changes: `sudo nixos-rebuild test --flake .#hydenix`
- Update Home Manager: `nix run .#hm` or `home-manager switch --flake .#hm`
- Update flake inputs: `nix flake update`
- Update specific input: `nix flake update hydenix`
- Execute all commands by yourself except those requiring sudo (ask me to execute them)

## Architecture Overview

This is a Hydenix-based NixOS configuration that uses the flake system. The architecture follows these key patterns:

### Core Configuration Flow
1. `flake.nix` - Entry point, defines inputs (Hydenix, nixpkgs) and system configuration
2. `config.nix` - Main configuration file that imports all modules and sets Hydenix options
3. System modules in `modules/system/` - System-level configurations (audio, camera, settings)
4. Home Manager modules in `modules/hm/` - User-level configurations (Hyprland, shells, apps)
5. `environment.nix` - System packages and environment variables
6. `services.nix` - System services configuration

### Package Management
- Hydenix packages: Available via `pkgs` (from Hydenix's nixpkgs)
- User packages: Available via `pkgs.userPkgs` (from user's nixpkgs-unstable)
- Unstable packages: Available via `pkgs-unstable` parameter
- The configuration uses `allowUnfree = true` and `cudaSupport = true`

### Hyprland Configuration
- Configured through `modules/hm/default.nix` with extensive Hydenix options
- Multi-monitor setup with workspaces assigned to specific monitors
- Custom keyboard layouts (us_qwerty-fr, jp for specific devices)
- Integration with fcitx5 for input method support

## Code Style Guidelines

- Use 2-space indentation for all Nix files
- Follow standard NixOS module structure for new modules
- Import modules in `config.nix` for both system (nixModules) and user (homeModules)
- Add system packages to `environment.nix`, home packages to `modules/hm/default.nix`
- Keep configuration modular, with separate files for categories like services, hardware, etc.
- Use relative imports with `toString ./file.nix` pattern
- Hyprland configs should be organized by purpose (keybindings, windowrules, etc.)
- Follow Nix functional programming patterns and avoid imperative style

## Repository Structure

- Root directory: System-level configuration files
- `modules/hm/`: User-specific Home Manager modules and configurations
- `modules/hm/scripts/`: Custom scripts for desktop management and theming
- `modules/system/`: System-level NixOS modules
- Hardware configuration in `hardware-configuration.nix`
- Service configurations in dedicated files (`services.nix`, `systemd.nix`, etc.)

## Key Configuration Files

- `config.nix` - Main configuration with Hydenix options and user setup
- `environment.nix` - System packages and environment variables
- `modules/hm/default.nix` - Home Manager configuration with Hydenix modules
- `modules/hm/files.nix` - Home file management
- `services.nix` - System services (ollama, safeeyes, hardware support)

## Important Notes

- Hostname is set to "xps13-9320" in config.nix:97
- User "dori" with initial password (should be changed after first login)
- Uses systemd-boot (not GRUB) for booting
- Intel CPU and integrated graphics setup
- Custom keyboard layout qwerty-fr is configured
- Gaming module enabled with Lutris setup
