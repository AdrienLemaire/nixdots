#!/usr/bin/env bash
BASE="/tmp/gif-session"
FRAMES="$BASE/frames"
GEOM_FILE="$BASE/geom"
TS_FILE="$BASE/timestamps.txt"

mkdir -p "$FRAMES"

# First capture → select area
if [ ! -f "$GEOM_FILE" ]; then
	slurp >"$GEOM_FILE"
fi

GEOM=$(cat "$GEOM_FILE")
COUNT=$(ls "$FRAMES"/*.png 2>/dev/null | wc -l)
FILE=$(printf "frame-%05d.png" $((COUNT + 1)))

# Capture at 2x scale natively
grim -g "$GEOM" -s 2 "$FRAMES/$FILE"

# Verify file was created
if [ ! -f "$FRAMES/$FILE" ]; then
	notify-send "ERROR" "Failed to capture frame"
	exit 1
fi

TS=$(date +%s.%N)
echo "$FILE $TS" >>"$TS_FILE"

notify-send "GIF frame added ($((COUNT + 1)))"
