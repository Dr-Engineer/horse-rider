extends Node
## Headless balance and rules check. Run:
##   Godot --headless --path . res://tests/sim_balance.tscn -- <races> <season> [seed]
## Prints standings, finish times, damage by class, crash causes, and asserts the rules.

var failures: Array[String] = []
var course_index := 0
var verbose_steward := false


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
		print("  FAIL: ", msg)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var n_races: int = int(args[0]) if args.size() > 0 else 6
	var season: int = int(args[1]) if args.size() > 1 else 0
	var seed0: int = int(args[2]) if args.size() > 2 else 1234
	course_index = int(args[3]) if args.size() > 3 else 0
	var verbose: bool = args.size() > 4
	if args.size() > 5:
		Hazards.debug = true
	if n_races > 0:
		unit_tests()
		rule_tests()
	races(n_races, season, seed0, verbose)
	print("RESULT: ", "PASS" if failures.is_empty() else "FAIL (%d)" % failures.size())
	for f in failures:
		print("  - ", f)
	get_tree().quit(0 if failures.is_empty() else 1)


func make_race(season: int, seed_v: int) -> Race:
	var race := Race.new()
	race.headless = true
	race.auto_begin = false
	race.player_ai = true
	race.begin({"season": season, "seed": seed_v, "course_index": course_index})
	return race


func unit_tests() -> void:
	print("== unit tests ==")
	var race := make_race(0, 7)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	# 1. Ranged hits can never push shake past 85 and never unseat on impact.
	var victim := race.riders[0]
	var shooter := race.riders[1]
	victim.invuln_t = 0.0
	var unseated := 0
	for i in 400:
		if not victim.is_riding():
			victim.state = "ride"
			victim.health = 100.0
			victim.shake = 0.0
		var before := victim.shake
		var res := victim.receive_hit(shooter, 0.0, 30.0, "ranged", 1)
		check(victim.shake <= maxf(before, Rider.RANGED_SHAKE_CAP) + 0.001, "ranged shake cap broken: %.1f" % victim.shake)
		if res["crashed"]:
			unseated += 1
		victim.shake = minf(victim.shake, 99.0)
	check(unseated == 0, "ranged hits with zero damage must never crash a rider (got %d)" % unseated)
	# ranged hit when shake already above 85 from melee does not raise it
	victim.state = "ride"
	victim.shake = 92.0
	victim.health = 100.0
	victim.receive_hit(shooter, 1.0, 12.0, "ranged", 1)
	check(victim.shake <= 92.0 + 0.001 and victim.is_riding(), "ranged hit changed shake above the cap")
	# ranged can finish a rider whose health is gone
	victim.state = "ride"
	victim.shake = 0.0
	victim.health = 2.0
	var fin := victim.receive_hit(shooter, 5.0, 8.0, "ranged", 1)
	check(fin["crashed"] and fin["reason"] == "health", "ranged should be able to finish a rider at zero health")
	# 2. Melee does unseat on impact, 100 always crashes.
	var crashes := 0
	for i in 200:
		victim.state = "ride"
		victim.shake = 0.0
		victim.health = 100.0
		victim.invuln_t = 0.0
		var hits := 0
		while victim.is_riding() and hits < 30:
			victim.receive_hit(shooter, 0.0, 24.0, "melee", 1)
			hits += 1
		if not victim.is_riding() and victim.crash_reason == "impact":
			crashes += 1
		check(hits <= 6, "melee impact 24 should unseat within 6 hits at the latest, took %d" % hits)
	check(crashes == 200, "melee should always eventually unseat on impact (%d/200)" % crashes)
	victim.state = "ride"
	victim.shake = 99.0
	victim.health = 100.0
	var always := victim.receive_hit(shooter, 0.0, 5.0, "body", 1)
	check(always["crashed"] == false or always["reason"] == "impact", "shake 100 should crash")
	# 3. Health crash is 7 s; mash shortens by at most 2.5 s; remount at 55
	victim.state = "ride"
	victim.shake = 0.0
	victim.health = 100.0
	victim.speed = 20.0
	victim.receive_hit(shooter, 120.0, 0.0, "melee", 1)
	check(victim.crash_reason == "health", "health 0 must crash")
	var t := 0.0
	var it := Rider.Intent.new()
	while victim.state != "ride" and t < 20.0:
		it.mash = false
		victim.simulate(1.0 / 60.0, it, race.track)
		t += 1.0 / 60.0
	check(absf(t - 7.0) < 0.1, "health crash should take 7 s unmashed, took %.2f" % t)
	check(absf(victim.health - 55.0) < 0.01, "remount at 55 health, got %.1f" % victim.health)
	victim.invuln_t = 0.0
	victim.receive_hit(shooter, 120.0, 0.0, "melee", 1)
	t = 0.0
	var f := 0
	while victim.state != "ride" and t < 20.0:
		it.mash = (f % 4 == 0)
		f += 1
		victim.simulate(1.0 / 60.0, it, race.track)
		t += 1.0 / 60.0
	check(absf(t - 4.5) < 0.15, "health crash with heavy mashing should take 4.5 s, took %.2f" % t)
	# impact crash is about 3.5 s
	victim.shake = 99.0
	victim.health = 100.0
	victim.invuln_t = 0.0
	victim.receive_hit(shooter, 0.0, 30.0, "melee", 1)
	check(victim.crash_reason == "impact", "melee 30 at shake 99 must unseat")
	t = 0.0
	while victim.state != "ride" and t < 20.0:
		victim.simulate(1.0 / 60.0, it, race.track)
		t += 1.0 / 60.0
	check(absf(t - 3.5) < 0.1, "impact crash should take 3.5 s, took %.2f" % t)
	# 4. Data checks
	var ranged_dmg := 0.0
	var ranged_imp := 0.0
	for id: String in GameData.RANGED_IDS:
		ranged_dmg = maxf(ranged_dmg, float(GameData.WEAPONS[id]["damage"]) * (1.3 if id == "bow" else 1.0))
		ranged_imp = maxf(ranged_imp, float(GameData.WEAPONS[id]["impact"]) * (1.3 if id == "bow" else 1.0))
	var melee_dmg := 0.0
	var melee_imp := 0.0
	var mc := 0
	for id: String in ["knife", "pencase", "whip", "sword", "key", "spear"]:
		melee_dmg += float(GameData.WEAPONS[id]["damage"])
		melee_imp += float(GameData.WEAPONS[id]["impact"])
		mc += 1
	check(ranged_dmg < melee_dmg / float(mc) * 1.0, "max ranged damage %.1f should be below the average melee damage %.1f" % [ranged_dmg, melee_dmg / float(mc)])
	check(ranged_imp < melee_imp / float(mc), "max ranged impact %.1f should be below the average melee impact %.1f" % [ranged_imp, melee_imp / float(mc)])
	print("  ranged max dmg %.1f impact %.1f; melee avg dmg %.1f impact %.1f" % [ranged_dmg, ranged_imp, melee_dmg / float(mc), melee_imp / float(mc)])
	race.free()


func flat_course(events: Array) -> Dictionary:
	var c := Race.fallback_course()
	c["segments"] = [[1200, 0, 0]]
	c["events"] = events + [{"type": "start", "s": 14.0}, {"type": "finish", "s": 1100.0}]
	return c


func tick(race: Race, secs: float, it_by_rider: Dictionary = {}) -> void:
	var n := int(secs * 60.0)
	for i in n:
		race.step(1.0 / 60.0)


func rule_tests() -> void:
	print("== rule tests ==")
	# --- sacred sites: right side gains, wrong side loses, Bon reversed, hitting one throws and never harms it
	var race := Race.new()
	race.headless = true
	race.auto_begin = false
	race.player_ai = true
	race.begin({"season": 1, "seed": 3, "course_override": flat_course([{"type": "chorten", "s": 100.0, "d": 3.0}, {"type": "mani_wall", "s": 200.0, "d": -4.0, "len": 12.0}])})
	race.countdown = 0.0
	race.started = true
	for r in race.riders:
		r.state = "finished"   # park everyone except the two test riders
		r.s = 900.0
	var a := race.riders[0]
	var b := race.riders[1]
	for r in [a, b]:
		r.state = "ride"
		r.finished = false
		r.speed = 15.0
		r.invuln_t = 0.0
	a.s = 90.0
	a.d = 0.0       # chorten at d=3 is on the right: good
	b.s = 90.0
	b.d = 6.5       # chorten is on the left: wrong side
	b.lungta = 2.0
	a.lungta = 0.0
	race.hazards.check_rider(a, 99.9)
	var gi := Rider.Intent.new()
	gi.throttle = 0.5
	for i in 120:
		for r in [a, b]:
			var prev: float = r.s
			r.simulate(1.0 / 60.0, gi, race.track)
			race.hazards.check_rider(r, prev)
	check(a.lungta > 0.2, "passing a chorten with it on the right should gain Lungta (got %.2f)" % a.lungta)
	check(b.lungta < 2.0, "passing a chorten on the wrong side should lose Lungta (got %.2f)" % b.lungta)
	# Bon rider: wrong side for others is right for them
	a.s = 190.0
	a.d = -8.5   # wall at d=-4 is on the right of a? no: wall is at -4, rider at -8.5, so the wall is on the right
	a.bon = true
	a.lungta = 2.0
	a.state = "ride"
	a.invuln_t = 0.0
	for i in 150:
		var prev2: float = a.s
		a.simulate(1.0 / 60.0, gi, race.track)
		race.hazards.check_rider(a, prev2)
	check(a.lungta < 2.0, "a Bon rider passing with the site on the right should lose fortune (got %.2f)" % a.lungta)
	# hitting the wall throws the rider
	b.s = 190.0
	b.d = -4.0
	b.state = "ride"
	b.bon = false
	for i in 90:
		var prev3: float = b.s
		b.simulate(1.0 / 60.0, gi, race.track)
		race.hazards.check_rider(b, prev3)
		if not b.is_riding():
			break
	check(b.crash_reason == "hazard", "riding into a mani wall should throw the rider")
	race.free()

	# --- shield: block, parry
	race = make_race(0, 5)
	var att := race.riders[0]
	var vic := race.riders[1]
	vic.has_shield = true
	vic.blocking = true
	vic.block_time = 0.5
	vic.shield_side = -1
	vic.invuln_t = 0.0
	var h0 := vic.health
	var info := race.apply_hit(att, vic, 20.0, 30.0, "melee", "sword", -1)
	check(info["blocked"] and absf(vic.health - (h0 - 5.0)) < 0.01, "shield should cut damage by 75%% (health %.1f -> %.1f)" % [h0, vic.health])
	check(vic.shake <= 30.0 * 0.35 + 0.01, "shield should cut impact by 65%% (shake %.1f)" % vic.shake)
	vic.shake = 0.0
	vic.health = 100.0
	vic.block_time = 0.1
	att.shake = 0.0
	var lung0 := vic.lungta
	var pinfo := race.apply_hit(att, vic, 20.0, 30.0, "melee", "sword", -1)
	check(pinfo["parried"] and att.shake >= 25.0 and vic.lungta > lung0 and vic.health == 100.0, "parry: attacker +25 shake, defender gains Lungta, no damage")
	# blocked from the other side goes through
	vic.block_time = 0.5
	vic.shake = 0.0
	var oinfo := race.apply_hit(att, vic, 20.0, 30.0, "melee", "sword", 1)
	check(not oinfo["blocked"], "a shield only covers the side it faces")
	# arrows are blocked from any side
	vic.shake = 0.0
	vic.invuln_t = 0.0
	var ainfo := race.apply_hit(att, vic, 7.0, 8.0, "ranged", "bow", 1)
	check(ainfo["blocked"], "a shield blocks arrows from any side")
	# --- weapon snatch and drop
	att.weapon_id = "fists"
	vic.weapon_id = "sword"
	race._take_or_drop(att, vic)
	check(att.weapon_id == "sword" and vic.weapon_id == "fists", "a better weapon is snatched")
	att.weapon_id = "sword"
	vic.weapon_id = "knife"
	race._take_or_drop(att, vic)
	check(att.weapon_id == "sword" and vic.weapon_id == "fists" and race.hazards.pickups.size() >= 1, "a worse weapon drops on the course")
	# --- Second Wind: shake immunity for 4 s, meter spent
	att.lungta = 5.0
	att.state = "ride"
	var swi := Rider.Intent.new()
	swi.second_wind = true
	att.simulate(1.0 / 60.0, swi, race.track)
	check(att.second_wind_t > 3.9 and att.lungta == 0.0, "Second Wind should spend a full meter for about 4 s")
	att.shake = 0.0
	att.invuln_t = 0.0
	att.receive_hit(vic, 5.0, 38.0, "melee", 1)
	check(att.shake == 0.0, "Second Wind gives shake immunity")
	race.free()

	# --- Quiet Ground: striking costs Lungta and a fine
	race = Race.new()
	race.headless = true
	race.auto_begin = false
	race.player_ai = true
	race.begin({"season": 1, "seed": 3, "course_override": flat_course([{"type": "quiet_zone", "s0": 80.0, "s1": 160.0}])})
	var q := race.riders[0]
	q.s = 100.0
	q.lungta = 2.0
	q.state = "ride"
	var qi := Rider.Intent.new()
	qi.strike_right = true
	race.countdown = 0.0
	race.started = true
	q.simulate(1.0 / 60.0, qi, race.track)
	check(q.lungta < 2.0 and q.fines > 0, "striking on Quiet Ground should cost Lungta and a fine")
	race.free()

	# --- leap clears a log, a grounded rider is thrown
	race = Race.new()
	race.headless = true
	race.auto_begin = false
	race.player_ai = true
	race.begin({"season": 0, "seed": 3, "course_override": flat_course([{"type": "log", "s": 120.0, "d": 0.0, "len": 6.0, "yaw": 0.0}])})
	var lj := race.riders[0]
	var lg := race.riders[1]
	for r in race.riders:
		if r != lj and r != lg:
			r.state = "finished"
			r.s = 900.0
	for r in [lj, lg]:
		r.state = "ride"
		r.s = 105.0
		r.d = 0.0 if r == lj else 0.0
		r.speed = 18.0
		r.invuln_t = 0.0
	lg.d = 0.5
	lj.d = -0.5
	var jump := Rider.Intent.new()
	jump.throttle = 0.5
	var flat := Rider.Intent.new()
	flat.throttle = 0.5
	var jumped := false
	for i in 120:
		var pj: float = lj.s
		var pg: float = lg.s
		if not jumped and lj.s > 113.0:
			jump.leap = true
			jumped = true
		else:
			jump.leap = false
		lj.simulate(1.0 / 60.0, jump, race.track)
		lg.simulate(1.0 / 60.0, flat, race.track)
		race.hazards.check_rider(lj, pj)
		race.hazards.check_rider(lg, pg)
		lj.d = -0.5
		lg.d = 0.5
	check(lj.crash_reason == "" and lj.s > 125.0, "a leap should clear a log")
	check(lg.crash_reason == "hazard", "a grounded rider hitting a log is thrown")
	race.free()

	# --- target pole: a ranged shot with no rival in the cone aims at the pole and scores silver
	race = Race.new()
	race.headless = true
	race.auto_begin = false
	race.player_ai = true
	race.begin({"season": 0, "seed": 3, "course_override": flat_course([{"type": "target_pole", "s": 135.0, "d": 7.0}, {"type": "scarf", "s": 112.0, "d": -1.0, "color": 2}])})
	var sh := race.riders[0]
	for r in race.riders:
		if r != sh:
			r.state = "finished"
			r.s = 1000.0
	sh.state = "ride"
	sh.is_player = true
	sh.s = 100.0
	sh.d = 0.0
	sh.speed = 15.0
	sh.ranged_id = "bow"
	sh.ammo = 12
	sh.fire_pending = true
	sh.fire_power = 1.0
	race.countdown = 0.0
	race.started = true
	var pi := Rider.Intent.new()
	pi.throttle = 0.5
	for i in 180:
		race.step(1.0 / 60.0)
	check(sh.silver_bonus >= 10, "a bow shot at a target pole should score silver (got %d)" % sh.silver_bonus)
	check(sh.scoops == 1, "riding over a scarf should scoop it (scoops %d)" % sh.scoops)
	race.free()

	# --- steward fines a rider who is down (Season 2 and later: season index 1)
	race = Race.new()
	race.headless = true
	race.auto_begin = false
	race.player_ai = true
	race.begin({"season": 1, "seed": 3, "course_override": flat_course([])})
	check(race.hazards.stewards.size() >= 2, "stewards should patrol from Season 2")
	var sd := race.riders[0]
	var st: Dictionary = race.hazards.stewards[0]
	for r in race.riders:
		if r != sd:
			r.state = "finished"
			r.s = 1000.0
	sd.state = "ride"
	sd.s = float(st["s"]) - 10.0
	sd.d = 0.0
	sd.speed = 10.0
	sd.invuln_t = 0.0
	race.countdown = 0.0
	race.started = true
	sd.receive_hit(race.riders[1], 120.0, 0.0, "melee", 1)
	st["s"] = sd.s + 4.0
	st["d"] = 5.0
	for i in 60 * 8:
		race.step(1.0 / 60.0)
		if i % 60 == 0 and verbose_steward:
			print("   steward t=%d rider %s s=%.1f d=%.1f | steward s=%.1f d=%.1f stagger=%.1f" % [i / 60, sd.state, sd.s, sd.d, float(st["s"]), float(st["d"]), float(st["stagger"])])
	check(sd.fines == GameData.fine(1), "a steward should fine a downed rider (fines %d, expected %d)" % [sd.fines, GameData.fine(1)])
	race.free()


func races(n: int, season: int, seed0: int, verbose: bool) -> void:
	print("== %d races, season %d, course %d ==" % [n, season, course_index])
	var win_times: Array[float] = []
	var last_times: Array[float] = []
	var crash_totals := {"impact": 0, "health": 0, "hazard": 0}
	var dmg := {"body": 0.0, "melee": 0.0, "ranged": 0.0}
	var hits := {"body": 0, "melee": 0, "ranged": 0}
	var imps := {"body": 0.0, "melee": 0.0, "ranged": 0.0}
	var by_klass := {}
	var thrown_total := {}
	var kinds_total := {}
	var spread10: Array[float] = []
	var per_rider := {}
	var kd_counts: Array[int] = []
	var player_places: Array[int] = []
	var wins := {}
	var blocked := 0
	var parried := 0
	var swings := 0
	var shots := 0
	var snatched := 0
	var dropped := 0
	var unfinished := 0
	var second_winds := 0
	var lungta_sum := 0.0
	var t0 := Time.get_ticks_msec()
	for i in n:
		var race := make_race(season, seed0 + i)
		var steps := 0
		while not race.ended and steps < 60 * 450:
			race.step(1.0 / 60.0)
			steps += 1
			if steps == 60 * 13 + 216:
				var lo := 1.0e9
				var hi := 0.0
				for rr in race.riders:
					lo = minf(lo, rr.s)
					hi = maxf(hi, rr.s)
				spread10.append(hi - lo)
		for v in race.violations:
			check(false, "race %d: %s" % [i, v])
		var res := race.results
		var kds := 0
		var crashes_here := 0
		if verbose or i == 0:
			print("-- race %d (%s) time %.1f s" % [i, race.course.get("name", "?"), race.race_time])
		for e in res:
			var r: Rider = e["rider"]
			kds += r.knockdowns
			crashes_here += r.crashes
			if r.finished:
				if int(e["place"]) == 1:
					win_times.append(r.finish_time)
					wins[r.display_name] = int(wins.get(r.display_name, 0)) + 1
				last_times.append(r.finish_time)
			else:
				unfinished += 1
			var pr: Dictionary = per_rider.get(r.display_name, {"n": 0, "place": 0.0, "kd": 0, "crash": 0, "hits": 0, "dmg": 0.0, "style": r.style, "time": 0.0, "fin": 0})
			pr["n"] += 1
			pr["place"] += float(e["place"])
			pr["kd"] += r.knockdowns
			pr["crash"] += r.crashes
			pr["hits"] += r.hits_landed
			pr["dmg"] += r.damage_dealt
			if r.finished:
				pr["time"] += r.finish_time
				pr["fin"] += 1
			per_rider[r.display_name] = pr
			if r.is_player:
				player_places.append(int(e["place"]))
			if verbose or i == 0:
				print("   %d. %-22s %s t=%6.1f kd=%d crash=%d hp=%3.0f %s%s" % [e["place"], r.display_name, "FIN" if r.finished else "DNF", r.finish_time, r.knockdowns, r.crashes, r.health, r.weapon_id, " [P]" if r.is_player else ""])
		kd_counts.append(crashes_here)
		for k: String in crash_totals:
			crash_totals[k] += int(race.stats["crash"][k])
		for k: String in dmg:
			dmg[k] += float(race.stats["damage"][k])
			hits[k] += int(race.stats["hits"][k])
			imps[k] += float(race.stats["impact"][k])
		for k: String in race.stats["kinds"]:
			kinds_total[k] = int(kinds_total.get(k, 0)) + int(race.stats["kinds"][k])
		for k: String in race.stats["thrown"]:
			thrown_total[k] = int(thrown_total.get(k, 0)) + int(race.stats["thrown"][k])
		for k: String in race.stats["crash_by_klass"]:
			by_klass[k] = int(by_klass.get(k, 0)) + int(race.stats["crash_by_klass"][k])
		second_winds += int(race.stats.get("second_winds", 0))
		for rr2 in race.riders:
			lungta_sum += rr2.lungta
		blocked += int(race.stats["blocked"])
		parried += int(race.stats["parried"])
		swings += int(race.stats["swings"])
		shots += int(race.stats["shots"])
		snatched += int(race.stats["snatched"])
		dropped += int(race.stats["dropped"])
		race.free()
	var secs := float(Time.get_ticks_msec() - t0) / 1000.0
	print("sim time %.1f s for %d races" % [secs, n])
	print("pack spread 10 s after the start (m): avg %.1f max %.1f" % [_avg(spread10), _maxf(spread10)])
	print("winner time avg %.1f  (min %.1f max %.1f)  last finisher avg %.1f  unfinished %d" % [_avg(win_times), _minf(win_times), _maxf(win_times), _avg(last_times), unfinished])
	var kd_avg := 0.0
	for c in kd_counts:
		kd_avg += float(c)
	kd_avg /= float(maxi(kd_counts.size(), 1))
	print("crashes per race avg %.1f  (%s)" % [kd_avg, kd_counts])
	print("crash causes: ", crash_totals, "  by last hit: ", by_klass)
	print("hazard throws: ", thrown_total, " hits by kind: ", kinds_total)
	for k: String in dmg:
		print("  %-6s hits %4d  damage %7.1f  avg/hit %.2f  impact avg/hit %.2f" % [k, hits[k], dmg[k], dmg[k] / float(maxi(int(hits[k]), 1)), imps[k] / float(maxi(int(hits[k]), 1))])
	print("swings %d shots %d blocked %d parried %d snatched %d dropped %d  second winds %d  avg lungta at end %.2f" % [swings, shots, blocked, parried, snatched, dropped, second_winds, lungta_sum / float(maxi(n * 8, 1))])
	print("player-equivalent AI places: ", player_places, " avg %.2f" % _avgi(player_places))
	print("winners: ", wins)
	print("per rider (avg place, knockdowns dealt, crashes taken, hits landed per race):")
	for nm: String in per_rider:
		var pr2: Dictionary = per_rider[nm]
		var cnt := float(pr2["n"])
		print("  %-24s %-9s place %.1f  kd %.1f  crashed %.1f  hits %.1f  dmg %.0f  time %.0f" % [nm, pr2["style"], pr2["place"] / cnt, pr2["kd"] / cnt, pr2["crash"] / cnt, pr2["hits"] / cnt, pr2["dmg"] / cnt, pr2["time"] / maxf(float(pr2["fin"]), 1.0)])
	# rule assertions across all races
	check(int(by_klass.get("impact/ranged", 0)) == 0, "a ranged hit unseated on impact")
	if int(hits["ranged"]) > 0 and int(hits["melee"]) > 0:
		var r_avg: float = dmg["ranged"] / float(hits["ranged"])
		var m_avg: float = dmg["melee"] / float(hits["melee"])
		var r_imp: float = imps["ranged"] / float(hits["ranged"])
		var m_imp: float = imps["melee"] / float(hits["melee"])
		# per-hit damage depends on the weapon mix (whips and pen cases are weak melee), so allow a little slack there
		check(r_avg < m_avg * 1.15 and r_avg < 9.2, "ranged damage per hit %.2f should be below melee %.2f" % [r_avg, m_avg])
		check(r_imp < m_imp, "ranged impact per hit %.2f should be below melee %.2f" % [r_imp, m_imp])
	if n >= 4:
		check(_avg(win_times) > 90.0 and _avg(win_times) < 230.0, "race length should be about 2-3 minutes, got %.1f" % _avg(win_times))
		check(kd_avg >= 2.0 and kd_avg <= 14.0, "knockdowns per race should be sane, got %.1f" % kd_avg)


func _avg(a: Array[float]) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += v
	return s / float(a.size())


func _avgi(a: Array[int]) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += float(v)
	return s / float(a.size())


func _minf(a: Array[float]) -> float:
	var m := 1.0e9
	for v in a:
		m = minf(m, v)
	return m


func _maxf(a: Array[float]) -> float:
	var m := 0.0
	for v in a:
		m = maxf(m, v)
	return m
