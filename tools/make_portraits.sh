#!/bin/bash
# Renders assets/ui/portraits/<id>.png for every player and rival, then imports them. tools/make_portraits.sh [id ...]
cd "$(dirname "$0")/.."
"${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}" --path . --resolution 800x600 -s res://tools/make_portraits.gd -- "$@" 2>&1 | grep -E "portrait|ERROR|SCRIPT" | head -40
tools/godot_import.sh
