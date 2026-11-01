class_name Rider
extends RefCounted
## One racer. Lives in track space (s metres along the course, d metres right of centre) with no physics engine.
## Race feeds an Intent each tick; the controller (PlayerControl or RiderAI) fills it.
## Health and Shake rules follow docs/GAME_DESIGN.md exactly.

signal crashed(rider: Rider, reason: String)
signal remounted(rider: Rider)
signal swing_started(rider: Rider, kind: String)
signal second_wind_started(rider: Rider)
signal landed(rider: Rider)
signal launched(rider: Rider)

class Intent:
	var steer := 0.0       # -1 left .. 1 right
	var throttle := 0.0    # -1 rein in .. 1 urge
	var whip := false
	var leap := false      # pressed this tick
	var strike_left := false   # pressed this tick
	var strike_right := false  # pressed this tick
	var kick := false      # pressed this tick
	var ranged := false    # held
	var shield := false    # held
	var second_wind := false   # pressed this tick
	var mash := false      # any press, used while resting

	func clear_edges() -> void:
		leap = false
		strike_left = false
		strike_right = false
		kick = false
		second_wind = false
		mash = false

# --- tuning ---
const CRUISE := 0.62            # fraction of top speed held with no input
const CURVE_K := 0.42           # curve push strength, times speed squared times curvature
const MAX_PUSH := 6.5
const WHIP_BOOST := 1.12
const WHIP_DRAIN := 22.0
const STAMINA_REGEN := 9.0
const DRAFT_TOP := 0.12         # in a full slipstream: this much more top speed,
const DRAFT_ACCEL := 0.8        # this much more acceleration,
const DRAFT_EASE := 0.35        # this much less stamina spent on the whip, and this much more of it back when not whipping
const HAND_HEIGHT := 1.95       # where a rider looses a shot from, above the ground
const DRAW_SLOW := 0.93         # the horse's top speed is this much of itself while a shot is drawn
const KICK_DELAY := 0.3         # a kick takes this long to land,
const KICK_SLOW := 0.9          # and the horse's top speed is this much of itself until it's done
const SLIDE_TIME := 0.55        # sideways momentum from a slam or a kick fades with this time constant, in seconds
const EXHAUSTED_TOP := 0.88
const SHAKE_DRAIN := 5.5
const WOBBLE_AT := 45.0
const TEETER_AT := 70.0
const RANGED_SHAKE_CAP := 85.0
const SECOND_WIND_TIME := 4.0
const GRAVITY := 18.0
const LEAP_VY := 7.0
const HEALTH_REST := 7.0
const IMPACT_REST_TOTAL := 3.5
const REMOUNT_HEALTH := 55.0
const HEALTH_REGEN := 2.6
const EDGE_SLOW := 0.45
const SCRUB_WIDTH := 5.5

# --- identity ---
var display_name := ""
var rival_id := ""
var is_player := false
var slot := 0
var data: Dictionary = {}
var horse: Dictionary = {}
var horse_id := ""
var bon := false
var portrait := ""
var colour_a := Color.WHITE
var colour_b := Color.WHITE
var skin := Color.WHITE
var wardrobe: Array = []
var skill := 0.7
var aggression := 0.5
var pace := 0.97
var lane := 0.0
var style := ""
var bulk := 1.0
var saddle_cut := 0.0
var finish_s := 1.0e9
var rng: RandomNumberGenerator

# --- public state read by HUD and AI ---
var s := 0.0
var d := 0.0
var speed := 0.0
var lateral := 0.0              # sideways speed from the reins, which answers at once
var slide := 0.0                # sideways speed carried from a slam or a kick, which the reins don't stop, only fight
var height := 0.0
var vy := 0.0
var top_speed := 20.0
var yaw := 0.0
var health := 100.0
var max_health := 100.0
var shake := 0.0
var stamina := 80.0
var max_stamina := 80.0
var lungta := 0.0
var state := "ride"
var rest_left := 0.0
var weapon_id := "fists"
var ranged_id := ""
var ammo := 0
var has_shield := false
var blocking := false
var drawing := false
var draw_amount := 0.0
var place := 0
var finished := false
var finish_time := 0.0
var knockdowns := 0
var scoops := 0

# --- extra bookkeeping ---
var crashes := 0
var crash_reasons: Array[String] = []
var silver_bonus := 0
var fines := 0
var wobble_amount := 0.0
var wobble_dir := 0.0
var second_wind_t := 0.0
var exhausted := false
var whip_on := false
var invuln_t := 0.0
var flash_t := 0.0
var hit_side := 0
var hit_age := 99.0
var last_hitter: Rider = null
var last_hit_age := 99.0
var last_hit_klass := ""
var age := 0.0
var since_damage := 99.0
var mud := false
var airborne_t := 0.0
var land_cooldown := 0.0
var in_quiet := false
var on_scrub := false
var scooping_t := 0.0
var draft := 0.0                # how far into another horse's wind trail, 0 to 1
var draft_from: Rider = null    # whose
var scoop_side := 1.0
var pole_hits: Dictionary = {}
var scarf_taken: Dictionary = {}
var steward_hits := 0
var damage_dealt := 0.0
var hits_landed := 0
var teetering_announced := false

# fun stats, counted only when the race has visuals (never in the headless sim)
var hats_knocked := 0
var near_misses := 0
var overtakes := 0
var best_streak := 0
var hat_off := false

# combat
var swing_t := -1.0
var swing_total := 0.0
var swing_hit_t := 0.0
var swing_side := 1
var swing_kind := ""
var swing_done := false
var swing_weapon := ""
var swing_quiet_charged := false
var strike_buffer := 0
var strike_buffer_t := 0.0
var kick_buffer_t := 0.0
var cooldown := 0.0
var block_time := 0.0
var shield_side := -1
var draw_t := 0.0
var recover_t := 0.0
var fire_pending := false
var fire_power := 0.0
var rope_out := false
var target_lock: Rider = null
var aim_dir := Vector3.ZERO     # where this rider's next shot goes, set from the sight. Zero leaves it to rival aiming.
var shoved: Rider = null        # who this rider just slammed with the horse,
var shoved_t := 0.0             # and how long a strike on them still lands harder

# crash flow
var crash_reason := ""
var crash_total := 0.0
var phases: Array = []     # [[state, duration], ...]
var phase_i := 0
var phase_left := 0.0
var phase_age := 0.0
var mash_cut := 0.0
var horse_s := 0.0
var horse_d := 0.0
var horse_speed := 0.0
var horse_height := 0.0
var fall_vs := 0.0
var fall_vd := 0.0
var run_from_s := 0.0
var run_from_d := 0.0
var fall_dir := 1.0
var last_crash_s := 0.0
var crash_what := ""

static func throttle_for_fraction(f: float) -> float:
	return clampf((f - CRUISE) / (1.0 - CRUISE), -1.0, 1.0)


## Build a rider from a RIVALS/PLAYERS entry.
func setup(p_data: Dictionary, opts: Dictionary, p_rng: RandomNumberGenerator) -> void:
	rng = p_rng
	data = p_data
	display_name = p_data.get("name", "Rider")
	rival_id = opts.get("id", "")
	is_player = opts.get("is_player", false)
	portrait = "res://assets/ui/portraits/%s.png" % rival_id
	bon = p_data.get("bon", false)
	colour_a = p_data.get("slot_a", Color.WHITE)
	colour_b = p_data.get("slot_b", Color.WHITE)
	skin = p_data.get("skin", Color("c58e62"))
	wardrobe = p_data.get("wardrobe", ["body_chuba", "head_young"])
	skill = p_data.get("skill", 0.7)
	aggression = p_data.get("aggression", 0.5)
	pace = p_data.get("pace", 0.97)
	lane = p_data.get("lane", 0.0)
	style = p_data.get("style", "")
	horse_id = opts.get("horse_id", p_data.get("horse", "old_tsampa"))
	horse = GameData.HORSES.get(horse_id, GameData.HORSES["old_tsampa"])
	bulk = horse["bulk"]
	max_stamina = horse["stamina"]
	stamina = max_stamina
	top_speed = horse["speed"]
	weapon_id = opts.get("weapon_id", p_data.get("weapon", "fists"))
	ranged_id = opts.get("ranged_id", p_data.get("ranged", ""))
	has_shield = opts.get("has_shield", p_data.get("shield", false))
	# tolerate odd ids from saves or menus
	if not GameData.WEAPONS.has(weapon_id) or String(GameData.WEAPONS[weapon_id]["klass"]) == "ranged":
		weapon_id = "fists"
	if ranged_id != "" and (not GameData.WEAPONS.has(ranged_id) or String(GameData.WEAPONS[ranged_id]["klass"]) != "ranged"):
		ranged_id = ""
	var w: Dictionary = GameData.weapon(ranged_id) if ranged_id != "" else {}
	ammo = int(w.get("ammo", 0)) if ranged_id != "" else 0
	# a rival carries a third of a full quiver: more shots are there for the player's aim, not to be pelted with
	if not is_player and ammo > 0:
		ammo = ammo / 3
	saddle_cut = GameData.saddle_cut(int(opts.get("saddle_level", 0)))
	max_health = 100.0 + GameData.armor_health(int(opts.get("armor_level", 0)))
	health = max_health


func place_on_grid(p_s: float, p_d: float) -> void:
	s = p_s
	d = p_d
	speed = 0.0
	horse_s = s
	horse_d = d
	state = "ride"


func gait() -> String:
	var f := speed / maxf(float(horse["speed"]), 1.0)
	if speed < 2.5 or f < 0.12:
		return "walk" if speed > 0.5 else "idle"
	if f < 0.4:
		return "trot"
	if f < 0.74:
		return "canter"
	return "gallop"


func is_riding() -> bool:
	return state == "ride" or state == "airborne"


## The wardrobe's hat piece ("hat_felt"...), or "" for a rider who wears none.
func hat_piece() -> String:
	for w: Variant in wardrobe:
		if String(w).begins_with("hat_"):
			return String(w)
	return ""


func is_ranged_only() -> bool:
	return weapon_id == "fists" and ranged_id != ""


func swing_active() -> bool:
	return swing_t >= swing_hit_t and swing_t < swing_hit_t + 0.14 and not swing_done and swing_t >= 0.0


func add_lungta(v: float) -> void:
	lungta = clampf(lungta + v, 0.0, 5.0)


## Which side this rider's wobble pushes right now (-1, 0, 1), for "steer against it" checks.
func wobble_sign() -> float:
	return signf(wobble_dir) if absf(wobble_dir) > 0.05 else 0.0


# ---------------------------------------------------------------------------------------------
# Simulation
# ---------------------------------------------------------------------------------------------

func simulate(dt: float, it: Intent, track: Track) -> void:
	age += dt
	flash_t = maxf(0.0, flash_t - dt)
	hit_age += dt
	last_hit_age += dt
	since_damage += dt
	invuln_t = maxf(0.0, invuln_t - dt)
	match state:
		"ride", "airborne":
			_tick_ride(dt, it, track)
		"finished":
			_tick_finished(dt, track)
		_:
			_tick_crash(dt, it, track)


func _tick_ride(dt: float, it: Intent, track: Track) -> void:
	var hw := track.half_width_at(s)
	var airborne := state == "airborne"

	# --- fortune, Second Wind ---
	second_wind_t = maxf(0.0, second_wind_t - dt)
	if it.second_wind and lungta >= 4.99 and second_wind_t <= 0.0:
		lungta = 0.0
		second_wind_t = SECOND_WIND_TIME
		second_wind_started.emit(self)

	# --- stamina and whip ---
	whip_on = it.whip and stamina > 0.0 and not airborne and not blocking and not exhausted
	if whip_on:
		stamina = maxf(0.0, stamina - WHIP_DRAIN * (1.0 - DRAFT_EASE * draft) * dt)
		if stamina <= 0.0:
			exhausted = true
	else:
		stamina = minf(max_stamina, stamina + STAMINA_REGEN * (1.0 + DRAFT_EASE * draft) * dt * (0.6 if exhausted else 1.0))
		if exhausted and stamina >= 0.25 * max_stamina:
			exhausted = false

	# --- top speed ---
	var top: float = horse["speed"]
	if whip_on:
		top *= WHIP_BOOST
	if exhausted:
		top *= EXHAUSTED_TOP
	if second_wind_t > 0.0:
		top *= 1.12
	top *= clampf(1.0 - track.slope_at(s) * 0.9, 0.85, 1.12)
	top *= 1.0 + DRAFT_TOP * draft
	if blocking:
		top *= 0.85
	if drawing:
		top *= DRAW_SLOW
	if swing_t >= 0.0 and swing_kind == "kick":
		top *= KICK_SLOW
	var edge := absf(d) - hw
	on_scrub = edge > 0.0
	var cap := top
	if on_scrub:
		cap *= 1.0 - EDGE_SLOW * clampf(edge / 4.0, 0.0, 1.0)
	if mud and not airborne:
		cap *= 0.55
	top_speed = top

	# --- speed ---
	var cruise := top * CRUISE
	var target: float
	if it.throttle >= 0.0:
		target = lerpf(cruise, top, it.throttle)
	else:
		target = lerpf(cruise, 3.0, -it.throttle)
	target = minf(target, cap)
	if target > speed:
		var accel: float = horse["accel"]
		accel *= (1.5 if whip_on else 1.0) * (1.25 if second_wind_t > 0.0 else 1.0) * (1.0 + DRAFT_ACCEL * draft)
		accel *= clampf(1.45 - speed / maxf(top, 1.0), 0.3, 1.0)
		speed = minf(speed + accel * dt, target)
	else:
		var brake := 9.0 if it.throttle < -0.1 else 3.2
		if speed > cap:
			brake = 11.0
		speed = maxf(speed - brake * dt, target)

	# --- shake: drain, wobble ---
	wobble_amount = clampf((shake - WOBBLE_AT) / 40.0, 0.0, 1.0)
	if shake >= WOBBLE_AT:
		wobble_dir = sin(age * 5.2 + float(slot) * 1.7) * (0.35 + 0.65 * wobble_amount)
	else:
		wobble_dir = 0.0
	var drain := SHAKE_DRAIN
	if shake >= WOBBLE_AT and absf(it.steer) > 0.3 and signf(it.steer) == -signf(wobble_dir) and absf(wobble_dir) > 0.15:
		drain *= 2.0
	if second_wind_t > 0.0:
		drain *= 2.0
	shake = maxf(0.0, shake - drain * dt)
	if shake < TEETER_AT - 10.0:
		teetering_announced = false
	if since_damage > 2.5 and health < max_health:
		health = minf(max_health, health + HEALTH_REGEN * dt)

	# --- steering ---
	var steer_in := it.steer
	var speed_scale := 0.3 + 0.7 * clampf(speed / maxf(float(horse["speed"]), 1.0), 0.0, 1.0)
	var handling: float = horse["handling"]
	if blocking:
		handling *= 0.85
	var max_lat := handling * 2.5 * speed_scale
	var lat_target := steer_in * max_lat
	if airborne:
		lat_target *= 0.35
	lat_target += wobble_dir * 3.4 * wobble_amount
	# Steering the same way as a slam's momentum adds nothing until the momentum has faded below what steering alone gives.
	if lat_target * slide > 0.0:
		lat_target = signf(lat_target) * maxf(absf(lat_target) - absf(slide), 0.0)
	var k := 1.0 - exp(-dt / 0.06)
	lateral += (lat_target - lateral) * k
	slide *= exp(-dt / SLIDE_TIME)
	shoved_t = maxf(0.0, shoved_t - dt)

	# --- curve push ---
	var kappa := track.curve_at(s)
	var push := clampf(-kappa * speed * speed * CURVE_K, -MAX_PUSH, MAX_PUSH)
	if airborne:
		push *= 0.5

	# --- integrate position ---
	d += (lateral + slide + push) * dt
	var inner := maxf(0.55, 1.0 - kappa * d)
	var slope_mult := 1.0
	s += speed * slope_mult / inner * dt
	var limit := hw + SCRUB_WIDTH
	if absf(d) > limit:
		# rocks and trees beyond the scrub: thrown if fast, otherwise just stopped
		if speed > 9.0 and not airborne and state == "ride":
			d = clampf(d, -limit, limit)
			crash_what = "scrub"
			crash("hazard")
			return
		d = clampf(d, -limit, limit)
		lateral = 0.0
		slide = 0.0
		speed = minf(speed, 6.0)
	yaw = lerpf(yaw, atan2(lateral + slide + push, maxf(speed, 4.0)), 1.0 - exp(-dt / 0.1))
	horse_s = s
	horse_d = d
	horse_speed = speed

	# --- leap and air ---
	land_cooldown = maxf(0.0, land_cooldown - dt)
	if airborne:
		airborne_t += dt
		vy -= GRAVITY * dt
		height += vy * dt
		if height <= 0.0:
			height = 0.0
			vy = 0.0
			state = "ride"
			airborne_t = 0.0
			land_cooldown = 0.25
			landed.emit(self)
	elif it.leap and land_cooldown <= 0.0:
		leap_now(LEAP_VY)

	# --- combat state ---
	_tick_combat(dt, it)

	# --- crash from fast shake dropping? never. Done. ---


## This rider's velocity in the world, which a shot inherits when it leaves the hand.
func world_velocity(track: Track) -> Vector3:
	var push := clampf(-track.curve_at(s) * speed * speed * CURVE_K, -MAX_PUSH, MAX_PUSH)
	return track.tangent_at(s) * speed + track.right_at(s) * (side_speed() + push) + Vector3.UP * vy


## All the sideways speed the rider has of their own, reins and momentum together.
func side_speed() -> float:
	return lateral + slide


## Where this rider's ranged weapon is, near enough, with no model to ask: a bow in the left hand, anything else in the right.
func hand_point(track: Track) -> Vector3:
	return track.point(s + 0.5, d + (-0.35 if ranged_id == "bow" else 0.35), HAND_HEIGHT + height)


func leap_now(power: float) -> void:
	if state != "ride" and state != "airborne":
		return
	state = "airborne"
	vy = power
	height = 0.01
	airborne_t = 0.0
	launched.emit(self)


func _tick_combat(dt: float, it: Intent) -> void:
	cooldown = maxf(0.0, cooldown - dt)
	recover_t = maxf(0.0, recover_t - dt)
	strike_buffer_t = maxf(0.0, strike_buffer_t - dt)
	kick_buffer_t = maxf(0.0, kick_buffer_t - dt)

	# shield
	var can_shield := has_shield and swing_t < 0.0 and not drawing and state == "ride" and recover_t <= 0.0
	if it.shield and can_shield:
		if not blocking:
			blocking = true
			block_time = 0.0
		else:
			block_time += dt
	else:
		blocking = false
		block_time = 0.0

	# melee and kick requests
	if it.strike_left:
		strike_buffer = -1
		strike_buffer_t = 0.2
	if it.strike_right:
		strike_buffer = 1
		strike_buffer_t = 0.2
	if it.kick:
		kick_buffer_t = 0.2
	if swing_t >= 0.0:
		swing_t += dt
		if swing_t >= swing_total:
			swing_t = -1.0
			swing_kind = ""
			cooldown = 0.04
	var free := swing_t < 0.0 and cooldown <= 0.0 and not blocking and not drawing and state == "ride" and not rope_out
	if free and kick_buffer_t > 0.0:
		kick_buffer_t = 0.0
		strike_buffer_t = 0.0
		_start_swing(0, "kick")
	elif free and strike_buffer_t > 0.0 and strike_buffer != 0:
		var side := strike_buffer
		strike_buffer_t = 0.0
		strike_buffer = 0
		_start_swing(side, "melee")

	# ranged
	if ranged_id != "" and swing_t < 0.0 and not blocking and state == "ride":
		var w: Dictionary = GameData.WEAPONS[ranged_id]
		var draw_time: float = w["draw"]
		if it.ranged and ammo != 0 and recover_t <= 0.0 and not rope_out:
			if not drawing:
				drawing = true
				draw_t = 0.0
			draw_t += dt
			draw_amount = clampf(draw_t / draw_time, 0.0, 1.0)
		elif drawing:
			drawing = false
			if draw_t >= float(w["min_draw"]):
				fire_pending = true
				fire_power = draw_amount
				recover_t = 0.35 if ranged_id != "roped_spear" else 0.2
				if ammo > 0:
					ammo -= 1
			draw_t = 0.0
			draw_amount = 0.0
	elif drawing:
		drawing = false
		draw_t = 0.0
		draw_amount = 0.0


func _start_swing(side: int, kind: String) -> void:
	swing_kind = kind
	swing_side = side
	var wid := "kick" if kind == "kick" else weapon_id
	swing_weapon = wid
	var w: Dictionary = GameData.WEAPONS[wid]
	swing_total = w["swing"]
	swing_hit_t = KICK_DELAY if kind == "kick" else swing_total * 0.36
	swing_t = 0.0
	swing_done = false
	swing_quiet_charged = false
	swing_started.emit(self, kind)


func _tick_finished(dt: float, track: Track) -> void:
	speed = maxf(0.0, speed - 5.5 * dt)
	var hw := track.half_width_at(s)
	# ease in from the edges toward the middle, but keep a lane of your own (Race spreads finished riders apart)
	lateral = lerpf(lateral, (clampf(d, -hw * 0.5, hw * 0.5) - d) * 0.7, 1.0 - exp(-dt / 0.3))
	d = clampf(d + lateral * dt, -hw, hw)
	s = minf(s + speed * dt, track.length - 2.0)
	blocking = false
	drawing = false
	swing_t = -1.0
	yaw = lerpf(yaw, 0.0, 0.1)
	horse_s = s
	horse_d = d
	horse_speed = speed


# ---------------------------------------------------------------------------------------------
# Taking hits
# ---------------------------------------------------------------------------------------------

## Apply a hit. damage and impact are final numbers (shield, saddle, bulk already applied).
## klass "ranged" never unseats on impact: it cannot lift shake above RANGED_SHAKE_CAP.
func receive_hit(attacker: Rider, damage: float, impact: float, klass: String, side: int) -> Dictionary:
	var out := {"crashed": false, "reason": "", "shake_before": shake, "shake_after": shake, "ignored": false}
	if not is_riding() or invuln_t > 0.0:
		out["ignored"] = true
		return out
	health = maxf(0.0, health - damage)
	if damage > 0.0:
		since_damage = 0.0
	var before := shake
	if second_wind_t <= 0.0 and impact > 0.0:
		var after := before + impact
		if klass == "ranged":
			after = minf(after, maxf(before, RANGED_SHAKE_CAP))
		shake = clampf(after, 0.0, 100.0)
	out["shake_before"] = before
	out["shake_after"] = shake
	hit_side = side
	hit_age = 0.0
	flash_t = 0.12
	last_hitter = attacker
	last_hit_age = 0.0
	last_hit_klass = klass
	speed = maxf(0.0, speed - impact * 0.05)
	var reason := ""
	if health <= 0.0:
		reason = "health"
	elif klass != "ranged" and second_wind_t <= 0.0:
		if shake >= 100.0:
			reason = "impact"
		elif shake > TEETER_AT:
			var chance := 0.5 * (shake - TEETER_AT) / (100.0 - TEETER_AT)
			if rng.randf() < chance:
				reason = "impact"
	if reason != "":
		out["crashed"] = true
		out["reason"] = reason
		crash(reason, float(side))
	return out


## Throw the rider. reason: "impact" (about 3.5 s), "health" (7 s rest), "hazard" (like impact).
func crash(reason: String, from_side: float = 0.0) -> void:
	if not is_riding():
		return
	crashes += 1
	crash_reason = reason
	crash_reasons.append(reason)
	last_crash_s = s
	state = "falling"
	lungta *= 0.5
	blocking = false
	drawing = false
	draw_t = 0.0
	draw_amount = 0.0
	swing_t = -1.0
	swing_kind = ""
	fire_pending = false
	strike_buffer_t = 0.0
	kick_buffer_t = 0.0
	whip_on = false
	shake = 0.0
	wobble_amount = 0.0
	wobble_dir = 0.0
	second_wind_t = 0.0
	mud = false
	rope_out = false
	mash_cut = 0.0
	fall_dir = -from_side if from_side != 0.0 else (1.0 if rng.randf() < 0.5 else -1.0)
	horse_s = s
	horse_d = d
	horse_speed = speed
	fall_vs = speed * 0.62
	fall_vd = side_speed() * 0.4 + fall_dir * 1.6
	slide = 0.0
	shoved_t = 0.0
	vy = 4.2 + speed * 0.07
	height = 0.05
	if reason == "health":
		crash_total = HEALTH_REST
		phases = [["falling", 0.9], ["rest", HEALTH_REST - 0.9 - 1.5 - 0.4], ["run", 1.5], ["mount", 0.4]]
	else:
		crash_total = IMPACT_REST_TOTAL
		phases = [["falling", 0.9], ["down", 0.7], ["run", 1.5], ["mount", 0.4]]
	phase_i = 0
	_enter_phase()
	rest_left = _remaining()
	crashed.emit(self, reason)


func _enter_phase() -> void:
	var ph: Array = phases[phase_i]
	state = ph[0]
	phase_left = ph[1]
	phase_age = 0.0
	if state == "run":
		run_from_s = s
		run_from_d = d
		fall_vs = 0.0
		fall_vd = 0.0


func _remaining() -> float:
	var t := phase_left
	for i in range(phase_i + 1, phases.size()):
		var ph: Array = phases[i]
		t += float(ph[1])
	return t


func _tick_crash(dt: float, it: Intent, track: Track) -> void:
	# the horse trots on and waits, never hurt
	horse_speed *= exp(-2.4 * dt)
	if horse_speed < 0.4:
		horse_speed = 0.0
	horse_s = minf(horse_s + horse_speed * dt, track.length - 3.0)
	horse_d = clampf(horse_d + signf(horse_d) * 0.3 * dt, -track.half_width_at(horse_s) + 1.0, track.half_width_at(horse_s) - 1.0)
	horse_height = 0.0
	if state == "rest" and it.mash and mash_cut < 2.5:
		var cut := minf(0.32, 2.5 - mash_cut)
		mash_cut += cut
		phase_left -= cut
	phase_left -= dt
	phase_age += dt
	match state:
		"falling":
			s = minf(s + fall_vs * dt, track.length - 3.0)
			d += fall_vd * dt
			fall_vs *= exp(-2.0 * dt)
			fall_vd *= exp(-2.0 * dt)
			vy -= GRAVITY * dt
			height += vy * dt
			if height <= 0.0:
				height = 0.0
				vy = absf(vy) * 0.3 if absf(vy) > 3.0 else 0.0
			d = clampf(d, -track.half_width_at(s) - 3.0, track.half_width_at(s) + 3.0)
		"down", "rest":
			height = 0.0
		"run":
			var ph: Array = phases[phase_i]
			var t := clampf(phase_age / float(ph[1]), 0.0, 1.0)
			t = t * t * (3.0 - 2.0 * t) * 0.35 + t * 0.65
			s = lerpf(run_from_s, horse_s, t)
			d = lerpf(run_from_d, horse_d, t)
			height = 0.0
		"mount":
			s = horse_s
			d = horse_d
			height = 0.0
	if phase_left <= 0.0:
		phase_i += 1
		if phase_i >= phases.size():
			_remount()
			return
		_enter_phase()
	rest_left = _remaining()


func _remount() -> void:
	state = "ride"
	s = horse_s
	d = horse_d
	speed = 3.0
	lateral = 0.0
	height = 0.0
	vy = 0.0
	yaw = 0.0
	shake = 0.0
	if crash_reason == "health":
		health = REMOUNT_HEALTH
	invuln_t = 1.2
	rest_left = 0.0
	last_hitter = null
	remounted.emit(self)


func to_result() -> Dictionary:
	return {
		"rider": self, "place": place, "time": finish_time, "knockdowns": knockdowns,
		"bounty": 0, "scoops": scoops, "crashed": crashes, "fines": fines, "silver": silver_bonus,
		"hats": hats_knocked, "near_misses": near_misses, "overtakes": overtakes, "best_streak": best_streak,
	}
