#!/usr/bin/env bash
# Floating memory inspector. Opens kitty + btop sorted by memory so
# SIGSTOP (s) / SIGCONT (s) / SIGTERM (t) / SIGKILL (k) on the worst
# offender is one keystroke. Triggered by SUPER+ESCAPE.
exec kitty \
  --class=mem-inspector \
  --title='Memory Inspector' \
  -o initial_window_width=1400 \
  -o initial_window_height=800 \
  btop --preset 2
