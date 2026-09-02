#!/usr/bin/env bash
# Open the goals window. Single entry point: keybind, dunst action and timer all
# call this, so there is one place where the pipeline is defined.
# stderr is dropped because HyDE's gtk.css is a GTK3-era stylesheet and GTK4
# prints ~60 harmless rejections of -gtktreeview-* properties on every launch.
set -u
REPO="$HOME/Projects/Perso/personal-goals"
exec "$REPO/bin/goalstate" 2>/dev/null | "$REPO/bin/goals-window" 2>/dev/null
