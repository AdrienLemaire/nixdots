#!/usr/bin/env bash
BASE="/tmp/gif-session"
FRAMES="$BASE/frames"
TS_FILE="$BASE/timestamps.txt"
TMP="/tmp/gif-ordered"
OUT="$HOME/Videos/gif-$(date +%Y%m%d-%H%M%S).gif"

# Validate input files exist
if [ ! -f "$TS_FILE" ]; then
	notify-send "ERROR" "No frames captured. Run gif-frame.sh first."
	exit 1
fi

if [ ! -d "$FRAMES" ] || [ -z "$(ls -A "$FRAMES" 2>/dev/null)" ]; then
	notify-send "ERROR" "No frame files found in $FRAMES"
	exit 1
fi

mkdir -p "$TMP" "$HOME/Videos"
rm -f "$TMP"/*

FPS=12
MIN_FRAME_DURATION=0.1
MAX_FRAME_DURATION=2.0
PADDING_FRAMES=2

total_frames=$(wc -l <"$TS_FILE")
current_frame=0

notify-send "GIF Generation" "Processing $total_frames frames..."

prev_ts=""
while read -r file ts; do
	current_frame=$((current_frame + 1))
	progress=$((current_frame * 100 / total_frames))

	# Validate source file exists
	if [ ! -f "$FRAMES/$file" ]; then
		notify-send "ERROR" "Missing frame: $FRAMES/$file"
		exit 1
	fi

	if [ $((current_frame % (total_frames / 10 + 1))) -eq 0 ] || [ "$current_frame" -eq "$total_frames" ]; then
		notify-send "GIF Generation" "Processing frames: $progress% ($current_frame/$total_frames)"
	fi

	if [ -z "$prev_ts" ]; then
		duration=0.5
	else
		duration=$(awk "BEGIN {print $ts - $prev_ts}")
	fi

	duration=$(awk "BEGIN {
        if ($duration < $MIN_FRAME_DURATION) print $MIN_FRAME_DURATION;
        else if ($duration > $MAX_FRAME_DURATION) print $MAX_FRAME_DURATION;
        else print $duration;
    }")

	repeat=$(awk "BEGIN {print int($duration * $FPS)}")
	[ "$repeat" -lt 1 ] && repeat=1
	repeat=$((repeat + PADDING_FRAMES))

	for ((i = 0; i < repeat; i++)); do
		cp "$FRAMES/$file" "$TMP/${file%.png}_$i.png"
	done

	prev_ts=$ts
done <"$TS_FILE"

# Verify we have frames to process
if [ -z "$(ls -A "$TMP" 2>/dev/null)" ]; then
	notify-send "ERROR" "No frames prepared for encoding"
	exit 1
fi

notify-send "GIF Generation" "Encoding with gifski..."

# Fixed: removed duplicate 'gifski' line
gifski \
	--fps $FPS \
	--quality 100 \
	--fast \
	--repeat 0 \
	-o "$OUT" \
	"$TMP"/*.png

if [ $? -ne 0 ]; then
	notify-send "ERROR" "gifski encoding failed"
	exit 1
fi

wl-copy <"$OUT"
rm -rf "$BASE" "$TMP"

notify-send "GIF Complete ✓" "$(basename "$OUT") - $(du -h "$OUT" | cut -f1)"
