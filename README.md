# Hydenix Template

## Intro

Now that you've created your own flake, you can start customizing the template to your liking.

1. edit `config.nix` with your preferences
2. run `sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix`
3. `git init && git add .` (flakes have to be managed via git)
4. run any of the packages in your new `flake.nix`

`config.nix` is your main configuration file. It is used to set variables and import your own custom modules

## Upgrading

Hydenix can be upgraded, downgraded, or version locked easy.

in your template flake folder, update hydenix to main using
```bash
nix flake update hydenix
```

or define a specific version in your `flake.nix` template
```nix
inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    hydenix = {
      # Available inputs:
      # Main: github:richen604/hydenix
      # Dev: github:richen604/hydenix/dev 
      # Commit: github:richen604/hydenix/<commit-hash>
      # Version: github:richen604/hydenix/v1.0.0
      url = "github:richen604/hydenix";
    };
  };
```

## Hydenix Documentation - Customization and Common Issues

When adding custom modules, use the `config.nix` file to import them. 
Be warned it is very easy to override hydenix defaults this way, here are some tips to prevent breakage:

### Boot option

Boot option is systemd by default, rebuilds will only *effect the boot option selected* so you need to change boot in Bios to use grub if you have systemd and vice versa.

`config.nix` - `nixModules`
```nix
{...}:
{
# default option, disable if switching to grub
boot.loader.systemd-boot.enable = true;
  #! Enable grub below, note you will have to change to the new bios boot option for settings to apply
  # boot = {
  #   loader = {
  #     efi = {
  #       canTouchEfiVariables = true;
  #       efiSysMountPoint = "/boot/efi";
  #     };
  #     grub = {
  #       enable = true;
  #       devices = [ "nodev" ];
  #       efiSupport = true;
  #       useOSProber = true;
  #     };
  #   };
  # };
}
```

### Home.activation

For [`home.activation`](https://github.com/richen604/hydenix/blob/main/hydenix/hm/home-activation.nix), make sure the scripts run after `setTheme`

```nix
home.activation = {
    example = lib.hm.dag.entryAfter [ "setTheme" ] ''
        $DRY_RUN_CMD echo "example"
    '';
}
```

### Home.file

For `home.file`, reference [`home-file.nix`](https://github.com/richen604/hydenix/blob/main/hydenix/hm/home-file.nix) for files.
```nix
home.file = {
    ".config/example" = {
        source = ./example;
        force = true; # false by default
        recursive = true; # false by default
        mutable = true; # Hydenix custom, allows for files to be modified after being created. false by default
    };
}
```

Common way of using this would be to persist waybar and kitty styles.
```bash
# for waybar
cp ~/.config/waybar/config.ctl ~/path/to/flake/config.ctl
# for kitty
cp ~/.config/kitty/kitty.conf ~/path/to/flake/kitty.conf
```
Then in your `config.nix` homeModules import
```nix
home.file = {
    # waybar
    ".config/waybar/config.ctl" = {
        source = ./config.ctl; # path to your waybar config.ctl
        force = true;
        mutable = true;
    };
    # kitty
    ".config/kitty/kitty.conf" = {
        source = ./kitty.conf; # path to your kitty.conf
        force = true;
        mutable = true;
    };
}
```

### Common issues

- waybar look weird after rebuild? run `Hyde waybar reload`
- config resets on rebuild? note [readme](https://github.com/richen604/hydenix/blob/main/README.md#limitations)
- dolphin icons not showing? open `qt5ct` and set icon theme

### Requesting features

Please open a [feature request](https://github.com/richen604/hydenix/issues/new?template=feature_request.md) if you have any feature requests.

## Nix Resources

> [!TIP]
> Nix is a powerful package manager and configuration system that can be overwhelming at first. Here are some resources to help you get started:

General Resources
- [Nix Packages](https://search.nixos.org/packages)
- [Nix Options](https://search.nixos.org/options)
- [Home Manager Options](https://nix-community.github.io/home-manager/options.html) *hint: use control + f to search*
- [NixOS Wiki](https://nixos.wiki)
- [Nixpkgs Discussions](https://discourse.nixos.org)
- [Nixpkgs Issues](https://github.com/NixOS/nixpkgs/issues)
