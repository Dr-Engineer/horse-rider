# Technical architecture

Godot 4.7 (Forward+), GDScript with static types. Blender 5.2 for models, driven through the Blender MCP.
Godot MCP for running the project and reading its output.

## Coordinates

- **Blender:** Z up, models face +Y, X right, metres. glTF export puts them in Godot facing -Z.
- **Pose values:** rotations in armature axes relative to rest. +X swings a hanging arm forward, -Y raises a
  right arm outward, +Z yaws left. Helpers in `art/blender/kit.py`.
- **Track space:** `s` metres along the course, `d` metres right of centre. `Track.frame(s, d, h)` gives world
  transforms. Riders and hazards live in track space, with no physics engine. Rendering reads it each frame.
- **World space:** shots (`Projectile`) fly here, under gravity and air drag, and work out their own `s`, `d` and `h` as they
  go, for the ground and the target poles. Each tick's flight is tested against an upright cylinder around each rider.

## Layout

```
art/blender/       Blender scripts (kit, horse, rider, weapons, props)
art/tools/         Atlas, font, audio and voice generators
assets/            Generated output, never edited by hand
data/              game_data.gd: weapons, horses, rivals; courses.gd; voice_bank.gd (generated)
docs/              Design documents
scripts/core/      Autoloads: Game (state, save), Sfx (audio and voices)
scripts/race/      Track, TrackBuilder, TrackDressing, Rider, RiderAI, Race, Hazards, Roadside, CameraRig, Fx, and for visuals and sound only: Chatter, Flair, Life
scripts/ui/        HUD and menus
shaders/           toon, walker, crowd, ground, road, mud, ink, sky, water, flag
tests/             Lookdev scenes, headless balance simulation and focused checks
tools/             run_hidden.ps1, bmcp.py, export_lines.gd, spectrogram.py, make_voice_review.py, screenshot.gd
```

## Key decisions

- **Track-space simulation** makes the AI simple, lets 8 riders run cheaply, and allows a headless simulated
  race for balance checks.
- **Procedural terrain:** `TrackBuilder` rasterises distance to the course onto a grid, then builds flat-shaded
  chunks and a coarse far range. A test course of 2.2 km builds in about 0.3 seconds.
- **One GLB per character type** with wardrobe meshes toggled per rider. Per-instance colours use
  `instance uniform` (slots A-D, flash).
- **Ink as a post pass** reads depth, normals and a class stored in ROUGHNESS. No inverted hulls.
- **Animation:** Rider and horse have their own AnimationPlayer. Rider attaches to the horse's `saddle` bone through
  `BoneAttachment3D`, then detaches when thrown. Weapons attach to `grip` bones.

## Loop

`Race` owns the course and riders and ticks in `_physics_process` at 60 Hz:
1. Each `Rider` runs a controller (`PlayerControl` or `RiderAI`) that fills an intent struct.
2. `Rider.simulate(delta)` applies speed, steering, curve push, off-road, hazards and combat timers.
3. `Race` resolves rider contact and scoring.
4. Visual nodes update from state.

`Race` can run without visuals (`headless := true`), which `tests/sim_balance.gd` uses to check balance rules
such as "ranged never unseats on impact" and "crash counts stay in a sane range".

The player's aim is one number, `Race.aim_screen`, a fraction of the screen. `PlayerControl.move_sight` sets it from the mouse or
right stick, the HUD paints the sight there, and `Race.update_sight` turns it into a line through the camera that the shot flies along. A test can
set `Race.aim_held` and move it directly, as `tests/autoplay` does, which exercises the whole path without touching the real pointer.

`Chatter`, `Flair` and `Life` watch the race and add voices, comic moments and roadside animals. They're never created when headless and
use their own random numbers, so they can't change a simulated race. Their stats (`Rider.hats_knocked`, `near_misses`, `overtakes`,
`best_streak`) count only when not headless.

## Testing

Nothing may open a window on the user's screen or play sound. Run anything that needs pixels through `tools/run_hidden.ps1`, which
starts Godot on an invisible Windows desktop (hiding the window, moving it off-screen and Godot's no-focus setting all still took focus):
`powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_hidden.ps1 -Timeout 120 -Log out.txt -GodotArgs "res://tests/autoplay.tscn -- <out_dir> 60 7 1 1 sword"`

In a real race the HUD keeps the pointer inside the window. Test runs (`Game.test_run`) must not: clipping the cursor reaches past the hidden
desktop to the user's real pointer.

- `tests/sim_balance.gd`: full AI races headless, prints standings, damage by weapon class, crash causes.
- `tests/combat_check`: fists, kick timing and shove, slam momentum, the 1.5x strikes. `tests/roadside_check`: bullseye rings, wolves, sheep, blows from the rough.
- `tests/aim_check`: shot physics against the sums, what a dead-on shot and a shot aimed high do at range, wind trail strength and catch-up.
- `tests/dressing_check`: no prop model hovers above its origin, and no scatter lands on the road.
- `tests/road_check`: bend radii, how near the road comes to itself and whether a landmark sits on it, for every course and Season, with a map of each (`-s`, takes an output folder).
- `tests/steer_check`: how far a horse runs with no steering, and whether on-or-off keyboard steering with a human's reaction time holds the road flat out.
- `tests/autoplay`: a bot drives the real game with rendering and saves screenshots and FPS at set moments.
- `tests/hazard_view`, `prop_view`, `track_view`, `lookdev`: art review through the real shaders.
- `tests/chatter_check`, `flair_check`, `gait_check`: voices, showing off and hoof timing. `tests/mix_check`: records a race with Movie Maker to measure loudness.
- `tools/ui_walkthrough.gd`: every menu screen with screenshots. `tools/hud_chatter_test.gd`: the subtitle strip.

## Save

`user://save.cfg`: progress, money, horse, weapons, tack, grudges. `user://settings.cfg`: music, effects, voices, language, fullscreen.
Runs of `res://tests`, `res://tools` and `-s` use `test_save.cfg` and `test_settings.cfg` instead. Godot started from a Claude session
writes to the real user data folder, so a test on the normal paths would overwrite the player's game.
