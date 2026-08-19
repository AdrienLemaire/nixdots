#!/usr/bin/env bash
# Measure BLE keyboard reconnect latency: from `connect` to uhid input device present.
#
# `hid=` is the metric that matters: time from LE link up to the keyboard being
# usable. `link=` is noisy -- repeated forced disconnects make peripherals back
# off their advertising -- so ignore it and space runs out.
#
# Baseline 2026-08-18, MX Keys Mini at MinConnectionInterval=24/Max=40 (30-50ms):
#   hid = 3.85, 3.87, 3.41, 3.33, 3.44 s   (Pebble M350s mouse: 0.01 s, cached)
#
# After dropping to 6/12 (7.5-15 ms), expectation:
#   hid ~1.2-1.8 s  -> round-trip bound confirmed, keep the change
#   hid ~3.4 s      -> not round-trip bound, revert (pure battery cost, no gain)
MAC="${1:-D3:46:9C:DC:46:1B}"
NAME="${2:-MX Keys Mini}"
LABEL="${3:-run}"

have_input() {
  grep -lFx "$NAME" /sys/class/input/input*/name 2>/dev/null | head -1
}

bluetoothctl disconnect "$MAC" >/dev/null 2>&1
# wait until the uhid device is gone
for _ in $(seq 1 60); do
  [ -z "$(have_input)" ] && break
  sleep 0.1
done
sleep 2

t0=$(date +%s.%N)
bluetoothctl connect "$MAC" >/dev/null 2>&1
t_link=$(date +%s.%N)
dev=""
for _ in $(seq 1 300); do
  dev="$(have_input)"
  [ -n "$dev" ] && break
  sleep 0.05
done
t_hid=$(date +%s.%N)

if [ -z "$dev" ]; then
  echo "$LABEL: FAILED - no input device after 15s"
  exit 1
fi
awk -v a="$t0" -v b="$t_link" -v c="$t_hid" -v l="$LABEL" \
  'BEGIN{printf "%-14s link=%.2fs  hid=%.2fs  total=%.2fs\n", l, b-a, c-b, c-a}'
