#!/usr/bin/env bash
# Watch for BLE link drops and record the HCI disconnect reason.
#
# The reason code is the one fact that decides whether idle drops are fixable:
#   0x13 Remote User Terminated  -> the keyboard deliberately went to sleep.
#                                   Nothing host-side can prevent it.
#   0x08 Connection Timeout      -> supervision-timeout link failure.
#                                   Forcing better conn params would help.
#   0x16 Terminated By Local Host-> something on THIS machine disconnected it.
#
# Runs indefinitely on a tiny filtered stream (not a full btsnoop capture), so
# it is safe to leave running for hours. Start it, then use the laptop normally
# and step away as you usually would.
#
#   sudo systemd-run --unit=bt-drop-watch --collect \
#       /home/dori/Projects/Perso/hydenix/docs/bt-watch-drops.sh
#
#   # later, to read it:      cat /var/log/bt-drops.log
#   # to stop:                sudo systemctl stop bt-drop-watch
set -u

LOG="${1:-/var/log/bt-drops.log}"

if [ "$(id -u)" -ne 0 ]; then
  echo "must run as root" >&2
  exit 1
fi

touch "$LOG"
chmod 644 "$LOG"
{
  echo "=== bt-drop-watch started $(date -Is) ==="
  echo "=== keyboard D3:46:9C:DC:46:1B / mouse D1:A5:04:8A:E8:E2 ==="
} >> "$LOG"

exec stdbuf -oL btmon -T -P 2>&1 \
  | grep --line-buffered -E \
      'Disconnect|Reason:|Connection Complete|Connection Update Complete|Device Connected|Device Disconnected|Address:|LE Address:' \
  >> "$LOG"
