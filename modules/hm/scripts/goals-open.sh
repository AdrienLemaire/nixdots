#!/usr/bin/env bash
# Launch one goals script through the live Hyprland instance.
#
# Never ExecStart a window directly from a timer: it works, but it blocks for
# the window's whole lifetime and pins the Type=oneshot unit open until you
# close it. hyprctl dispatch exec returns instantly.
#
# The instance signature is probed rather than inherited: the systemd user
# manager's copy is a snapshot from whichever Hyprland ran the import, and it
# goes stale across a Hyprland restart.
#
# hyprctl dispatch exec hands everything after it to /bin/sh -c, so the
# argument must be one executable and nothing else -- no redirections, no
# compound commands, no nested quotes.
set -u
[ $# -eq 1 ] || exit 0

hyprctl=/run/current-system/sw/bin/hyprctl
rt="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
his=""
if [ -x "$hyprctl" ] && [ -d "$rt/hypr" ]; then
  for d in "$rt"/hypr/*/; do
    s=$(basename "$d")
    if HYPRLAND_INSTANCE_SIGNATURE="$s" "$hyprctl" version >/dev/null 2>&1; then
      his="$s"; break
    fi
  done
fi
if [ -z "$his" ]; then
  echo "no live Hyprland instance; skipping"
  exit 0
fi

HYPRLAND_INSTANCE_SIGNATURE="$his" "$hyprctl" dispatch exec -- "$1" >/dev/null 2>&1
exit 0
