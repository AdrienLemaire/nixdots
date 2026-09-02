#!/usr/bin/env bash
# Open the goals window. Single entry point: keybind, dunst action and timer all
# call this, so there is one place where the pipeline is defined.
# stderr is dropped because HyDE's gtk.css is a GTK3-era stylesheet and GTK4
# prints ~60 harmless rejections of -gtktreeview-* properties on every launch.
set -u
REPO="$HOME/Projects/Perso/personal-goals"
# goals-python (modules/hm/goals-window.nix) is a python with GI_TYPELIB_PATH baked
# in; a bare python3 cannot find Gtk-4.0 outside a GTK app's own wrapper environment.
exec "$REPO/bin/goalstate" 2>/dev/null | goals-python "$REPO/bin/goals-window" 2>/dev/null
