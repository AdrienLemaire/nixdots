#!/usr/bin/env bash
# Open the evening review window. Mirrors goals-today.sh: one place where the
# pipeline is defined, for the keybind, the dunst action and the timer alike.
# goals-python (modules/hm/goals-window.nix) is a python with GI_TYPELIB_PATH
# baked in; a bare python3 cannot find Gtk-4.0 outside a GTK app's own wrapper.
# stderr is dropped because HyDE's gtk.css is a GTK3-era stylesheet and GTK4
# prints ~60 harmless rejections of -gtktreeview-* properties on every launch.
set -u
REPO="${GOALS_REPO:-$HOME/Projects/Perso/personal-goals}"
exec "$REPO/bin/goalstate" 2>/dev/null | goals-python "$REPO/bin/goals-review" 2>/dev/null
