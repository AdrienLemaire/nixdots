# NixOS Configuration

Modern NixOS setup with Hyprland, migrating from Hydenix to standard nixpkgs-unstable.

## System Info

- **Hostname**: xps13-9320
- **Desktop**: Hyprland (Wayland)
- **Shell**: Nushell + Zsh
- **Terminal**: Ghostty, Kitty
- **Editor**: Neovim (LazyVim)
- **Theme**: Catppuccin (via Stylix migration in progress)
- **Input**: fcitx5 with Mozc (Japanese), custom US-QWERTY-FR layout

## Quick Commands

```bash
# Test changes (no bootloader entry)
sudo nixos-rebuild test --flake .#xps13-9320

# Apply changes
sudo nixos-rebuild switch --flake .#xps13-9320

# Update all inputs
nix flake update

# Update specific input
nix flake update nixpkgs
nix flake update home-manager

# Rollback to previous generation
sudo nixos-rebuild switch --rollback

# Cleanup old generations (30+ days)
sudo nix-collect-garbage --delete-older-than 30d
```

## Directory Structure

```
.
├── flake.nix              # Flake inputs (nixpkgs, home-manager, etc.)
├── host/
│   ├── config.nix         # Main system configuration
│   └── environment.nix    # System packages
├── modules/
│   ├── hm/                # Home Manager modules
│   │   ├── default.nix    # User configuration
│   │   ├── files.nix      # Dotfiles management
│   │   └── home/          # Config files (hypr, fcitx5, etc.)
│   └── system/            # System modules (audio, camera, input, etc.)
└── hardware-configuration.nix
```

## Migration Status

Currently migrating from Hydenix to standard NixOS + Home Manager:
- [x] Phase 1: Direct nixpkgs/home-manager inputs
- [ ] Phase 2: Stylix theming
- [ ] Phase 3-7: Module migration
- [ ] Phase 8: Remove Hydenix dependency

## Maintenance

Weekly update routine:
```bash
nix flake update
sudo nixos-rebuild test --flake .#xps13-9320
sudo nixos-rebuild switch --flake .#xps13-9320
git add flake.lock && git commit -m "update: $(date +%Y-%m-%d)"
```
