#!/usr/bin/env bash
# Catch the "ghostty window opens but shell never appears" stall in the act.
#
# A healthy ghostty surface has: 1 window, 1 shell child, 1 ptmx fd, 1 `renderer` thread.
# The stall produces a mapped window with none of the rest. This polls for that divergence
# and dumps everything needed to diagnose it the moment it happens.
#
# Usage:  ./ghostty-watch-stall.sh [interval_seconds]
# Output: /tmp/ghostty-stall-<timestamp>.log  (also echoed)
#
# Read-only. Never signals ghostty.

set -uo pipefail
INTERVAL="${1:-5}"

# Hyprland's signature is not inherited by detached shells; resolve the live one.
resolve_his() {
  local d
  for d in /run/user/"$(id -u)"/hypr/*/; do
    [ -S "$d/.socket.sock" ] || continue
    if HYPRLAND_INSTANCE_SIGNATURE="$(basename "$d")" hyprctl version >/dev/null 2>&1; then
      basename "$d"; return 0
    fi
  done
  return 1
}

HYPRLAND_INSTANCE_SIGNATURE="$(resolve_his)" || { echo "no live Hyprland socket" >&2; exit 1; }
export HYPRLAND_INSTANCE_SIGNATURE

ghostty_pid() { pgrep -u "$(id -u)" -f 'ghostty-wrapped|^ghostty$' | head -1; }

GPID="$(ghostty_pid)"
[ -n "$GPID" ] || { echo "no ghostty process found" >&2; exit 1; }
echo "watching ghostty pid=$GPID every ${INTERVAL}s (signature ${HYPRLAND_INSTANCE_SIGNATURE})"

windows()  { hyprctl clients -j | jq '[.[]|select(.class=="com.mitchellh.ghostty")]|length'; }
shells()   { ps --ppid "$GPID" --no-headers 2>/dev/null | wc -l; }
ptmx()     { ls -l /proc/"$GPID"/fd 2>/dev/null | grep -c ptmx; }
renderers(){ grep -lx renderer /proc/"$GPID"/task/*/comm 2>/dev/null | wc -l; }

dump() {
  local out="$1"
  {
    echo "===== ghostty stall detected $(date -Is) ====="
    echo "pid=$GPID  windows=$(windows) shells=$(shells) ptmx=$(ptmx) renderers=$(renderers)"
    echo
    echo "--- hyprctl clients (ghostty) ---"
    hyprctl clients -j | jq '.[]|select(.class=="com.mitchellh.ghostty")
      |{address,workspace:.workspace.id,title,mapped,hidden,floating,xwayland,at,size}'
    echo
    echo "--- threads (comm / state / wchan) ---"
    for t in /proc/"$GPID"/task/*; do
      printf '%-8s %-18s %-3s %s\n' "$(basename "$t")" \
        "$(cat "$t/comm" 2>/dev/null)" \
        "$(awk '{print $3}' "$t/stat" 2>/dev/null)" \
        "$(cat "$t/wchan" 2>/dev/null)"
    done
    echo
    echo "--- children ---"
    ps --ppid "$GPID" -o pid,stat,lstart,wchan:25,cmd 2>/dev/null
    echo
    echo "--- fds (pty / socket) ---"
    ls -l /proc/"$GPID"/fd 2>/dev/null | grep -E 'ptmx|pts|socket'
    echo
    echo "--- surface scopes ---"
    systemctl --user list-units --all --no-legend 2>/dev/null | grep -i ghostty
    echo
    echo "--- recent journal (surfaces, portal, systemd jobs) ---"
    journalctl --user --since "3 min ago" 2>/dev/null \
      | grep -viE 'tmux server for agent|Inhibiting other than idle' | tail -40
    echo
    echo "--- systemd --user job queue ---"
    systemctl --user list-jobs --no-legend 2>/dev/null | head -20
    echo "===== end ====="
  } | tee -a "$out"
}

LOG="/tmp/ghostty-stall-$(date +%Y%m%d-%H%M%S).log"
consecutive=0

while :; do
  if ! kill -0 "$GPID" 2>/dev/null; then
    GPID="$(ghostty_pid)"
    [ -n "$GPID" ] || { echo "ghostty gone, exiting"; exit 0; }
    echo "ghostty restarted, now watching pid=$GPID"
  fi

  w="$(windows)"; r="$(renderers)"; s="$(shells)"
  if [ "$w" -gt "$r" ] || [ "$w" -gt "$s" ]; then
    consecutive=$((consecutive + 1))
    # require two consecutive samples so a surface mid-creation isn't flagged
    if [ "$consecutive" -eq 2 ]; then
      dump "$LOG"
      echo "*** dumped to $LOG ***"
    fi
  else
    consecutive=0
  fi
  sleep "$INTERVAL"
done
