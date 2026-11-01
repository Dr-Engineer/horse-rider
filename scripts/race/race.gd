class_name Race
extends Node3D
## Owns the course and the 8 riders, ticks at 60 Hz, resolves combat, contact and scoring.
## `headless = true` runs the whole thing with no visuals (tests/sim_balance.gd steps it by hand).

signal race_started
signal race_finished(results: Array)
signal rider_hit(attacker: Rider, victim: Rider, info: Dictionary)
signal rider_crashed(rider: Rider, reason: String)
signal rider_remounted(rider: Rider)
signal announcement(text: String, kind: String)
## Extra signals for FX and audio (not in INTERFACES, additive).
signal rider_event(kind: String, rider: Rider, info: Dictionary)
## Someone speaks. line is what Sfx.say returned plus "speaker"; rider is null for the starter and the stewards.
signal chatter(rider: Rider, line: Dictionary)

const GRID_ROWS := 4
const MAX_RACE_TIME := 420.0
const AFTER_PLAYER_FINISH := 7.0
## With visuals the starter gets time to call the riders before the numbers; the headless sim keeps its 3.6 s.
const COUNTDOWN_HEADLESS := 3.6
const COUNTDOWN_SHOWN := 5.0
const HAT_SILVER := 3
const DRAFT_RANGE := 55.0       # how far back a horse's wind trail reaches
const DRAFT_WIDTH_NEAR := 1.8   # half width of the trail just behind the horse
const DRAFT_WIDTH_FAR := 3.0    # and at its far end
const RIDER_LOW := 1.1          # a shot hits a rider between these heights above the ground: the saddle up to the hat.
const RIDER_HIGH := 2.8         # Below that it's the horse, and horses are never hurt, so it flies on.
const RIDER_HEAD := 2.2         # above this it's the head
const RIDER_HIT_RADIUS := 0.85
const MAX_STUCK := 14           # arrows left standing in the ground
const SIGHT_RANGE := 110.0      # how far along the sight a shot is taken to be going if it meets nothing
const KICK_PUSH := 13.5         # sideways speed a kick gives its target, which fades over Rider.SLIDE_TIME: a shove of over 6 m
const SPEAR_CLOSE := 2.0        # nearer than this a spear has no room to work,
const SPEAR_CLOSE_DAMAGE := 1.0 / 3.0   # and does this share of its damage
const SLAM_SPEED := 4.5         # a slam takes this much sideways speed toward the other rider,
const SLAM_EDGE := 3.0          # and this much more sideways momentum than they have (speed times the horse's bulk)
const SLAM_DAMAGE := 1.5        # a strike lands this much harder
const STRIKE_SPEED := 6.5       # with nearly all the sideways speed a horse has, going toward the target,
const STRIKE_EDGE := 5.5        # who has next to none of their own,
const SLAM_WINDOW := 0.8        # or for this long after a slam as hard as that
const SLAM_BOUNCE := 0.25       # how much two horses that slam together spring apart: 0 goes on as one, 1 bounces right off

var riders: Array[Rider] = []
var player: Rider
var track: Track
var course: Dictionary = {}
var countdown := 0.0
var paused_for_ui := false:
	set(v):
		paused_for_ui = v
		_apply_pause(v)

var headless := false
var auto_begin := true
var player_ai := false       # player slot driven by AI (sim and autoplay)
var season := 0
var grudges: Dictionary = {}
var hazards: Hazards
var roadside: Roadside
var rng := RandomNumberGenerator.new()
var race_time := 0.0
var finish_s := 0.0
var started := false
var ended := false
var projectiles: Array[Projectile] = []
var controllers: Dictionary = {}
var visuals: Dictionary = {}
var fx: Node = null
var cam_rig: Node = null
var hud: Node = null
## Visuals-only helpers (Chatter, Flair, Life), never created when headless.
var chatter_node: Node = null
var flair: Node = null
var life: Node = null
var terrain: Object = null          # the TrackBuilder, for ground heights off the road
var road_material: ShaderMaterial = null
var config: Dictionary = {}
var finish_order: Array[Rider] = []
var results: Array = []
var stats := {}
var violations: Array[String] = []
var world: Node3D = null
var aim_screen := Vector2(0.5, 0.4)  # where the player's sight is, as a fraction of the screen
var aim_held := false                # a test is moving the sight itself

var _began := false
var _end_timer := -1.0
var _last_count := 99
var _barge_cd: Dictionary = {}
var _was_drawing: Dictionary = {}
var _was_mud: Dictionary = {}
var _was_quiet := false
var _proj_nodes: Node3D = null
var _stuck: Array[Dictionary] = []


func _ready() -> void:
	if auto_begin and not _began and is_inside_tree() and get_tree().current_scene == self:
		begin(Game.race_config())


func _physics_process(delta: float) -> void:
	if paused_for_ui or not _began:
		return
	step(delta)


func _process(delta: float) -> void:
	if headless or not _began:
		return
	for r: Rider in visuals:
		var v: Node3D = visuals[r]
		v.call("sync", delta)
	if hazards != null:
		hazards.update_visuals()
	if roadside != null:
		roadside.update_visuals(delta)
	_update_projectile_visuals(delta)
	var ctrl: Variant = controllers.get(player)
	if ctrl is PlayerControl and not paused_for_ui:
		(ctrl as PlayerControl).move_sight(delta)
	if not ended:
		var pr := player
		if pr != null:
			Sfx.set_gallop(clampf(pr.speed / maxf(float(pr.horse["speed"]), 1.0), 0.0, 1.0) if pr.is_riding() else 0.0)
			var crowd := 0.65 if int(config.get("course_index", 0)) >= 3 else 0.2
			Sfx.set_ambience(clampf(pr.speed / 30.0 + pr.draft * 0.3, 0.0, 1.0), crowd)


# ---------------------------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------------------------

func begin(cfg: Dictionary) -> void:
	_teardown()
	config = cfg
	season = int(cfg.get("season", 0))
	grudges = cfg.get("grudges", {})
	if cfg.has("seed"):
		rng.seed = int(cfg["seed"])
	else:
		rng.randomize()
	if cfg.has("course_override"):
		course = cfg["course_override"]
	else:
		course = _get_course(int(cfg.get("course_index", 0)), season)
	track = Track.new()
	track.build(course["segments"], float(course["half_width"]))
	hazards = Hazards.new()
	hazards.setup(track, course.get("events", []), season, rng)
	hazards.happened.connect(_on_hazard)
	finish_s = minf(hazards.finish_s, track.length - 40.0)
	hazards.finish_s = finish_s
	stats = {
		"damage": {"body": 0.0, "melee": 0.0, "ranged": 0.0}, "impact": {"body": 0.0, "melee": 0.0, "ranged": 0.0},
		"hits": {"body": 0, "melee": 0, "ranged": 0},
		"blocked": 0, "parried": 0, "crash": {"impact": 0, "health": 0, "hazard": 0},
		"crash_by_klass": {}, "thrown": {}, "kinds": {}, "max_ranged_shake": 0.0, "swings": 0, "shots": 0, "snatched": 0, "dropped": 0,
	}
	_build_riders(cfg)
	countdown = COUNTDOWN_HEADLESS if headless else COUNTDOWN_SHOWN
	_last_count = 99
	race_time = 0.0
	started = false
	ended = false
	_end_timer = -1.0
	roadside = Roadside.new()
	roadside.setup(self, course.get("events", []))
	if not headless:
		_build_visuals()
	roadside.settle()
	_began = true
	if not headless and is_inside_tree():
		announcement.emit("READY", "info")


func _apply_pause(on: bool) -> void:
	var mode := Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
	for r: Rider in visuals:
		(visuals[r] as Node).process_mode = mode
	if fx != null:
		fx.process_mode = mode
	for helper: Node in [chatter_node, flair, life]:
		if helper != null:
			helper.process_mode = mode
	if cam_rig != null:
		if on:
			cam_rig.call("reset_time")
		cam_rig.process_mode = mode


func _exit_tree() -> void:
	_clear_refs()


func _clear_refs() -> void:
	for r in riders:
		r.last_hitter = null
		r.target_lock = null
		r.draft_from = null
		r.shoved = null


func _teardown() -> void:
	_clear_refs()
	for c in get_children():
		c.queue_free()
	riders.clear()
	visuals.clear()
	controllers.clear()
	projectiles.clear()
	finish_order.clear()
	results.clear()
	violations.clear()
	fx = null
	cam_rig = null
	hud = null
	chatter_node = null
	flair = null
	life = null
	terrain = null
	road_material = null
	world = null
	_barge_cd.clear()
	_was_mud.clear()
	_stuck.clear()
	player = null


func _get_course(index: int, p_season: int) -> Dictionary:
	if ResourceLoader.exists("res://data/courses.gd"):
		var cs: GDScript = load("res://data/courses.gd")
		var d: Variant = cs.call("get_course", index, p_season)
		if typeof(d) == TYPE_DICTIONARY and not (d as Dictionary).is_empty():
			return d
	return fallback_course()


static func fallback_course() -> Dictionary:
	return {
		"id": "fallback", "name": "Test Road", "region": "Kham", "blurb": "A plain road for testing.",
		"segments": [[260, 0, 0], [220, 70, 8], [200, -30, 6], [300, -60, 22], [220, 45, 14], [260, 90, -12], [200, -50, 10], [320, -40, 30], [240, 0, 0]],
		"half_width": 11.0,
		"biome": {
			"seed": 7, "half_width": 11.0, "rugged": 16.0, "mountain": 180.0, "snow_line": 150.0, "far_snow_line": 380.0, "horizon": 620.0,
			"colors": {
				"grass_a": Color("7e9a41"), "grass_b": Color("8fa548"), "grass_c": Color("b6a94f"), "verge": Color("b6a94f"),
				"rock": Color("7d7a78"), "rock_dark": Color("544f52"), "snow": Color("f6fbff"), "snow_shade": Color("bfd2e8"),
			},
		},
		"env": {
			"sun_color": Color("fff0d0"), "sun_energy": 0.45, "sun_rot": Vector3(-48, -38, 0), "ambient": Color(0.74, 0.76, 0.95),
			"ambient_energy": 0.6, "sky_top": Color("7fb4d8"), "sky_horizon": Color("bfe0e8"), "fog_color": Color("bfe0e8"), "fog_density": 0.0006,
		},
		"events": [
			{"type": "start", "s": 14.0}, {"type": "finish", "s": 2130.0},
			{"type": "boulder", "s": 300.0, "d": -3.0}, {"type": "boulder", "s": 640.0, "d": 4.0}, {"type": "boulder", "s": 980.0, "d": -5.0},
			{"type": "boulder", "s": 1330.0, "d": 2.0}, {"type": "boulder", "s": 1710.0, "d": -2.0},
			{"type": "log", "s": 430.0, "d": 0.0, "w": 6.0}, {"type": "log", "s": 1160.0, "d": 3.0, "w": 5.0}, {"type": "log", "s": 1930.0, "d": -2.0, "w": 6.0},
			{"type": "mud", "s": 530.0, "d": -2.0}, {"type": "mud", "s": 1440.0, "d": 3.0},
			{"type": "ramp", "s": 800.0, "d": -3.0}, {"type": "ramp", "s": 1620.0, "d": 3.0},
			{"type": "mani_wall", "s": 350.0, "d": 8.0}, {"type": "mani_wall", "s": 900.0, "d": -8.0}, {"type": "mani_wall", "s": 1490.0, "d": 8.0},
			{"type": "chorten", "s": 710.0, "d": 9.0}, {"type": "chorten", "s": 1270.0, "d": -9.0}, {"type": "chorten", "s": 1980.0, "d": 9.0},
			{"type": "yak_herd", "s": 1060.0, "d": 0.0}, {"type": "sheep", "s": 590.0, "d": 2.0}, {"type": "sheep", "s": 1790.0, "d": -1.0},
			{"type": "caravan", "s": 320.0, "d": 7.0}, {"type": "caravan", "s": 1380.0, "d": -6.0},
			{"type": "scarf", "s": 470.0, "d": -2.0}, {"type": "scarf", "s": 860.0, "d": 3.0}, {"type": "scarf", "s": 1110.0, "d": -4.0},
			{"type": "target_pole", "s": 1570.0, "d": 5.0}, {"type": "target_pole", "s": 1610.0, "d": -5.0}, {"type": "target_pole", "s": 1650.0, "d": 5.0},
			{"type": "pass", "s": 1300.0},
			{"type": "quiet_zone", "s0": 1830.0, "s1": 1900.0},
		],
	}


func _pick_rivals(cfg: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var explicit: Array = cfg.get("rivals", [])
	for id: String in explicit:
		if GameData.RIVALS.has(id) and out.size() < 7:
			out.append(id)
	var featured: String = str(cfg.get("featured_rival", ""))
	if featured != "" and GameData.RIVALS.has(featured) and not out.has(featured):
		var fseasons: Array = GameData.RIVALS[featured]["seasons"]
		if fseasons.has(season):
			out.append(featured)
	if out.size() >= 7:
		return out
	var pool := GameData.rival_ids_for_season(season)
	if season == 2 and pool.has("wangyal") and not out.has("wangyal"):
		out.append("wangyal")
	for id: String in pool:
		if grudges.has(id) and out.size() < 7 and not out.has(id):
			out.append(id)
	var rest: Array[String] = []
	for id: String in pool:
		if not out.has(id):
			rest.append(id)
	# shuffle with the race rng
	for i in range(rest.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := rest[i]
		rest[i] = rest[j]
		rest[j] = t
	for id: String in rest:
		if out.size() < 7:
			out.append(id)
	return out


func _build_riders(cfg: Dictionary) -> void:
	var rival_ids := _pick_rivals(cfg)
	var player_id: String = cfg.get("player_id", "joru")
	var pdata: Dictionary = GameData.PLAYERS.get(player_id, GameData.PLAYERS["joru"])
	var popts := {
		"id": player_id, "is_player": true, "horse_id": cfg.get("horse_id", "old_tsampa"),
		"weapon_id": cfg.get("weapon_id", "fists"), "ranged_id": cfg.get("ranged_id", ""),
		"has_shield": cfg.get("has_shield", false), "saddle_level": cfg.get("saddle_level", 0), "armor_level": cfg.get("armor_level", 0),
	}
	# the player starts on the back row so the chase camera sees the whole pack and nobody blocks it
	var player_slot := rng.randi_range(6, 7)
	var rival_i := 0
	for slot in 8:
		var r := Rider.new()
		r.slot = slot
		if slot == player_slot:
			r.setup(pdata, popts, rng)
			r.is_player = true
			player = r
		else:
			var rid := rival_ids[rival_i % rival_ids.size()]
			rival_i += 1
			r.setup(GameData.RIVALS[rid], {"id": rid, "is_player": false}, rng)
		r.finish_s = finish_s
		var row := slot / 2
		var col := slot % 2
		var gs := hazards.start_s - float(row) * 3.8 - (1.4 if col == 1 else 0.0)
		var gd := (-1.9 if col == 0 else 1.9) * (1.0 if track.half_width_at(gs) > 5.0 else 0.5)
		r.place_on_grid(maxf(gs, 1.0), gd)
		r.place = slot + 1
		r.crashed.connect(_on_crashed)
		r.remounted.connect(_on_remounted)
		r.swing_started.connect(_on_swing_started)
		r.second_wind_started.connect(_on_second_wind)
		r.launched.connect(_on_launched)
		r.landed.connect(_on_landed)
		riders.append(r)
		if r.is_player and not player_ai:
			controllers[r] = PlayerControl.new(r, self)
		else:
			controllers[r] = RiderAI.new(r, self, rng)
	_update_places()


# ---------------------------------------------------------------------------------------------
# Visual setup
# ---------------------------------------------------------------------------------------------

func _script_has(script: GDScript, method: String) -> bool:
	for m in script.get_script_method_list():
		if m["name"] == method:
			return true
	return false


func _build_visuals() -> void:
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	var env: Dictionary = course.get("env", {})
	var made := false
	var ak: GDScript = load("res://scripts/core/art_kit.gd")
	if _script_has(ak, "make_world"):
		ak.call("make_world", world, env)
		made = true
	if not made:
		_fallback_environment(env)
	var ground := ShaderMaterial.new()
	ground.shader = load("res://shaders/ground.gdshader")
	var road := ShaderMaterial.new()
	road.shader = load("res://shaders/road.gdshader")
	road.set_shader_parameter("tile", _road_tile(int(config.get("course_index", 0))))
	road_material = road
	var tb_script: GDScript = load("res://scripts/race/track_builder.gd")
	if tb_script != null and tb_script.can_instantiate():
		var builder: Object = tb_script.new(track, course["biome"])
		builder.call("build_into", world, ground, road)
		terrain = builder
	if ResourceLoader.exists("res://scripts/race/track_dressing.gd"):
		var td_script: GDScript = load("res://scripts/race/track_dressing.gd")
		if td_script != null and td_script.can_instantiate():
			var td: Object = td_script.new(track, course, rng)
			td.call("build_into", world)
	hazards.build_visuals(world)
	roadside.build_visuals(world)
	_proj_nodes = Node3D.new()
	_proj_nodes.name = "Projectiles"
	add_child(_proj_nodes)
	var vs: GDScript = load("res://scripts/race/rider_visual.gd")
	for r in riders:
		var v: Node3D = vs.new()
		v.name = "Visual_%d" % r.slot
		add_child(v)
		v.call("setup", r, track, self)
		visuals[r] = v
	fx = load("res://scripts/race/fx.gd").new()
	fx.name = "Fx"
	add_child(fx)
	fx.call("bind", self)
	cam_rig = load("res://scripts/race/camera_rig.gd").new()
	cam_rig.name = "CameraRig"
	add_child(cam_rig)
	cam_rig.call("bind", self)
	if ResourceLoader.exists("res://scripts/ui/hud.gd"):
		var hud_script: GDScript = load("res://scripts/ui/hud.gd")
		hud = hud_script.new()
		hud.name = "HUD"
		add_child(hud)
		hud.call("bind", self)
	chatter_node = _make_helper("res://scripts/race/chatter.gd", "Chatter")
	flair = _make_helper("res://scripts/race/flair.gd", "Flair")
	life = _make_helper("res://scripts/race/life.gd", "Life")


## One of the visuals-only helpers (Chatter, Flair, Life): loaded by path so a broken file can't stop the race.
func _make_helper(path: String, node_name: String) -> Node:
	if not ResourceLoader.exists(path):
		return null
	var script: GDScript = load(path)
	if script == null or not script.can_instantiate():
		return null
	var n: Node = script.new()
	n.name = node_name
	add_child(n)
	n.call("bind", self)
	return n


func _road_tile(index: int) -> Texture2D:
	var path := "res://assets/atlas/road_%d.png" % index
	if ResourceLoader.exists(path):
		return load(path)
	for name in ["road_0", "road_1"]:
		var p2 := "res://assets/atlas/%s.png" % name
		if ResourceLoader.exists(p2):
			return load(p2)
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	img.fill(Color("d8be8e"))
	var lr := RandomNumberGenerator.new()
	lr.seed = 3
	for i in 60:
		img.set_pixel(lr.randi() % 16, lr.randi() % 16, Color("b98d5a"))
	return ImageTexture.create_from_image(img)


func _fallback_environment(env: Dictionary) -> void:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = env.get("sky_horizon", Color("bfe0e8"))
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = env.get("ambient", Color(0.74, 0.76, 0.95))
	e.ambient_light_energy = env.get("ambient_energy", 0.6)
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.fog_enabled = true
	e.fog_light_color = env.get("fog_color", Color("bfe0e8"))
	e.fog_density = env.get("fog_density", 0.0006)
	e.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = e
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = env.get("sun_rot", Vector3(-48, -38, 0))
	sun.light_color = env.get("sun_color", Color.WHITE)
	sun.light_energy = env.get("sun_energy", 0.45) * 2.4
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	world.add_child(sun)
	world.add_child(ArtKit.ink_pass())


# ---------------------------------------------------------------------------------------------
# Tick
# ---------------------------------------------------------------------------------------------

func step(dt: float) -> void:
	if not _began or ended:
		return
	if countdown > 0.0:
		var prev := countdown
		countdown -= dt
		_countdown_events(prev)
		if countdown > 0.0:
			return
		countdown = 0.0
		started = true
		Sfx.play("horn")
		Sfx.play("go")
		announcement.emit("GO!", "big")
		race_started.emit()
	race_time += dt
	var prev_s: Dictionary = {}
	for r in riders:
		var ctrl: Object = controllers[r]
		var intent: Rider.Intent = ctrl.call("think", dt)
		prev_s[r] = r.s
		r.simulate(dt, intent, track)
	hazards.update(dt, riders)
	roadside.update(dt)
	for r in riders:
		hazards.check_rider(r, prev_s[r])
	_update_draft(dt)
	if player != null:
		if player.in_quiet and not _was_quiet:
			announcement.emit("QUIET GROUND", "info")
			rider_event.emit("quiet_enter", player, {})
		_was_quiet = player.in_quiet
	if not headless:
		for r in riders:
			if r.mud and not _was_mud.get(r, false):
				rider_event.emit("mud", r, {})
				if r.is_player or absf(r.s - player.s) < 25.0:
					Sfx.play_at("splash", visual_pos(r), 0.0 if r.is_player else -6.0)
			_was_mud[r] = r.mud
	_combat_step(dt)
	_spread_finished(dt)
	_check_finish()
	_update_places()
	_watch_shake()
	if _end_timer >= 0.0:
		_end_timer -= dt
		if _end_timer <= 0.0:
			_end_race()
	elif race_time > MAX_RACE_TIME:
		_end_race()


func _countdown_events(prev: float) -> void:
	var n := int(ceil(countdown))
	if countdown > 0.0 and n < _last_count and n <= 3:
		_last_count = n
		Sfx.play("drum_hit", 0.0, 1.0 - 0.08 * float(3 - n))
		announcement.emit(str(n), "big")
		if not headless:
			rider_event.emit("count", null, {"n": n})
	elif countdown <= 0.0 and prev > 0.0:
		pass


## Riders who have crossed the line drift apart, so nobody ends up standing inside a rival (the finish camera circles them).
## Finished riders take no part in anything else, so this changes no result.
func _spread_finished(dt: float) -> void:
	for i in finish_order.size():
		var a := finish_order[i]
		for j in range(i + 1, finish_order.size()):
			var b := finish_order[j]
			var gap := b.d - a.d
			if absf(a.s - b.s) < 2.8 and absf(gap) < 1.5:
				var dir := signf(gap) if absf(gap) > 0.02 else (1.0 if a.slot < b.slot else -1.0)
				var push := (1.5 - absf(gap)) * 3.0 * dt
				a.d -= dir * push * 0.5
				b.d += dir * push * 0.5


## The wind trail. A horse at speed leaves stiller air behind it, and whoever rides in that air has less to push through,
## which is how a rider who has fallen back gets back in touch. The trail is strongest close behind, fades out over
## DRAFT_RANGE metres, and spreads a little as it thins. A slow horse leaves less of one.
func _update_draft(dt: float) -> void:
	for r in riders:
		var want := 0.0
		var from: Rider = null
		if r.is_riding() and r.speed > 8.0:
			for o in riders:
				if o == r or not o.is_riding() or o.speed < 8.0:
					continue
				var ds := o.s - r.s
				if ds < 1.5 or ds > DRAFT_RANGE:
					continue
				var far := ds / DRAFT_RANGE
				var width := lerpf(DRAFT_WIDTH_NEAR, DRAFT_WIDTH_FAR, far)
				var strength := pow(1.0 - far, 0.8) * (1.0 - smoothstep(width * 0.6, width, absf(o.d - r.d))) * clampf(o.speed / 16.0, 0.0, 1.0)
				if strength > want:
					want = strength
					from = o
		r.draft = lerpf(r.draft, want, 1.0 - exp(-dt / 0.35))
		r.draft_from = from


func _watch_shake() -> void:
	var r := player
	if r != null and r.is_riding():
		if r.shake >= Rider.TEETER_AT and not r.teetering_announced:
			r.teetering_announced = true
			announcement.emit("TEETERING", "bad")
			rider_event.emit("teetering", r, {})


# ---------------------------------------------------------------------------------------------
# Queries used by the AI
# ---------------------------------------------------------------------------------------------

func nearest_rival(r: Rider, max_dist: float) -> Rider:
	var best: Rider = null
	var best_d := max_dist
	for o in riders:
		if o == r or not o.is_riding():
			continue
		var dist := Vector2(o.s - r.s, (o.d - r.d) * 1.5).length()
		if dist < best_d:
			best_d = dist
			best = o
	return best


func leader_s() -> float:
	var best := 0.0
	for r in riders:
		best = maxf(best, r.s)
	return best


func second_s() -> float:
	var a := 0.0
	var b := 0.0
	for r in riders:
		if r.s > a:
			b = a
			a = r.s
		elif r.s > b:
			b = r.s
	return b


func find_lock(r: Rider) -> Rider:
	if r.ranged_id == "":
		return null
	var w: Dictionary = GameData.WEAPONS[r.ranged_id]
	var rng_m: float = w["reach"]
	var best: Rider = null
	var best_ds := 1.0e9
	for o in riders:
		if o == r or not o.is_riding():
			continue
		var ds := o.s - r.s
		if ds < 1.5 or ds > rng_m:
			continue
		var dd := absf(o.d - r.d)
		if dd > ds * 0.45 + 1.4:
			continue
		if ds < best_ds:
			best_ds = ds
			best = o
	return best


func standings() -> Array[Rider]:
	var order: Array[Rider] = riders.duplicate()
	order.sort_custom(func(a: Rider, b: Rider) -> bool:
		if a.finished != b.finished:
			return a.finished
		if a.finished:
			return a.finish_time < b.finish_time
		return a.s > b.s)
	return order


func _update_places() -> void:
	var order := standings()
	for i in order.size():
		order[i].place = i + 1


# ---------------------------------------------------------------------------------------------
# Combat
# ---------------------------------------------------------------------------------------------

func _combat_step(dt: float) -> void:
	for r in riders:
		if r.fire_pending:
			_fire(r)
		if r.swing_t >= 0.0 and r.swing_active() and not r.swing_done:
			_resolve_swing(r)
		if r.drawing:
			r.target_lock = null if controllers[r] is PlayerControl else find_lock(r)
			if not _was_drawing.get(r, false) and not headless:
				Sfx.play_at("bow_draw" if r.ranged_id == "bow" else "whoosh", visual_pos(r), 0.0 if r.is_player else -6.0)
			_was_drawing[r] = true
		else:
			r.target_lock = null
			_was_drawing[r] = false
		if r.blocking:
			var near := nearest_rival(r, 10.0)
			if near != null:
				r.shield_side = 1 if near.d > r.d else -1
	_step_projectiles(dt)
	_contacts(dt)
	for k: int in _barge_cd.keys():
		_barge_cd[k] = float(_barge_cd[k]) - dt
		if float(_barge_cd[k]) <= 0.0:
			_barge_cd.erase(k)


func _resolve_swing(r: Rider) -> void:
	var kind := r.swing_kind
	var wid := r.swing_weapon
	var w: Dictionary = GameData.WEAPONS[wid]
	var reach: float = w["reach"]
	var best: Rider = null
	var best_dist := 1.0e9
	var best_dx := 0.0
	for o in riders:
		if o == r or not o.is_riding():
			continue
		var dx := o.d - r.d
		var ds := o.s - r.s
		if kind == "melee":
			if dx * float(r.swing_side) < 0.2:
				continue
		elif absf(dx) < 0.2:
			continue
		var dist := sqrt(dx * dx + ds * ds)
		if dist > reach + 0.5 or absf(ds) > reach:
			continue
		if dist < best_dist:
			best_dist = dist
			best = o
			best_dx = dx
	# stewards can be struck too (and will hold a grudge on the fine)
	if best == null:
		for st in hazards.stewards:
			var sdx: float = float(st["d"]) - r.d
			var sds: float = float(st["s"]) - r.s
			if sdx * float(r.swing_side if kind == "melee" else signf(sdx)) > 0.2 and sqrt(sdx * sdx + sds * sds) < reach + 0.5 and float(st["stagger"]) <= 0.0:
				st["stagger"] = 3.0
				r.steward_hits += 1
				rider_event.emit("steward_hit", r, {})
				r.swing_done = true
				return
		# no one in reach: what's beside the road can be struck too, and a sheep in it
		var side := r.swing_side if kind == "melee" else 0
		if roadside.struck(r, reach, side):
			r.swing_done = true
		elif hazards.sheep_struck(r.s + minf(reach, 1.5), r.d + float(side) * reach * 0.6, reach):
			roadside.fine_for_sheep(r, visual_pos(r))
			r.swing_done = true
		return
	r.swing_done = true
	var damage: float = w["damage"]
	var impact: float = w["impact"]
	if wid == "key" and best_dist < 1.5:
		damage *= 0.5
	if wid == "spear":
		if best_dist < SPEAR_CLOSE:
			damage *= SPEAR_CLOSE_DAMAGE
		if r.speed >= 0.9 * float(r.horse["speed"]):
			impact *= 1.25
	var slam := _slamming(r, best)
	if slam:
		damage *= SLAM_DAMAGE
		stats["slam_strikes"] = int(stats.get("slam_strikes", 0)) + 1
	var victim_side := -1 if best_dx > 0.0 else 1   # side of the victim the attacker stands on
	var klass: String = w["klass"]
	var mid_swing := best.swing_t >= 0.0
	var info := apply_hit(r, best, damage, impact, klass, wid, victim_side, slam)
	if kind == "kick" and not info.get("parried", false):
		var shove := signf(best_dx) * KICK_PUSH * clampf(r.bulk / maxf(best.bulk, 0.5), 0.75, 1.3) * (0.5 if info.get("blocked", false) else 1.0)
		best.slide += shove
		r.slide -= shove * 0.12    # kicking off someone pushes you back a little too
		best.speed = maxf(0.0, best.speed - 1.0)
	if mid_swing and not info.get("crashed", false) and best.weapon_id != "fists" and not info.get("blocked", false) and rng.randf() < 0.35:
		_take_or_drop(r, best)


## Whether this rider comes at the other with this much sideways speed and this much more sideways momentum than they have,
## whichever way they're going: meeting someone coming just as hard, or chasing someone going just as fast, is neither.
func _has_edge(r: Rider, other: Rider, speed: float, edge: float) -> bool:
	var toward := r.side_speed() * signf(other.d - r.d)
	return toward >= speed and r.bulk * toward - other.bulk * absf(other.side_speed()) >= edge


## A strike lands harder only with a hard run at someone holding their line, or straight after slamming them that hard.
func _slamming(r: Rider, target: Rider) -> bool:
	return (r.shoved == target and r.shoved_t > 0.0) or _has_edge(r, target, STRIKE_SPEED, STRIKE_EDGE)


func apply_hit(attacker: Rider, victim: Rider, damage: float, impact: float, klass: String, kind: String, side: int, slam := false) -> Dictionary:
	var info := {"damage": damage, "impact": impact, "klass": klass, "blocked": false, "parried": false, "side": side, "kind": kind, "crashed": false, "slam": slam}
	if not victim.is_riding() or victim.invuln_t > 0.0:
		info["ignored"] = true
		return info
	if victim.blocking:
		var faces := klass == "ranged" or side == victim.shield_side
		if faces:
			if klass != "ranged" and victim.block_time <= 0.2:
				info["parried"] = true
				info["damage"] = 0.0
				info["impact"] = 0.0
				stats["parried"] = int(stats["parried"]) + 1
				victim.add_lungta(0.8)
				attacker.receive_hit(victim, 0.0, 25.0, "body", -side)
				rider_hit.emit(attacker, victim, info)
				rider_event.emit("parry", victim, {"attacker": attacker})
				if not headless:
					Sfx.play_at("clang", visual_pos(victim), 0.0, 1.15)
				return info
			info["blocked"] = true
			info["damage"] = damage * 0.25
			info["impact"] = impact * 0.35
			stats["blocked"] = int(stats["blocked"]) + 1
	var imp: float = info["impact"]
	imp *= (1.0 - victim.saddle_cut) / (0.6 + 0.4 * victim.bulk)
	var dmg: float = info["damage"]
	info["impact"] = imp
	var res := victim.receive_hit(attacker, dmg, imp, klass, side)
	if klass != "ranged" and kind != "fists" and not info["blocked"]:
		victim.lateral += -float(side) * imp * 0.07
	if slam and attacker.is_player and not res["ignored"]:
		announcement.emit("SLAM!  x%.1f" % SLAM_DAMAGE, "good")
	info["crashed"] = res["crashed"]
	info["crash_reason"] = res["reason"]
	attacker.hits_landed += 1
	attacker.damage_dealt += dmg
	var kk := klass
	stats["damage"][kk] = float(stats["damage"][kk]) + dmg
	stats["impact"][kk] = float(stats["impact"][kk]) + imp
	stats["hits"][kk] = int(stats["hits"][kk]) + 1
	stats["kinds"][kind] = int(stats["kinds"].get(kind, 0)) + 1
	if klass == "ranged":
		var sh_after: float = res["shake_after"]
		var sh_before: float = res["shake_before"]
		stats["max_ranged_shake"] = maxf(float(stats["max_ranged_shake"]), minf(sh_after, 1000.0) if sh_after > sh_before else 0.0)
		if sh_after > maxf(sh_before, Rider.RANGED_SHAKE_CAP) + 0.001:
			violations.append("ranged hit raised shake above cap: %.1f -> %.1f" % [sh_before, sh_after])
		if res["crashed"] and res["reason"] == "impact":
			violations.append("ranged hit unseated on impact")
	rider_hit.emit(attacker, victim, info)
	if not headless:
		_hit_sound(victim, info, kind)
	return info


func _hit_sound(victim: Rider, info: Dictionary, kind: String) -> void:
	var snd := "hit_light"
	var imp: float = info.get("impact", 0.0)
	if info.get("blocked", false):
		snd = "clang"
	elif kind == "whip":
		snd = "whip"
	elif imp >= 18.0:
		snd = "hit_heavy"
	var loud := 0.0 if (victim.is_player or player != null and absf(victim.s - player.s) < 20.0) else -8.0
	Sfx.play_at(snd, visual_pos(victim), loud, rng.randf_range(0.94, 1.08))


func _take_or_drop(attacker: Rider, victim: Rider) -> void:
	var wid := victim.weapon_id
	if wid == "fists":
		return
	victim.weapon_id = "fists"
	if attacker.is_riding() or attacker.state == "ride":
		if GameData.weapon_value(wid) > GameData.weapon_value(attacker.weapon_id) and GameData.WEAPONS[wid]["klass"] == "melee":
			attacker.weapon_id = wid
			stats["snatched"] = int(stats["snatched"]) + 1
			rider_event.emit("snatch", attacker, {"weapon": wid, "from": victim})
			if attacker.is_player:
				announcement.emit("GOT THE %s" % String(GameData.WEAPONS[wid]["name"]).to_upper(), "good")
			return
	hazards.drop_weapon(wid, victim.s + 1.5, victim.d)
	stats["dropped"] = int(stats["dropped"]) + 1
	rider_event.emit("drop", victim, {"weapon": wid})


func _fire(r: Rider) -> void:
	r.fire_pending = false
	var w: Dictionary = GameData.WEAPONS[r.ranged_id]
	var p := Projectile.new()
	p.shooter = r
	p.weapon_id = r.ranged_id
	p.kind = "arrow" if r.ranged_id == "bow" else ("stone" if r.ranged_id == "sling" else "spear")
	var hand := shot_point(r)
	var own := r.world_velocity(track)
	# a half-drawn bow or a half-swung sling throws slower, and so falls shorter
	var muzzle := launch_speed(r.ranged_id, r.fire_power)
	var dir := r.aim_dir
	if dir == Vector3.ZERO:
		dir = _rival_aim(r, hand, own, muzzle, float(w["reach"]))
	p.launch(track, hand, r.s, dir * muzzle + own)
	p.power = r.fire_power
	var boost := 1.0 + 0.3 * r.fire_power if r.ranged_id == "bow" else 1.0
	p.damage = float(w["damage"]) * boost
	p.impact = float(w["impact"]) * boost
	p.max_out = float(w["reach"])
	if r.ranged_id == "roped_spear":
		r.rope_out = true
	projectiles.append(p)
	stats["shots"] = int(stats["shots"]) + 1
	if hazards.in_quiet(r.s):
		_quiet_penalty(r)
	if not headless:
		_make_projectile_visual(p)
		var snd: String = {"bow": "bow_loose", "sling": "sling", "roped_spear": "rope"}[r.ranged_id]
		Sfx.play_at(snd, visual_pos(r), -2.0 if not r.is_player else 0.0)


static func launch_speed(weapon: String, power: float) -> float:
	return float(GameData.WEAPONS[weapon]["speed"]) * (0.55 + 0.45 * power)


## The launch direction that lands a shot on something moving along the road, now at (ts, td, th) with speeds vs and vd in
## track space, allowing for the shooter's own velocity and for the drop. How long the shot flies depends on where it goes
## and where it goes depends on how long it flies, so this goes round a few times. Air drag is small enough to leave out.
func aim_for(from: Vector3, own: Vector3, muzzle: float, ts: float, td: float, th: float, vs: float, vd: float) -> Vector3:
	var t := from.distance_to(track.point(ts, td, th)) / muzzle
	var aim := Vector3.FORWARD
	for i in 4:
		aim = track.point(ts + vs * t, td + vd * t, th) - from - own * t + Vector3.UP * (0.5 * Projectile.GRAVITY * t * t)
		t = aim.length() / muzzle
	return aim.normalized()


## How a rival aims: it reads the same physics, then misses by however much its skill allows.
func _rival_aim(r: Rider, hand: Vector3, own: Vector3, muzzle: float, reach: float) -> Vector3:
	var dir := track.tangent_at(r.s)
	var dist_m := 20.0
	var tgt := r.target_lock
	if tgt != null and tgt.is_riding():
		dir = aim_for(hand, own, muzzle, tgt.s, tgt.d, 1.9 + tgt.height, tgt.speed, tgt.lateral)
		dist_m = Vector2(tgt.s - r.s, tgt.d - r.d).length()
	else:
		var pole := _pole_in_view(r, reach)
		if not pole.is_empty():
			dir = aim_for(hand, own, muzzle, float(pole["s"]), float(pole["d"]), 2.3, 0.0, 0.0)
	var err_deg := 2.5 + (1.0 - r.skill) * 8.0 + dist_m * 0.08
	if r.is_player:
		err_deg = 0.6 + dist_m * 0.02
	dir = dir.rotated(Vector3.UP, deg_to_rad(rng.randfn(0.0, err_deg)))
	return dir.rotated(dir.cross(Vector3.UP).normalized(), deg_to_rad(rng.randfn(0.0, err_deg * 0.3)))


## Where a rider's shots leave from: the weapon in their hand, where there's a model to ask.
func shot_point(r: Rider) -> Vector3:
	var v: Variant = visuals.get(r)
	if v != null:
		return (v as Node3D).call("shot_point")
	return r.hand_point(track)


## The player's sight is a line from the camera through the point aim_screen on the screen. A shot leaves from the weapon in
## the rider's hand, which is off to one side of that line, and is aimed to cross the line at the point where the shot will
## come down: the first thing it would meet if it fell away from the line as it flew. So it lands where the sight and the
## drop say it should, from wherever the bow really is.
func update_sight(r: Rider) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		r.aim_dir = Vector3.ZERO
		return
	var rect := get_viewport().get_visible_rect().size
	var ndc := aim_screen * 2.0 - Vector2.ONE
	var tan_v := tan(deg_to_rad(cam.fov * 0.5))
	var ray := (cam.global_basis * Vector3(ndc.x * tan_v * rect.x / rect.y, -ndc.y * tan_v, -1.0)).normalized()
	var from := cam.global_position
	var hand := shot_point(r)
	var muzzle := launch_speed(r.ranged_id, maxf(r.draw_amount, 0.25))
	var own := r.world_velocity(track)
	var start := (hand - from).dot(ray)
	var t := maxf(start, 1.0) + 4.0
	var s_at := r.s
	while t < SIGHT_RANGE:
		# where the shot would be after flying this far: it falls away from the sight, and it carries the horse's speed too
		var fly := (t - start) / muzzle
		var q := from + ray * t + own * fly + Vector3.DOWN * 0.5 * Projectile.GRAVITY * fly * fly
		s_at = clampf(s_at + (q - track.point(s_at)).dot(track.tangent_at(s_at)), 0.0, track.length)
		if q.y <= track.point(s_at).y or _shot_meets(r, q, fly):
			break
		t += 1.5
	r.aim_dir = (from + ray * t - hand).normalized()


## Whether a shot at this point, after flying this long, would be meeting something it could hit.
func _shot_meets(r: Rider, q: Vector3, fly: float) -> bool:
	for o in riders:
		if o != r and o.is_riding():
			var base := track.point(o.s + o.speed * fly, o.d + o.lateral * fly, o.height)
			var up := q.y - base.y
			if Vector2(base.x - q.x, base.z - q.z).length() < 1.2 and up > 0.0 and up < RIDER_HIGH + 0.3:
				return true
	return roadside.near_target(q, fly)


## The nearest target pole ahead that this rider has not hit yet, for aiming when no rival is in the cone.
func _pole_in_view(r: Rider, range_m: float) -> Dictionary:
	var best: Dictionary = {}
	var best_ds := 1.0e9
	for pole in hazards.poles:
		var key := "pole_%d" % int(pole["id"])
		if r.scarf_taken.has(key):
			continue
		var ds := float(pole["s"]) - r.s
		if ds < 5.0 or ds > range_m * 0.8:
			continue
		if absf(float(pole["d"]) - r.d) > ds * 1.2 + 3.0:
			continue
		if ds < best_ds:
			best_ds = ds
			best = pole
	return best


func _step_projectiles(dt: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var p := projectiles[i]
		p.step(dt)
		if p.alive and not p.returning:
			var stopped := hazards.pole_shot(p.shooter, p.s, p.d, p.h)
			for o in riders:
				if o == p.shooter or not o.is_riding():
					continue
				var hit_h := _height_hit(p, o)
				if hit_h < 0.0:
					continue
				var side := 1 if p.shooter.d > o.d else -1
				var info := apply_hit(p.shooter, o, p.damage, p.impact, "ranged", p.weapon_id, side)
				if hit_h > RIDER_HEAD and not info.get("blocked", false) and not info.get("ignored", false):
					rider_event.emit("head_shot", o, {"by": p.shooter})
				p.hit_any = true
				stopped = true
				break
			if not stopped:
				match roadside.shot(p):
					Roadside.Struck.BOARD:
						if p.kind == "arrow":
							_land(p)     # it stays in the board
						stopped = true
					Roadside.Struck.BEAST:
						stopped = true
			if not stopped and hazards.sheep_struck(p.s, p.d, 0.8, p.h):
				roadside.fine_for_sheep(p.shooter, p.pos)
				stopped = true
			if stopped:
				if p.kind == "spear":
					p.returning = true
				else:
					p.alive = false
			elif p.kind != "spear" and p.pos.y <= _ground_under(p):
				_land(p)
		if not p.alive:
			if p.kind == "spear":
				p.shooter.rope_out = false
			_retire_projectile_visual(p)
			projectiles.remove_at(i)


## How high above the ground this tick's flight crosses a rider, or -1 if it misses. The shot's path is a straight line over
## one tick, tested against an upright cylinder around the rider.
func _height_hit(p: Projectile, o: Rider) -> float:
	var base := track.point(o.s, o.d, o.height)
	var a := p.last_pos - base
	var b := p.pos - base
	var flat_a := Vector2(a.x, a.z)
	var flat_ab := Vector2(b.x - a.x, b.z - a.z)
	var t := clampf(-flat_a.dot(flat_ab) / maxf(flat_ab.length_squared(), 0.0001), 0.0, 1.0)
	if (flat_a + flat_ab * t).length() > RIDER_HIT_RADIUS:
		return -1.0
	var y := lerpf(a.y, b.y, t)
	return y if y >= RIDER_LOW and y <= RIDER_HIGH else -1.0


## The height of the ground under a shot. On and beside the road that's the road's height; further out, the land where it's known.
func _ground_under(p: Projectile) -> float:
	if terrain != null and absf(p.d) > track.half_width_at(p.s) + 4.0:
		return float(terrain.call("ground_y", p.pos.x, p.pos.z))
	return p.pos.y - p.h


## A shot that comes down without hitting anything: an arrow stays stuck where it landed for a while.
func _land(p: Projectile) -> void:
	p.alive = false
	if headless:
		return
	if fx != null and absf(p.s - player.s) < 70.0:
		fx.call("burst", p.pos, Vector3.UP, fx.get("dust_colour"), 0.35)
	if p.kind == "arrow" and p.node != null and is_instance_valid(p.node):
		p.node.look_at_from_position(p.pos, p.pos + p.vel.normalized(), Vector3.UP)
		_stuck.append({"node": p.node, "left": 6.0})
		p.node = null
		while _stuck.size() > MAX_STUCK:
			var old: Dictionary = _stuck.pop_front()
			if is_instance_valid(old["node"]):
				(old["node"] as Node).queue_free()


func _contacts(dt: float) -> void:
	var n := riders.size()
	for i in n:
		var a := riders[i]
		if not a.is_riding():
			continue
		for j in range(i + 1, n):
			var b := riders[j]
			if not b.is_riding():
				continue
			var ds := b.s - a.s
			if absf(ds) > 2.5:
				continue
			var dd := b.d - a.d
			if absf(dd) > 1.15:
				continue
			var overlap := 1.15 - absf(dd)
			var sgn := signf(dd) if absf(dd) > 0.03 else (1.0 if a.slot < b.slot else -1.0)
			var wa := b.bulk / (a.bulk + b.bulk)
			var wb := a.bulk / (a.bulk + b.bulk)
			a.d -= sgn * overlap * wa * 0.4
			b.d += sgn * overlap * wb * 0.4
			# nose to tail: the rider behind eases off instead of passing through
			if absf(dd) < 0.85 and absf(ds) < 2.4:
				if ds > 0.0:
					a.speed = minf(a.speed, maxf(b.speed - 0.3, 0.5))
				else:
					b.speed = minf(b.speed, maxf(a.speed - 0.3, 0.5))
			var key := a.slot * 16 + b.slot
			if _barge_cd.has(key):
				continue
			# only with a real edge in sideways momentum is it a slam: otherwise the horses just lean on each other
			var attacker: Rider = null
			var victim: Rider = null
			if _has_edge(a, b, SLAM_SPEED, SLAM_EDGE):
				attacker = a
				victim = b
			elif _has_edge(b, a, SLAM_SPEED, SLAM_EDGE):
				attacker = b
				victim = a
			if attacker == null:
				continue
			# only a really hard slam sets up the bigger hit that follows it
			if _has_edge(attacker, victim, STRIKE_SPEED, STRIKE_EDGE):
				attacker.shoved = victim
				attacker.shoved_t = SLAM_WINDOW
			var dir := signf(victim.d - attacker.d)
			var power := attacker.side_speed() * dir + maxf(-victim.side_speed() * dir, 0.0) * 0.5
			_barge_cd[key] = 1.6
			var k := clampf((power - 2.0) / 6.0, 0.35, 1.6)
			var ratio := clampf(attacker.bulk / maxf(victim.bulk, 0.5), 0.6, 1.7)
			var vside := -1 if victim.d > attacker.d else 1
			var bw: Dictionary = GameData.WEAPONS["barge"]
			apply_hit(attacker, victim, float(bw["damage"]) * k, float(bw["impact"]) * k * ratio, "body", "barge", vside)
			_carry_momentum(attacker, victim)
			victim.speed = maxf(0.0, victim.speed - 0.6 * k)


## Two horses slamming together side on go on together, the heavier one losing less of its speed, with a little spring apart.
## The rider who slammed keeps what's left of their sideways speed whatever they do with the reins, and the other rider is
## carried along with it.
func _carry_momentum(attacker: Rider, victim: Rider) -> void:
	var total := attacker.bulk + victim.bulk
	var va := attacker.side_speed()
	var vb := victim.side_speed()
	var together := (attacker.bulk * va + victim.bulk * vb) / total
	var apart := SLAM_BOUNCE * (va - vb) / total
	attacker.lateral = 0.0
	attacker.slide = together - apart * victim.bulk
	victim.slide += together + apart * attacker.bulk - vb


func _quiet_penalty(r: Rider) -> void:
	r.add_lungta(-0.5)
	var amount := GameData.fine(season) / 2
	r.fines += amount
	rider_event.emit("quiet_struck", r, {"fine": amount})
	if r.is_player:
		announcement.emit("QUIET GROUND  -%d" % amount, "bad")


# ---------------------------------------------------------------------------------------------
# Events
# ---------------------------------------------------------------------------------------------

func _on_swing_started(r: Rider, kind: String) -> void:
	stats["swings"] = int(stats["swings"]) + 1
	if kind == "kick":
		var near := nearest_rival(r, 6.0)
		if near != null:
			r.swing_side = 1 if near.d > r.d else -1
	if hazards.in_quiet(r.s):
		_quiet_penalty(r)
	if not headless:
		Sfx.play_at("whoosh", visual_pos(r), -4.0 if not r.is_player else -1.0, rng.randf_range(0.95, 1.1))


## A hat came off (Fx decides when, and calls this). Counts it for the player and tells Chatter, Flair and the HUD.
func note_hat(victim: Rider, by: Rider) -> void:
	if headless:
		return
	if by != null and by.is_player and by != victim:
		by.hats_knocked += 1
		by.silver_bonus += HAT_SILVER
	rider_event.emit("hat", victim, {"by": by})


func _on_crashed(r: Rider, reason: String) -> void:
	stats["crash"][reason] = int(stats["crash"][reason]) + 1
	if reason == "hazard":
		stats["thrown"][r.crash_what] = int(stats["thrown"].get(r.crash_what, 0)) + 1
	var key := "%s/%s" % [reason, r.last_hit_klass if r.last_hit_age < 4.0 else "none"]
	stats["crash_by_klass"][key] = int(stats["crash_by_klass"].get(key, 0)) + 1
	if reason == "impact" and r.last_hit_klass == "ranged" and r.last_hit_age < 0.05:
		violations.append("impact crash credited to ranged hit")
	var by := r.last_hitter
	if reason != "hazard" and by != null and r.last_hit_age < 4.0 and by != r:
		by.knockdowns += 1
		by.add_lungta(0.8)
		if r.weapon_id != "fists":
			if r.last_hit_klass == "ranged":
				var wid := r.weapon_id
				r.weapon_id = "fists"
				hazards.drop_weapon(wid, r.s + 1.5, r.d)
				stats["dropped"] = int(stats["dropped"]) + 1
			else:
				_take_or_drop(by, r)
		if by.is_player:
			announcement.emit("KNOCKDOWN  +%d" % GameData.bounty(season), "good")
	rider_crashed.emit(r, reason)
	rider_event.emit("crash", r, {"reason": reason, "by": by})
	if r.is_player:
		match reason:
			"impact":
				announcement.emit("UNSEATED!", "bad")
			"health":
				announcement.emit("DOWN!", "bad")
			_:
				announcement.emit("THROWN!", "bad")
	if not headless:
		Sfx.play_at("crash", visual_pos(r), 0.0)
		Sfx.play_at("grunt", visual_pos(r), -3.0)


func _on_remounted(r: Rider) -> void:
	rider_remounted.emit(r)
	rider_event.emit("remount", r, {})


func _on_second_wind(r: Rider) -> void:
	stats["second_winds"] = int(stats.get("second_winds", 0)) + 1
	rider_event.emit("second_wind", r, {})
	if r.is_player:
		announcement.emit("SECOND WIND!", "big")
	if not headless:
		Sfx.play("second_wind")


func _on_launched(r: Rider) -> void:
	rider_event.emit("leap", r, {})


func _on_landed(r: Rider) -> void:
	rider_event.emit("land", r, {})
	if not headless:
		Sfx.play_at("land", visual_pos(r), 0.0 if r.is_player else -8.0)


func _on_hazard(kind: String, r: Rider, info: Dictionary) -> void:
	rider_event.emit("h_" + kind, r, info)
	match kind:
		"pass":
			if r.is_player:
				announcement.emit("KI KI SO SO!", "big")
				Sfx.play("flag_up")
			rider_event.emit("pass_cry", r, info)
		"site_good":
			if r.is_player:
				announcement.emit("FORTUNE  +", "good")
		"site_bad":
			if r.is_player:
				announcement.emit("WRONG SIDE", "bad")
		"scarf":
			if r.is_player:
				announcement.emit("SCARF!  +8", "good")
				Sfx.play("coin")
		"pole":
			if r.is_player:
				announcement.emit("TARGET POLE!  +10", "good")
				Sfx.play("bell")
		"ramp":
			if r.is_player:
				announcement.emit("AIR!  +4", "good")
		"fined":
			if r.is_player:
				announcement.emit("STEWARD!  -%d" % int(info["amount"]), "bad")
		"thrown":
			pass
		"sheep":
			pass
		"pickup":
			if r.is_player:
				announcement.emit("GOT THE %s" % String(GameData.WEAPONS[info["weapon"]]["name"]).to_upper(), "good")


func _check_finish() -> void:
	for r in riders:
		if r.finished or not r.is_riding():
			continue
		if r.s >= finish_s:
			r.finished = true
			var over := (r.s - finish_s) / maxf(r.speed, 1.0)
			r.finish_time = race_time - over
			r.state = "finished"
			r.horse_s = r.s
			finish_order.append(r)
			r.place = finish_order.size()
			rider_event.emit("finish", r, {"place": r.place})
			if r.is_player:
				announcement.emit("FINISH!", "big")
				Sfx.play("cymbal")
				_end_timer = AFTER_PLAYER_FINISH
	var all_done := true
	for r in riders:
		if not r.finished:
			all_done = false
			break
	if all_done:
		_end_race()
	elif _end_timer < 0.0 and finish_order.size() >= 6:
		_end_timer = 10.0


func _end_race() -> void:
	if ended:
		return
	ended = true
	_update_places()
	results.clear()
	for r in standings():
		var res := r.to_result()
		res["bounty"] = r.knockdowns * GameData.bounty(season)
		res["prize"] = GameData.prize(season, r.place)
		res["qualified"] = r.place <= 3 and r.finished
		res["finished"] = r.finished
		results.append(res)
	race_finished.emit(results)


# ---------------------------------------------------------------------------------------------
# Visual helpers
# ---------------------------------------------------------------------------------------------

func visual_pos(r: Rider) -> Vector3:
	return track.point(r.s, r.d, 1.0 + r.height)


func _projectile_model(p: Projectile) -> Node3D:
	var path := ""
	if p.kind == "arrow":
		path = "res://assets/models/weapons/arrow.glb"
	elif p.kind == "spear":
		path = "res://assets/models/weapons/roped_spear.glb"
	if path != "" and ResourceLoader.exists(path):
		var m: Node3D = (load(path) as PackedScene).instantiate()
		ArtKit.apply(m, ArtKit.toon(ArtKit.CLASS_RIDER))
		return m
	return null


func _make_projectile_visual(p: Projectile) -> void:
	if _proj_nodes == null:
		return
	if p.shooter.is_player:
		_make_tracer(p)
	var n := Node3D.new()
	var model := _projectile_model(p)
	if model != null:
		n.add_child(model)
		_proj_nodes.add_child(n)
		p.node = n
		if p.kind == "spear":
			_make_rope(p)
		return
	var mi := MeshInstance3D.new()
	if p.kind == "stone":
		var ball := SphereMesh.new()
		ball.radius = 0.09
		ball.height = 0.18
		ball.radial_segments = 8
		ball.rings = 4
		mi.mesh = ball
	else:
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.03 if p.kind == "arrow" else 0.05
		mesh.bottom_radius = mesh.top_radius
		mesh.height = 1.0 if p.kind == "arrow" else 1.6
		mesh.radial_segments = 5
		mi.mesh = mesh
		mi.rotation_degrees.x = 90.0
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("2a1d18") if p.kind != "stone" else Color("6b6570")
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	n.add_child(mi)
	_proj_nodes.add_child(n)
	p.node = n
	if p.kind == "spear":
		_make_rope(p)


func _make_rope(p: Projectile) -> void:
	if p.kind == "spear":
		var rope := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.025
		rm.bottom_radius = 0.025
		rm.height = 1.0
		rm.radial_segments = 4
		rope.mesh = rm
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color("c9b48a")
		rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rope.material_override = rmat
		_proj_nodes.add_child(rope)
		p.rope = rope


## A thin line behind the player's own shots, so the arc they fly can be seen and learned.
func _make_tracer(p: Projectile) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = ImmediateMesh.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	mi.material_override = m
	_proj_nodes.add_child(mi)
	p.tracer = mi


func _draw_tracer(p: Projectile) -> void:
	if p.path.is_empty() or p.path[p.path.size() - 1].distance_squared_to(p.pos) > 0.25:
		p.path.append(p.pos)
	var im := p.tracer.mesh as ImmediateMesh
	im.clear_surfaces()
	if p.path.size() < 2:
		return
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in p.path.size():
		im.surface_set_color(Color(1.0, 0.97, 0.85, 0.15 + 0.7 * float(i) / float(p.path.size() - 1)))
		im.surface_add_vertex(p.path[i])
	im.surface_end()


## The shot itself is gone (a stuck arrow has already been handed over). Its line fades out over a moment.
func _retire_projectile_visual(p: Projectile) -> void:
	if p.node != null and is_instance_valid(p.node):
		p.node.queue_free()
	if p.rope != null and is_instance_valid(p.rope):
		p.rope.queue_free()
	if p.tracer != null and is_instance_valid(p.tracer):
		var fade := create_tween()
		fade.tween_property(p.tracer.material_override, "albedo_color:a", 0.0, 0.6)
		fade.tween_callback(p.tracer.queue_free)


func _update_projectile_visuals(delta: float) -> void:
	for p in projectiles:
		if p.tracer != null and is_instance_valid(p.tracer):
			_draw_tracer(p)
		if p.node == null or not is_instance_valid(p.node):
			continue
		var pos := p.pos
		var ahead := pos + (pos - p.shooter.hand_point(track)).normalized() if p.returning else pos + p.vel.normalized()
		if pos.distance_to(ahead) > 0.001:
			p.node.look_at_from_position(pos, ahead, Vector3.UP)
		else:
			p.node.position = pos
		if p.rope != null and is_instance_valid(p.rope):
			var hand := shot_point(p.shooter)
			var mid := (hand + pos) * 0.5
			var ln := hand.distance_to(pos)
			if ln > 0.05:
				p.rope.look_at_from_position(mid, pos, Vector3.UP)
				p.rope.rotate_object_local(Vector3.RIGHT, PI * 0.5)
				p.rope.scale = Vector3(1.0, ln, 1.0)
	for i in range(_stuck.size() - 1, -1, -1):
		_stuck[i]["left"] = float(_stuck[i]["left"]) - delta
		if float(_stuck[i]["left"]) <= 0.0:
			if is_instance_valid(_stuck[i]["node"]):
				(_stuck[i]["node"] as Node).queue_free()
			_stuck.remove_at(i)
