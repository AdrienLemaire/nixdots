#!/usr/bin/env bash
# Capture an HCI trace of one keyboard reconnect cycle. Run as root:
#   sudo ./docs/bt-trace.sh
# Writes a world-readable btsnoop file so it can be decoded unprivileged.
#
# Retries the connect until the link actually comes up -- after a forced
# disconnect the keyboard backs off its advertising, so a single connect
# attempt often misses the window entirely.
set -u

MAC="${1:-D3:46:9C:DC:46:1B}"
NAME="${2:-MX Keys Mini}"
OUT="${3:-/tmp/bt-trace.snoop}"

if [ "$(id -u)" -ne 0 ]; then
  echo "must run as root (sudo $0)" >&2
  exit 1
fi

have_input() { grep -lFx "$NAME" /sys/class/input/input*/name 2>/dev/null | head -1; }

rm -f "$OUT"
btmon -w "$OUT" >/dev/null 2>&1 &
BTMON=$!
trap 'kill $BTMON 2>/dev/null' EXIT

sleep 1
echo "disconnecting $MAC ..."
bluetoothctl disconnect "$MAC" >/dev/null 2>&1
for _ in $(seq 1 60); do [ -z "$(have_input)" ] && break; sleep 0.2; done
sleep 3

echo "reconnecting (will retry up to ~90s) ..."
for i in $(seq 1 9); do
  bluetoothctl connect "$MAC" >/dev/null 2>&1
  [ -n "$(have_input)" ] && { echo "  connected on attempt $i"; break; }
  sleep 2
done

sleep 2
kill $BTMON 2>/dev/null
wait $BTMON 2>/dev/null
chmod 644 "$OUT"

if [ -z "$(have_input)" ]; then
  echo "WARNING: keyboard never reconnected -- trace may be incomplete"
fi
echo "wrote $OUT ($(stat -c %s "$OUT") bytes)"
