# My NixOS Dotfiles

My personal NixOS configuration using [Hydenix](https://github.com/richen604/hydenix) - a modern Hyprland desktop environment for NixOS.

## Quick Start

1. Clone this repo
2. Update `hardware-configuration.nix` for your system:
   ```bash
   sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
   ```
3. Edit personal details in `config.nix` (hostname, timezone, username, etc.)
4. Build and switch:
   ```bash
   sudo nixos-rebuild switch --flake .#hydenix
   ```

## Features

- **Desktop**: Hyprland with multi-monitor support
- **Shell**: Nushell with custom scripts and completions
- **Terminal**: Ghostty with custom keybindings
- **Editor**: Neovim with LazyVim
- **AI Tools**: Claude CLI, Aider, Goose
- **Input**: Custom keyboard layouts (US-QWERTY-FR, Japanese)
- **Theme**: Catppuccin with automatic wallpaper switching

## Key Files

- `config.nix` - Main system configuration
- `environment.nix` - System packages
- `modules/hm/default.nix` - Home Manager configuration
- `modules/system/` - System-level modules

## Updating

```bash
# Update flake inputs
nix flake update

# Update specific input
nix flake update hydenix

# Rebuild system
sudo nixos-rebuild switch --flake .#hydenix
```
