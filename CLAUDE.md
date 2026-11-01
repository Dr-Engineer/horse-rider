# Windhorse Rumble

Road-Rash-style horse combat racing, Tibet, 1954, Godot 4.7 and Blender 5.2. Claude does all the work and is the
user's only interface.

Read before changing anything:
- `docs/GAME_DESIGN.md`: rules, numbers, and the binding cultural rules
- `docs/STYLE_GUIDE.md`: the visual rules
- `docs/WORLD_AND_CAST.md`: story, courses, cast
- `docs/ASSET_BIBLE.md`: every asset and the script that builds it
- `docs/TECH_ARCHITECTURE.md`: code layout and coordinate conventions
- `docs/RESEARCH.md`: findings and their limits
- `docs/HANDOFF.md`: where the project stands, how the user works, what's next
- `docs/NEW_COMPUTER_SETUP.md`: installing everything on a new computer

Practical notes:
- Blender 5.2 must be open in a window for the MCP. `tools/bmcp.py` calls it if the session's own tools aren't loaded.
- After changing anything in `assets/`, run `tools/godot_import.sh` (set `GODOT` if it isn't in `/Applications`).
- `assets/` is generated, so change the scripts in `art/`, not the outputs.
- Only start agents when the user asks. Give them strict file ownership (`docs/INTERFACES.md`) and a lighter model: parallel research agents on the heaviest model used up the usage limit quickly.
- The GitHub repo is public. Run the leak check before every push.
