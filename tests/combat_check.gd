extends Node
## Checks hand to hand: fists hit harder than a kick and don't shove, a kick lands late, slows the kicker and pushes the target,
## a slam from the side carries on after the contact, and a strike with sideways speed behind it, or right after a slam, deals
## 1.5 times the damage. Also the ranged numbers: three times the shots, a little more damage, still under the melee rule.
## Usage: Godot --headless --path . --audio-driver Dummy res://tests/combat_check.tscn

const DT := 1.0 / 60.0

var failures := 0


func _ready() -> void:
	_ranged_numbers()
	_fists()
	_kick()
	_slam_carries()
	_slam_needs_edge()
	_spear_up_close()
	_strikes_with_momentum()
	print("RESULT: %s (%d)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("  FAIL: " + what)


func _race() -> Race:
	var c := Race.fallback_course()
	c["segments"] = [[2400, 0, 0]]
	c["half_width"] = 12.0
	c["events"] = [{"type": "start", "s": 14.0}, {"type": "finish", "s": 2300.0}]
	var race := Race.new()
	race.headless = true
	race.auto_begin = false
	race.player_ai = true
	add_child(race)
	race.begin({"season": 0, "seed": 5, "course_override": c})
	race.countdown = 0.0
	race.started = true
	for r in race.riders:
		r.state = "finished"
		r.s = 2200.0
	return race


## Two riders on equal horses, side by side.
func _pair(race: Race, gap: float) -> Array[Rider]:
	var a := race.riders[0]
	var b := race.riders[1]
	for r in [a, b]:
		r.state = "ride"
		r.s = 300.0
		r.d = 0.0
		r.speed = 20.0
		r.lateral = 0.0
		r.slide = 0.0
		r.horse = GameData.HORSES["old_tsampa"]
		r.bulk = 1.0
		r.health = 100.0
		r.max_health = 100.0
		r.shake = 0.0
		r.invuln_t = 0.0
		r.weapon_id = "fists"
		r.has_shield = false
		r.swing_t = -1.0
		r.cooldown = 0.0
	b.d = gap
	return [a, b]


func _ride(riders: Array[Rider], secs: float, track: Track) -> void:
	var it := Rider.Intent.new()
	it.throttle = 1.0
	var t := 0.0
	while t < secs:
		for r in riders:
			r.simulate(DT, it, track)
		t += DT


func _ranged_numbers() -> void:
	check(int(GameData.WEAPONS["bow"]["ammo"]) == 36 and int(GameData.WEAPONS["sling"]["ammo"]) == 297, "three times the shots")
	check(float(GameData.WEAPONS["sling"]["damage"]) > 3.0 and float(GameData.WEAPONS["bow"]["damage"]) > 7.0 and float(GameData.WEAPONS["roped_spear"]["damage"]) > 9.0, "a little more ranged damage")
	var melee := 0.0
	for id: String in ["knife", "pencase", "whip", "sword", "key", "spear"]:
		melee += float(GameData.WEAPONS[id]["damage"]) / 6.0
	check(float(GameData.WEAPONS["bow"]["damage"]) * 1.3 < melee, "the strongest ranged shot stays under the average melee weapon")


func _fists() -> void:
	var race := _race()
	var pair := _pair(race, 1.6)
	var a := pair[0]
	var b := pair[1]
	check(float(GameData.WEAPONS["fists"]["damage"]) > float(GameData.WEAPONS["kick"]["damage"]), "fists do more damage than a kick")
	a._start_swing(1, "melee")
	var speed_before := a.speed
	var hit_at := -1.0
	var t := 0.0
	var it := Rider.Intent.new()
	it.throttle = 1.0
	var d_before := b.d
	while t < 0.5:
		a.simulate(DT, it, race.track)
		b.simulate(DT, it, race.track)
		if a.swing_t >= 0.0 and a.swing_active() and not a.swing_done:
			race._resolve_swing(a)
			if hit_at < 0.0:
				hit_at = t
		t += DT
	check(is_equal_approx(b.health, 100.0 - float(GameData.WEAPONS["fists"]["damage"])), "a punch does its damage: health %.1f" % b.health)
	check(absf(b.d - d_before) < 0.15, "a punch doesn't shove: moved %.2f m" % absf(b.d - d_before))
	check(a.speed >= speed_before - 0.01, "a punch doesn't slow the puncher: %.1f to %.1f" % [speed_before, a.speed])
	print("  punch: lands at %.2f s, %.0f damage, target moved %.2f m, puncher keeps %.1f m/s" % [hit_at, 100.0 - b.health, absf(b.d - d_before), a.speed])
	race.free()


func _kick() -> void:
	var race := _race()
	var pair := _pair(race, 1.6)
	var a := pair[0]
	var b := pair[1]
	var twin := race.riders[2]
	twin.state = "ride"
	twin.s = 300.0
	twin.d = -8.0
	twin.speed = 20.0
	twin.horse = a.horse
	twin.swing_t = -1.0
	a._start_swing(1, "kick")
	var it := Rider.Intent.new()
	it.throttle = 1.0
	var d_before := b.d
	var hit_at := -1.0
	var t := 0.0
	var slowest := 1.0
	while t < 1.4:
		for r: Rider in [a, b, twin]:
			r.simulate(DT, it, race.track)
		t += DT
		slowest = minf(slowest, a.speed / twin.speed)
		if a.swing_t >= 0.0 and a.swing_active() and not a.swing_done:
			race._resolve_swing(a)
			if hit_at < 0.0:
				hit_at = t
		if t < 0.6:
			check(is_equal_approx(a.top_speed, twin.top_speed * Rider.KICK_SLOW), "the kicker's top speed should be %.0f%% while kicking" % (Rider.KICK_SLOW * 100.0))
	var shoved := absf(b.d - d_before)
	print("  kick: lands at %.2f s, %.1f damage, target pushed %.2f m, kicker down to %.0f%% of the speed of a rider who didn't, %.1f m behind" % [hit_at, 100.0 - b.health, shoved, slowest * 100.0, twin.s - a.s])
	check(absf(hit_at - Rider.KICK_DELAY) < 0.04, "a kick should land after %.2f s, landed at %.2f" % [Rider.KICK_DELAY, hit_at])
	check(is_equal_approx(b.health, 100.0 - float(GameData.WEAPONS["kick"]["damage"])), "a kick does its low damage: health %.1f" % b.health)
	check(shoved > 5.5 and shoved < 8.0, "a kick should push the target a long way: %.2f m" % shoved)
	check(slowest > 0.89 and slowest < 0.97, "a kick should cost about 10%% of the kicker's speed, no more: down to %.0f%%" % (slowest * 100.0))
	race.free()


## One rider steers hard into another, then lets go of the reins at the moment they meet. Both go on sideways.
func _slam_carries() -> void:
	var race := _race()
	var pair := _pair(race, 1.1)
	var a := pair[0]
	var b := pair[1]
	a.lateral = 7.5
	var b_before := b.d
	race._contacts(DT)
	check(b.health < 100.0, "a slam should do damage")
	check(a.shoved == b and a.shoved_t > 0.0, "the slammer should know who they slammed")
	check(b.slide > 2.0, "the one slammed should be carried along: slide %.1f" % b.slide)
	check(a.slide > 1.5, "the one slamming should keep going: slide %.1f" % a.slide)
	var a_before := a.d
	_ride([a, b], 1.2, race.track)
	var a_went := a.d - a_before
	var b_went := b.d - b_before
	print("  slam at 7.5 m/s, reins let go: slammer carries on %.2f m, target carried %.2f m" % [a_went, b_went])
	check(a_went > 0.6, "the slammer's momentum should carry on: %.2f m" % a_went)
	check(b_went > 1.2, "the target should be carried: %.2f m" % b_went)
	race.free()
	# momentum fades instead of going on for ever
	race = _race()
	pair = _pair(race, 1.1)
	pair[0].lateral = 7.5
	race._contacts(DT)
	_ride(pair, 3.0, race.track)
	check(absf(pair[0].slide) < 0.2 and absf(pair[1].slide) < 0.2, "momentum should fade: %.2f and %.2f" % [pair[0].slide, pair[1].slide])
	race.free()
	# a heavier horse pushes further than a light one
	var went: Array[float] = []
	for bulk: float in [1.5, 0.9]:
		race = _race()
		pair = _pair(race, 1.1)
		pair[0].bulk = bulk
		pair[0].lateral = 7.5
		race._contacts(DT)
		went.append(pair[1].slide)
		race.free()
	check(went[0] > went[1] + 0.3, "a heavy horse should shove harder: %.1f against %.1f" % [went[0], went[1]])


## A slam takes real speed and a decent chunk more sideways momentum than the other rider has, whichever way they're going.
func _slam_needs_edge() -> void:
	for row: Array in [
		[7.5, 0.0, 1.0, true, "hard into a rider holding their line"],
		[7.5, 3.0, 1.0, true, "hard into a rider drifting away"],
		[7.5, -4.0, 1.0, true, "hard into a rider coming slower"],
		[7.5, -7.5, 1.0, false, "two riders coming at each other just as hard"],
		[7.5, -5.5, 1.0, false, "not much more than a rider coming the other way"],
		[7.5, 6.0, 1.0, false, "chasing a rider going nearly as fast"],
		[3.5, 0.0, 1.0, false, "too slow to count"],
		[5.0, 3.0, 1.0, false, "a small edge on an equal horse"],
		[5.0, 3.0, 1.5, true, "the same speeds on a heavy horse: momentum counts"],
	]:
		var race := _race()
		var pair := _pair(race, 1.1)
		pair[0].lateral = float(row[0])
		pair[1].lateral = float(row[1])
		pair[0].bulk = float(row[2])
		race._contacts(DT)
		var slammed := pair[1].health < 100.0
		check(slammed == bool(row[3]), "%s: expected %s" % [row[4], "a slam" if row[3] else "no slam"])
		check(slammed or (is_equal_approx(pair[1].slide, 0.0) and pair[0].shoved == null), "%s: no slam should mean no push" % row[4])
		race.free()
	# an ordinary slam pushes, but only a really hard one sets up the bigger hit
	var soft_race := _race()
	var soft := _pair(soft_race, 1.1)
	soft[0].lateral = 5.0
	soft_race._contacts(DT)
	check(soft[1].health < 100.0 and soft[0].shoved == null, "a slam at 5 m/s is a slam, and doesn't set up a 1.5x hit")
	soft_race.free()


## A spear has no room to work up close.
func _spear_up_close() -> void:
	var full := float(GameData.WEAPONS["spear"]["damage"])
	var results: Array[float] = []
	for gap: float in [1.5, 1.9, 2.4, 3.8]:
		var race := _race()
		var pair := _pair(race, gap)
		pair[0].weapon_id = "spear"
		pair[0]._start_swing(1, "melee")
		pair[0].swing_t = pair[0].swing_hit_t
		race._resolve_swing(pair[0])
		results.append(100.0 - pair[1].health)
		race.free()
	print("  spear at 1.5, 1.9, 2.4 and 3.8 m: %.1f, %.1f, %.1f, %.1f" % results)
	check(is_equal_approx(results[0], full / 3.0) and is_equal_approx(results[1], full / 3.0), "a spear up close should do a third: %.1f and %.1f" % [results[0], results[1]])
	check(is_equal_approx(results[2], full) and is_equal_approx(results[3], full), "a spear at its length should do it all: %.1f and %.1f" % [results[2], results[3]])


## The damage of one punch with the attacker set up a given way.
func _punch(setup: Callable) -> float:
	var race := _race()
	var pair := _pair(race, 1.6)
	var a := pair[0]
	var b := pair[1]
	setup.call(a, b)
	a._start_swing(1, "melee")
	a.swing_t = a.swing_hit_t
	race._resolve_swing(a)
	var dmg := 100.0 - b.health
	race.free()
	return dmg


func _strikes_with_momentum() -> void:
	var plain := float(GameData.WEAPONS["fists"]["damage"])
	var still := _punch(func(_a: Rider, _b: Rider) -> void: pass)
	check(is_equal_approx(still, plain), "a plain punch does plain damage: %.1f" % still)
	var moving := _punch(func(a: Rider, _b: Rider) -> void: a.lateral = 7.5)
	check(is_equal_approx(moving, plain * 1.5), "a punch with sideways speed toward the target does 1.5x: %.1f" % moving)
	var away := _punch(func(a: Rider, _b: Rider) -> void: a.lateral = -6.0)
	check(is_equal_approx(away, plain), "moving away from the target earns nothing: %.1f" % away)
	var slow := _punch(func(a: Rider, _b: Rider) -> void: a.lateral = 6.0)
	check(is_equal_approx(slow, plain), "a fair bit of sideways speed still earns nothing: %.1f" % slow)
	var matched := _punch(func(a: Rider, b: Rider) -> void:
		a.lateral = 7.5
		b.lateral = -5.0)
	check(is_equal_approx(matched, plain), "no bonus against a rider coming nearly as hard: %.1f" % matched)
	var chased := _punch(func(a: Rider, b: Rider) -> void:
		a.lateral = 7.5
		b.lateral = 5.0)
	check(is_equal_approx(chased, plain), "no bonus chasing a rider going nearly as fast: %.1f" % chased)
	var carried := _punch(func(a: Rider, _b: Rider) -> void: a.slide = 7.5)
	check(is_equal_approx(carried, plain * 1.5), "momentum from a slam counts: %.1f" % carried)
	var after := _punch(func(a: Rider, b: Rider) -> void:
		a.shoved = b
		a.shoved_t = 0.8)
	check(is_equal_approx(after, plain * 1.5), "a punch right after slamming them does 1.5x: %.1f" % after)
	var late := _punch(func(a: Rider, b: Rider) -> void:
		a.shoved = b
		a.shoved_t = 0.0)
	check(is_equal_approx(late, plain), "a punch long after a slam is plain: %.1f" % late)
	var other := _punch(func(a: Rider, _b: Rider) -> void:
		a.shoved = a
		a.shoved_t = 1.0)
	check(is_equal_approx(other, plain), "slamming someone else earns nothing on this target: %.1f" % other)
	print("  punch: plain %.1f, with sideways speed %.1f, right after a slam %.1f" % [still, moving, after])
	# the shield still cuts it, and a ranged hit never gets it
	var race := _race()
	var pair := _pair(race, 1.6)
	pair[0].lateral = 7.0
	var info := race.apply_hit(pair[0], pair[1], 7.0, 8.0, "ranged", "bow", 1)
	check(not info.get("slam", false) and is_equal_approx(pair[1].health, 93.0), "ranged hits are never slams")
	race.free()
