{ config, lib, pkgs, ... }:
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
    # emoji-picker.sh runs rofi with `-matching fuzzy`, so a query matches any
    # entry containing those letters as a subsequence, in order but with any
    # gaps: "cat" pulls in "graduation cap", "flag: Cape Verde", "cactus"...
    # The whole emoji.db is ~1800 short lines, so nearly every query returns
    # junk ahead of the literal match. `normal` matches each whitespace-
    # separated token as a plain substring, which is what a picker wants. The
    # flag is set rather than dropped so an upstream default change cannot
    # quietly reinstate fuzzy; emoji-picker.sh repeats it in all four of its
    # rofi invocations (the --rasi branch plus the three styles), hence the /g.
    # glyph-picker.sh (mod+period) is the same picker over the Nerd Font glyph
    # names and carries the same flag on its single rofi call.
    sed -i 's/-matching fuzzy/-matching normal/g' $out/emoji-picker.sh $out/glyph-picker.sh
    # Every HyDE menu that sizes itself against the focused monitor turns the
    # scale into a "percent" divisor by deleting the decimal point: "1.50" -> 150,
    # then `width * 100 / 150`. Hyprland 0.56 prints `"scale": 1` for integer
    # scales, so the dot-strip is a no-op, the divisor is 1 instead of 100, and
    # every derived pixel value comes out 100x too large. Seen as: the theme
    # selector laying out 333 columns and rendering an empty overlay, and
    # ctrl+alt+del's wlogout asking for 30240px button margins, which GDK refuses
    # ("Unable to create Cairo image surface: invalid value (typically too big)")
    # so nothing clickable is drawn. get_rofi_pos in globalcontrol.sh is the same
    # bug and mispositions every rofi popup that spawns at the cursor.
    #
    # Fixed at the source of the number: jq multiplies by 100 itself. The
    # dot-stripping downstream survives as a no-op on an already-integer value,
    # which is why it does not need removing too. wbarstylegen.sh is untouched --
    # upstream already writes `(.height / .scale)` there.
    sed -i "s#| \.scale'#| (.scale * 100 | round)'#" \
      $out/theme.select.sh $out/rofiselect.sh $out/wallpaper.sh $out/logoutlaunch.sh
    sed -i 's#\\(\.scale)#\\(.scale * 100 | round)#' $out/gamelauncher.sh $out/globalcontrol.sh
    sed -i 's#,\.scale,#,(.scale * 100 | round),#' $out/quickapps.sh
    # Fail the build rather than ship a silently unpatched menu if HyDE ever
    # rewrites one of these lines.
    for f in theme.select.sh rofiselect.sh wallpaper.sh logoutlaunch.sh \
      gamelauncher.sh globalcontrol.sh quickapps.sh; do
      grep -q 'scale \* 100' $out/$f || { echo "monitor-scale patch missed $f"; exit 1; }
    done
    # cliphist.sh (mod+v / mod+shift+v) anchors rofi at the cursor via
    # get_rofi_pos. With the pointer near the bottom edge the list grows past
    # the screen, so pin it to the centre of the focused monitor instead.
    sed -i 's#rofi_position=$(get_rofi_pos)#rofi_position="window{location:center;anchor:center;x-offset:0;y-offset:0;}"#' \
      $out/cliphist.sh
    grep -q 'location:center' $out/cliphist.sh || { echo "cliphist centre patch missed"; exit 1; }
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
  # The notification just sits there and a left-click does nothing. `dmenu` is
  # a global-only setting and cannot be set per rule.
  #
  # This patch only covers the file as first deployed. HyDE's generator
  # rewrites dunstrc at every login -- see patchedWallbash below, which is
  # what keeps the dmenu line correct afterwards.
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
  # HyDE ships `mouse_left_click = context, close_current`, so opening the
  # action menu also *closes* the notification -- and dunstify then prints
  # close reason 2, "dismissed by the user", to the script still waiting on
  # it. Reaching for Snooze therefore spent one of the day's two dismissals
  # and threw the answer away. `context` alone leaves the notification up
  # until the menu is answered, which is what the menu is for.
  # The grep fails the build if upstream rewords the line, rather than letting
  # the patch go quietly dead the way the dmenu one did.
  leftClickRule = ''
    sed -i 's|^mouse_left_click = context, close_current$|mouse_left_click = context|' $out
    grep -q '^mouse_left_click = context$' $out
  '';
  patchedDunstrc = pkgs.runCommand "hyde-dunstrc" { } ''
    cp ${pkgs.hyde}/Configs/.config/dunst/dunstrc $out
    chmod u+w $out
    sed -i 's|/usr/bin/rofi|${pkgs.rofi}/bin/rofi|g' $out
    sed -i 's|/usr/bin/xdg-open|${pkgs.xdg-utils}/bin/xdg-open|g' $out
    ${leftClickRule}
    ${cadenceRule}
  '';
  patchedDunstConf = pkgs.runCommand "hyde-dunst-conf" { } ''
    cp ${pkgs.hyde}/Configs/.config/dunst/dunst.conf $out
    chmod u+w $out
    # dunst.conf carries no dmenu line -- the generator writes that itself,
    # correctly once patched (see patchedWallbash). Only browser and the rule
    # are needed here.
    sed -i 's|/usr/bin/xdg-open|${pkgs.xdg-utils}/bin/xdg-open|g' $out
    ${leftClickRule}
    ${cadenceRule}
  '';
  # HyDE's wallbash generator for dunstrc (wallbash/scripts/dunst.sh) writes
  # `dmenu = $(which rofi) -config notification -dmenu -p dunst:`. It re-runs
  # at every login: home-manager's setTheme activation step (upstream hydenix
  # theme.nix) runs theme.switch -> wallpaper -> color.set -> wallbash inside
  # nixos-activation.service, whose PATH is that step's own tool list plus
  # coreutils -- `which` is in it, rofi is not. `$(which rofi)` expands to
  # nothing and the live file reads `dmenu =  -config notification ...`, so
  # every left-click logs
  #   dunst: CRITICAL: [invoke_dmenu:0278] Cannot spawn dmenu:
  #     Failed to execute child process "-config" (No such file or directory)
  # and no action menu appears. Seen 2026-09-05: rebuild 10:50, dunstrc
  # regenerated 10:52:12, dunst up 10:53:38. patchedDunstrc above is
  # overwritten within seconds of activation, so the store path has to be
  # baked into the generator itself. Same directory-source override as the
  # trees above: hydenix links ".local/share/wallbash/" as one recursive,
  # mutable entry in its hyde module. The grep fails the build if upstream
  # rewrites the line, rather than letting the patch go quietly dead again.
  patchedWallbash = pkgs.runCommand "hyde-wallbash" { } ''
    cp -r ${pkgs.hyde}/Configs/.local/share/wallbash $out
    chmod -R u+w $out
    sed -i 's|$(which rofi)|${pkgs.rofi}/bin/rofi|g' $out/scripts/dunst.sh
    grep -q '^dmenu = ${pkgs.rofi}/bin/rofi -config' $out/scripts/dunst.sh
  '';

  # Upstream hydenix (theme.nix) applies the theme twice: the activation step
  # above, at every home-manager activation, and two systemd user units,
  # setTheme.service and setThemeDconf.service, at every graphical session.
  # The units are what this fixes; patchedWallbash is what fixes the dunstrc,
  # since the activation step cannot be given a PATH from here.
  #
  # Upstream gives both units a `Path = [ ... ]` list. That is not a systemd
  # key: every login logs
  #   setTheme.service:7: Unknown key 'Path' in section [Service], ignoring.
  # sixteen times over, and the units run on the user manager's PATH by luck.
  # setTheme's ExecStart also ends in `|| true`, which systemd hands to
  # theme.switch.sh as two literal arguments -- ExecStart is not a shell. Both
  # are replaced by a wrapper that puts the intended tool list, plus the rofi
  # the dunstrc generator needs, in front of the inherited PATH and then runs
  # the command as written -- so setTheme's `|| true` now means what upstream
  # meant, and setThemeDconf keeps failing loudly as it does upstream. Only
  # the Service keys are forced; the Unit and Install sections stay upstream's.
  themeTools = with pkgs; [
    swww
    killall
    hyprland
    dunst
    libnotify
    systemd
    waybar
    kitty
    gawk
    coreutils
    parallel
    imagemagick
    which
    util-linux
    dconf
    rofi
  ];
  # hyde-shell's logout (wlogout's Logout button) runs `uwsm stop` whenever
  # `uwsm check is-active` succeeds, and that check only looks at
  # graphical-session.target -- which modules/hm/default.nix starts by hand for
  # the portals. SDDM launches start-hyprland directly, not through uwsm, so
  # `uwsm stop` prints "Compositor is not running." and the session stays up.
  # Drop the uwsm branch so it falls through to `hyprctl dispatch exit`.
  # hyde-shell derives LIB_DIR/SHARE_DIR from its own path (bin/../lib), so the
  # copy keeps HyDE's .local layout with lib and share linked back to pkgs.hyde.
  patchedHydeShell = pkgs.runCommand "hyde-shell" { } ''
    mkdir -p $out/bin
    ln -s ${pkgs.hyde}/Configs/.local/lib $out/lib
    ln -s ${pkgs.hyde}/Configs/.local/share $out/share
    sed '/^hyde-logout() {/,/^}/s/if uwsm check is-active; then/if false; then/' \
      ${pkgs.hyde}/Configs/.local/bin/hyde-shell > $out/bin/hyde-shell
    chmod +x $out/bin/hyde-shell
    grep -q 'if false; then' $out/bin/hyde-shell || { echo "hyde-logout patch missed"; exit 1; }
  '';
  themeService = name: command: {
    Path = lib.mkForce [ ];
    ExecStart = lib.mkForce (toString (pkgs.writeShellScript name ''
      export PATH="${lib.makeBinPath themeTools}:${config.home.homeDirectory}/.local/bin:$PATH"
      ${config.home.homeDirectory}/.local/lib/hyde/${command}
    ''));
  };
in
{
  systemd.user.services.setTheme.Service = themeService "hyde-set-theme"
    ''theme.switch.sh -s "${config.hydenix.hm.theme.active}" || true'';
  systemd.user.services.setThemeDconf.Service = themeService "hyde-set-theme-dconf"
    "dconf.set.sh";

  home.file = {
    # See patchedWallbash above.
    ".local/share/wallbash/" = lib.mkForce {
      source = patchedWallbash;
      recursive = true;
      force = true;
      mutable = true;
    };
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
    # See patchedHydeShell above. hydenix's wrapper is a per-file key, so
    # mkForce replaces it; this keeps its PYTHONPATH export.
    ".local/bin/hyde-shell" = lib.mkForce {
      source = pkgs.writeShellScript "hyde-shell" ''
        export PYTHONPATH="${pkgs.python-pyamdgpuinfo}/${pkgs.python3.sitePackages}:$PYTHONPATH"
        exec ${pkgs.bashInteractive}/bin/bash ${patchedHydeShell}/bin/hyde-shell "$@"
      '';
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

    # zathura copies to the primary selection by default, which cliphist's
    # wl-paste watchers (and so mod+v) never see.
    ".config/zathura/zathurarc" = {
      text = ''
        set database "sqlite"
        set selection-clipboard clipboard
      '';
      force = true;
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
    ".local/share/bin/goals-anki-review.sh" = {
      source = ./scripts/goals-anki-review.sh;
      force = true;
      mutable = true;
      executable = true;
    };
    ".local/share/bin/goals-sunday.sh" = {
      source = ./scripts/goals-sunday.sh;
      force = true;
      mutable = true;
      executable = true;
    };
    ".local/share/bin/goals-claude.sh" = {
      source = ./scripts/goals-claude.sh;
      force = true;
      mutable = true;
      executable = true;
    };
    # NB: .local/lib/hyde/brightness-all.sh is NOT declared here -- it is
    # supplied by the patchedHydeLib tree above, for the same reason.
    ".claude-adrien/hooks/memgate.sh" = {
      source = ./scripts/memgate.sh;
      force = true;
      mutable = true;
      executable = true;
    };
    ".claude-adrien/hooks/tmux-status.sh" = {
      source = ./scripts/tmux-status.sh;
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
