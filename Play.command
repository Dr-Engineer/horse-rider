#!/bin/bash
# Double-click to play Windhorse Rumble. Needs Godot 4.7 in /Applications.
cd "$(dirname "$0")"
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
if [ ! -x "$GODOT" ]; then
  osascript -e 'display dialog "Godot 4.7 was not found in /Applications. Install it (godotengine.org) and double-click Play.command again." buttons {"OK"} default button "OK" with icon caution' >/dev/null 2>&1
  echo "Godot not found at $GODOT"
  exit 1
fi
# First run on a fresh copy: build the import cache so models and sounds load.
if [ ! -d ".godot/imported" ]; then
  echo "Importing assets (first run only)..."
  "$GODOT" --headless --path . --import >/dev/null 2>&1
fi
exec "$GODOT" --path .
