#!/bin/bash
# Records the demo video from real gameplay: a bot plays, Godot's Movie Maker captures each clip.
# Usage: tools/record_demo.sh <work_dir> <final.mp4>
cd "$(dirname "$0")/.."
W="$1"; FINAL="$2"; G=/Applications/Godot.app/Contents/MacOS/Godot
mkdir -p "$W" "$(dirname "$FINAL")"
swiftc -O tools/pngs2mp4.swift -o "$W/pngs2mp4" 2>/dev/null
swiftc -O tools/joinmp4.swift -o "$W/joinmp4" 2>/dev/null
clip() { # name first_frame args...
  local name="$1" first="$2"; shift 2
  mkdir -p "$W/$name"
  "$G" --path . --disable-vsync --fixed-fps 30 --resolution 1280x720 --write-movie "$W/$name/frame.png" "$@" > "$W/$name.log" 2>&1
  "$W/pngs2mp4" "$W/$name" "$W/$name.mp4" 30 "$first"
  /usr/bin/find "$W/$name" -name 'frame*.png' -delete
}
clip title 0 --quit-after 150 res://scenes/title.tscn
clip tea 0 res://tests/autoplay.tscn -- "$W/shots_tea" 40 3 0 0 sword bow
clip pass 120 res://tests/autoplay.tscn -- "$W/shots_pass" 34 21 2 2 spear bow -1 health mash 1430
clip fort 120 res://tests/autoplay.tscn -- "$W/shots_fort" 26 27 2 3 sword bow -1 health mash 1120
clip gate 120 res://tests/autoplay.tscn -- "$W/shots_gate" 34 33 2 4 key bow -1 health mash 1560
"$W/joinmp4" "$FINAL" "$W/title.mp4" "$W/tea.mp4" "$W/pass.mp4" "$W/fort.mp4" "$W/gate.mp4"
