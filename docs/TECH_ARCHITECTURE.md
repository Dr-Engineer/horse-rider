# Technical architecture

Godot 4.7 (Forward+), GDScript with static types. Blender 5.2 for models, driven through the Blender MCP.
Godot MCP for running the project and reading its output.

## Coordinates

- **Blender:** Z up, models face +Y, X right, metres. glTF export puts them in Godot facing -Z.
- **Pose values:** rotations in armature axes relative to rest. +X swings a hanging arm forward, -Y raises a
  right arm outward, +Z yaws left. Helpers in `art/blender/kit.py`.
- **Track space:** `s` metres along the course, `d` metres right of centre. `Track.frame(s, d, h)` gives world
  transforms. All gameplay happens in track space, with no physics engine. Rendering reads it each frame.

## Layout

```
art/blender/       Blender scripts (kit, horse, rider, weapons, props)
art/tools/         Atlas, font and audio generators
assets/            Generated output, never edited by hand
data/              game_data.gd: weapons, horses, rivals, courses
docs/              Design documents
scripts/core/      Autoloads: Game (state, save), Sfx (audio)
scripts/race/      Track, TrackBuilder, TrackDressing, Rider, RiderAI, Race, Hazards, CameraRig
scripts/ui/        HUD and menus
shaders/           toon, ground, road, ink, sky, water, flag
tests/             Lookdev scenes and headless balance simulation
tools/             bmcp.py, screenshot.gd
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

## Testing

- `tests/sim_balance.gd`: full AI races headless, prints standings, damage by weapon class, crash causes.
- `tests/autoplay`: a bot drives the real game with rendering and saves screenshots and FPS at set moments.
- `tests/lookdev.tscn`: art review through the real shaders.

## Save

`user://save.cfg`: progress, money, horse, weapons, tack, grudges.
