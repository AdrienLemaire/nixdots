{ lib, pkgs, inputs, ... }: {
  home.file = {
    # HyDE's defaults.conf sets the dwindle:pseudotile option, removed in Hyprland
    # 0.55; it errors the config (Error Overlay) on every `hyprctl reload`.
    # Patch the line out of the upstream hyde source instead of forking the whole
    # file, so this stays drift-proof: it re-applies when the hyde input updates.
    # (hyde-modified's build-phase seds don't touch defaults.conf, so the raw
    # source is equivalent here. pseudotiling still works via the `pseudo` dispatcher.)
    ".local/share/hypr/defaults.conf" = lib.mkForce {
      source = pkgs.runCommand "hypr-defaults.conf" { } ''
        sed '/^[[:space:]]*pseudotile[[:space:]]*=/d' \
          ${inputs.hydenix.inputs.hyde}/Configs/.local/share/hypr/defaults.conf > "$out"
      '';
      force = true;
      mutable = true;
    };
    # HyDE's sensorsinfo.py does `int(f.read().strip())` on /tmp/sensorinfo_page;
    # when that file is empty (its save_current_page truncates-then-writes, so a
    # concurrent waybar poll can read it mid-write) it raises ValueError, breaking
    # the cpuinfo module and spamming the journal on every poll. Default the parse
    # to page 0. Sourced from the raw hyde input like defaults.conf above, since
    # hyde-modified's build seds don't touch this file (raw == modified verified).
    ".local/lib/hyde/sensorsinfo.py" = lib.mkForce {
      source = pkgs.runCommand "hyde-sensorsinfo.py" { } ''
        sed 's/page = int(f.read().strip())/page = int(f.read().strip() or 0)/' \
          ${inputs.hydenix.inputs.hyde}/Configs/.local/lib/hyde/sensorsinfo.py > "$out"
      '';
      force = true;
      mutable = true;
      executable = true;
    };
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

    ".config/hyde/wallbash/always/tmux.dcol" = {
      source = ./home/wallbash/tmux.dcol;
      force = true;
      mutable = true;
    };

    ".config/hypr/keybindings.conf" = lib.mkForce {
      source = ./home/hypr/keybindings.conf;
      force = true;
      mutable = true;
    };
    # HyDE's dynamic.conf sources these unconditionally; provide placeholders so
    # they resolve (otherwise the startup Error Overlay shows globbing errors).
    ".config/hypr/nvidia.conf" = {
      source = ./home/hypr/nvidia.conf;
      force = true;
      mutable = true;
    };
    ".config/hypr/hyde.conf" = {
      source = ./home/hypr/hyde.conf;
      force = true;
      mutable = true;
    };
    ".config/hypr/windowrules.conf" = lib.mkForce {
    #".local/share/hypr/windowrules.conf" = lib.mkForce {
      source = ./home/hypr/windowrules.conf;
      force = true;
      mutable = true;
    };
    ".local/share/hypr/windowrules.conf" = lib.mkForce {
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
    ".local/share/bin/gif-frame.sh" = {
      source = ./scripts/gif-frame.sh;
      force = true;
      mutable = true;
    };
    ".local/share/bin/gif-build.sh" = {
      source = ./scripts/gif-build.sh;
      force = true;
      mutable = true;
    };
    ".local/share/bin/clip2remote" = {
      source = ./scripts/clip2remote;
      force = true;
      mutable = true;
      executable = true;
    };
    ".local/share/bin/mem-inspector.sh" = {
      source = ./scripts/mem-inspector.sh;
      force = true;
      mutable = true;
      executable = true;
    };
    ".local/share/bin/claude-statusline.sh" = {
      source = ./scripts/claude-statusline.sh;
      force = true;
      mutable = true;
      executable = true;
    };
    ".claude/hooks/memgate.sh" = {
      source = ./scripts/memgate.sh;
      force = true;
      mutable = true;
      executable = true;
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
