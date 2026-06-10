# nixpkgs renamed swww to awww (binaries awww/awww-daemon), but HyDE
# scripts still call swww/swww-daemon. awww-daemon also dropped the xrgb
# wl_shm format that HyDE passes, so map it to argb.
{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellScriptBin "swww" ''
      exec ${pkgs.awww}/bin/awww "$@"
    '')
    (pkgs.writeShellScriptBin "swww-daemon" ''
      args=()
      for a in "$@"; do
        [ "$a" = "xrgb" ] && a="argb"
        args+=("$a")
      done
      exec ${pkgs.awww}/bin/awww-daemon "''${args[@]}"
    '')
  ];
}
