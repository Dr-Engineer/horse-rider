extends Node
## Plays whole races headless, with a Chatter attached (Race only makes one when it has visuals), and checks the pacing
## rules over everything that was said: one voice at a time, a gap between lines, a pause before the same rival speaks
## again, nobody beyond 40 m, and not a word but the steward's on Quiet Ground. Prints how much each race said.
##   Godot --headless --path . --audio-driver Dummy res://tests/chatter_check.tscn -- [races] [seed]

const ChatterScript := preload("res://scripts/race/chatter.gd")

var failures := 0


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("  FAIL: ", msg)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var n_races := int(args[0]) if args.size() > 0 else 6
	var seed0 := int(args[1]) if args.size() > 1 else 100
	var totals: Dictionary = {}
	var per_rival: Dictionary = {}
	var gaps: Array[float] = []
	for i in n_races:
		var season := i % 3
		var course := (i * 2 + 1) % 5      # 1, 3, 0, 2, 4, 1 ... so the Quiet Ground courses are in
		var race := Race.new()
		race.headless = true
		race.auto_begin = false
		race.player_ai = true
		race.begin({"season": season, "seed": seed0 + i, "course_index": course, "featured_rival": "wangyal", "grudges": {"karma": true}})
		var chatter: Node = ChatterScript.new()
		chatter.bind(race)
		chatter.set("trace", false)
		var heard: Array[Dictionary] = []
		race.chatter.connect(func(rider: Rider, line: Dictionary) -> void: heard.append({"rider": rider, "line": line}))
		var steps := 0
		while not race.ended and steps < 60 * 450:
			race.step(1.0 / 60.0)
			chatter._process(1.0 / 60.0)
			steps += 1
		var spoken: Array = chatter.get("spoken")
		var prev_end := -99.0
		var prev_start := -99.0
		var last_by: Dictionary = {}
		var rivals_this := 0
		for e: Dictionary in spoken:
			var at: float = e["at"]
			var cat: String = e["cat"]
			var who: String = e["speaker"]
			var prio: int = e["prio"]
			if who != "starter":
				check(at >= prev_end - 0.001, "race %d: %s/%s started at %.1f while the last line was still going until %.1f" % [i, who, cat, at, prev_end])
				if prev_start > -50.0:
					gaps.append(at - prev_start)
				check(at - prev_start >= 1.2 or prev_start < -50.0, "race %d: %s/%s only %.1f s after the last line began" % [i, who, cat, at - prev_start])
			if bool(e["rival"]):
				rivals_this += 1
				check(float(e["gap"]) <= 40.5 or cat == "win", "race %d: %s/%s spoke from %.0f m away" % [i, who, cat, float(e["gap"])])
				var since: float = at - float(last_by.get(who, -99.0))
				check(since >= 6.4 or prio >= 5, "race %d: %s said %s only %.1f s after they last spoke" % [i, who, cat, since])
				last_by[who] = at
				per_rival[who] = int(per_rival.get(who, 0)) + 1
			check(not (bool(e["quiet"]) and who != "steward" and who != "starter"), "race %d: %s/%s spoke on Quiet Ground" % [i, who, cat])
			prev_end = at + float(e["dur"])
			prev_start = at
			totals[cat] = int(totals.get(cat, 0)) + 1
		var with_text := 0
		for e2: Dictionary in spoken:
			if bool(e2["subtitle"]):
				with_text += 1
		check(heard.size() == with_text, "race %d: %d lines should have a subtitle but %d were sent" % [i, with_text, heard.size()])
		print("race %d (season %d, %s, %.0f s): %d lines, %d from rivals" % [i, season, race.course.get("name", "?"), race.race_time, spoken.size(), rivals_this])
		chatter.free()
		race.free()
	# the steward is the one voice that speaks on Quiet Ground: a call on entering it, and one for a fine
	var race := Race.new()
	race.headless = true
	race.auto_begin = false
	race.player_ai = true
	race.begin({"season": 1, "seed": 5, "course_index": 3})
	var chatter: Node = ChatterScript.new()
	chatter.bind(race)
	race.countdown = 0.0
	race.started = true
	race.race_time = 30.0
	var calls: Array[String] = []
	race.chatter.connect(func(rider: Rider, line: Dictionary) -> void: calls.append("%s/%s" % [line.get("speaker", "?"), "no rider" if rider == null else "rider"]))
	race.player.in_quiet = true
	race.rider_event.emit("quiet_enter", race.player, {})
	for k in 500:
		race.race_time += 0.01
		chatter._process(0.01)
	race.rider_event.emit("h_fined", race.player, {"amount": 90})
	for k in 500:
		race.race_time += 0.01
		chatter._process(0.01)
	check(calls == ["steward/no rider", "steward/no rider"], "the steward calls once on entering Quiet Ground and once for a fine (%s)" % [calls])
	chatter.free()
	race.free()
	var avg_gap := 0.0
	for g in gaps:
		avg_gap += g
	print("lines by kind: ", totals)
	print("lines per rival: ", per_rival)
	print("average time between one line and the next: %.1f s" % (avg_gap / maxf(float(gaps.size()), 1.0)))
	print("RESULT: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	get_tree().quit(0 if failures == 0 else 1)
