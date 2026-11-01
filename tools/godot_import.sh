#!/bin/bash
# Runs a Godot import while holding a lock, so parallel work can't corrupt the import cache.
LOCK=/tmp/game_1_godot_import.lock
until mkdir "$LOCK" 2>/dev/null; do /bin/sleep 2; done
trap 'rmdir "$LOCK"' EXIT
cd "$(dirname "$0")/.." && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import 2>&1 | grep -iE "error|fail" | grep -v "Failed loading resource: res://assets/models/props" | head -20
exit 0
