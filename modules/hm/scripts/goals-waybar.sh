#!/usr/bin/env bash
# Waybar's exec for custom/goals.
#
# Absolute path, not hyde-shell: hyde-shell resolves from the store, so a
# patched ~/.local/lib/hyde copy never actually runs. stderr is dropped so a
# stray warning can never end up inside waybar's JSON.
#
# The spec caps the bar's poll; 3s per source × up to four serial sources is
# the worst case, and a stalled poll must not stall waybar.
set -u
REPO="$HOME/Projects/Perso/personal-goals"
exec timeout 8 "$REPO/bin/goals-waybar" 2>/dev/null
