extends Node
## Checks what stands beside the road: a bullseye pays by the ring and only once, a wolf pays and runs off, a sheep costs a fine
## and is fine itself, a blow counts from the rough but not from the road, the rough really is slower, and rivals earn nothing.
## Usage: Godot --headless --path . --audio-driver Dummy res://tests/roadside_check.tscn

const HW := 6.0
const FLOCK_S := 500.0

var failures := 0


func _ready() -> void:
	_rings()
	_once_only()
	_wolf()
	_sheep()
	_blows()
	_rivals()
	_pays_by_season()
	_courses()
	print("RESULT: %s (%d)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("  FAIL: " + what)


func _race(season: int = 0) -> Race:
	var c := Race.fallback_course()
	c["segments"] = [[2400, 0, 0]]
	c["half_width"] = HW
	c["events"] = [
		{"type": "start", "s": 14.0}, {"type": "finish", "s": 2300.0},
		{"type": "bullseye", "s": 300.0, "d": HW + Courses.BULLSEYE_OUT},
		{"type": "wolf_flock", "s": FLOCK_S, "d": -(HW + Courses.FLOCK_OUT), "sheep": 3, "wolves": 1},
		{"type": "sheep", "s": 800.0, "d": 0.0, "count": 4, "dir": 1, "speed": 0.0},
	]
	var race := Race.new()
	race.headless = true
	race.auto_begin = false
	race.player_ai = true
	add_child(race)
	race.begin({"season": season, "seed": 5, "course_override": c})
	race.countdown = 0.0
	race.started = true
	for r in race.riders:
		r.state = "finished"
		r.s = 2200.0
	return race


func _shooter(race: Race, s: float, d: float, player := true) -> Rider:
	var r := race.player
	if not player:
		r = race.riders[0] if race.riders[0] != race.player else race.riders[1]
	r.state = "ride"
	r.s = s
	r.d = d
	r.speed = 0.0
	r.lateral = 0.0
	r.ranged_id = "bow"
	r.fire_power = 1.0
	return r


## Looses an arrow at a world point allowing for the drop, and flies it until it's done. The animals hold still for it.
func _loose(race: Race, r: Rider, at: Vector3) -> void:
	var hand := r.hand_point(race.track)
	var muzzle := Race.launch_speed("bow", 1.0)
	var t := hand.distance_to(at) / muzzle
	for i in 3:
		var aim_v := at - hand + Vector3.UP * 0.5 * Projectile.GRAVITY * t * t
		t = aim_v.length() / muzzle
	r.aim_dir = (at - hand + Vector3.UP * 0.5 * Projectile.GRAVITY * t * t).normalized()
	race._fire(r)
	var p: Projectile = race.projectiles[race.projectiles.size() - 1]
	var steps := 0
	while p.alive and steps < 240:
		race._step_projectiles(1.0 / 60.0)
		steps += 1


func _rings() -> void:
	var race := _race()
	var board: Roadside.Board = race.roadside.boards[0]
	var r := _shooter(race, 270.0, 0.0)
	var up := board.normal.cross(Vector3.RIGHT).normalized()
	for row: Array in [[0.0, 20], [0.5, 10], [0.9, 5], [1.3, 0]]:
		board.scored = false
		r.silver_bonus = 0
		_loose(race, r, board.centre + Vector3.UP * float(row[0]))
		check(r.silver_bonus == int(row[1]), "a shot %.1f m above the middle of a board should pay %d, paid %d" % [row[0], row[1], r.silver_bonus])
	print("  board: middle pays %d, inner ring %d, outer ring %d, off the board nothing" % [Roadside.RING_SILVER[2], Roadside.RING_SILVER[1], Roadside.RING_SILVER[0]])
	race.free()


func _once_only() -> void:
	var race := _race()
	var board: Roadside.Board = race.roadside.boards[0]
	var r := _shooter(race, 270.0, 0.0)
	_loose(race, r, board.centre)
	var first := r.silver_bonus
	r.recover_t = 0.0
	_loose(race, r, board.centre)
	check(first == 20 and r.silver_bonus == first, "a board pays once: %d then %d" % [first, r.silver_bonus])
	race.free()


func _flock_animal(race: Race, kind: String) -> Roadside.Beast:
	for b: Roadside.Beast in race.roadside.flocks[0].beasts:
		if b.kind == kind:
			return b
	return null


func _wolf() -> void:
	var race := _race()
	var wolf := _flock_animal(race, "wolf")
	var r := _shooter(race, FLOCK_S - 25.0, -HW)
	# everyone else clear of the line of fire
	for b: Roadside.Beast in race.roadside.flocks[0].beasts:
		if b != wolf:
			b.s = FLOCK_S + 40.0
			race.roadside._locate(b)
	_loose(race, r, wolf.pos + Vector3.UP * 0.7)
	check(r.silver_bonus == Roadside.WOLF_SILVER, "a wolf should pay %d, paid %d" % [Roadside.WOLF_SILVER, r.silver_bonus])
	check(r.fines == 0, "a wolf costs no fine")
	check(wolf.state == "flee" and not wolf.gone, "a wolf that's hit runs, it doesn't die on the spot")
	var d0 := absf(wolf.d)
	for i in 60:
		race.roadside.update(1.0 / 60.0)
	check(absf(wolf.d) > d0 + 5.0, "it runs away from the road (%.1f to %.1f)" % [d0, absf(wolf.d)])
	for i in 180:
		race.roadside.update(1.0 / 60.0)
	check(wolf.gone, "a wolf that ran off is gone")
	# a flock with no wolves left grazes on without any trouble
	race.free()


func _sheep() -> void:
	var race := _race()
	var sheep := _flock_animal(race, "sheep")
	var r := _shooter(race, FLOCK_S - 25.0, -HW)
	for b: Roadside.Beast in race.roadside.flocks[0].beasts:
		if b != sheep:
			b.s = FLOCK_S + 40.0
			race.roadside._locate(b)
	_loose(race, r, sheep.pos + Vector3.UP * 0.7)
	check(r.fines == Roadside.SHEEP_FINE, "a sheep should cost %d, cost %d" % [Roadside.SHEEP_FINE, r.fines])
	check(r.silver_bonus == 0, "a sheep pays nothing")
	check(sheep.state == "bolt" and not sheep.gone, "a sheep that's hit bolts and lives")
	# and a sheep on the road counts the same
	r.s = 780.0
	r.d = 0.0
	r.fines = 0
	var road: Dictionary = {}
	for m in race.hazards.movers:
		if m["kind"] == "sheep":
			road = m
			break
	_loose(race, r, race.track.point(float(road["s"]), float(road["d"]), 0.7))
	check(r.fines == Roadside.SHEEP_FINE, "a sheep on the road costs the same, cost %d" % r.fines)
	race.free()


## A blow reaches the board from the rough, and not from the road. And the rough is slow enough to think about.
func _blows() -> void:
	var race := _race()
	var board: Roadside.Board = race.roadside.boards[0]
	var r := _shooter(race, board.s, HW)
	r.ranged_id = ""
	r.weapon_id = "sword"
	r._start_swing(1, "melee")
	r.swing_t = r.swing_hit_t
	race._resolve_swing(r)
	check(r.silver_bonus == 0, "a sword can't reach a board from the road (paid %d)" % r.silver_bonus)
	r.d = HW + 3.6
	r.swing_done = false
	race._resolve_swing(r)
	check(r.silver_bonus == Roadside.STRUCK_SILVER, "a sword reaches a board from the rough (paid %d)" % r.silver_bonus)
	# the other side reaches nothing
	board.scored = false
	r.silver_bonus = 0
	r._start_swing(-1, "melee")
	r.swing_t = r.swing_hit_t
	race._resolve_swing(r)
	check(r.silver_bonus == 0, "a blow to the left can't reach a board on the right")
	race.free()
	# ride out there and see what it costs: a pair of equal horses, one on the road and one in the rough
	race = _race()
	var a := race.riders[0]
	var b := race.riders[1]
	for o in [a, b]:
		o.state = "ride"
		o.s = 100.0
		o.speed = 20.0
		o.horse = GameData.HORSES["old_tsampa"]
	a.d = 0.0
	b.d = HW + 3.6
	var it := Rider.Intent.new()
	it.throttle = 1.0
	for i in 180:
		a.simulate(1.0 / 60.0, it, race.track)
		b.simulate(1.0 / 60.0, it, race.track)
	print("  3 s flat out: on the road %.0f m at %.1f m/s, in the rough %.0f m at %.1f m/s" % [a.s - 100.0, a.speed, b.s - 100.0, b.speed])
	check(b.speed < a.speed * 0.72 and b.is_riding(), "the rough should cost real speed but not throw: %.1f against %.1f" % [b.speed, a.speed])
	race.free()


func _rivals() -> void:
	var race := _race()
	var board: Roadside.Board = race.roadside.boards[0]
	var r := _shooter(race, 270.0, 0.0, false)
	_loose(race, r, board.centre)
	check(r.silver_bonus == 0 and not board.scored, "a rival's shot earns nothing and leaves the board for the player")
	var sheep := _flock_animal(race, "sheep")
	r.s = FLOCK_S - 25.0
	r.d = -HW
	for b: Roadside.Beast in race.roadside.flocks[0].beasts:
		if b != sheep:
			b.s = FLOCK_S + 40.0
			race.roadside._locate(b)
	_loose(race, r, sheep.pos + Vector3.UP * 0.7)
	check(r.fines == 0 and sheep.state == "bolt", "a rival's stray shot scares a sheep and costs them nothing")
	race.free()


func _pays_by_season() -> void:
	var race := _race(2)
	var board: Roadside.Board = race.roadside.boards[0]
	var r := _shooter(race, 270.0, 0.0)
	_loose(race, r, board.centre)
	check(r.silver_bonus == 40, "in Season 3 a bullseye pays double: %d" % r.silver_bonus)
	race.free()


## Every real course has some of each, off the road, and they're all reachable from the road by a shot.
func _courses() -> void:
	for index in Courses.count():
		for season in 3:
			var c := Courses.get_course(index, season)
			var t := Track.new()
			t.build(c["segments"], c["half_width"])
			var boards := 0
			var flocks := 0
			for e: Dictionary in c["events"]:
				var kind := String(e["type"])
				if kind == "bullseye" or kind == "wolf_flock":
					if kind == "bullseye":
						boards += 1
					else:
						flocks += 1
					var clear := absf(float(e["d"])) - t.half_width_at(float(e["s"]))
					check(clear >= Courses.BULLSEYE_OUT - 0.5, "%s S%d: a %s only %.1f m off the road" % [c["id"], season + 1, kind, clear])
			check(boards >= 3 and flocks >= 1, "%s S%d: %d boards and %d flocks" % [c["id"], season + 1, boards, flocks])
			if season == 0 or season == 2:
				print("  %-24s S%d: %2d boards, %d flocks" % [c["id"], season + 1, boards, flocks])
