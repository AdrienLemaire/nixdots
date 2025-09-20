{ lib, ... }: {
  home.file = {
    ".config/fcitx5/profile" = {
      source = ./home/fcitx5/profile;
      force = true;
      mutable = true;
    };
    ".config/fcitx5/config" = {
      source = ./home/fcitx5/config;
      force = true;
      mutable = true;
    };
    ".config/fcitx5/conf/classicui.conf" = {
      source = ./home/fcitx5/classicui.conf;
      force = true;
      mutable = true;
    };

    ".config/ghostty/config" = {
      source = ./home/ghostty.conf;
      force = true;
      mutable = true;
    };

    ".config/hypr/keybindings.conf" = lib.mkForce {
      source = ./home/hypr/keybindings.conf;
      force = true;
      mutable = true;
    };
    ".config/hypr/windowrules.conf" = lib.mkForce {
      source = ./home/hypr/windowrules.conf;
      force = true;
      mutable = true;
    };

    # ".config/hypr/userprefs.conf" = lib.mkForce {
    #   source = ./home/hypr/userprefs.conf;
    #   force = true;
    #   mutable = true;
    # };
    #
    ".config/kitty/kitty.conf" = {
      source = ./home/kitty/kitty.conf;
      force = true;
      mutable = true;
    };

    ".config/nushell/config.nu" = {
      source = ./home/nushell/config.nu;
      force = true;
      mutable = true;
    };
    ".config/nushell/env.nu" = {
      source = ./home/nushell/env.nu;
      force = true;
      mutable = true;
    };

    ".config/starship.toml" = {
      source = ./home/starship.toml;
      force = true;
      mutable = true;
    };

    # ".config/swaylock/config" = {
    #     source = ./home/swaylock;
    #     force = true;
    #     mutable = true;
    # };

    ".config/waybar/layouts/dori.jsonc" = lib.mkForce {
      source = ./home/waybar.jsonc;
      force = true;
      mutable = true;
    };
    # ".config/waybar/modules/whisper_overlay.jsonc" = lib.mkForce {
    #   source = ./home/whisper_overlay.jsonc;
    #   force = true;
    #   mutable = true;
    # };

    # "~/.config/wlogout/layout_1" = {
    #     source = ./home/wlogout;
    #     force = true;
    #     mutable = true;
    # };

    ".local/share/bin/toggle_show_desktop.sh" = {
      source = ./scripts/toggle_show_desktop.sh;
      force = true;
      mutable = true;
    };
    ".local/share/bin/themeselect.sh" = {
      source = ./scripts/themeselect.sh;
      force = true;
      mutable = true;
    };

    ".gitconfig" = {
      source = ./home/gitconfig;
      force = true;
      mutable = true;
    };
    ".zsh_dori" = {
      source = ./home/zshrc;
      force = true;
      mutable = true;
    };

  };
}
