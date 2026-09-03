#!/usr/bin/env bash
# Open Claude in the goals repo. One executable and nothing else.
#
# hyprctl dispatch exec hands its whole argument to /bin/sh -c: redirections,
# compound commands and nested quotes after -e are eaten by that outer shell
# rather than passed through. This wrapper exists so the dispatcher only ever
# sees one path.
#
# -e consumes the rest of argv and overrides `command = zsh` from ghostty.conf,
# so claude runs as PID 1 of the pty and the window closes when it exits. That
# is the same invocation the evening review's "Open Claude instead" button
# already uses; `claude` resolves via ~/.local/bin, never the versioned target.
set -u
REPO="${GOALS_REPO:-$HOME/Projects/Perso/personal-goals}"
exec ghostty --working-directory="$REPO" -e claude
