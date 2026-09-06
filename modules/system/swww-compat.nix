# nixpkgs replaced `swww` with the `awww` fork, so `pkgs.swww` is now a
# deprecation alias whose binaries are named awww/awww-daemon -- nothing called
# `swww` lands in PATH. HyDE's scripts (wallpaper.swww.sh, theme.switch.sh) and
# hydenix's own modules (hydenix/modules/hm/{swww,theme}.nix, which put
# `pkgs.swww` on a makeBinPath) all still call `swww` and `swww-daemon`.
#
# So override the alias with a package that really does provide those two
# names, wrapping awww. awww-daemon also dropped the xrgb wl_shm format that
# HyDE passes, so map it to argb on the way through.
#
# This has to be a *system* overlay: home-manager runs with useGlobalPkgs, so
# `nixpkgs.*` set inside a home-manager module is ignored. Overriding the attr
# here also means hydenix's references never force the alias thunk, which is
# what silences the "'swww' has been renamed to 'awww'" evaluation warning.
{ ... }:

{
  nixpkgs.overlays = [
    (final: prev: {
      swww = final.symlinkJoin {
        name = "swww-compat";
        # awww itself is kept in the join so the awww/awww-daemon names stay
        # available too -- that is what `pkgs.swww` resolved to before.
        paths = [
          (final.writeShellScriptBin "swww" ''
            exec ${prev.awww}/bin/awww "$@"
          '')
          (final.writeShellScriptBin "swww-daemon" ''
            args=()
            for a in "$@"; do
              [ "$a" = "xrgb" ] && a="argb"
              args+=("$a")
            done
            exec ${prev.awww}/bin/awww-daemon "''${args[@]}"
          '')
          prev.awww
        ];
      };
    })
  ];
}
