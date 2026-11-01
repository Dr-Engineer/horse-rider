class_name Flair
extends Node
## The player's moments: near misses at speed, overtakes by name, knockdown streaks and the slipstream. Audio, visuals and a
## little silver only (Rider.silver_bonus, near_misses, overtakes, best_streak), never the simulation. Player only, own
## random numbers, and it keeps to the comic-word rule: at most two words on screen, each gone in under 0.6 s.

const NEAR_GAP := 1.1                 # metres between the rider and the edge of the thing it missed
const NEAR_SPEED := 13.0
const NEAR_SILVER := 2
const NEAR_COOLDOWN := 0.9
const PASS_COOLDOWN := 10.0           # per rival, so two riders trading places are not counted again and again
const STREAK_WINDOW := 25.0
const STREAK_CALLS := ["DOUBLE!", "TRIPLE!", "RAMPAGE!"]
const STREAK_SHARE := [0.5, 1.0, 1.5]  # of the season's knockdown bounty
const WORD_WINDOW := 0.6
const TRAIL_LIFE := 2.8               # a streak lasts this long, so a galloping horse's line of them is about Race.DRAFT_RANGE long
const TRAIL_STREAKS := 40
const TRAIL_SHOWN := 110.0            # metres ahead of the player that a rival still shows one
const TRAIL_COLOUR := Color(0.5, 0.92, 0.9)   # turquoise like the HUD's slipstream meter, so it shows on a pale road too
const TRAIL_ALPHA := 0.5
const TRAIL_ALPHA_IN := 0.95          # when the player is riding in it

var race: Race
var rng := RandomNumberGenerator.new()

var _walls: Array[Dictionary] = []    # boulders, sorted by s. Skimming a mani wall or chorten earns nothing: they're sacred sites, not obstacles to show off on.
var _wi := 0
var _prev_s := 0.0
var _mover_side: Dictionary = {}      # mover id -> side of the player it was last seen on
var _last_near := -99.0
var _last_pass_call := -99.0
var _word_stamps: Array[float] = []   # race time of each recent comic word, from anyone
var _ahead: Dictionary = {}
var _pass_cd: Dictionary = {}
var _kd_seen := 0
var _streak := 0
var _last_kd := -99.0
var _delayed: Array[Dictionary] = []
var _trails: Dictionary = {}          # Rider -> the streaks behind them
var _draft_on := false
var _last_whoosh := -99.0


func bind(p_race: Race) -> void:
	race = p_race
	rng.randomize()
	for e in race.hazards.statics:
		if e["type"] == "boulder":
			_walls.append(e)
	_walls.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) < float(b["s"]))
	_prev_s = race.player.s
	for r in race.riders:
		if r != race.player:
			var t := _make_trail()
			add_child(t)
			_trails[r] = t
	race.rider_crashed.connect(_on_crashed)
	race.announcement.connect(_on_announcement)


## A horse's wind trail: streaks of air that stay where the horse left them and fade out, so the line of them behind
## each rival is the slipstream, about as long as the slipstream reaches. Ride into it.
func _make_trail() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = TRAIL_STREAKS
	p.lifetime = TRAIL_LIFE
	p.local_coords = false
	p.emitting = false
	p.direction = Vector3(0, 0, -1)     # the air is dragged along a little after the horse
	p.spread = 3.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3.ZERO
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.85, 0.55, 0.3)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.06, 0.06, 2.6)
	p.mesh = bm
	var ramp := Gradient.new()
	ramp.set_offset(0, 0.0)
	ramp.set_color(0, Color(1, 1, 1, 0.0))
	ramp.set_offset(1, 1.0)
	ramp.set_color(1, Color(1, 1, 1, 0.0))
	ramp.add_point(0.1, Color(1, 1, 1, 1.0))
	ramp.add_point(0.55, Color(1, 1, 1, 0.55))
	p.color_ramp = ramp
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(TRAIL_COLOUR, TRAIL_ALPHA)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# a streak right by the camera would be a great white bar, so they fade away as they come close to it
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 3.0
	m.distance_fade_max_distance = 11.0
	p.material_override = m
	return p


func _on_announcement(_text: String, kind: String) -> void:
	if kind == "good" or kind == "bad":
		_word_stamps.append(race.race_time)


## Comic words the HUD can still show: at most two, each lives 0.6 s.
func _room_for_word() -> bool:
	var live := 0
	for t in _word_stamps:
		if race.race_time - t < WORD_WINDOW:
			live += 1
	return live < 2


func _say(text: String, kind: String = "good") -> void:
	if _room_for_word():
		race.announcement.emit(text, kind)


func _process(dt: float) -> void:
	if race == null or race.player == null:
		return
	var i := _delayed.size() - 1
	while i >= 0:
		_delayed[i]["t"] = float(_delayed[i]["t"]) - dt
		if float(_delayed[i]["t"]) <= 0.0:
			var fn: Callable = _delayed[i]["fn"]
			_delayed.remove_at(i)
			fn.call()
		i -= 1
	while _word_stamps.size() > 0 and race.race_time - _word_stamps[0] > WORD_WINDOW:
		_word_stamps.pop_front()
	var p := race.player
	if race.started and not race.ended:
		_near_misses(p)
		_overtakes(p)
	_slipstream(p)
	_prev_s = p.s


# --- near misses -------------------------------------------------------------------------------------------------------

func _near_misses(p: Rider) -> void:
	var eligible := p.is_riding() and p.speed >= NEAR_SPEED and p.height < 0.6 and not p.finished
	while _wi < _walls.size() and float(_walls[_wi]["s"]) <= p.s:
		var e := _walls[_wi]
		_wi += 1
		if not eligible or float(e["s"]) <= _prev_s:
			continue
		var gap := absf(p.d - float(e["d"])) - (float(e["r"]) + 0.6)
		if gap > 0.0 and gap <= NEAR_GAP:
			_near_miss()
	for m in race.hazards.movers:
		var kind: String = m["kind"]
		if kind != "yak" and kind != "mule":
			continue
		var ms: float = m["s"]
		if absf(ms - p.s) > 16.0:
			continue
		var id: int = m["id"]
		var side := 1 if p.s > ms else -1
		var was := int(_mover_side.get(id, 0))
		_mover_side[id] = side
		if was == -1 and side == 1 and eligible and p.speed - float(m.get("vs", 0.0)) > 8.0:
			var gap2 := absf(p.d - float(m["d"])) - (float(m.get("rd", m["r"])) + 0.5)
			if gap2 > 0.0 and gap2 <= NEAR_GAP:
				_near_miss()


func _near_miss() -> void:
	var p := race.player
	if race.race_time - _last_near < NEAR_COOLDOWN:
		return
	_last_near = race.race_time
	p.near_misses += 1
	p.silver_bonus += NEAR_SILVER
	p.add_lungta(0.1)
	if not race.hazards.in_quiet(p.s):
		Sfx.play("near_miss", -2.0, rng.randf_range(0.95, 1.08))
	_say("CLOSE!  +%d" % NEAR_SILVER)


# --- overtakes -------------------------------------------------------------------------------------------------------------

func _overtakes(p: Rider) -> void:
	for r in race.riders:
		if r == p:
			continue
		var ds := r.s - p.s
		var st := int(_ahead.get(r, 0))
		var now_st := st
		if ds > 2.5:
			now_st = 1
		elif ds < -2.5:
			now_st = -1
		if st == 1 and now_st == -1 and p.is_riding() and r.is_riding() and p.invuln_t <= 0.0 and r.invuln_t <= 0.0 \
				and absf(r.d - p.d) < 7.0 and race.race_time > 4.0 and race.race_time - float(_pass_cd.get(r, -99.0)) > PASS_COOLDOWN:
			_pass_cd[r] = race.race_time
			p.overtakes += 1
			if race.race_time - _last_pass_call > 1.8:
				_last_pass_call = race.race_time
				_say("PASSED %s!" % r.rival_id.to_upper())
		_ahead[r] = now_st


# --- knockdown streaks ------------------------------------------------------------------------------------------------------

func _on_crashed(_r: Rider, _reason: String) -> void:
	var p := race.player
	if p.knockdowns <= _kd_seen:
		return
	_kd_seen = p.knockdowns
	_streak = _streak + 1 if race.race_time - _last_kd <= STREAK_WINDOW else 1
	_last_kd = race.race_time
	p.best_streak = maxi(p.best_streak, _streak)
	if _streak < 2:
		return
	var tier := clampi(_streak - 2, 0, STREAK_CALLS.size() - 1)
	var bonus := int(round(float(GameData.bounty(race.season)) * float(STREAK_SHARE[tier])))
	p.silver_bonus += bonus
	var text := "%s  +%d" % [STREAK_CALLS[tier], bonus]
	# a beat after the KNOCKDOWN word, so the two do not land on the same frame
	_delayed.append({"t": 0.45, "fn": func() -> void: race.announcement.emit(text, "good")})


# --- slipstream ----------------------------------------------------------------------------------------------------------------

## Every rival ahead of the player trails a line of wind streaks, brighter when the player is riding in it. Moving into a
## trail, the wind takes a breath.
func _slipstream(p: Rider) -> void:
	var lead := p.draft_from if p.is_riding() else null
	for r: Rider in _trails:
		var t: CPUParticles3D = _trails[r]
		var ahead := r.s - p.s
		var go := r.is_riding() and r.speed > 8.0 and ahead > -6.0 and ahead < TRAIL_SHOWN
		t.emitting = go
		if go:
			t.global_transform = race.track.frame(r.s - 1.3, r.d, 1.2)
		var m := t.material_override as StandardMaterial3D
		var alpha := TRAIL_ALPHA + (TRAIL_ALPHA_IN - TRAIL_ALPHA) * (p.draft if r == lead else 0.0)
		m.albedo_color.a = lerpf(m.albedo_color.a, alpha, 0.12)
	var on := lead != null and p.draft > 0.3 and p.speed > 9.0
	if on and not _draft_on and race.race_time - _last_whoosh > 4.0:
		_last_whoosh = race.race_time
		Sfx.play("whoosh", -16.0, 0.6)
	_draft_on = on
