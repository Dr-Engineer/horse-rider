extends Node
## Is there more steering to do, and can a person do it? On an empty course, for the slowest and fastest horses:
##   hands off   how far a horse at full speed runs from the middle of the road before leaving it, with no steering, averaged along the course
##   keyboard    a bot with on-or-off steering and a human's reaction time rides the whole course flat out. How much of it is
##               spent off the road, and how many times it is thrown? How much of the time does it have a steering key held down?
## Usage: Godot --headless --path . --audio-driver Dummy res://tests/steer_check.tscn

const REACTION := 0.2   # seconds between seeing the road and the hands acting on it
const DT := 1.0 / 60.0

var failures := 0


func _ready() -> void:
	for course in Courses.count():
		for season: int in [0, 2]:
			var c := Courses.get_course(course, season)
			var t := Track.new()
			t.build(c["segments"], float(c["half_width"]))
			for horse: String in ["old_tsampa", "sertso_grey"]:
				var off := _hands_off(t, horse)
				var keys := _keyboard(t, horse, false)
				var whip := _keyboard(t, horse, true)
				print("%-24s S%d %-12s hands off %4.0f m   flat out: %4.1f%% off road, %d thrown, steering %2.0f%% of the time.   whipping: %4.1f%% off road, %d thrown" % [
					c["id"], season + 1, horse, off, keys["off"], keys["thrown"], keys["held"], whip["off"], whip["thrown"]])
				check(int(keys["thrown"]) == 0, "%s %s: a keyboard rider at full throttle should be able to stay on" % [c["id"], horse])
				check(float(keys["off"]) < 4.0, "%s %s: a keyboard rider should stay on the road flat out, %.1f%% off" % [c["id"], horse, keys["off"]])
				check(off < 260.0, "%s %s: without steering a rider should soon leave the road, ran %.0f m" % [c["id"], horse, off])
	print("RESULT: %s (%d)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("  FAIL: " + what)


func _rider(horse: String) -> Rider:
	var r := Rider.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	r.setup(GameData.PLAYERS["joru"], {"id": "joru", "is_player": true, "horse_id": horse}, rng)
	return r


func _hands_off(t: Track, horse: String) -> float:
	var total := 0.0
	var n := 0
	var at := 200.0
	var it := Rider.Intent.new()
	it.throttle = 1.0
	while at < t.length - 300.0:
		var r := _rider(horse)
		r.place_on_grid(at, 0.0)
		r.speed = float(r.horse["speed"])
		while absf(r.d) <= t.half_width_at(r.s) and r.s < t.length - 5.0:
			r.simulate(DT, it, t)
		total += r.s - at
		n += 1
		at += 60.0
	return total / float(n)


func _keyboard(t: Track, horse: String, whip: bool) -> Dictionary:
	var r := _rider(horse)
	r.place_on_grid(24.0, 0.0)
	r.max_stamina = 1.0e9       # hold the whip all the way, the worst case
	r.stamina = r.max_stamina
	var it := Rider.Intent.new()
	it.throttle = 1.0
	it.whip = whip
	var seen := [] # what the hands are working from, REACTION seconds old
	var off := 0
	var held := 0
	var ticks := 0
	var thrown := 0
	while r.s < t.length - 45.0 and ticks < 60 * 300:
		# a rider aims for the middle of the road, looking a second ahead, and sees how the bend there will push
		var look := r.s + r.speed * 0.8
		var push := -t.curve_at(look) * r.speed * r.speed * Rider.CURVE_K
		seen.append(-(r.d + (r.lateral + push) * 0.5))
		var want: float = seen[0]
		if seen.size() > int(REACTION / DT):
			seen.pop_front()
		it.steer = 0.0 if absf(want) < 0.6 else signf(want)
		if it.steer != 0.0:
			held += 1
		r.simulate(DT, it, t)
		if absf(r.d) > t.half_width_at(r.s):
			off += 1
		ticks += 1
		if not r.is_riding():
			thrown += 1
			r.state = "ride"
			r.d = 0.0
			r.speed = 12.0
			r.lateral = 0.0
	return {"off": 100.0 * float(off) / float(ticks), "held": 100.0 * float(held) / float(ticks), "thrown": thrown}
