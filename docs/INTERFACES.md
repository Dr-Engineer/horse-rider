# Interfaces and file ownership

The contract between parallel workstreams. Stick to these names. If you must change one, change it here too and say
so in your final report.

## Round 2: polish, voices and fun (current ownership)

Only edit files you own. Code against the contract below for anything another stream owns. Missing sounds, lines and
props are skipped quietly, so you never need to wait for another stream to finish. This table replaces the older one below.

| Stream | Owns |
|---|---|
| **Art** | `art/blender/`, `assets/models/`, `art/tools/atlas*.py`, `make_atlas.py`, `make_road.py`, `assets/atlas/`, `shaders/`, `data/courses.gd`, `scripts/core/art_kit.gd`, `scripts/race/hazards.gd` (visuals only, the simulation stays as it is), `track_builder.gd`, `track_dressing.gd`, `track.gd`, `tests/hazard_view.*`, `lookdev.*`, `track_view.*` |
| **Audio** | `art/tools/make_voices.py`, `voice_script.py`, `voice_lines_game.json`, `make_audio.py`, `assets/audio/`, `data/voice_bank.gd`, `docs/VOICE_SCRIPT.md`, `scripts/core/sfx.gd`, `tools/spectrogram.py`, `tools/export_lines.gd`, `tests/mix_check.*` |
| **Race** | `scripts/race/race.gd`, `rider.gd`, `rider_ai.gd`, `rider_visual.gd`, `camera_rig.gd`, `fx.gd`, `player_control.gd`, `projectile.gd`, new `chatter.gd`, `life.gd`, `flair.gd`, `data/game_data.gd`, `scenes/race.tscn`, `tests/sim_balance.*`, `autoplay.*` |
| **UI** | `scripts/core/game.gd`, `input_setup.gd`, `scripts/ui/` (including `story_text.gd`), `scenes/` except `race.tscn`, `project.godot`, `art/tools/make_font.py`, `make_ui_icons.py`, `assets/fonts/`, `assets/ui/`, `tools/make_portraits.*`, `ui_walkthrough.gd` |
| **Coordinator** | Everything else: `docs/` apart from `VOICE_SCRIPT.md`, `README.md`, `CLAUDE.md`, git. Nobody else commits. |

### Voices (Audio provides, in `Sfx`)

```
Sfx.say(speaker: String, category: String, world_pos: Variant = null, volume_db := 0.0, lang := "") -> Dictionary
    Speaks a random line for that speaker and category, avoiding recent repeats. world_pos is a Vector3 for a positioned
    voice, or null for a flat one. lang "bo" or "en" forces a language, "" follows Game.voice_language. Returns the line
    {f, t, g, l, d} (file, subtitle text, English gloss for Tibetan lines, "en"/"bo", seconds), or {} if nothing played.
Sfx.say_text(speaker: String, text: String, volume_db := 0.0) -> float
    Speaks an exact line the menus show, by file name "<speaker>_<first 8 hex of md5 of text>.ogg". Returns seconds, or 0.0.
Sfx.stop_voice(), Sfx.voice_playing() -> bool, Sfx.set_voice_volume(0..1), var Sfx.voice_volume
```

Voices play on a `Voice` bus and duck the music while speaking. Speakers are rival ids, `joru`, `yangkyi`, `pola`, `mola`,
`child`, `steward`, `starter`. Categories are listed at the top of `art/tools/voice_script.py`: `pass_by, passed, hit_you,
hurt, down, gloat, near, hat, cry, win, start, scarf`; player rider `p_hurt, p_down, p_knock, p_remount, p_wind, p_cry,
p_scarf, p_win, p_lose`; `steward` has `fine, quiet`; `starter` has `ready, three, two, one, go`; `child` has `and_then`;
`pola` and `mola` have `greet, saying`.

`data/voice_bank.gd` is generated, `class_name VoiceBank`: `LINES[speaker][category]` is an array of those line
dictionaries, `SAYINGS: Array[String]` holds the old rider's sayings, and `PHRASES: Array` holds one entry per distinct
Tibetan phrase as `{t, g, f, speaker}` for the phrasebook.

New one-shot sounds through `Sfx.play` or `Sfx.play_at`: `cheer_kiki, cheer_lha, cheer_shuk, cheer_ala` (crowd shouts,
stored in `assets/audio/voice/`), `dog_bark, whinny, snort, yak_grunt, sheep_bleat, mule_bray, crane_call, marmot_whistle,
hat_pop, near_miss, harness_bells`. Unknown names are ignored, so code against them freely.

### Settings (UI provides, in `Game`)

`Game.voice_volume` (0..1, default 0.85) and `Game.voice_language` (0 both, 1 Tibetan, 2 English) are saved in the settings
file. **If the file exists but has no voice key, voice_volume starts at 0 when sfx is 0**, so a player who muted the game
stays muted. Never write to the settings file from a test.

### Chatter and stats (Race provides)

```
Race.chatter signal: chatter(rider: Rider, line: Dictionary)   # rider may be null for the starter or a steward
    line is what Sfx.say returned, plus "speaker": the speaker id. The HUD shows it as a subtitle for d + 1 seconds.
Race.chatter_node (Chatter), Race.life (Life): visuals-only helpers, never created when headless.
Rider.hats_knocked, near_misses, overtakes, best_streak: int. to_result() also carries "hats", "near_misses", "overtakes", "best_streak".
    Silver for these goes into Rider.silver_bonus, so Game's ledger picks it up with no change.
```

Everything Chatter, Life and Flair do is visual or audio: they use their own RandomNumberGenerator and never touch
`Race.rng`, so `tests/sim_balance` stays deterministic and its rules still hold. Stat counting happens only when not headless.

### Art helpers (Art provides, in `ArtKit`)

```
ArtKit.prop_walker(name) -> Node3D      # a prop whose legs can swing (yak, mule, sheep, dog, kiang)
ArtKit.set_stride(node, phase: float, amp: float)   # phase in radians (grows with distance walked), amp 0..1 (0 = still)
```

`Hazards` uses these for its movers. Race's `Life` uses them for roadside animals.

### Rules for every stream

- **No windows:** Godot must never appear on the user's screen or take focus while they work. Anything that needs pixels goes
  through `tools/run_hidden.ps1`, which uses an invisible desktop. Anything else uses `--headless`.
- **Silence:** every Godot run passes `--audio-driver Dummy`, which `run_hidden.ps1` and `--headless` already do. The user found
  the game too loud and has muted it on this PC. Never touch that settings file.
- Run imports through `tools/godot_import.sh` from Git Bash with `GODOT` set, so two imports can't collide.
- Keep files you save parse-clean: others are running the game at the same time. If a file you don't own has an error, wait a
  minute and retry, and report it if it stays broken. Don't fix it.
- No git writes. No new downloads beyond the installed voice tools.

### Added during round 2 (additive, on top of the contract above)

- `Sfx.say` also takes a Node3D or a Callable for `world_pos`, for a voice that follows a moving rider. With voices muted it still returns the line, so
  subtitles keep working. `Sfx.say_file(file, db)` plays one voice file by name. `Sfx.say_text` returns the line's length even when muted.
- `Race`: `note_hat(victim, by)`, `flair`, `terrain`. New `rider_event` kinds: `count`, `mud`, `hat`, `thud`. The countdown is 5.0 s with visuals and 3.6 s headless.
- `Rider`: `hat_off`, `hat_piece()`. Finished riders keep their lanes and spread apart.
- `RiderVisual.cadence(gait, speed, top)` replaces `GAIT_REF` and sets strides per second. `Sfx.set_gallop` and the hoof loops in `make_audio.py` follow it (`Sfx.LOOP_HZ`).
- `Game`: `settings_path`, `go(key, keep_voice)`, and the wager: `wager`, `wager_rival`, `wager_stake()`, `place_wager()`, `clear_wager()`. `last_result` gains `wager`,
  `wager_rival`, `wager_won`, `hats`, `near_misses`, `overtakes`, `best_streak`. `WINDHORSE_SETTINGS` in the environment names the settings file. `scripts/ui/speak.gd` guards every voice call from the menus.
- `ArtKit`: `WALKERS`, `walker_stride_length`, `mud_material`, `crowd_material`. Course `env` also takes `cloud_scale`, `cloud_light`, `cloud_shade`, `sun_size`, `sky_mid`.
- `VoiceBank.PHRASES` entries also carry `bo` and `d`.
- `tests/hazard_view` takes five more arguments (back, camera height, look height, tag, seconds of simulation). `tests/prop_view` shows walk poses.

## Round 1 ownership (history)

| Stream | Owns |
|---|---|
| **Characters** | `art/blender/kit.py`, `horse.py`, `rider.py`, `weapons.py`, `art/tools/atlas_palette.py` (append only), `atlas_tiles.py`, `make_atlas.py`, `assets/atlas/`, `assets/models/horse.glb`, `rider.glb`, `assets/models/weapons/`, `tests/lookdev.*`, `shaders/toon.gdshader`, `shaders/ink.gdshader`. Sole user of the live Blender MCP. |
| **World** | `art/blender/props*.py`, `art/tools/atlas_tiles_world.py`, `assets/models/props/`, `assets/atlas/road_*.png`, `data/courses.gd`, `scripts/core/art_kit.gd`, `scripts/race/track.gd`, `track_builder.gd`, `track_dressing.gd`, `shaders/ground, road, sky, water, flag`, `tests/track_view.*` |
| **Gameplay** | `data/game_data.gd`, `scripts/race/rider.gd`, `rider_visual.gd`, `rider_ai.gd`, `player_control.gd`, `race.gd`, `hazards.gd`, `projectile.gd`, `camera_rig.gd`, `fx.gd`, `scenes/race.tscn`, `tests/sim_balance.*`, `tests/autoplay.*` |
| **UI/Meta** | `scripts/core/game.gd`, `sfx.gd`, `input_setup.gd`, `scripts/ui/`, `scenes/` except `race.tscn`, `project.godot`, `art/tools/make_audio.py`, `art/tools/make_font.py`, `assets/audio/`, `assets/fonts/`, `assets/ui/`, `tools/make_portraits.*`, `Play.command` |

Everyone runs imports through `tools/godot_import.sh` (a lock stops two imports colliding).
Only Characters uses the live Blender. World runs Blender with `--background`.

## Autoloads

- `Game` (`scripts/core/game.gd`), `Sfx` (`scripts/core/sfx.gd`). See the stubs for the API.
- Input actions in `scripts/core/input_setup.gd`: steer_left, steer_right, urge, rein, whip, leap, strike_left,
  strike_right, kick, ranged, shield, second_wind, pause, ui_confirm, ui_back.

## data/game_data.gd (`class_name GameData`, static constants)

```
WEAPONS: id -> {name, tibetan, klass: "body"|"melee"|"ranged", damage, impact, reach, swing, cost, ammo, model, desc}
  ids: fists, kick, knife, pencase, whip, sword, key, spear, sling, bow, roped_spear
HORSES: id -> {name, cost, speed, accel, handling, stamina, bulk, coat: Color, mane: Color, rug: Color, desc}
  ids: old_tsampa, riwoche_dun, nangchen_bay, golok_black, sertso_grey, plus rivals' horses
TACK: saddle levels and armor levels
RIVALS: id -> {name, region, seasons: [0, 1, 2], weapon, ranged, shield, horse, skill, aggression, lane, bon: bool,
  slot_a, slot_b, wardrobe: [piece names], skin, lines: {intro: [], grudge: [], win: []}}
PLAYERS: joru, yangkyi with the same shape
static func prize(season, place), bounty(season), fine(season)
```

## data/courses.gd (`class_name Courses`, static)

```
static func count() -> int
static func get_course(index: int, season: int) -> Dictionary
  {id, name, region, blurb,
   segments: [[len, turn_deg, rise, optional half_width], ...], half_width,
   biome: {...for TrackBuilder...}, env: {sun_color, sun_energy, sun_rot: Vector3, ambient, ambient_energy, sky_top,
   sky_horizon, fog_color, fog_density, water_level (optional)},
   events: Array of Dictionary}
```

**Events** are gameplay things placed on the course, which `Hazards` spawns and simulates:

```
{type: "boulder"|"log"|"mud"|"ramp"|"mani_wall"|"chorten"|"yak_herd"|"sheep"|"caravan"|"scarf"|"target_pole",
 s: metres along, d: metres right of centre, ...}
{type: "quiet_zone", s0, s1}
{type: "pass", s}
{type: "start", s}, {type: "finish", s}
```

Everything else on the course is scenery, built by `TrackDressing`.

**World additions (World stream).** Event fields beyond `type, s, d` (metres): `boulder {size}`, `log {len, yaw}`,
`mud {w, len}`, `ramp {w, len, rise}`, `mani_wall {len, yaw}`, `chorten {}`, `yak_herd/sheep {count, dir, speed}`,
`caravan {count, speed}`, `scarf {color into Courses.SCARF_COLORS, group}` (the course data never emits color 1, so white can't appear whichever palette the HUD or Hazards use), `quiet_zone {s0, s1}`, `pass {s}`. The course dictionary also
carries `length, index, season, set_pieces, dress`; the `biome` also takes `river`, `lake`, `ledges`, `notches`,
`road_tex`, `fields`. Water is built by `TrackBuilder` from `biome.river` and `biome.lake` (not `env.water_level`).
`TrackBuilder.build_into(parent, ground_mat = null, road_mat = null)` makes its own materials when given null, and also
offers `ground_y(x, z)`, `height_at(s, d)`, `world_point(s, d)` (s may run past either end) and `dist_to_road(x, z)`.
`ArtKit.make_world(parent, env)` returns `{environment, sun, ink}`. `ArtKit.prop(name)` swaps any mesh named `flags*`
to the waving `flag` material; `ArtKit.grass_material()` is the no-outline sway material for ground cover. Prop GLBs face +Y (Godot -Z), origin on the ground; `mani_wall` is 12 m long along its
front axis, `scarf` uses slot A (`slot_a` instance uniform) for its colour. Prop sizes at scale 1 (width x height x length, m): mani_wall 2.4x2.3x12, chorten 4.6x7.0x4.6, boulder 3.8x2.8x3.8, log 1.5x1.4x5.7 (lies along its length), ramp 8.4x2.1x9 (rises toward the front, 1.5 m at the lip), mud_patch 9.8x0.1x16 (flat, lies on the road), yak 1.8x2.2x3.9, mule 1.6x2.1x3.0, sheep 0.8x1.0x1.4, scarf 0.6x0.1x2.4, target_pole 3.9 m tall, start_gate and finish_gate 37 m wide x 10.4 m tall (the dressing scales them to the road). Cameras need `far` of at least 8000 m (the far range and fog end are kilometres out); `TrackDressing` puts everything under one child node named `Dressing`. Tests: `tests/track_view.tscn -- <prefix> <course> <season> [fraction:yaw:pitch:height ...]`, also `bench`, `sun`, `lineup <props>`.

```
TrackDressing.new(track, course, rng).build_into(parent: Node3D)    # static scenery only
TrackBuilder.new(track, biome).build_into(parent, ground_mat, road_mat)
ArtKit.make_world(parent: Node3D, env: Dictionary)                  # WorldEnvironment, sun, sky, ink pass
ArtKit.prop(name) -> Node3D                                         # instanced GLB in the toon material
```

## Wardrobe names (rider.glb meshes)

`body_chuba, body_oneoff, body_fleece, body_hide, body_brocade`,
`head_young, head_old, head_woman, head_woman_old, head_soot`,
`hair_wound, hair_plaits, hair_mop, hair_short, hair_earlocks, hat_felt, hat_big, hat_peak, hat_fox, hat_basin, hat_disc, hat_foreign`,
`x_satchels, x_backpanel, x_casebell, x_bale, x_armcloth, x_scarf`

The Rider's `slot_a` colours robe, `slot_b` colours trim **and every hat** (hats use b1 light, b2 mid, b3 dark, with fixed
fur, brass and red-tassel accents). Hair uses slot D (`d1`, default near-black, so set `slot_d` to grey for old riders). Show one mesh per category and hide the rest.

**Skin tones (Characters, new):** every head exists in three tones: `head_young` (mid, `#B97F54`), `head_young_lt` (light,
`#D19A6E`) and `head_young_dp` (deep, `#96603C`); same for `head_old`, `head_woman`, `head_woman_old`, `head_soot`.
Pick `"head_%s%s" % [face, ["_lt", "", "_dp"][skin]]`; a rival's `wardrobe` list may simply name the tone variant (e.g. `head_old_dp`). The head mesh **includes the neck and both hands**, so one choice
sets all bare skin. The few bare bits on bodies (knees on `body_hide`) use slot C, so also set `slot_c` on every rider mesh
to the tone colour. Slots A (robe), B (trim and hats), C (bare skin) and D (hair) are per-instance uniforms (`set_instance_shader_parameter`).

Typical sets: Joru `body_chuba + head_young + hair_wound`; Wangyal `body_oneoff + head_young + hair_wound`;
Drukmo Kyi `body_chuba + head_woman + hat_peak + x_backpanel`; Chakri `body_chuba + head_soot + hair_earlocks + x_armcloth`;
Serkhar `body_brocade + head_old + hat_disc`. Bodies carry boots and sleeves, so no separate legs.

Atlas tiles (Characters): `face_<face>[_lt|_dp]`, `rug_lotus`, `rug_diamond`, `rug_cloud`, `band_stair`, `band_wave`,
`band_dots`, `band_lotus`, `brocade_cloud`, `saddle_pierced`.

## Animation names

**Rider:** ride, ride_slow, ride_whip, wobble, swing_R, swing_L, fist_R, fist_L, thrust_R, thrust_L, kick_R, kick_L,
bow_draw, bow_hold, bow_loose, block, throw, hit_R, hit_L, tumble, lie, getup, run, mount, rest_sit, victory, stand,
scoop_R, scoop_L (new: hang down that side of the horse and grab from the ground, 30 frames, hand lowest at frame 11 to 16).
Rider bones `grip.R`, `grip.L` hold weapons. The rider node sits at (0, -0.9, 0) under a BoneAttachment3D on the horse's `saddle` bone.

**Horse:** gallop, canter, trot, walk, idle, leap, rear, stumble.

**Weapons:** `assets/models/weapons/<model>.glb`, grip at the origin, pointing +Y in Blender (-Z in Godot).
Files: sword, knife, spear, roped_spear, key, whip, pencase, sling, bow, arrow, quiver, shield. Bow is modelled with its
limbs along Z and the string toward -Y (attach at `grip.L`); the shield face and boss point +Y (attach at `grip.L`);
the quiver's opening and arrow ends are at +Y (hang it from the hips with a tilt). The spear is 3.4 m long.
A weapon at `grip.R` follows the hand: it points down when the arm hangs and forward when the forearm is level (the ride pose
carries it forward and a little up), so tune the carry angle with `WEAPON_ROT` in `rider_visual.gd`.

## Race (`scripts/race/race.gd`, `class_name Race extends Node3D`, scene `scenes/race.tscn`)

```
signal race_started
signal race_finished(results: Array)        # [{rider, place, time, knockdowns, bounty, scoops, crashed: int}]
signal rider_hit(attacker: Rider, victim: Rider, info: Dictionary)  # {damage, impact, klass, blocked, parried, side}
signal rider_crashed(rider: Rider, reason: String)                  # "impact" | "health" | "hazard"
signal rider_remounted(rider: Rider)
signal announcement(text: String, kind: String)                     # kind: "good" | "bad" | "info" | "big"
var riders: Array[Rider]; var player: Rider; var track: Track; var course: Dictionary; var countdown: float
var paused_for_ui := false
func begin(config: Dictionary)   # config from Game.race_config()
func standings() -> Array[Rider]
```

The HUD (`scripts/ui/hud.gd`, a CanvasLayer) gets the Race with `hud.bind(race)`. `scenes/race.tscn` root is the Race and
adds a HUD if `res://scripts/ui/hud.gd` exists. When it's run directly with no menu, it uses `Game.race_config()` defaults.

## Rider (`scripts/race/rider.gd`, `class_name Rider`), public state read by HUD and AI

```
display_name, rival_id, is_player: bool
s, d, speed, lateral, height, top_speed
health, max_health, shake, stamina, max_stamina, lungta (0.0 to 5.0)
state: "ride" | "airborne" | "falling" | "down" | "rest" | "run" | "mount" | "finished"
rest_left: float, weapon_id, ranged_id, ammo, has_shield, blocking: bool, drawing: bool, draw_amount: float
place: int, finished: bool, finish_time: float, knockdowns: int, scoops: int
portrait: String  # res://assets/ui/portraits/<id>.png
```

## Tall tale rules

Everyone reads the "Cultural rules" in `docs/GAME_DESIGN.md`. They're binding.

## Gameplay additions (additive, nothing above was renamed)

- `Race`: extra signal `rider_event(kind, rider, info)` for FX and audio. Kinds: `teetering`, `crash`, `remount`, `leap`, `land`,
  `second_wind`, `parry`, `snatch`, `drop`, `finish`, `quiet_struck`, `steward_hit`, `pass_cry`, and `h_<kind>` from Hazards
  (`h_pass`, `h_site_good`, `h_site_bad`, `h_scarf`, `h_pole`, `h_ramp`, `h_fined`, `h_thrown`, `h_sheep`, `h_pickup`).
- `Race` vars: `headless`, `auto_begin`, `player_ai` (AI drives the player slot, for tests), `hazards`, `stats`, `violations`, `results`,
  `race_time`, `started`, `ended`. `Race.step(dt)` runs one tick by hand. `begin(config)` also reads `seed`, `rivals` (ids) and
  `featured_rival` (id, always included if it rides that season).
- Results rows also carry `fines`, `silver` (scarves, poles, ramps), `prize`, `qualified`, `finished`.
- `Rider.Intent` (steer, throttle, whip, leap, strike_left, strike_right, kick, ranged, shield, second_wind, mash) is filled by `PlayerControl` or `RiderAI`.
- `GameData.WEAPONS` ranged entries also have `draw`, `min_draw` and `speed`. Also `MELEE_IDS`, `RANGED_IDS`, `SHIELD`, `weapon_value(id)`.
- Course events read by `Hazards` use the field names in `data/courses.gd` (boulder `size`, log `len`/`yaw`, mud and ramp `w`/`len`,
  herd/sheep/caravan `count`/`dir`/`speed`, scarf `color`).
- Tests: `Godot --headless --path . res://tests/sim_balance.tscn -- <races> <season> [seed]` and
  `Godot --path . res://tests/autoplay.tscn -- <out_dir> [max_s] [seed] [season] [course] [weapon] [ranged] [crash_at_s] [crash_reason]`.

## UI/Meta API (added by the UI/Meta stream, nothing above changed)

- `Game.race_config()` also carries `"featured_rival"` (the id of the rival on the pre-race card). Race may ignore it.
- `Game.apply_race_result(results)` is called by the HUD when `race_finished` fires. It reads each entry's `rider`,
  `place`, `time`, `knockdowns`, `bounty` (silver), `scoops`, `silver` (bonus silver), `fines` (silver), updates money,
  qualification, grudges and the loan, autosaves, and returns the summary `Game.last_result` shows on the results screen.
- Grudges: the HUD watches `rider_hit` and `rider_crashed`, and a rival who crashes within 3 s of a player hit gets
  `Game.note_knockdown(rival_id)`. Grudges are in `Game.grudges` and in `race_config()`.
- Season rules: a course is cleared by finishing top 3 (the last course of Season 3 must be won). Clearing all five raises
  the Season. `Game.finished_game` is set after the final win.
- `Sfx.play(name, db, pitch)`, `Sfx.play_at(name, pos, db, pitch)`, `Sfx.music("menu"|"race"|"final")`,
  `Sfx.set_gallop(speed_fraction)`, `Sfx.set_ambience(wind, crowd)`, `Sfx.stop_loops()`.
  Sound names (assets/audio/*.wav): hooves_walk, hooves_trot, hooves_canter, hooves_gallop, wind, crowd, hit_light,
  hit_heavy, clang, whoosh, whip, bow_draw, bow_loose, sling, rope, crash, grunt, bell, horn, drum_hit, cymbal, flag_up,
  second_wind, splash, land, coin, count, go, ui_move, ui_ok, ui_back, jingle_win, jingle_lose, music_menu, music_race,
  music_final. Unknown names are ignored. A few aliases map to them (hit, thud, parry, swing, fall, ok, back...).
- The UI canvas is 640x360 scaled by whole numbers (project setting `stretch/scale_mode = integer`). Font sizes are
  multiples of 11. `UI` (scripts/ui/ui.gd) has the palette and drawing helpers.
