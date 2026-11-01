extends Node
## A bot plays a whole race through the real input actions, with rendering on.
## Usage: Godot --path . --audio-driver Dummy res://tests/autoplay.tscn -- <out_dir> [max_seconds] [seed] [season] [course] [weapon] [ranged]
##        [crash_at_s] [crash_reason] [nomash] [warp_m] [hat_at_s] [shot_every_s] [horse_id] [draft_at_s] [practice]
## Prints FPS stats, what the rivals said and the player's fun stats, and saves screenshots at chosen moments (start,
## first fight, hit, knockdown, leap, hat, mud, the finish orbit). Use "none" or "x" or -1 to skip an argument.

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
var force_hat_at := -1.0
var force_draft_at := -1.0
var finish_t0 := -1.0
var shot_every := 0.0
var shot_n := 0
var said: Array[String] = []
var player_shots_landed := 0
var practice := false


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
	force_hat_at = float(args[11]) if args.size() > 11 else -1.0
	shot_every = float(args[12]) if args.size() > 12 else 0.0
	force_draft_at = float(args[14]) if args.size() > 14 else -1.0
	practice = args.size() > 15 and args[15] == "practice"
	DirAccess.make_dir_recursive_absolute(out_dir)
	race = Race.new()
	race.auto_begin = false
	add_child(race)
	var horse: String = args[13] if args.size() > 13 else "old_tsampa"
	race.begin({"season": season, "seed": seed_v, "course_index": course, "weapon_id": weapon, "ranged_id": ranged, "has_shield": ranged == "" and weapon == "sword", "horse_id": horse})
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
	race.chatter.connect(func(r: Rider, line: Dictionary) -> void:
		said.append("%s/%s" % [line.get("speaker", "?"), line.get("t", "")])
		print("[say %5.1f] %s%s: %s" % [race.race_time, line.get("speaker", "?"), "" if r != null else " (no rider)", line.get("t", "")]))
	if race.chatter_node != null:
		race.chatter_node.set("debug", true)
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
	if attacker == race.player and info.get("klass", "") == "ranged":
		player_shots_landed += 1
		queue_shot("shot_landed", 0.04)
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
	if r == race.player and (kind == "leap" or kind == "pass_cry" or kind == "h_scarf" or kind == "second_wind" or kind == "mud"):
		queue_shot(kind, 0.12)
	if kind == "hat":
		print("[hat] %s lost a hat at s=%.0f" % [r.display_name, r.s])
		queue_shot("hat", 0.3)
		queue_shot("hat_late", 1.4)
	if kind == "finish" and r == race.player:
		finish_t0 = elapsed
		print("[finish] player place %d" % r.place)


func _on_finished(results: Array) -> void:
	print("== results ==")
	for e in results:
		var r: Rider = e["rider"]
		print("  %d. %-22s %s t=%.1f kd=%d crashes=%d%s" % [e["place"], r.display_name, "FIN" if r.finished else "DNF", r.finish_time, r.knockdowns, r.crashes, " [PLAYER]" if r.is_player else ""])
	finish_wait = 0.8   # the HUD switches to the results screen after 1.2 s, which would end this scene


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
	if force_hat_at > 0.0 and race.started and race.race_time > force_hat_at and race.fx != null:
		force_hat_at = -1.0
		var near := race.nearest_rival(race.player, 40.0)
		if near != null:
			print("[test] forcing a hat off %s" % near.display_name)
			race.fx.call("_try_hat", near, race.player, 1.0)
	if race.life != null and race.player != null:
		for kind in ["dogs", "kiang", "cranes", "marmots"]:
			for a in race.life.get(kind):
				var ahead: float = a.s - race.player.s
				var showing: bool = a.state in ["run", "rise", "up", "stand"] and ahead > 8.0 and ahead < 34.0 and absf(a.d - race.player.d) < 30.0
				if showing and (kind != "cranes" or a.state == "rise") and (kind != "dogs" or a.state == "run"):
					queue_shot("life_" + kind, 0.1)
	if race.flair != null and bool(race.flair.get("_draft_on")):
		queue_shot("draft", 0.4)
	if shot_every > 0.0 and race.started and race.race_time >= float(shot_n) * shot_every:
		queue_shot("t_%03d" % int(float(shot_n) * shot_every), 0.0)
		shot_n += 1
	if force_draft_at > 0.0 and race.started and race.race_time > force_draft_at:
		force_draft_at = -1.0
		var lead := race.nearest_rival(race.player, 40.0)
		if lead != null:
			print("[test] tucking the player in behind %s" % lead.display_name)
			race.player.s = lead.s - 6.0
			race.player.d = lead.d
			race.player.speed = lead.speed
	if finish_t0 > 0.0:
		for pair in [["fin_0_4", 0.4], ["fin_1_5", 1.5], ["fin_3_0", 3.0], ["fin_4_5", 4.5], ["fin_6_0", 6.0]]:
			if elapsed - finish_t0 > float(pair[1]):
				queue_shot(String(pair[0]), 0.0)
	if crash_t0 > 0.0:
		for pair in [["c_0_3", 0.3], ["c_0_9", 0.9], ["c_1_6", 1.6], ["c_3_0", 3.0], ["c_5_0", 5.0], ["c_6_3", 6.3], ["c_7_5", 7.5]]:
			if elapsed - crash_t0 > float(pair[1]):
				queue_shot(String(pair[0]), 0.0)
	if race.player != null and race.player.drawing and race.player.draw_amount > 0.6:
		queue_shot("aim", 0.05)
	if race.player != null and race.roadside != null:
		for b: Roadside.Board in race.roadside.boards:
			var dsb: float = b.s - race.player.s
			if dsb > 9.0 and dsb < 16.0:
				queue_shot("board_close", 0.0)
		for f: Roadside.Flock in race.roadside.flocks:
			var dsf: float = f.s - race.player.s
			if dsf > 9.0 and dsf < 20.0:
				queue_shot("flock_close", 0.0)
			if dsf > 26.0 and dsf < 36.0:
				queue_shot("flock_far", 0.0)
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
	var alive := int(race.life.get("count_alive")) if race.life != null else 0
	print("shot ", path, " t=%.1f s=%.0f life=%d" % [race.race_time, race.player.s, alive])
	if race.life != null:
		for kind in ["dogs", "kiang", "cranes", "marmots"]:
			for a in race.life.get(kind):
				print("   %s %s s=%.0f d=%.1f h=%.1f v=(%.1f, %.1f) vis=%s" % [a.kind, a.state, a.s, a.d, a.h, a.vs, a.vd, a.node.visible if a.node != null else "-"])


func _drive(dt: float) -> void:
	var r := race.player
	if r == null:
		return
	var it := brain.think(dt)
	if practice:
		_practice(r, it)
	else:
		_aim_sight(r)
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


## Instead of shooting rivals, holds the sight on the nearest thing beside the road that's in range and shoots that.
func _practice(r: Rider, it: Rider.Intent) -> void:
	race.aim_held = true
	it.ranged = false
	var cam := get_viewport().get_camera_3d()
	if cam == null or r.ranged_id == "" or r.ammo == 0 or not r.is_riding():
		return
	var at := Vector3.ZERO
	var ts := 0.0
	var td := 0.0
	var tv := Vector2.ZERO
	var best := 45.0
	for b: Roadside.Board in race.roadside.boards:
		var ds: float = b.s - r.s
		if not b.scored and ds > 14.0 and ds < best:
			best = ds
			at = b.centre
			ts = b.s
			td = b.d
			tv = Vector2.ZERO
	for f: Roadside.Flock in race.roadside.flocks:
		for w: Roadside.Beast in f.beasts:
			var ds: float = w.s - r.s
			if w.kind == "wolf" and not w.gone and w.state != "flee" and ds > 10.0 and ds < best:
				best = ds
				at = w.pos + Vector3.UP * 0.7
				ts = w.s
				td = w.d
				tv = Vector2(w.vs, w.vd)
	if at == Vector3.ZERO:
		return
	queue_shot("practice_near", 0.0)
	var th: float = at.y - race.track.point(ts, td).y
	race.aim_screen = _sight_for(r, cam, ts, td, th, tv.x, tv.y, maxf(r.draw_amount, 0.8))
	it.ranged = not (r.drawing and r.draw_amount >= 1.0)
	if r.drawing and r.draw_amount >= 1.0:
		queue_shot("practice_loose", 0.05)
	if r.drawing and r.draw_amount > 0.7:
		queue_shot("practice_aim", 0.0)


## Holds the sight where a good shot would put it, allowing for drop and movement, by the same screen position the mouse sets.
func _aim_sight(r: Rider) -> void:
	if r.ranged_id == "":
		return     # leaves PlayerControl reading the mouse, as in a real race
	race.aim_held = true
	if not r.drawing:
		return
	var cam := get_viewport().get_camera_3d()
	var lock := race.find_lock(r)
	if cam == null or lock == null:
		return
	race.aim_screen = _sight_for(r, cam, lock.s, lock.d, 1.9 + lock.height, lock.speed, lock.lateral, r.draw_amount)
	if not shots_taken.has("sight_logged"):
		shots_taken["sight_logged"] = true
		print("[sight] on %s, screen %s, aim_dir %s" % [lock.display_name, race.aim_screen, r.aim_dir])


## Where the sight has to sit to hit something moving along the road, allowing for the drop, from the weapon in the hand.
func _sight_for(r: Rider, cam: Camera3D, ts: float, td: float, th: float, vs: float, vd: float, draw: float) -> Vector2:
	var hand := race.shot_point(r)
	var dir := race.aim_for(hand, r.world_velocity(race.track), Race.launch_speed(r.ranged_id, draw), ts, td, th, vs, vd)
	return cam.unproject_position(hand + dir * hand.distance_to(race.track.point(ts, td, th))) / get_viewport().get_visible_rect().size


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
	var pr := race.player
	print("player: place %d  knockdowns %d  hats %d  near misses %d  overtakes %d  best streak %d  silver bonus %d" % [pr.place, pr.knockdowns, pr.hats_knocked, pr.near_misses, pr.overtakes, pr.best_streak, pr.silver_bonus])
	if pr.ranged_id != "":
		print("shots: %d left of %s, %d landed in all, %d by the player" % [pr.ammo, pr.ranged_id, int(race.stats["hits"]["ranged"]), player_shots_landed])
	print("roadside: %d wolves driven off, %d sheep struck, fines %d, silver bonus %d" % [race.roadside.wolves_driven, race.roadside.sheep_struck, pr.fines, pr.silver_bonus])
	print("sight at %s" % race.aim_screen)
	if race.chatter_node != null:
		print("chatter: %d lines %s" % [int(race.chatter_node.get("lines_total")), race.chatter_node.get("said")])
	print("time scale at exit: %.2f" % Engine.time_scale)
	get_tree().quit()
