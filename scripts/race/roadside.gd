class_name Roadside
extends RefCounted
## What stands beside the road for the taking: archery bullseyes, and flocks of sheep with wolves worrying them. Riders don't
## have to bother with any of it. A shot scores silver on a bullseye's rings or by driving off a wolf, and a shot that lands
## on a sheep costs a fine. A blow from the saddle counts too, but all of it stands out past the road's edge, so reaching
## it with a weapon means riding the rough. Nothing here dies: a wolf that's hit yelps and runs for it, a sheep bolts and
## comes back. Only the player earns or pays, though anyone's stray shot will scare an animal. Own random numbers, so it
## never disturbs Race.rng.

const FLOCK_MIN_OUT := 5.0        # no animal comes nearer the road's edge than this
const FLOCK_RADIUS := 4.5
const FLOCK_ACTIVE := 260.0       # a flock moves only with the player this close, and is built only then
const BOARD_HEIGHT := 2.4         # these three match art/blender/props_sacred.py
const RINGS: Array[float] = [1.05, 0.7, 0.35]
const RING_SILVER: Array[int] = [5, 10, 20]
const RING_WORDS: Array[String] = ["ON THE BOARD", "GOOD SHOT", "BULLSEYE!"]
const STRUCK_SILVER := 10         # a bullseye struck with a weapon
const WOLF_SILVER := 12
const SHEEP_FINE := 8
const BEAST_RADIUS := 0.7
const BEAST_HEIGHT := 1.3
const WOLF_SIZE := 1.3            # a little bigger than life, like the mastiffs, to read from a gallop
const SHEEP_SIZE := 1.15
const BOARD_ANGLE := 25.0         # a board faces this many degrees from straight back down the road, toward it
const GALLOP_STRIDE := 2.6

enum Struck { NOTHING, BOARD, BEAST }


class Board:
	var s := 0.0
	var d := 0.0
	var centre := Vector3.ZERO
	var normal := Vector3.BACK
	var scored := false
	var wobble := 0.0
	var node: Node3D = null


class Beast:
	var kind := "sheep"
	var s := 0.0
	var d := 0.0
	var vs := 0.0
	var vd := 0.0
	var pos := Vector3.ZERO
	var state := "graze"
	var t := 0.0
	var aim := Vector2.ZERO           # where a grazing sheep is headed, or which way a wolf is circling
	var prey: Beast = null
	var phase := 0.0
	var hit_cd := 0.0
	var gone := false
	var node: Node3D = null


class Flock:
	var s := 0.0
	var d := 0.0
	var side := 1.0
	var beasts: Array[Beast] = []
	var live := false


var race: Race
var track: Track
var rng := RandomNumberGenerator.new()
var boards: Array[Board] = []
var flocks: Array[Flock] = []
var wolves_driven := 0            # by the player, for the tests and the HUD
var sheep_struck := 0
var pay := 1.0                    # the prizes grow with the Season, and so does this


func setup(p_race: Race, events: Array) -> void:
	race = p_race
	track = race.track
	pay = 1.0 + 0.5 * float(race.season)
	var seed_v := int(race.config.get("seed", 0))
	if seed_v != 0:
		rng.seed = seed_v * 104729 + 31
	else:
		rng.randomize()
	for ev: Dictionary in events:
		match String(ev.get("type", "")):
			"bullseye":
				var b := Board.new()
				b.s = float(ev["s"])
				b.d = float(ev["d"])
				boards.append(b)
			"wolf_flock":
				var f := Flock.new()
				f.s = float(ev["s"])
				f.d = float(ev["d"])
				f.side = 1.0 if f.d >= 0.0 else -1.0
				for i in int(ev.get("sheep", 5)):
					f.beasts.append(_beast("sheep", f))
				for i in int(ev.get("wolves", 2)):
					f.beasts.append(_beast("wolf", f))
				flocks.append(f)


func _beast(kind: String, f: Flock) -> Beast:
	var b := Beast.new()
	b.kind = kind
	var a := rng.randf() * TAU
	var r := FLOCK_RADIUS * (0.95 if kind == "wolf" else rng.randf_range(0.1, 0.65))
	b.s = f.s + cos(a) * r
	b.d = f.d + sin(a) * r
	b.phase = rng.randf() * TAU
	b.t = rng.randf_range(0.0, 2.5)
	b.aim = Vector2(cos(a), sin(a)) * r if kind == "sheep" else Vector2(1.0 if rng.randf() < 0.5 else -1.0, 0.0)
	b.state = "circle" if kind == "wolf" else "graze"
	return b


## Now that the land is known: moves anything on a cliff or in a ditch across to the other side of the road if that's better,
## and gives up on it if neither will do. With no land (headless) everything stays on the level with the road.
func settle() -> void:
	var keep_boards: Array[Board] = []
	for b in boards:
		if not _flat(b.s, b.d):
			if not _flat(b.s, -b.d):
				continue
			b.d = -b.d
		var tangent := track.tangent_at(b.s)
		var flat := Vector3(tangent.x, 0.0, tangent.z).normalized()
		var toward_road := -track.right_at(b.s) * signf(b.d)
		b.normal = (-flat * cos(deg_to_rad(BOARD_ANGLE)) + toward_road * sin(deg_to_rad(BOARD_ANGLE))).normalized()
		var at := track.point(b.s, b.d)
		b.centre = Vector3(at.x, _ground(b.s, b.d) + BOARD_HEIGHT, at.z)
		keep_boards.append(b)
	boards = keep_boards
	var keep_flocks: Array[Flock] = []
	for f in flocks:
		if not _flat(f.s, f.d):
			if not _flat(f.s, -f.d):
				continue
			for b in f.beasts:
				b.d = -f.d + (b.d - f.d)
			f.d = -f.d
			f.side = -f.side
		for b in f.beasts:
			_keep_out_of_road(b, f)
			_locate(b)
		keep_flocks.append(f)
	flocks = keep_flocks


func _ground(s: float, d: float) -> float:
	if race.terrain != null:
		return float(race.terrain.call("height_at", s, d))
	return track.point(clampf(s, 0.0, track.length), d).y


## Level enough to stand on, and near the height of the road: no cliff, bank or river cut.
func _flat(s: float, d: float) -> bool:
	if race.terrain == null:
		return true
	var road_y := track.point(s).y
	if absf(_ground(s, d) - road_y) > 3.0:
		return false
	return absf(_ground(s, d + 3.0) - _ground(s, d - 3.0)) < 2.0 and absf(_ground(s + 3.0, d) - _ground(s - 3.0, d)) < 2.0


func _hw(s: float) -> float:
	return track.half_width_at(clampf(s, 0.0, track.length))


func _locate(b: Beast) -> void:
	var at := track.point(clampf(b.s, 0.0, track.length), b.d)
	b.pos = Vector3(at.x, _ground(b.s, b.d), at.z)


func _keep_out_of_road(b: Beast, f: Flock) -> void:
	var nearest := _hw(b.s) + FLOCK_MIN_OUT
	if b.d * f.side < nearest:
		b.d = f.side * nearest


# --- the animals ---------------------------------------------------------------------------------------------------------

func update(dt: float) -> void:
	if race.player == null:
		return
	for b in boards:
		b.wobble = maxf(0.0, b.wobble - dt * 2.5)
	for f in flocks:
		if absf(f.s - race.player.s) > FLOCK_ACTIVE:
			continue
		for b in f.beasts:
			if b.gone:
				continue
			b.hit_cd = maxf(0.0, b.hit_cd - dt)
			if b.kind == "wolf":
				_tick_wolf(b, f, dt)
			else:
				_tick_sheep(b, f, dt)
			b.s += b.vs * dt
			b.d += b.vd * dt
			if b.state != "flee":
				_keep_out_of_road(b, f)
			_locate(b)


func _towards(b: Beast, to_s: float, to_d: float, speed: float, dt: float, ease := 0.2) -> void:
	var to := Vector2(to_s - b.s, to_d - b.d)
	var v := to.normalized() * speed if to.length() > 0.05 else Vector2.ZERO
	var k := 1.0 - exp(-dt / ease)
	b.vs = lerpf(b.vs, v.x, k)
	b.vd = lerpf(b.vd, v.y, k)


## Round the flock at a lope, then in at the nearest sheep, then back out. A wolf that's been hit runs for the hills.
func _tick_wolf(b: Beast, f: Flock, dt: float) -> void:
	b.t -= dt
	match b.state:
		"circle":
			var a := atan2(b.d - f.d, b.s - f.s) + b.aim.x * 0.7
			_towards(b, f.s + cos(a) * FLOCK_RADIUS, f.d + sin(a) * FLOCK_RADIUS, 4.5, dt)
			if b.t <= 0.0:
				b.prey = _nearest_sheep(b, f)
				if b.prey != null:
					b.state = "lunge"
					b.t = 1.3
				else:
					b.t = 2.0
		"lunge":
			if b.prey == null or b.prey.gone:
				b.state = "circle"
				b.t = 1.0
				return
			_towards(b, b.prey.s, b.prey.d, 8.5, dt, 0.1)
			if b.t <= 0.0 or Vector2(b.prey.s - b.s, b.prey.d - b.d).length() < 0.9:
				b.prey = null
				b.state = "circle"
				b.t = rng.randf_range(1.4, 3.4)
				b.aim.x = -b.aim.x
		"flee":
			_towards(b, b.s - 6.0, b.d + f.side * 30.0, 13.0, dt, 0.08)
			if b.t <= 0.0:
				b.gone = true
				_drop_node(b)


func _nearest_sheep(b: Beast, f: Flock) -> Beast:
	var best: Beast = null
	var best_d := INF
	for o in f.beasts:
		if o.kind == "sheep":
			var dist := Vector2(o.s - b.s, o.d - b.d).length()
			if dist < best_d:
				best_d = dist
				best = o
	return best


## Grazing about the middle of the flock, until a wolf comes close, and then away from it.
func _tick_sheep(b: Beast, f: Flock, dt: float) -> void:
	b.t -= dt
	var threat: Beast = null
	var threat_d := 3.2
	for o in f.beasts:
		if o.kind == "wolf" and not o.gone and o.state != "flee":
			var dist := Vector2(o.s - b.s, o.d - b.d).length()
			if dist < threat_d:
				threat_d = dist
				threat = o
	if threat != null:
		b.state = "bolt"
		b.t = 0.8
		var away := Vector2(b.s - threat.s, b.d - threat.d).normalized()
		b.aim = Vector2(b.s, b.d) + away * 5.0
	match b.state:
		"graze":
			_towards(b, f.s + b.aim.x, f.d + b.aim.y, 0.8, dt, 0.5)
			if b.t <= 0.0 or Vector2(f.s + b.aim.x - b.s, f.d + b.aim.y - b.d).length() < 0.3:
				var a := rng.randf() * TAU
				b.aim = Vector2(cos(a), sin(a)) * rng.randf_range(0.3, FLOCK_RADIUS * 0.65)
				b.t = rng.randf_range(2.0, 5.0)
		"bolt":
			_towards(b, b.aim.x, b.aim.y, 5.5, dt, 0.1)
			if b.t <= 0.0:
				b.state = "graze"
				b.t = 0.0


# --- what a shot or a blow does -------------------------------------------------------------------------------------------

## A shot on its way past this tick, and what it struck.
func shot(p: Projectile) -> Struck:
	for b in boards:
		if absf(b.s - p.s) < 8.0 and _board_shot(p, b):
			return Struck.BOARD
	for f in flocks:
		if absf(f.s - p.s) > 16.0:
			continue
		for beast in f.beasts:
			if not beast.gone and _beast_shot(p, beast):
				_hit_beast(p.shooter, beast, f)
				return Struck.BEAST
	return Struck.NOTHING


## The shot crosses the board's face inside the outer ring: its rings pay more the nearer the middle. It stops where it hit.
func _board_shot(p: Projectile, b: Board) -> bool:
	var before := (p.last_pos - b.centre).dot(b.normal)
	var after := (p.pos - b.centre).dot(b.normal)
	if before <= 0.0 or after > 0.0:
		return false
	var at := p.last_pos.lerp(p.pos, before / (before - after))
	var off := at.distance_to(b.centre)
	if off > RINGS[0]:
		return false
	var ring := 0
	for i in RINGS.size():
		if off <= RINGS[i]:
			ring = i
	if not b.scored and p.shooter.is_player:
		b.scored = true
		_pay(p.shooter, RING_SILVER[ring], RING_WORDS[ring], at, 0.1 + 0.1 * float(ring))
	b.wobble = 1.0
	p.pos = at
	return true


func _beast_shot(p: Projectile, b: Beast) -> bool:
	var a := p.last_pos - b.pos
	var c := p.pos - b.pos
	var flat_a := Vector2(a.x, a.z)
	var flat_ac := Vector2(c.x - a.x, c.z - a.z)
	var t := clampf(-flat_a.dot(flat_ac) / maxf(flat_ac.length_squared(), 0.0001), 0.0, 1.0)
	if (flat_a + flat_ac * t).length() > BEAST_RADIUS:
		return false
	var y := lerpf(a.y, c.y, t)
	return y >= 0.0 and y <= BEAST_HEIGHT


## A blow from the saddle on whatever is in reach on that side. side 0 reaches either way (a kick). True if it landed.
func struck(r: Rider, reach: float, side: int) -> bool:
	for b in boards:
		if _in_reach(r, b.s, b.d, reach, side):
			if not b.scored and r.is_player:
				b.scored = true
				_pay(r, STRUCK_SILVER, "GOOD BLOW", b.centre, 0.1)
			b.wobble = 1.0
			return true
	for f in flocks:
		if absf(f.s - r.s) > 20.0:
			continue
		for beast in f.beasts:
			if not beast.gone and _in_reach(r, beast.s, beast.d, reach, side):
				_hit_beast(r, beast, f)
				return true
	return false


func _in_reach(r: Rider, s: float, d: float, reach: float, side: int) -> bool:
	var dx := d - r.d
	if side != 0 and dx * float(side) < 0.2:
		return false
	var ds := s - r.s
	return absf(ds) <= reach and sqrt(dx * dx + ds * ds) <= reach + 0.5


func _hit_beast(r: Rider, b: Beast, f: Flock) -> void:
	if b.hit_cd > 0.0 or b.state == "flee":
		return
	b.hit_cd = 0.6
	var up := b.pos + Vector3.UP * 0.8
	if b.kind == "wolf":
		b.state = "flee"
		b.t = 2.6
		b.prey = null
		if r.is_player:
			wolves_driven += 1
			_pay(r, WOLF_SILVER, "WOLF!", up, 0.2)
		_sound("dog_bark", up, -3.0, 1.55)
	else:
		b.state = "bolt"
		b.t = 1.2
		var away := Vector2(b.s - r.s, b.d - r.d).normalized()
		b.aim = Vector2(b.s, b.d) + away * 6.0
		fine_for_sheep(r, up)
		_sound("sheep_bleat", up, -2.0, 1.2)
	if not race.headless and r.is_player and race.fx != null:
		race.fx.call("burst", up, Vector3.UP, Color("f4efe4"), 0.5)


## Silver and fortune for the player, and everyone is told.
func _pay(r: Rider, silver: int, words: String, at: Vector3, fortune: float) -> void:
	var amount := roundi(float(silver) * pay)
	r.silver_bonus += amount
	r.add_lungta(fortune)
	race.announcement.emit("%s  +%d" % [words, amount], "good")
	race.rider_event.emit("roadside", r, {"silver": amount, "what": words})
	_sound("bell" if silver >= RING_SILVER[2] else "coin", at, -2.0, 1.0)
	if not race.headless and race.fx != null:
		race.fx.call("burst", at, Vector3.UP, Color("ffd24a"), 0.7)


## Hitting a sheep costs a fine, wherever the sheep is. Only the player has a herder to answer to.
func fine_for_sheep(r: Rider, _at: Vector3) -> void:
	if not r.is_player:
		return
	sheep_struck += 1
	var amount := roundi(float(SHEEP_FINE) * pay)
	r.fines += amount
	r.add_lungta(-0.2)
	race.announcement.emit("NOT THE SHEEP!  -%d" % amount, "bad")
	race.rider_event.emit("roadside", r, {"silver": -amount, "what": "sheep"})


func _sound(name: String, at: Vector3, db: float, pitch: float) -> void:
	if not race.headless and not race.hazards.in_quiet(race.player.s):
		Sfx.play_at(name, at, db, pitch)


## Whether a shot at this point in the air, after flying this long, would be at something it could hit here.
func near_target(q: Vector3, fly: float) -> bool:
	for b in boards:
		if b.centre.distance_to(q) < RINGS[0] + 0.4:
			return true
	for f in flocks:
		if absf(f.s - race.player.s) < FLOCK_ACTIVE:
			for beast in f.beasts:
				if not beast.gone:
					var at := track.point(clampf(beast.s + beast.vs * fly, 0.0, track.length), beast.d + beast.vd * fly)
					if Vector3(at.x, beast.pos.y + 0.6, at.z).distance_to(q) < BEAST_RADIUS + 0.4:
						return true
	return false


# --- what it looks like ---------------------------------------------------------------------------------------------------

var _parent: Node3D = null
var _scan := 0.0


func build_visuals(parent: Node3D) -> void:
	_parent = Node3D.new()
	_parent.name = "Roadside"
	parent.add_child(_parent)


func update_visuals(dt: float) -> void:
	if _parent == null or race.player == null:
		return
	_scan -= dt
	if _scan <= 0.0:
		_scan = 0.3
		_manage(race.player.s)
	for b in boards:
		if b.node != null:
			_place_board(b)
	for f in flocks:
		if f.live:
			for beast in f.beasts:
				if beast.node != null:
					_place_beast(beast, dt)


## Models exist only around the player: built as they come into range, freed once they're well behind.
func _manage(ps: float) -> void:
	for b in boards:
		var near := b.s > ps - 80.0 and b.s < ps + 420.0
		if near and b.node == null:
			b.node = ArtKit.prop("bullseye")
			_parent.add_child(b.node)
			_place_board(b)
		elif not near and b.node != null:
			b.node.queue_free()
			b.node = null
	for f in flocks:
		var near := f.s > ps - 70.0 and f.s < ps + FLOCK_ACTIVE
		if near and not f.live:
			f.live = true
			for beast in f.beasts:
				if not beast.gone:
					beast.node = ArtKit.prop_walker(beast.kind)
					_parent.add_child(beast.node)
					_place_beast(beast, 0.0)
		elif not near and f.live:
			f.live = false
			for beast in f.beasts:
				_drop_node(beast)


func _drop_node(b: Beast) -> void:
	if b.node != null and is_instance_valid(b.node):
		b.node.queue_free()
	b.node = null


## The board faces its normal, nodding on its stand when something strikes it.
func _place_board(b: Board) -> void:
	var foot := b.centre - Vector3.UP * BOARD_HEIGHT
	var basis := Basis.looking_at(b.normal, Vector3.UP)
	if b.wobble > 0.0:
		basis = basis * Basis(Vector3.RIGHT, 0.09 * b.wobble * sin(b.wobble * 18.0))
	b.node.global_transform = Transform3D(basis, foot)


func _place_beast(b: Beast, dt: float) -> void:
	var tangent := track.tangent_at(clampf(b.s, 0.0, track.length))
	var flat := Vector3(tangent.x, 0.0, tangent.z).normalized()
	var heading := flat * b.vs + track.right_at(clampf(b.s, 0.0, track.length)) * b.vd
	var speed := Vector2(b.vs, b.vd).length()
	var size := WOLF_SIZE if b.kind == "wolf" else SHEEP_SIZE
	if speed > 0.25:
		var basis := Basis.looking_at(heading.normalized(), Vector3.UP).scaled_local(Vector3.ONE * size)
		b.node.global_transform = Transform3D(basis, b.pos)
	else:
		b.node.global_position = b.pos
		if dt == 0.0:
			b.node.rotation.y = b.phase
			b.node.scale = Vector3.ONE * size
	var stride := ArtKit.walker_stride_length(b.node) * (GALLOP_STRIDE if speed > 3.0 else 1.0)
	b.phase = fposmod(b.phase + TAU * speed * dt / maxf(stride, 0.1), TAU)
	ArtKit.set_stride(b.node, b.phase, clampf(speed / 2.0, 0.0, 1.0))
