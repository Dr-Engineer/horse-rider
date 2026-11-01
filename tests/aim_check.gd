extends Node
## Checks that shots really follow the physics: the drop matches gravity, the shooter's own speed carries over, a shot aimed
## straight at a far rider falls short while one aimed higher lands, a rider's own aim solution hits a moving target, and a
## shot at the horse's legs doesn't count. Also the wind trail: it reaches where it should, and a rider behind one catches up.
## Usage: Godot --headless --path . --audio-driver Dummy res://tests/aim_check.tscn

var failures := 0


func _ready() -> void:
	_flight()
	_compensation()
	_rope_length()
	_moving_target()
	_horse_is_safe()
	_wind_trail()
	_catch_up()
	print("RESULT: %s (%d)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("  FAIL: " + what)


## A race on a long straight flat road with one shooter and one target, and nobody else's input.
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
	return race


func _park(r: Rider, s: float, d: float, speed: float) -> void:
	r.s = s
	r.d = d
	r.speed = speed
	r.lateral = 0.0
	r.state = "ride"


## Runs just the projectile for up to the given time. Returns [hits on target, last height above ground, flight time].
func _shoot(race: Race, shooter: Rider, target: Rider, dir: Vector3, power: float, weapon: String, secs: float) -> Dictionary:
	shooter.ranged_id = weapon
	shooter.fire_power = power
	shooter.aim_dir = dir
	var before := target.health
	var hits := [0]
	var cb := func(_a: Rider, v: Rider, _i: Dictionary) -> void:
		if v == target:
			hits[0] += 1
	race.rider_hit.connect(cb)
	race._fire(shooter)
	var p: Projectile = race.projectiles[race.projectiles.size() - 1]
	var t := 0.0
	var dt := 1.0 / 60.0
	var far := 0.0
	var min_h := 99.0
	while t < secs and p.alive and not p.returning:
		shooter.s += shooter.speed * dt
		target.s += target.speed * dt
		race._step_projectiles(dt)
		t += dt
		far = p.s
		min_h = minf(min_h, p.h)
	race.rider_hit.disconnect(cb)
	return {"hits": hits[0], "t": t, "far": far, "h": min_h, "damage": before - target.health, "proj": p}


func _flight() -> void:
	var race := _race()
	var a := race.riders[0]
	_park(a, 200.0, 0.0, 0.0)
	var b := race.riders[1]
	_park(b, 900.0, 8.0, 0.0)
	# level shot from a standing horse: time to the ground is sqrt(2h/g), slowed a touch by the air
	var level := race.track.tangent_at(a.s)
	var got := _shoot(race, a, b, level, 1.0, "bow", 3.0)
	var expect_t := sqrt(2.0 * Rider.HAND_HEIGHT / Projectile.GRAVITY)
	check(absf(float(got["t"]) - expect_t) < 0.05, "level arrow should land after %.2f s, took %.2f" % [expect_t, got["t"]])
	var expect_far := 70.0 * expect_t
	var flown := float(got["far"]) - a.s
	check(flown < expect_far and flown > expect_far * 0.92, "level arrow should fly a little under %.0f m (the air slows it), flew %.1f" % [expect_far, flown])
	print("  level arrow: %.2f s, %.1f m (vacuum %.2f s, %.1f m)" % [got["t"], flown, expect_t, expect_far])
	# the shooter's own speed carries into the shot
	_park(a, 200.0, 0.0, 20.0)
	got = _shoot(race, a, b, level, 1.0, "bow", 3.0)
	flown = float(got["far"]) - 200.0
	check(flown > 70.0 * expect_t + 20.0 * expect_t * 0.9, "at 20 m/s the arrow should carry the horse's speed, flew %.1f" % flown)
	# half a draw falls shorter
	_park(a, 200.0, 0.0, 0.0)
	var half := _shoot(race, a, b, level, 0.3, "bow", 3.0)
	check(float(half["far"]) - 200.0 < 0.8 * (70.0 * expect_t), "a weak draw should fall well short, flew %.1f" % (float(half["far"]) - 200.0))
	race.free()


## Aim dead at a rider's chest at range and the shot drops under them. Aim higher and it hits. Close up, the drop doesn't matter.
func _compensation() -> void:
	for row: Array in [["bow", 45.0, false], ["bow", 15.0, true], ["sling", 26.0, false], ["sling", 10.0, true], ["roped_spear", 16.0, false], ["roped_spear", 9.0, true], ["roped_spear", 25.0, false]]:
		var weapon: String = row[0]
		var range_m: float = row[1]
		var race := _race()
		var a := race.riders[0]
		var b := race.riders[1]
		for o in race.riders:
			if o != a and o != b:
				_park(o, 2000.0, 8.0, 0.0)
		a.ranged_id = weapon
		_park(a, 300.0, 0.0, 20.0)
		_park(b, 300.0 + range_m, 0.0, 20.0)
		var hand := a.hand_point(race.track)
		var chest := race.track.point(b.s, b.d, 1.9)
		var straight := (chest - hand).normalized()
		var plain := _shoot(race, a, b, straight, 1.0, weapon, 2.0)
		var hit_plain := int(plain["hits"]) > 0
		check(hit_plain == bool(row[2]), "%s at %.0f m aimed dead on: expected %s, got %s" % [weapon, range_m, "hit" if row[2] else "miss", "hit" if hit_plain else "miss"])
		# aim as high as the drop is at that range, and the shot lands
		_park(a, 300.0, 0.0, 20.0)
		_park(b, 300.0 + range_m, 0.0, 20.0)
		b.invuln_t = 0.0
		var t := range_m / Race.launch_speed(weapon, 1.0)
		var high := (chest + Vector3.UP * 0.5 * Projectile.GRAVITY * t * t - hand).normalized()
		var aimed := _shoot(race, a, b, high, 1.0, weapon, 2.0)
		check(int(aimed["hits"]) > 0, "%s at %.0f m aimed above by the drop should hit" % [weapon, range_m])
		print("  %-12s %3.0f m: drop %.2f m. Aimed dead on: %s. Aimed above: %s" % [weapon, range_m, 0.5 * Projectile.GRAVITY * t * t, "hit" if hit_plain else "miss", "hit" if int(aimed["hits"]) > 0 else "miss"])
		race.free()


## The rope is as long as the roped spear's reach: aim as well as you like, a rider past the end of it is safe.
func _rope_length() -> void:
	var race := _race()
	var a := race.riders[0]
	var b := race.riders[1]
	for o in race.riders:
		if o != a and o != b:
			_park(o, 2000.0, 8.0, 0.0)
	var reach := float(GameData.WEAPONS["roped_spear"]["reach"])
	a.ranged_id = "roped_spear"
	_park(a, 300.0, 0.0, 20.0)
	_park(b, 300.0 + reach + 3.0, 0.0, 20.0)
	var hand := a.hand_point(race.track)
	var chest := race.track.point(b.s, b.d, 1.9)
	var t := (reach + 3.0) / Race.launch_speed("roped_spear", 1.0)
	var got := _shoot(race, a, b, (chest + Vector3.UP * 0.5 * Projectile.GRAVITY * t * t - hand).normalized(), 1.0, "roped_spear", 2.0)
	check(int(got["hits"]) == 0, "a roped spear shouldn't reach past %.0f m" % reach)
	race.free()


## Rivals use aim_for. With no error it must hit a target that is moving differently from the shooter.
func _moving_target() -> void:
	var cases := [
		["bow", 40.0, 0.0, 20.0, 24.0, 0.0], ["bow", 30.0, 6.0, 22.0, 18.0, -3.0], ["sling", 22.0, -4.0, 20.0, 21.0, 2.0], ["roped_spear", 14.0, 3.0, 20.0, 20.0, 0.0],
	]
	for row: Array in cases:
		var race := _race()
		var a := race.riders[0]
		var b := race.riders[1]
		for o in race.riders:
			if o != a and o != b:
				_park(o, 2000.0, 8.0, 0.0)
		var weapon: String = row[0]
		_park(a, 300.0, 0.0, float(row[3]))
		_park(b, 300.0 + float(row[1]), float(row[2]), float(row[4]))
		b.lateral = float(row[5])
		a.ranged_id = weapon
		var dir := race.aim_for(a.hand_point(race.track), a.world_velocity(race.track), Race.launch_speed(weapon, 1.0), b.s, b.d, 1.9, b.speed, b.lateral)
		var hits := [0]
		a.ranged_id = weapon
		a.fire_power = 1.0
		a.aim_dir = dir
		var cb := func(_a: Rider, v: Rider, _i: Dictionary) -> void:
			if v == b:
				hits[0] += 1
		race.rider_hit.connect(cb)
		race._fire(a)
		var p: Projectile = race.projectiles[race.projectiles.size() - 1]
		var t := 0.0
		var dt := 1.0 / 60.0
		while t < 2.0 and p.alive and not p.returning:
			a.s += a.speed * dt
			b.s += b.speed * dt
			b.d += b.lateral * dt
			race._step_projectiles(dt)
			t += dt
		check(int(hits[0]) > 0, "%s with a perfect solve should hit a moving target: %s" % [weapon, str(row)])
		race.free()


func _horse_is_safe() -> void:
	var race := _race()
	var a := race.riders[0]
	var b := race.riders[1]
	for o in race.riders:
		if o != a and o != b:
			_park(o, 2000.0, 8.0, 0.0)
	a.ranged_id = "bow"
	_park(a, 300.0, 0.0, 0.0)
	_park(b, 312.0, 0.0, 0.0)
	# a flat shot through the horse's legs, from low down: the rider is untouched
	var dir := (race.track.point(b.s, b.d, 0.6) - a.hand_point(race.track)).normalized()
	var low := _shoot(race, a, b, dir, 1.0, "bow", 2.0)
	check(int(low["hits"]) == 0 and is_equal_approx(float(low["damage"]), 0.0), "a shot at the horse must not count as a hit")
	# over the head misses as well
	_park(a, 300.0, 0.0, 0.0)
	dir = (race.track.point(b.s, b.d, 3.6) - a.hand_point(race.track)).normalized()
	var high := _shoot(race, a, b, dir, 1.0, "bow", 2.0)
	check(int(high["hits"]) == 0, "a shot over the head must miss")
	race.free()


func _draft_at(ds: float, dd: float, lead_speed: float) -> float:
	var race := _race()
	var a := race.riders[0]
	var b := race.riders[1]
	for o in race.riders:
		if o != a and o != b:
			_park(o, 2000.0, 8.0, 0.0)
	_park(a, 300.0, 0.0, 18.0)
	_park(b, 300.0 + ds, dd, lead_speed)
	for i in 240:
		race._update_draft(1.0 / 60.0)
	var v := a.draft
	race.free()
	return v


func _wind_trail() -> void:
	var near := _draft_at(5.0, 0.0, 20.0)
	var middle := _draft_at(30.0, 0.0, 20.0)
	var far := _draft_at(50.0, 0.0, 20.0)
	var beyond := _draft_at(58.0, 0.0, 20.0)
	var old_limit := _draft_at(14.5, 0.0, 20.0)
	print("  draft at 5 m %.2f, 14.5 m %.2f, 30 m %.2f, 50 m %.2f, 58 m %.2f" % [near, old_limit, middle, far, beyond])
	check(near > 0.8, "close behind should be nearly a full draft, got %.2f" % near)
	check(old_limit > 0.6, "at 14.5 m, past the old trail's end, should still be strong, got %.2f" % old_limit)
	check(middle > 0.35 and middle < near, "at 30 m should still help, got %.2f" % middle)
	check(far > 0.05 and far < middle, "at 50 m should be faint, got %.2f" % far)
	check(beyond < 0.001, "past the trail should be nothing, got %.3f" % beyond)
	check(_draft_at(10.0, 4.0, 20.0) < 0.001, "well to the side of the trail should be nothing")
	check(_draft_at(10.0, 0.0, 5.0) < 0.001, "a walking horse leaves no trail to speak of")


## Two equal horses at the same throttle, one 40 m behind the other. In the trail the rider behind closes up; out of it, it doesn't.
func _catch_up() -> void:
	var gaps := []
	for in_trail: bool in [true, false]:
		var race := _race()
		var a := race.riders[0]
		var b := race.riders[1]
		for o in race.riders:
			if o != a and o != b:
				_park(o, 2300.0, 8.0, 0.0)
		a.horse = b.horse
		_park(a, 300.0, 0.0, 20.0)
		_park(b, 340.0, 0.0 if in_trail else 8.0, 20.0)
		var it := Rider.Intent.new()
		it.throttle = 1.0
		var t := 0.0
		while t < 15.0:
			a.simulate(1.0 / 60.0, it, race.track)
			b.simulate(1.0 / 60.0, it, race.track)
			race._update_draft(1.0 / 60.0)
			t += 1.0 / 60.0
		gaps.append(b.s - a.s)
		race.free()
	print("  gap after 15 s, starting from 40 m: in the trail %.1f m, out of it %.1f m" % [gaps[0], gaps[1]])
	check(float(gaps[0]) < 40.0 - 8.0, "a rider in the trail should close at least 8 m in 15 s, gap %.1f" % gaps[0])
	check(absf(float(gaps[1]) - 40.0) < 1.5, "out of the trail the gap should hold, gap %.1f" % gaps[1])
