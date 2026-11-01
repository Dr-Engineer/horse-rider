extends Node
## A bot plays a whole race through the real input actions, with rendering on.
## Usage: Godot --path . res://tests/autoplay.tscn -- <out_dir> [max_seconds] [seed] [season] [course] [weapon] [ranged]
## Prints FPS stats and saves screenshots at chosen moments (start, first fight, hit, knockdown, leap, finish).

var out_dir := "/tmp/autoplay"
var max_seconds := 200.0
var race: Race
var brain: RiderAI
var held: Dictionary = {}
var release_at: Dictionary = {}
var fps_samples: Array[float] = []
var frame_ms: Array[float] = []
var shots_taken: Dictionary = {}
var shot_queue: Array[String] = []
var elapsed := 0.0
var fps_t := 0.0
var finish_wait := -1.0
var last_hit_victim_player := false
var _prev_state := "ride"
var swing_pause := 0.0
var want_shots: Dictionary = {}
var wall_t0 := 0
var force_crash_at := -1.0
var force_reason := "health"
var crash_t0 := -1.0
var no_mash := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		max_seconds = float(args[1])
	var seed_v: int = int(args[2]) if args.size() > 2 else 99
	var season: int = int(args[3]) if args.size() > 3 else 0
	var course: int = int(args[4]) if args.size() > 4 else 0
	var weapon: String = args[5] if args.size() > 5 else "sword"
	var ranged: String = args[6] if args.size() > 6 else ""
	force_crash_at = float(args[7]) if args.size() > 7 else -1.0
	force_reason = args[8] if args.size() > 8 else "health"
	no_mash = args.size() > 9 and args[9] == "nomash"
	var warp: float = float(args[10]) if args.size() > 10 else 0.0
	DirAccess.make_dir_recursive_absolute(out_dir)
	race = Race.new()
	race.auto_begin = false
	add_child(race)
	race.begin({"season": season, "seed": seed_v, "course_index": course, "weapon_id": weapon, "ranged_id": ranged, "has_shield": ranged == "" and weapon == "sword"})
	print("stewards ", race.hazards.stewards.size(), " season ", race.season)
	# Lets a recording start part way along the course, by a landmark.
	if warp > 0.0:
		for r: Rider in race.riders:
			r.s += warp
	brain = RiderAI.new(race.player, race, race.rng)
	race.rider_hit.connect(_on_hit)
	race.rider_crashed.connect(_on_crashed)
	race.race_finished.connect(_on_finished)
	race.rider_event.connect(_on_event)
	race.announcement.connect(func(t: String, k: String) -> void: print("[announce %s] %s" % [k, t]))
	wall_t0 = Time.get_ticks_msec()
	print("autoplay: course '%s' seed %d, out %s" % [race.course.get("name", "?"), seed_v, out_dir])


func _press(action: String, strength: float = 1.0) -> void:
	if not held.has(action):
		Input.action_press(action, strength)
		held[action] = strength
	elif absf(float(held[action]) - strength) > 0.01:
		Input.action_press(action, strength)
		held[action] = strength


func _release(action: String) -> void:
	if held.has(action):
		Input.action_release(action)
		held.erase(action)


func _tap(action: String, secs: float = 0.08) -> void:
	_press(action)
	release_at[action] = elapsed + secs


func _on_hit(attacker: Rider, victim: Rider, info: Dictionary) -> void:
	if victim == race.player and not shots_taken.has("hit_taken") and not info.get("blocked", false):
		queue_shot("hit_taken", 0.05)
	elif attacker == race.player and not shots_taken.has("hit_landed") and not info.get("blocked", false):
		queue_shot("hit_landed", 0.05)


func _on_crashed(r: Rider, reason: String) -> void:
	if r == race.player:
		queue_shot("player_crash_" + reason, 0.35)
	elif absf(r.s - race.player.s) < 25.0 and not shots_taken.has("rival_down"):
		queue_shot("rival_down", 0.25)


func _on_event(kind: String, r: Rider, _info: Dictionary) -> void:
	if r == race.player and (kind == "leap" or kind == "pass_cry" or kind == "h_scarf" or kind == "second_wind"):
		queue_shot(kind, 0.12)


func _on_finished(results: Array) -> void:
	print("== results ==")
	for e in results:
		var r: Rider = e["rider"]
		print("  %d. %-22s %s t=%.1f kd=%d crashes=%d%s" % [e["place"], r.display_name, "FIN" if r.finished else "DNF", r.finish_time, r.knockdowns, r.crashes, " [PLAYER]" if r.is_player else ""])
	finish_wait = 1.5


func queue_shot(tag: String, delay: float) -> void:
	if shots_taken.has(tag):
		return
	shots_taken[tag] = true
	want_shots[tag] = elapsed + delay


func _process(dt: float) -> void:
	elapsed += dt
	frame_ms.append(dt * 1000.0)
	fps_t += dt
	if fps_t >= 0.25:
		fps_t = 0.0
		fps_samples.append(Engine.get_frames_per_second())
	# release taps
	for a: String in release_at.keys():
		if elapsed >= float(release_at[a]):
			_release(a)
			release_at.erase(a)
	_drive(dt)
	# scheduled screenshots
	for tag: String in want_shots.keys():
		if elapsed >= float(want_shots[tag]):
			want_shots.erase(tag)
			_save(tag)
	if force_crash_at > 0.0 and race.started and race.race_time > force_crash_at and crash_t0 < 0.0:
		crash_t0 = elapsed
		race.player.crash(force_reason)
	if crash_t0 > 0.0:
		for pair in [["c_0_3", 0.3], ["c_0_9", 0.9], ["c_1_6", 1.6], ["c_3_0", 3.0], ["c_5_0", 5.0], ["c_6_3", 6.3], ["c_7_5", 7.5]]:
			if elapsed - crash_t0 > float(pair[1]):
				queue_shot(String(pair[0]), 0.0)
	if race.player != null and race.player.drawing and race.player.draw_amount > 0.6 and (race.player.target_lock != null):
		queue_shot("aim", 0.05)
	if race.player != null and race.hazards != null:
		for st in race.hazards.stewards:
			var dsw: float = float(st["s"]) - race.player.s
			if dsw > 10.0 and dsw < 26.0:
				queue_shot("steward", 0.1)
	if race.started:
		var t := race.race_time
		if t > 1.2:
			queue_shot("start_1s", 0.0)
		if t > 6.0:
			queue_shot("run_6s", 0.0)
		if t > 25.0:
			queue_shot("run_25s", 0.0)
		if t > 60.0:
			queue_shot("run_60s", 0.0)
	elif race.countdown < 2.0:
		queue_shot("grid", 0.0)
	if finish_wait >= 0.0:
		finish_wait -= dt
		if finish_wait < 0.0:
			_quit()
	if elapsed > max_seconds:
		print("autoplay: time limit reached")
		_quit()


func _save(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, tag]
	img.save_png(path)
	print("shot ", path, " t=%.1f" % race.race_time)


func _drive(dt: float) -> void:
	var r := race.player
	if r == null:
		return
	var it := brain.think(dt)
	# translate to real actions
	if it.steer < -0.04:
		_press("steer_left", clampf(-it.steer, 0.0, 1.0))
		_release("steer_right")
	elif it.steer > 0.04:
		_press("steer_right", clampf(it.steer, 0.0, 1.0))
		_release("steer_left")
	else:
		_release("steer_left")
		_release("steer_right")
	if it.throttle > 0.05:
		_press("urge", it.throttle)
		_release("rein")
	elif it.throttle < -0.05:
		_press("rein", -it.throttle)
		_release("urge")
	else:
		_release("urge")
		_release("rein")
	if it.whip:
		_press("whip")
	else:
		_release("whip")
	if it.shield:
		_press("shield")
	else:
		_release("shield")
	if it.ranged:
		_press("ranged")
	else:
		_release("ranged")
	if it.leap:
		_tap("leap", 0.1)
	if it.strike_left:
		_tap("strike_left")
	if it.strike_right:
		_tap("strike_right")
	if it.kick:
		_tap("kick")
	if it.mash and not no_mash:
		_tap("urge", 0.05)
	if r.lungta >= 4.99:
		_tap("second_wind")


func _quit() -> void:
	var secs := float(Time.get_ticks_msec() - wall_t0) / 1000.0
	var fps_min := 1.0e9
	var fps_sum := 0.0
	var fps_max := 0.0
	for f in fps_samples:
		fps_min = minf(fps_min, f)
		fps_sum += f
		fps_max = maxf(fps_max, f)
	var worst := 0.0
	for m in frame_ms:
		worst = maxf(worst, m)
	var sorted := frame_ms.duplicate()
	sorted.sort()
	var p99 := 0.0
	if sorted.size() > 10:
		p99 = sorted[int(float(sorted.size()) * 0.99)]
	print("FPS avg %.1f min %.1f max %.1f | frame ms p99 %.1f worst %.1f | wall %.1f s" % [fps_sum / maxf(float(fps_samples.size()), 1.0), fps_min, fps_max, p99, worst, secs])
	get_tree().quit()
