{ lib, pkgs, ... }:
let
  # hydenix links HyDE's config trees with `recursive = true` *directory* entries
  # (home.file.".local/share/hypr/" in its hyprland module, ".local/lib/hyde" in
  # its hyde module). A per-file `home.file."<dir>/<file>"` override is a
  # different attribute key, so lib.mkForce on it has nothing to override and is
  # silently a no-op -- the file linked from the directory wins. Three patches
  # here were dead code for weeks that way (verified: the deployed files were
  # byte-identical to hyde-modified's). Patch the directory *source* instead,
  # which is the key hydenix actually sets. Both trees are copied from pkgs.hyde
  # (hydenix's own modified hyde, not the raw input) so its build-phase seds are
  # preserved, and the patches re-apply when the hyde input updates.
  patchedHyprConfigs = pkgs.runCommand "hyde-hypr-configs" { } ''
    cp -r ${pkgs.hyde}/Configs/.local/share/hypr $out
    chmod -R u+w $out
    # dwindle:pseudotile was removed in Hyprland 0.55. Verified against the
    # running compositor: `hyprctl getoption dwindle:pseudotile` -> "no such
    # option", and there is no renamed equivalent (misc:/general:/dwindle:pseudo
    # are all absent). The `pseudo` dispatcher still works, so only the config
    # option goes; the keybind that uses it is unaffected.
    sed -i '/^[[:space:]]*pseudotile[[:space:]]*=/d' $out/defaults.conf
    # The vendored HyDE revision's windowrules.conf predates Hyprland's v0.53+
    # window-rule syntax and emits 108 parse errors against 0.55. Our copy is the
    # newer upstream file plus the two variables HyDE would otherwise set by
    # version detection ($WINDOWRULES_HYPRLAND_V_0_53 and $&), which hydenix does
    # not vendor. It already deploys cleanly to .config/hypr/windowrules.conf.
    cp ${./home/hypr/windowrules.conf} $out/windowrules.conf
  '';
  patchedHydeLib = pkgs.runCommand "hyde-lib" { } ''
    cp -r ${pkgs.hyde}/Configs/.local/lib/hyde $out
    chmod -R u+w $out
    # HyDE's sensorsinfo.py does `int(f.read().strip())` on /tmp/sensorinfo_page;
    # when that file is empty (its save_current_page truncates-then-writes, so a
    # concurrent waybar poll can read it mid-write) it raises ValueError, breaking
    # the cpuinfo module and spamming the journal on every poll. Default to page 0.
    sed -i 's/page = int(f.read().strip())/page = int(f.read().strip() or 0)/' \
      $out/sensorsinfo.py
    # cpuinfo.sh builds waybar's JSON by hand and joins the per-core temperatures
    # with jq's join("\\n\t"). In a jq string literal "\\n" is the two-character
    # escape \n (what the JSON needs) but "\t" is a *real* tab byte, which is an
    # illegal control character inside a JSON string. waybar then rejects every
    # poll: "custom/cpuinfo: Error parsing JSON: Control character in string"
    # -- 3436 of them in one hour on 2026-08-30. Escape the tab like the newline.
    sed -i 's/join("\\\\n\\t")/join("\\\\n\\\\t")/' $out/cpuinfo.sh
    # Installed next to HyDE's own scripts so keybindings.conf can reach it via
    # $scrPath, the same way every other bind in that file does. It has to go in
    # the tree rather than its own home.file entry for the reason above.
    cp ${./scripts/brightness-all.sh} $out/brightness-all.sh
    chmod +x $out/brightness-all.sh
  '';
  # The vendored dunst config was generated on the upstream author's Arch box
  # (it still carries /home/khing icon paths) and shipped verbatim, so it
  # points dmenu at /usr/bin/rofi and browser at /usr/bin/xdg-open -- neither
  # of which exists on NixOS. Reproduced live:
  #   dunst: CRITICAL: [invoke_dmenu:0278] Cannot spawn dmenu:
  #     Failed to execute child process "/usr/bin/rofi" (No such file...)
  # The notification just sits there and a left-click does nothing. HyDE's own
  # generator (.local/share/hyde/wallbash/scripts/dunst.sh:87) writes
  # `$(which rofi)` and would be correct if it had ever been re-run here; it
  # has not. `dmenu` is a global-only setting and cannot be set per rule.
  #
  # Unlike the two trees above, hydenix declares these as *per-file* keys in
  # its own modules/hm/notifications.nix, so lib.mkForce on the same key does
  # override -- the silent no-op described at the top of this file does not
  # apply here. Verified against the pinned revision before this was written.
  #
  # Both files are patched. dunstrc is what dunst reads; dunst.conf is what
  # `hyde-shell wallbash dunst` splices back into a regenerated dunstrc on the
  # next wallpaper change, so patching only dunstrc would put the [cadence]
  # rule one wallpaper away from vanishing.
  #
  # printf rather than a heredoc: a heredoc inside this indented Nix string
  # would carry its leading spaces into a dunst section header. The redirect
  # lives inside the string, not at each call site: this indented string ends
  # in a trailing newline, and `${cadenceRule} >> $out` would put `>> $out`
  # on its own line -- a no-op appended after the real one, not an error, so
  # nothing would have caught it.
  cadenceRule = ''
    printf '\n[cadence]\nappname = "cadence"\nhistory_ignore = true\n' >> $out
  '';
  patchedDunstrc = pkgs.runCommand "hyde-dunstrc" { } ''
    cp ${pkgs.hyde}/Configs/.config/dunst/dunstrc $out
    chmod u+w $out
    sed -i 's|/usr/bin/rofi|${pkgs.rofi}/bin/rofi|g' $out
    sed -i 's|/usr/bin/xdg-open|${pkgs.xdg-utils}/bin/xdg-open|g' $out
    ${cadenceRule}
  '';
  patchedDunstConf = pkgs.runCommand "hyde-dunst-conf" { } ''
    cp ${pkgs.hyde}/Configs/.config/dunst/dunst.conf $out
    chmod u+w $out
    # dunst.conf carries no dmenu line -- the generator writes that itself,
    # and writes it correctly. Only browser and the rule are needed here.
    sed -i 's|/usr/bin/xdg-open|${pkgs.xdg-utils}/bin/xdg-open|g' $out
    ${cadenceRule}
  '';
in
{
  home.file = {
    ".local/share/hypr/" = lib.mkForce {
      source = patchedHyprConfigs;
      recursive = true;
    };
    ".local/lib/hyde" = lib.mkForce {
      source = patchedHydeLib;
      recursive = true;
      executable = true;
      force = true;
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

    # See patchedDunstrc above. mkForce overrides hydenix's own per-file
    # entries in modules/hm/notifications.nix; `mutable = true` matches theirs,
    # which matters because wallbash rewrites dunstrc in place.
    ".config/dunst/dunstrc" = lib.mkForce {
      source = patchedDunstrc;
      force = true;
      mutable = true;
    };
    ".config/dunst/dunst.conf" = lib.mkForce {
      source = patchedDunstConf;
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
      source = ./home/hypr/windowrules.conf;
      force = true;
      mutable = true;
    };
    # NB: .local/share/hypr/windowrules.conf is NOT declared here -- it is
    # supplied by the patchedHyprConfigs tree above, since a per-file entry
    # under hydenix's recursive directory entry would be a silent no-op.


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
    ".local/share/bin/goals-lib.sh" = {
      source = ./scripts/goals-lib.sh;
      force = true;
      mutable = true;
      executable = true;
    };
    ".local/share/bin/goals-today.sh" = {
      source = ./scripts/goals-today.sh;
      force = true;
      mutable = true;
      executable = true;
    };
    ".local/share/bin/goals-waybar.sh" = {
      source = ./scripts/goals-waybar.sh;
      force = true;
      mutable = true;
      executable = true;
    };
    ".local/share/bin/goals-open.sh" = {
      source = ./scripts/goals-open.sh;
      force = true;
      mutable = true;
      executable = true;
    };
    ".local/share/bin/goals-review.sh" = {
      source = ./scripts/goals-review.sh;
      force = true;
      mutable = true;
      executable = true;
    };
    ".local/share/bin/goals-morning.sh" = {
      source = ./scripts/goals-morning.sh;
      force = true;
      mutable = true;
      executable = true;
    };
    ".local/share/bin/goals-evening.sh" = {
      source = ./scripts/goals-evening.sh;
      force = true;
      mutable = true;
      executable = true;
    };
    ".local/share/bin/goals-nudge.sh" = {
      source = ./scripts/goals-nudge.sh;
      force = true;
      mutable = true;
      executable = true;
    };
    # NB: .local/lib/hyde/brightness-all.sh is NOT declared here -- it is
    # supplied by the patchedHydeLib tree above, for the same reason.
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
