#!/bin/bash
# tools/run_walkthrough.sh <out_dir> [screens...]   (kills Godot after 170 s if it hangs)
cd "$(dirname "$0")/.."
out="$1"; shift
mkdir -p "$out"
"${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}" --path . --disable-vsync --resolution 1600x900 -s res://tools/ui_walkthrough.gd -- "$out" "$@" > "$out/log.txt" 2>&1 &
pid=$!
for i in $(seq 1 170); do
  if ! kill -0 $pid 2>/dev/null; then break; fi
  sleep 1
done
kill $pid 2>/dev/null
grep -E "shot |ERROR|SCRIPT|Parse|Invalid|Condition" "$out/log.txt" | head -${LINES_MAX:-40}
