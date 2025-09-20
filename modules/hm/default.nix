{ pkgs, inputs, ... }:

{
  imports = [
    # ./example.nix - add your modules here
    ./files.nix
    ./common
  ];

  home.packages = [
    pkgs.nu_scripts
  ];

  programs.neovim.plugins = [
    pkgs.vimPlugins.nvim-tree-lua
    {
      plugin = pkgs.vimPlugins.vim-startify;
      config = "let g:startify_change_to_vcs_root = 0";
    }
    inputs.mcphub-nvim.packages.x86_64-linux.default
  ];
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableNushellIntegration = true;
  };

  hydenix.hm = {
    enable = true; # enable home-manager module
    comma.enable = true; # useful nix tool to run software without installing it first
    dolphin.enable = true; # file manager
    editors = {
      enable = true; # enable editors module
      vscode.enable = false;
      default = "nvim";
    };
    fastfetch.enable = true; # fastfetch configuration
    firefox.enable = true; # enable firefox module
    git = {
      enable = true; # enable git module
      name = null; # git user name eg "John Doe"
      email = null; # git user email eg "john.doe@example.com"
    };
    hyde.enable = true; # enable hyde module
    hyprland = {
      enable = true; # enable hyprland module
      extraConfig = ''
          # fix OBS cursor artifact
          cursor {
            no_hardware_cursors = false 
          }

          monitor = eDP-1, 1920x1200, 0x0, 1
          monitor = DP-4, 2048x1080, -384x-1080, 1
          monitor = desc:SNL S3-L S3-L 20241026, 1920x1080, -1920x0, 1
          monitor = desc:SNR S3-R S3-R 20241026, 1920x1080, 1920x0, 1

          workspace = 1,monitor:eDP-1
          workspace = 2,monitor:DP-4
          workspace = 3, monitor:desc:SNL S3-L S3-L 20241026
          workspace = 4, monitor:desc:SNR S3-R S3-R 20241026

        input {
            kb_layout = us_qwerty-fr
            resolve_binds_by_sym = 1
            follow_mouse = 1

            touchpad {
                natural_scroll = no
            }

            sensitivity = 0
            force_no_accel = 1
            numlock_by_default = true
        }
        device {
          name = pebble-k380s
          kb_layout = jp
          kb_options = compose:ralt
        }

        exec-once=fcitx5 -d -r
        exec-once = [workspace 2 silent] firefox
        exec-once = [workspace 1 silent] ghostty
      '';

      overrideMain = null; # complete override of hyprland.conf
      suppressWarnings = false; # suppress warnings
      # Animation configurations
      animations = {
        enable = true; # enable animation configurations
        preset = "standard"; # string from override or default: "standard" # or "LimeFrenzy", "classic", "diablo-1", "diablo-2", "disable", "dynamic", "end4", "fast", "high", "ja", "me-1", "me-2", "minimal-1", "minimal-2", "moving", "optimized", "standard", "vertical"
        extraConfig = ""; # additional animation configuration
        overrides = { }; # override specific animation files by name
      };
      # Shader configurations
      shaders = {
        enable = true; # enable shader configurations
        active = "disable"; # string from override or default: "disable" # or "blue-light-filter", "color-vision", "custom", "grayscale", "invert-colors", "oled", "oled-saver", "paper", "vibrance", "wallbash"
        overrides = { }; # override or add custom shaders
      };
      # Workflow configurations
      workflows = {
        enable = true; # enable workflow configurations
        active = "default"; # string from override or default: "default" # or "editing", "gaming", "powersaver", "snappy"
        overrides = { }; # override or add custom workflows
      };
      # Hypridle configurations
      hypridle = {
        enable = true; # enable hypridle configurations
        extraConfig = ""; # additional hypridle configuration
        overrideConfig = null; # complete hypridle configuration override (null or lib.types.lines)
      };
      # Keybindings configurations
      keybindings = {
        enable = true; # enable keybindings configurations
        extraConfig = ""; # additional keybindings configuration
        overrideConfig = null; # complete keybindings configuration override (null or lib.types.lines)
      };
      # Window rules configurations
      windowrules = {
        enable = true; # enable window rules configurations
        extraConfig = ""; # additional window rules configuration
        overrideConfig = null; # complete window rules configuration override (null or lib.types.lines)
      };
      # NVIDIA configurations
      nvidia = {
        enable = false; # enable NVIDIA configurations (defaults to config.hardware.nvidia.enabled)
        extraConfig = ""; # additional NVIDIA configuration
        overrideConfig = null; # complete NVIDIA configuration override (null or lib.types.lines)
      };
      # Monitor configurations
      monitors = {
        enable = true; # enable monitor configurations
        overrideConfig = null; # complete monitor configuration override (null or lib.types.lines)
      };
    };
    lockscreen = {
      enable = true; # enable lockscreen module
      hyprlock = true; # enable hyprlock lockscreen
      swaylock = false; # enable swaylock lockscreen
    };
    notifications.enable = true; # enable notifications module
    qt.enable = true; # enable qt module
    rofi.enable = true; # enable rofi module
    screenshots = {
      enable = true; # enable screenshots module
      grim.enable = true; # enable grim screenshot tool
      slurp.enable = true; # enable slurp region selection tool
      satty.enable = false; # enable satty screenshot annotation tool
      swappy.enable = true; # enable swappy screenshot editor
    };
    shell = {
      enable = true; # enable shell module
      zsh = {
        enable = true; # enable zsh shell
        plugins = [ "sudo" "git" ]; # zsh plugins
        configText = "source ~/.zsh_dori"; # zsh config text
      };
      bash.enable = false; # enable bash shell
      fish.enable = false; # enable fish shell
      pokego.enable = false; # enable Pokemon ASCII art scripts
      p10k.enable = false; # enable p10k prompt
      starship.enable = true; # enable starship prompt
    };
    social = {
      enable = true; # enable social module
      discord.enable = false; # enable discord module
      webcord.enable = false; # enable webcord module
      vesktop.enable = true; # enable vesktop module
    };
    spotify.enable = false;
    swww.enable = true; # enable swww wallpaper daemon
    terminals = {
      enable = true; # enable terminals module
      kitty = {
        enable = true; # enable kitty terminal
        configText = ""; # kitty config text
      };
    };
    theme = {
      enable = true; # enable theme module
      active = "Catppuccin Mocha"; # active theme name
      themes = [ "Catppuccin Mocha" "Catppuccin Latte" "Cosmic Blue" "Another World" "Ancient Aliens" "Sci fi" "Peace Of Mind" ]; # default enabled themes, full list in https://github.com/richen604/hydenix/tree/main/hydenix/sources/themes
    };
    waybar = {
      enable = true; # enable waybar module
      userStyle = ""; # custom waybar user-style.css
    };
    wlogout.enable = true; # enable wlogout module
    xdg.enable = true; # enable xdg module
  };
}
