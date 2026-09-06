{ pkgs, lib, ... }:
let
  # Hyprland's environment carries no GI_TYPELIB_PATH -- only GTK apps get one, via
  # their own nix wrapper -- so PyGObject launched from a keybind, a dunst action or
  # a systemd timer cannot find Gtk-4.0 or Adw-1 ("Namespace Gtk not available").
  # This interpreter bakes the path in. Same set ghostty's wrapper carries, minus the
  # gstreamer/rsvg/layer-shell entries the goals window does not touch.
  # lib.getLib: glib and pango list `bin` as their first output, so a bare
  # reference would resolve to *-bin, which has no girepository-1.0. The
  # typelibs live in the lib/out output -- the same one wrapGAppsHook uses.
  typelibs = lib.makeSearchPath "lib/girepository-1.0" (map lib.getLib (with pkgs; [
    gtk4
    libadwaita
    glib
    gobject-introspection
    pango
    gdk-pixbuf
    graphene
    harfbuzz
  ]));
  # garminconnect: cadence/garmin.py reads Garmin Connect through this interpreter.
  python = pkgs.python3.withPackages (ps: [ ps.pygobject3 ps.garminconnect ]);
in
{
  home.packages = [
    (pkgs.writeShellScriptBin "goals-python" ''
      export GI_TYPELIB_PATH="${typelibs}''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
      exec ${python}/bin/python3 "$@"
    '')
  ];
}
