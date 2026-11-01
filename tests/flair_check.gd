extends Node
## Checks Flair's rules without a window: a near miss pays only for a clean pass at speed, an overtake is counted once,
## and knockdowns inside 25 s make a streak that pays through silver_bonus. Flair and Chatter are built by hand here,
## on a headless Race, which never makes them itself.
##   Godot --headless --path . --audio-driver Dummy res://tests/flair_check.tscn

const FlairScript := preload("res://scripts/race/flair.gd")

var failures := 0


func check(cond: bool, msg: String) -> void:
	print("  %s %s" % ["ok  " if cond else "FAIL", msg])
	if not cond:
		failures += 1


func make(events: Array) -> Race:
	var race := Race.new()
	race.headless = true
	race.auto_begin = false
	race.player_ai = true
	var course := Race.fallback_course()
	course["segments"] = [[1200, 0, 0]]
	course["events"] = events + [{"type": "start", "s": 14.0}, {"type": "finish", "s": 1100.0}]
	race.begin({"season": 0, "seed": 11, "course_override": course})
	race.countdown = 0.0
	race.started = true
	race.race_time = 10.0
	for r in race.riders:
		if r != race.player:
			r.state = "finished"
			r.finished = true
			r.s = 1000.0
	return race


func run_past(flair: Node, race: Race, d: float, speed: float) -> void:
	var p := race.player
	p.state = "ride"
	p.s = 90.0
	p.d = d
	p.speed = speed
	p.invuln_t = 0.0
	flair._prev_s = p.s
	var it := Rider.Intent.new()
	it.throttle = 0.6
	while p.s < 112.0 and p.is_riding():
		var prev := p.s
		p.simulate(1.0 / 60.0, it, race.track)
		p.speed = speed
		p.d = d
		race.hazards.check_rider(p, prev)
		race.race_time += 1.0 / 60.0
		flair._process(1.0 / 60.0)


func _ready() -> void:
	print("== flair rules")
	var boulder := {"type": "boulder", "s": 100.0, "d": 2.0, "size": 1.1}
	var edge := 1.1 * 1.25 + 0.6
	# 1. a clean pass 0.5 m off the boulder's edge pays once
	var race := make([boulder])
	var flair: Node = FlairScript.new()
	flair.bind(race)
	var words: Array[String] = []
	race.announcement.connect(func(t: String, _k: String) -> void: words.append(t))
	run_past(flair, race, 2.0 - edge - 0.5, 18.0)
	check(race.player.near_misses == 1 and race.player.silver_bonus == FlairScript.NEAR_SILVER, "a pass half a metre clear is a near miss (%d, silver %d)" % [race.player.near_misses, race.player.silver_bonus])
	check(words.size() == 1 and words[0].begins_with("CLOSE!"), "and calls CLOSE! once (%s)" % [words])
	flair.free()
	race.free()
	# 2. too wide, too slow and a hit pay nothing
	for case: Array in [[2.0 - edge - 2.5, 18.0, "two and a half metres clear"], [2.0 - edge - 0.5, 8.0, "at a trot"], [2.0, 18.0, "straight into it"]]:
		race = make([boulder])
		flair = FlairScript.new()
		flair.bind(race)
		run_past(flair, race, float(case[0]), float(case[1]))
		check(race.player.near_misses == 0, "no near miss %s" % case[2])
		flair.free()
		race.free()
	# 3. an overtake is counted once, then not again for ten seconds
	race = make([])
	flair = FlairScript.new()
	flair.bind(race)
	var p := race.player
	var rival: Rider = null
	for r in race.riders:
		if r != p:
			rival = r
			break
	rival.state = "ride"
	rival.finished = false
	p.state = "ride"
	p.invuln_t = 0.0
	rival.invuln_t = 0.0
	p.s = 200.0
	p.d = 0.0
	rival.s = 205.0
	rival.d = 0.5
	flair._process(1.0 / 60.0)
	p.s = 210.0
	flair._process(1.0 / 60.0)
	check(p.overtakes == 1, "passing a rival counts once (%d)" % p.overtakes)
	p.s = 200.0
	flair._process(1.0 / 60.0)
	p.s = 210.0
	flair._process(1.0 / 60.0)
	check(p.overtakes == 1, "trading places again at once does not count again (%d)" % p.overtakes)
	flair.free()
	race.free()
	# 4. knockdowns inside 25 s make a streak, a long gap starts again
	race = make([])
	flair = FlairScript.new()
	flair.bind(race)
	p = race.player
	var other: Rider = race.riders[0] if race.riders[0] != p else race.riders[1]
	var bounty := GameData.bounty(race.season)
	var calls: Array[String] = []
	race.announcement.connect(func(t: String, _k: String) -> void: calls.append(t))
	for k in 3:
		p.knockdowns += 1
		race.rider_crashed.emit(other, "impact")
		race.race_time += 8.0
	flair._process(0.5)
	flair._process(0.5)
	check(p.best_streak == 3, "three knockdowns 8 s apart are a streak of three (%d)" % p.best_streak)
	check(p.silver_bonus == int(round(bounty * 0.5)) + bounty, "the streak pays %d + %d silver (got %d)" % [int(round(bounty * 0.5)), bounty, p.silver_bonus])
	var heard := " ".join(calls)
	check(calls.size() == 2 and heard.contains("DOUBLE!") and heard.contains("TRIPLE!"), "and calls DOUBLE! and TRIPLE! (%s)" % [calls])
	race.race_time += 60.0
	p.knockdowns += 1
	race.rider_crashed.emit(other, "impact")
	check(p.best_streak == 3, "a knockdown a minute later starts again without lowering the best (%d)" % p.best_streak)
	flair.free()
	race.free()
	print("RESULT: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	get_tree().quit(0 if failures == 0 else 1)
