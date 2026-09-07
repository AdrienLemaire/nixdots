{ pkgs, inputs, ... }:

{
  imports = [
    # ./example.nix - add your modules here
    ./files.nix
    ./fonts.nix
    ./goals-notify.nix
    ./goals-window.nix
    ./hypr-reload.nix
    ./hyprland-session.nix
    ./hypridle-recycle.nix
    ./theme-activation-env.nix
    ./tmux.nix
    ./common
  ];

  home.packages = [
    pkgs.nu_scripts
  ];

  # Newer home-manager flipped this default from true to false, and warns while
  # home.stateVersion (25.05, set by hydenix) is below 26.05 and so still gets
  # the legacy true. Taking the new default is the no-op here: hydenix's own
  # xdg.nix already exports every XDG_*_DIR in home.sessionVariables with
  # identical values. The only thing `true` would add is XDG_PROJECTS_DIR, from
  # the `projects` user dir that newer home-manager introduced -- a variable
  # this session never had. So false reproduces the current environment
  # exactly; true would not. Verified by diffing home.sessionVariables both ways.
  xdg.userDirs.setSessionVariables = false;

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
    uwsm.enable = true;
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
      name = "Adrien Lemaire"; # git user name eg "John Doe"
      email = "lemaire.adrien@gmail.com"; # git user email eg "john.doe@example.com"
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
            accel_profile = flat
            # force_no_accel bypasses libinput entirely, which also discards
            # `sensitivity`. flat profile = no acceleration, but scalable.
            force_no_accel = 0
            numlock_by_default = true
        }
        device {
          name = pebble-m350s-mouse
          accel_profile = flat
          sensitivity = 1.0
        }
        # Both BLE keyboards are blacklisted off hid-vivaldi (see host/config.nix),
        # and hid-generic names the keyboard collection "<device> Keyboard" ->
        # hyprland "<device>-keyboard". Rules are kept under both names so the
        # layout survives regardless of which driver binds. Hyprland ignores
        # rules for devices that are not present.
        device {
          name = pebble-k380s
          kb_layout = jp
          kb_options = compose:ralt
        }
        device {
          name = pebble-k380s-keyboard
          kb_layout = jp
          kb_options = compose:ralt
        }
        device {
          name = mx-keys-mini
          # JIS legends at levels 1-2, qwerty-fr accents on AltGr (e.g. AltGr+W = é).
          # No kb_options here on purpose: compose:ralt would rebind RAlt to
          # Multi_key and make every level-3 accent unreachable.
          kb_layout = jp_qwerty-fr
        }
        device {
          name = mx-keys-mini-keyboard
          kb_layout = jp_qwerty-fr
        }

        # fcitx5 is supervised by systemd --user (modules/system/input.nix)
        # so it comes back if it dies. reset-failed clears a start-limit hit
        # left by a previous session; restart rather than start discards any
        # instance that outlived the last compositor, which Linger=yes allows.
        exec-once = systemctl --user reset-failed fcitx5.service ; systemctl --user restart fcitx5.service

        # Nothing else activates graphical-session.target here (SDDM runs a plain
        # session script, not uwsm), and xdg-desktop-portal 1.22 refuses to start
        # without it -- see modules/hm/hyprland-session.nix. The environment is
        # re-exported on this line rather than relying on HyDE's own
        # dbus-update-activation-environment exec-once, because exec-once entries
        # are fired in order but not awaited. XDG_SESSION_DESKTOP is in the list
        # because setTheme.service comes up with this target and reaches HyDE's
        # waybar.py, which names its unit hyde-$XDG_SESSION_DESKTOP-bar and
        # dedupes on that exact name -- if HyDE's own `--all` export has not
        # landed yet, that unit is hyde-unknown-bar and a second waybar starts.
        # The duplicate bars actually observed came from the activation snippet
        # instead, which needs its own fix; see ./theme-activation-env.nix.
        #
        # Stopped on shutdown so the lingering user manager does not carry a dead
        # compositor's session into the next login. Shutdown stops
        # graphical-session.target rather than hyprland-session.target: PartOf
        # propagates from the session target, so that one line also tears down the
        # portals and every app2unit-launched HyDE daemon, and hyprland-session
        # follows through its BindsTo.
        exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP && systemctl --user start hyprland-session.target
        exec-shutdown = systemctl --user stop graphical-session.target
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
        # DEAD for the same reason (files.nix overrides keybindings.conf). The
        # SUPER+escape bind lives in home/hypr/keybindings.conf.
        extraConfig = "";
        overrideConfig = null; # complete keybindings configuration override (null or lib.types.lines)
      };
      # Window rules configurations
      windowrules = {
        enable = true; # enable window rules configurations
        # DEAD: files.nix force-overrides .config/hypr/windowrules.conf, so anything
        # here never reaches disk. Put rules in home/hypr/windowrules.conf instead.
        extraConfig = "";
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
      discord.enable = true; # enable discord module
      vesktop.enable = false; # enable vesktop module
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
      userStyle = ''
        /* HyDE defines no #custom-* selectors, so the module inherits @main-fg
           and looks native. The semantic tier survives theme and wallpaper
           changes; the 88 raw @wallbash_* vars do not. No red: nothing here is
           wrong, and red is reserved for things that are. */
        #custom-goals { padding: 0 8px; }
        #custom-goals.done    { color: @wb-act-bg; }
        #custom-goals.partial { color: @main-fg; }
        #custom-goals.none    { color: @main-fg; }
        #custom-goals.paused  { color: @main-fg; }
      ''; # custom waybar user-style.css
    };
    wlogout.enable = true; # enable wlogout module
    xdg.enable = true; # enable xdg module
  };
}
