#!/bin/bash
# Parse-checks the UI/meta GDScript files with autoloads present: tools/check_scripts.sh [extra res:// paths]
cd "$(dirname "$0")/.."
"${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}" --headless --path . -s res://tools/check_load.gd -- "$@" 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error|FAILED|checked|ERROR:" | head -30
exit 0
