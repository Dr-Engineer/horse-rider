class_name RiderAI
extends RefCounted
## Rival personalities. Reads the race, writes a Rider.Intent. Each style rides differently:
## line choice and hazard avoidance by look-ahead, aligning alongside to fight, backing off below 30 health,
## shields, ranged riders hanging back to harass, grudges against the player, mild catch-up, hands down on Quiet Ground.

const STEP := 0.12

var r: Rider
var race: Race
var rng: RandomNumberGenerator
var intent := Rider.Intent.new()

var line_d := 0.0
var mode := "race"          # race | fight | harass | retreat
var target: Rider = null
var target_hold := 0.0
var think_acc := 0.0
var attack_cd := 0.0
var react_t := 0.0
var shield_t := 0.0
var fire_phase := "idle"    # idle | draw | wait
var fire_t := 0.0
var fire_hold := 0.0
var fire_cd := 0.0
var f_desired := 0.97
var gap_target := 0.0
var fight_line := 0.0
var engaged := false
var blocked := false
var dodging := false
var quiet_hands := false
var leap_s := -1.0
var leap_d := 0.0
var whip_t := 0.0
var grudge := false
var noise := 0.0
var noise_t := 0.0
var season_mult := 1.0
var mash_t := 0.0
var cached_kappa := 0.0
var steer_gain := 1.0
var ranged_mode := false
var opportunist := 0.0
var fight_rest := 0.0
var jab_ok := false
var ram_t := 0.0
var leap_r := 0.0


func _init(p_rider: Rider, p_race: Race, p_rng: RandomNumberGenerator) -> void:
	r = p_rider
	race = p_race
	rng = p_rng
	think_acc = rng.randf() * STEP
	line_d = r.d
	ranged_mode = r.ranged_id != "" and r.weapon_id == "fists"
	grudge = false
	if race != null and race.grudges.has(r.rival_id):
		var g: Variant = race.grudges[r.rival_id]
		grudge = bool(g) if typeof(g) == TYPE_BOOL else int(g) > 0
	season_mult = 0.955 + 0.03 * float(race.season)
	if r.is_player:
		season_mult = 1.0


func think(dt: float) -> Rider.Intent:
	intent.clear_edges()
	if not r.is_riding():
		intent.steer = 0.0
		intent.throttle = 0.0
		intent.whip = false
		intent.ranged = false
		intent.shield = false
		if r.state == "rest":
			mash_t -= dt
			if mash_t <= 0.0:
				mash_t = rng.randf_range(0.12, 0.3) / (0.4 + r.skill)
				intent.mash = true
		return intent
	attack_cd -= dt
	fire_cd -= dt
	shield_t -= dt
	whip_t -= dt
	noise_t -= dt
	if noise_t <= 0.0:
		noise_t = rng.randf_range(0.4, 1.2)
		noise = rng.randfn(0.0, 0.5) * (1.1 - r.skill)
	think_acc -= dt
	if think_acc <= 0.0:
		think_acc += STEP
		_decide()
	_act(dt)
	return intent


# ---------------------------------------------------------------------------------------------
# Decisions at about 8 Hz
# ---------------------------------------------------------------------------------------------

func _decide() -> void:
	var track := race.track
	var hw := track.half_width_at(r.s)
	var usable := maxf(hw - 1.7, 2.0)
	var spd := maxf(r.speed, 10.0)
	quiet_hands = race.hazards.in_quiet(r.s) or race.hazards.quiet_ahead(r.s, spd * 0.6)

	if r.health < 30.0:
		mode = "retreat"
	elif mode == "retreat" and r.health >= 50.0:
		mode = "race"

	fight_rest -= STEP
	jab_ok = rng.randf() < r.aggression * 0.02
	_pick_target()
	engaged = target != null and mode != "retreat" and not quiet_hands
	var w: Dictionary = GameData.WEAPONS[r.weapon_id]
	var reach: float = w["reach"]
	if engaged:
		var tgt := target
		var side := 1.0 if tgt.d > r.d else -1.0
		if ranged_mode:
			var rw: Dictionary = GameData.WEAPONS[r.ranged_id]
			gap_target = clampf(float(rw["reach"]) * 0.42, 9.0, 20.0)
			fight_line = clampf(tgt.d + rng.randf_range(-0.8, 0.8), -usable, usable)
			mode = "harass"
		else:
			gap_target = 0.3
			var lat := clampf(reach * 0.62, 1.75, 2.4)
			fight_line = clampf(tgt.d - side * lat, -usable, usable)
			if r.style == "blocker":
				# holds her lane and makes others come to her
				fight_line = clampf(r.lane * usable * 0.75, -usable, usable)
			mode = "fight"
	elif mode != "retreat":
		mode = "race"

	# --- line choice ---
	var base := r.lane * usable * 0.75
	var k_ahead := track.curve_at(r.s + 22.0 + spd * 0.5)
	base += clampf(k_ahead * 240.0, -1.0, 1.0) * usable * 0.5 * (0.4 + 0.6 * r.skill)
	if mode == "retreat":
		# keep clear of the nearest rival
		var near := race.nearest_rival(r, 12.0)
		if near != null:
			base = clampf(r.d - signf(near.d - r.d) * 4.0, -usable, usable)
	elif engaged:
		base = fight_line
	var look := 18.0 + spd * 1.35
	var obs := race.hazards.obstacles_ahead(r.s, look)
	var best_c := base
	var best_score := INF
	var steps := int(ceil(usable * 2.0 / 1.25))
	var can_leap := true
	leap_s = -1.0
	for k in range(steps + 1):
		var c := -usable + float(k) * (usable * 2.0 / float(maxi(steps, 1)))
		var score := absf(c - base) * (0.5 if engaged else 0.35) + absf(c - r.d) * 0.12
		score += _lane_penalty(c, obs, can_leap)
		score += _rider_penalty(c)
		if score < best_score:
			best_score = score
			best_c = c
	line_d = best_c
	blocked = best_score > 30.0
	# something hard dead ahead on this line: time to get out of the way, whoever is alongside
	dodging = false
	for o in obs:
		var ahead := float(o["s"]) - r.s
		if not o.get("want", false) and not o.get("soft", false) and o["kind"] != "log" and ahead > 0.0 and ahead < spd * 1.7 and absf(r.d - float(o["d"])) < float(o["r"]) + 1.0:
			dodging = true
			break
	# the nearest log ahead: leap it if we are over it when we get there
	for o in obs:
		var okind: String = o["kind"]
		if okind == "log" and float(o["s"]) > r.s - 0.5:
			leap_s = float(o["s"])
			leap_d = float(o["d"])
			leap_r = float(o["r"])
			break

	# --- desired speed fraction ---
	var f := r.pace * season_mult
	if r.style == "finisher" and r.s > race.finish_s * 0.62:
		f += 0.03
	if r.style == "reckless":
		f += 0.015
	# mild catch-up
	var lead := race.leader_s()
	var behind := lead - r.s
	if behind > 50.0:
		f += clampf((behind - 50.0) / 600.0, 0.0, 1.0) * 0.03
	elif behind < 1.0 and race.second_s() < r.s - 60.0:
		f -= 0.02
	# bends
	var kmax := maxf(absf(track.curve_at(r.s + 8.0)), absf(track.curve_at(r.s + 8.0 + spd * 0.9)))
	if kmax > 0.002:
		var allow := 3.4 + 3.2 * r.skill
		var v_safe := sqrt(allow / (kmax * Rider.CURVE_K))
		f = minf(f, v_safe / maxf(float(r.horse["speed"]), 1.0))
	if blocked:
		# every lane is shut (a herd crossing, a caravan): slow right down and wait for a gap
		var dmin := 1.0e9
		for o in obs:
			if o.get("want", false) or (o["kind"] == "log"):
				continue
			if absf(line_d - float(o["d"])) < float(o["r"]) + 0.9:
				dmin = minf(dmin, float(o["s"]) - r.s - float(o.get("hl", 1.0)))
		f = minf(f, clampf((dmin - 5.0) / 22.0, 0.0, 1.0) * 0.55)
	f_desired = f

	# --- whip bursts ---
	var remaining := race.finish_s - r.s
	var burst_range: float = (r.stamina / Rider.WHIP_DRAIN) * float(r.horse["speed"]) * 1.15
	if remaining < burst_range and r.stamina > 8.0 and remaining > 0.0 and r.style != "avoider":
		whip_t = maxf(whip_t, 0.5)
	elif whip_t <= 0.0 and r.stamina > 0.75 * r.max_stamina and not r.exhausted and r.style != "avoider":
		var catching := engaged and target != null and (target.s - r.s) > 5.0
		var chance := 0.05 + 0.25 * r.skill + (0.2 if catching else 0.0)
		if r.style == "sprinter" or r.style == "reckless" or r.style == "front":
			chance += 0.1
		if rng.randf() < chance * 0.3:
			whip_t = rng.randf_range(1.2, 2.6)

	# --- shield: raise when a rival is winding up beside us ---
	if r.has_shield:
		var threatened := false
		for o in race.riders:
			if o == r or not o.is_riding():
				continue
			if absf(o.s - r.s) < 5.0 and absf(o.d - r.d) < 5.0 and (o.swing_t >= 0.0 or o.drawing):
				threatened = true
				break
		var near_hold := (r.style == "blocker" or r.style == "avoider") and race.nearest_rival(r, 3.5) != null
		if (threatened and rng.randf() < 0.4 + 0.6 * r.skill) or near_hold:
			shield_t = maxf(shield_t, rng.randf_range(0.35, 0.7))


func _pick_target() -> void:
	target_hold -= STEP
	if target != null and (not target.is_riding() or absf(target.s - r.s) > 38.0):
		target = null
		target_hold = 0.0
		fight_rest = maxf(fight_rest, 2.0)
	if target != null and target_hold > 0.0:
		return
	if target != null:
		# a fight just ended: rest before picking another
		fight_rest = rng.randf_range(7.0, 17.0) * (1.6 - r.aggression)
		target = null
	if fight_rest > 0.0 and not (r.last_hitter != null and r.last_hit_age < 3.0):
		target_hold = 0.0
		return
	var best: Rider = null
	var best_score := 1.0e9
	var retaliate: Rider = null
	if r.last_hitter != null and r.last_hit_age < 5.0 and r.last_hitter.is_riding():
		retaliate = r.last_hitter
	for o in race.riders:
		if o == r or not o.is_riding():
			continue
		var ds := o.s - r.s
		var score := 0.0
		if ranged_mode:
			if ds < 4.0 or ds > 36.0:
				continue
			score = ds * 0.6 + absf(o.d - r.d)
		else:
			if absf(ds) > 22.0:
				continue
			score = absf(ds) + absf(o.d - r.d) * 1.5
		if grudge and o.is_player:
			score -= 28.0
		if r.style == "clerk" and o.place < r.place:
			score -= 8.0
		if o.health < 30.0 and r.aggression > 0.5:
			score -= 5.0
		if o.shake > 60.0:
			score -= 6.0
		if o == retaliate:
			score -= 20.0
		if score < best_score:
			best_score = score
			best = o
	if race.race_time < 4.5:
		target = null
		target_hold = 1.0
		return
	var engage_p := clampf(r.aggression * 0.75 + 0.05, 0.08, 0.9)
	if r.style == "avoider":
		engage_p = 0.0
		if retaliate != null:
			best = retaliate
			engage_p = 0.9
	if r.style == "front" or r.style == "shortcut":
		engage_p *= 0.6
	if (r.style == "brawler") and best != null and rng.randf() < 0.3 and absf(best.s - r.s) < 3.0 and absf(best.d - r.d) < 3.5:
		ram_t = 0.45
	if grudge and best != null and best.is_player:
		engage_p = maxf(engage_p, 0.95)
	if best != null and rng.randf() < engage_p:
		target = best
		target_hold = rng.randf_range(3.5, 6.0)
	else:
		target = null
		target_hold = rng.randf_range(0.6, 1.4)


func _lane_penalty(c: float, obs: Array[Dictionary], can_leap: bool) -> float:
	var p := 0.0
	for o in obs:
		var od: float = o["d"]
		var rad: float = o["r"]
		var dl := absf(c - od)
		var kind: String = o["kind"]
		if o.get("want", false):
			var bonus := 0.0
			if kind == "scarf":
				bonus = 0.5 + (2.0 if r.style == "trickster" else 0.0) + (0.4 if r.is_player else 0.0)
			else:
				bonus = 1.2 if (r.style == "reckless" or r.style == "shortcut") else (0.4 if r.skill > 0.7 else 0.0)
			if dl < rad + 0.3:
				p -= bonus
			continue
		var soft: bool = o.get("soft", false)
		var margin := rad + 1.0
		# sweeping sideways through an obstacle that is alongside or about to be
		var odist := float(o["s"]) - r.s
		var ohl: float = o.get("hl", 1.0)
		if odist < ohl + 2.5 and odist > -ohl - 3.0 and not soft and not (kind == "log" and can_leap):
			var lo := minf(r.d, c)
			var hi := maxf(r.d, c)
			if od + margin > lo and od - margin < hi and absf(r.d - od) > margin * 0.5 and absf(c - r.d) > 0.5:
				p += 45.0
		elif odist >= ohl + 2.5 and not soft and not (kind == "log" and can_leap):
			var ovs: float = float(o.get("vs", 0.0))
			var t_reach := (odist - ohl) / maxf(r.speed - ovs, 3.0)
			var t_cross := (absf(c - r.d)) / 6.0
			if t_reach < t_cross + 0.2:
				var lo2 := minf(r.d, c)
				var hi2 := maxf(r.d, c)
				if od + margin > lo2 and od - margin < hi2 and absf(r.d - od) > margin:
					p += 45.0
		if kind == "log" and can_leap:
			margin = rad
			if dl < margin:
				p += 0.5
			continue
		if dl < margin:
			var dist := float(o["s"]) - r.s
			var amt := 3.0 if soft else 60.0
			var q := amt * (1.0 - clampf(dl / margin, 0.0, 1.0) * 0.5)
			if dist < 10.0:
				q *= 1.5
			p += q
		if o["sacred"] and dl < 9.0:
			# pass sacred sites with them on the right (Bon riders: on the left) for fortune
			var knows := rng.randf() > (1.0 - r.skill) * 0.25
			if knows:
				var want_right := not r.bon
				var site_right := od > c
				if site_right == want_right and dl > rad + 0.5:
					p -= 1.4
	return p


## Riders keep out from right behind a horse they'd run into, but further back a rider with any sense tucks into its wind trail.
func _rider_penalty(c: float) -> float:
	var p := 0.0
	var trail := 0.0
	for o in race.riders:
		if o == r or not o.is_riding():
			continue
		var ds := o.s - r.s
		if ds > 0.0 and ds < 13.0 and absf(c - o.d) < 1.7 and o != target:
			p += 3.0 * (1.0 - ds / 13.0) + 0.5
		elif ds >= 13.0 and ds < Race.DRAFT_RANGE and absf(c - o.d) < 1.7:
			trail = maxf(trail, 1.0 - ds / Race.DRAFT_RANGE)
	return p - trail * (0.3 + r.skill)


# ---------------------------------------------------------------------------------------------
# Acting every tick
# ---------------------------------------------------------------------------------------------

func _act(dt: float) -> void:
	var track := race.track
	# --- steering ---
	var err := line_d - r.d
	var speed_scale := 0.3 + 0.7 * clampf(r.speed / maxf(float(r.horse["speed"]), 1.0), 0.0, 1.0)
	var max_lat: float = float(r.horse["handling"]) * 2.5 * speed_scale
	var kappa := track.curve_at(r.s + r.speed * 0.12)
	var push := clampf(-kappa * r.speed * r.speed * Rider.CURVE_K, -Rider.MAX_PUSH, Rider.MAX_PUSH)
	var steer := clampf(err * 0.9, -1.0, 1.0) * clampf(1.0 + 0.0 * err, 0.0, 1.0)
	steer += clampf(-push / maxf(max_lat, 1.0), -1.0, 1.0) * (0.55 + 0.45 * r.skill)
	steer += noise * 0.12
	var ram := ram_t > 0.0 and target != null
	ram_t -= dt
	if ram:
		steer = signf(target.d - r.d)
	elif not dodging:
		for o in race.riders:
			if o == r or not o.is_riding():
				continue
			if absf(o.s - r.s) < 3.2:
				var gap := o.d - r.d
				if absf(gap) < 2.6 and signf(gap) == signf(steer) and absf(steer) > 0.15:
					steer = signf(steer) * minf(absf(steer), 0.18)
					break
	if r.wobble_amount > 0.15 and r.skill > 0.35:
		steer += -signf(r.wobble_dir) * 0.8
	# stay on the road
	var hw := track.half_width_at(r.s)
	if absf(r.d) > hw - 0.5:
		steer += clampf(-r.d, -1.0, 1.0) * 0.8
	intent.steer = clampf(steer, -1.0, 1.0)

	# --- speed ---
	var f := f_desired
	var want_whip := whip_t > 0.0
	if engaged and target != null and target.is_riding():
		var ds := target.s - r.s
		var gerr := ds - gap_target
		var v_des := target.speed + clampf(gerr * 1.1, -9.0, 10.0)
		if mode == "harass":
			v_des = target.speed + clampf(gerr * 0.8, -8.0, 8.0)
		var f_fight := v_des / maxf(float(r.horse["speed"]), 1.0)
		# never crawl to wait for a fight: two riders matching each other would stall the whole pack
		f_fight = maxf(f_fight, f_desired * 0.88)
		f = minf(f_fight, 1.14)
		if f > f_desired + 0.04 and not want_whip and r.stamina > 0.25 * r.max_stamina and not r.exhausted:
			want_whip = true
		f = maxf(f, 0.3)
		f = minf(f, f_desired + 0.14) if not blocked else minf(f, 0.5)
		if f_desired < 0.9:
			f = minf(f, f_desired)
	elif mode == "retreat":
		f = minf(f, 0.78)
	intent.whip = want_whip and not r.exhausted
	var mult := 1.12 if intent.whip else 1.0
	intent.throttle = Rider.throttle_for_fraction(minf(f, 1.0 * mult) / mult)

	# --- Second Wind: spend a full fortune meter in the closing stretch or when rattled in a fight ---
	if r.lungta >= 4.99 and r.second_wind_t <= 0.0:
		if r.s > race.finish_s * 0.62 or (engaged and r.shake > 55.0):
			intent.second_wind = true

	# --- leap ---
	if leap_s > 0.0:
		var dist := leap_s - r.s
		if dist > 0.0 and dist < r.speed * 0.3 + 0.9 and absf(r.d - leap_d) < leap_r + 0.6 and r.state == "ride":
			intent.leap = true
			leap_s = -1.0

	# --- combat ---
	intent.shield = shield_t > 0.0 and r.has_shield
	intent.ranged = false
	if quiet_hands:
		fire_phase = "idle"
		return
	if intent.shield:
		return
	if ranged_mode and r.ammo != 0 and mode != "retreat":
		_ranged(dt)
	if r.swing_t < 0.0 and attack_cd <= 0.0 and mode != "retreat" and not r.drawing:
		_melee(dt)


func _melee(dt: float) -> void:
	var w: Dictionary = GameData.WEAPONS[r.weapon_id]
	var reach: float = w["reach"] + 0.45
	var best: Rider = null
	var best_dist := 1.0e9
	for o in race.riders:
		if o == r or not o.is_riding():
			continue
		var dx := o.d - r.d
		var ds := o.s - r.s
		if absf(ds) > reach or absf(dx) > reach or absf(dx) < 0.3:
			continue
		var dist := sqrt(dx * dx + ds * ds)
		if dist > reach * 0.93:
			continue
		var wanted := (o == target) or jab_ok or (o == r.shoved and r.shoved_t > 0.0)
		if not wanted:
			continue
		if dist < best_dist:
			best_dist = dist
			best = o
	if best == null:
		react_t = 0.0
		return
	react_t += dt
	var delay := 0.1 + 0.28 * (1.2 - r.skill)
	if react_t < delay:
		return
	react_t = 0.0
	var dx2 := best.d - r.d
	if r.weapon_id == "fists" and best_dist < 2.0 and rng.randf() < 0.18:
		intent.kick = true
	elif dx2 > 0.0:
		intent.strike_right = true
	else:
		intent.strike_left = true
	var total: float = w["swing"]
	attack_cd = total + rng.randf_range(0.1, 0.5) * (1.7 - r.aggression)


func opportunist_chance() -> float:
	# a quick jab at whoever is alongside, more often for aggressive riders
	return r.aggression * 0.025


func _ranged(dt: float) -> void:
	var rw: Dictionary = GameData.WEAPONS[r.ranged_id]
	match fire_phase:
		"idle":
			if fire_cd <= 0.0 and race.find_lock(r) != null:
				fire_phase = "draw"
				fire_t = 0.0
				fire_hold = float(rw["draw"]) * rng.randf_range(0.95, 1.3) + (0.15 if r.ranged_id == "bow" else 0.0)
				intent.ranged = true
		"draw":
			intent.ranged = true
			fire_t += dt
			if fire_t >= fire_hold:
				fire_phase = "wait"
				fire_t = 0.0
				fire_cd = rng.randf_range(0.5, 1.5) * (1.4 - 0.5 * r.skill)
				intent.ranged = false
		"wait":
			fire_t += dt
			if fire_t > 0.3 and fire_cd <= 0.0:
				fire_phase = "idle"
