class_name Life
extends Node3D
## Roadside life, all of it for show: mastiffs that run the verge barking at the riders, kiang that gallop beside the road
## on the Grass Sea, cranes that lift off as you pass and marmots that pop up, whistle and duck. Nothing here collides or
## touches the simulation, everything stays off the road, and each animal exists only while the player is close to it.
## Own random numbers, so it never disturbs Race.rng.

const MAX_DOGS := 4
const MAX_CRANES := 6
const MAX_MARMOTS := 4
const DOG_TOP_SPEED := 16.5
## A little bigger than life, so the mastiff and the marmot read from a gallop.
const SCALE := {"dog": 1.3, "kiang": 1.0, "crane": 1.2, "marmot": 1.3}
const KIANG_COURSES := ["grass_sea"]
const CRANE_COURSES := ["grass_sea", "turquoise_pass", "gallop_behind_the_fort"]
const MARMOT_COURSES := ["grass_sea", "turquoise_pass"]
const HOMES := ["tent_black", "house_kham", "house_tsang", "house_white"]
## Metres a prop_walker covers in one gallop cycle, as a multiple of the walking stride Art gives it.
const GALLOP_STRIDE := 3.2


class Actor:
	var kind := ""
	var node: Node3D = null
	var s := 0.0
	var d := 0.0
	var h := 0.0
	var vs := 0.0
	var vd := 0.0
	var vh := 0.0
	var state := "idle"
	var t := 0.0
	var phase := 0.0
	var home_s := 0.0
	var home_d := 0.0
	var side := 1.0
	var timer := 0.0
	var bark := 0.0
	var pulse := 0.0
	var aux := 4.5                         # a dog's distance past the road edge while it runs the verge
	var face := 0.0                        # yaw, from the track direction, an animal holds while it stands
	var spot: Dictionary = {}
	var static_node: Node3D = null


var race: Race
var track: Track
var rng := RandomNumberGenerator.new()
var dogs: Array[Actor] = []
var kiang: Array[Actor] = []
var cranes: Array[Actor] = []
var marmots: Array[Actor] = []
var count_alive := 0                       # for the tests: actors in the tree right now

var _ak: GDScript = null
var _has_walker := false
var _has_stride := false
var _course_id := ""
var _dog_spots: Array[Dictionary] = []
var _crane_spots: Array[Dictionary] = []
var _marmot_spots: Array[Dictionary] = []
var _kiang_on := false
var _next_herd := 150.0                    # player.s at which the next herd shows up
var _scan := 0.0
var _statics: Array[Node3D] = []           # the dressing's own dogs, hidden while a live one stands in their place
var _bark_cd := 0.0


func bind(p_race: Race) -> void:
	race = p_race
	track = race.track
	var seed_v := int(race.config.get("seed", 0))
	if seed_v != 0:
		rng.seed = seed_v * 7919 + 13
	else:
		rng.randomize()
	_course_id = String(race.course.get("id", ""))
	_ak = load("res://scripts/core/art_kit.gd")
	_has_walker = _script_has(_ak, "prop_walker")
	_has_stride = _script_has(_ak, "set_stride")
	_kiang_on = _course_id in KIANG_COURSES
	_find_static_dogs()
	_plan_dogs()
	_plan_cranes()
	_plan_marmots()


func _script_has(script: GDScript, method: String) -> bool:
	for m in script.get_script_method_list():
		if m["name"] == method:
			return true
	return false


# --- planning: where life could be, decided once ---------------------------------------------------------------------

func _find_static_dogs() -> void:
	if race.world == null:
		return
	var dressing := race.world.get_node_or_null("Dressing")
	if dressing == null:
		return
	for c in dressing.get_children():
		if c is Node3D and String(c.scene_file_path).ends_with("/dog.glb"):
			_statics.append(c)


func _hw(s: float) -> float:
	return track.half_width_at(clampf(s, 0.0, track.length))


## World height of the ground at (s, d), on the terrain when we have it and on the road plane when we do not.
func _ground(s: float, d: float) -> float:
	if race.terrain != null:
		return float(race.terrain.call("height_at", s, d))
	return track.point(clampf(s, 0.0, track.length), d, 0.0).y


## True when the ground there is level enough with the road to stand on: no ledges, banks or river cuts.
func _flat_enough(s: float, d: float) -> bool:
	var road_y := track.point(clampf(s, 0.0, track.length), signf(d) * minf(absf(d), _hw(s)), 0.0).y
	if absf(_ground(s, d) - road_y) > 3.2:
		return false
	return absf(_ground(s, d + 2.0) - _ground(s, d - 2.0)) < 1.6 and absf(_ground(s + 2.0, d) - _ground(s - 2.0, d)) < 1.6


func _plan_dogs() -> void:
	var homes: Array[Dictionary] = []
	for sp: Dictionary in race.course.get("set_pieces", []):
		if String(sp.get("prop", "")) in HOMES and sp.has("s"):
			homes.append({"s": float(sp["s"]), "d": float(sp.get("d", 0.0))})
	# one cluster per run of buildings, one dog (two for a big cluster) to guard it
	homes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) < float(b["s"]))
	var i := 0
	while i < homes.size():
		var j := i
		var sum_s := 0.0
		var sum_d := 0.0
		while j < homes.size() and float(homes[j]["s"]) - float(homes[i]["s"]) < 70.0:
			sum_s += float(homes[j]["s"])
			sum_d += float(homes[j]["d"])
			j += 1
		var n := j - i
		var cs := sum_s / float(n)
		var cd := sum_d / float(n)
		var sgn := 1.0 if cd >= 0.0 else -1.0
		var home_d := sgn * maxf(absf(cd) - 9.0, _hw(cs) + 7.0)
		for k in (2 if n >= 4 else 1):
			var hs := cs + rng.randf_range(-6.0, 6.0) + 8.0 * float(k)
			var hd := home_d + sgn * rng.randf_range(-2.0, 2.0)
			if _flat_enough(hs, hd):
				_dog_spots.append({"s": hs, "d": hd, "actor": null})
		i = j
	# a dog the dressing already lies down, even where no building was found
	for sp2: Dictionary in race.course.get("set_pieces", []):
		if String(sp2.get("prop", "")) == "dog" and sp2.has("s"):
			var near := false
			for spot in _dog_spots:
				if absf(float(spot["s"]) - float(sp2["s"])) < 40.0:
					near = true
			if not near and _flat_enough(float(sp2["s"]), float(sp2.get("d", 0.0))):
				_dog_spots.append({"s": float(sp2["s"]), "d": float(sp2.get("d", 0.0)), "actor": null})
	_dog_spots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) < float(b["s"]))


func _plan_cranes() -> void:
	if not _course_id in CRANE_COURSES:
		return
	var s := rng.randf_range(160.0, 260.0)
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	while s < track.length - 260.0:
		var d := side * (_hw(s) + rng.randf_range(11.0, 26.0))
		if _flat_enough(s, d) and _flat_enough(s + 3.0, d + side * 2.0):
			_crane_spots.append({"s": s, "d": d, "actor": null, "gone": false})
		s += rng.randf_range(170.0, 280.0)
		side = -side if rng.randf() < 0.7 else side


func _plan_marmots() -> void:
	if not _course_id in MARMOT_COURSES:
		return
	var s := rng.randf_range(120.0, 200.0)
	while s < track.length - 240.0:
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var d := side * (_hw(s) + rng.randf_range(4.0, 11.0))
		if _flat_enough(s, d):
			_marmot_spots.append({"s": s, "d": d, "actor": null, "done": false})
		s += rng.randf_range(90.0, 170.0)


# --- building and placing ------------------------------------------------------------------------------------------------

func _walker(prop: String) -> Node3D:
	if _has_walker:
		return _ak.call("prop_walker", prop)
	return ArtKit.prop(prop)


func _stride(node: Node3D, phase: float, amp: float) -> void:
	if _has_stride:
		_ak.call("set_stride", node, phase, amp)


func _stride_length(node: Node3D) -> float:
	if node.has_meta("walker_stride"):
		return float(node.get_meta("walker_stride")) * GALLOP_STRIDE
	return 3.0


func _spawn(kind: String, prop: String, walker: bool) -> Actor:
	var a := Actor.new()
	a.kind = kind
	a.node = _walker(prop) if walker else ArtKit.prop(prop)
	add_child(a.node)
	a.node.visible = false
	return a


func _free(a: Actor) -> void:
	if a.static_node != null and is_instance_valid(a.static_node):
		a.static_node.visible = true
	if a.node != null and is_instance_valid(a.node):
		a.node.queue_free()
	a.node = null


## Put an animal on the ground at its track position, facing the way it is moving (or along a.face when it stands).
## squash scales it along its own axes on top of its size, for barks and wingbeats.
func _place(a: Actor, squash: Vector3 = Vector3.ONE) -> void:
	if a.node == null:
		return
	var tangent := track.tangent_at(clampf(a.s, 0.0, track.length))
	var fwd := Vector3(tangent.x, 0.0, tangent.z).normalized()
	var right := track.right_at(clampf(a.s, 0.0, track.length))
	var heading := fwd * a.vs + right * a.vd
	if heading.length() < 0.3:
		heading = fwd.rotated(Vector3.UP, a.face)
	var p := track.point(clampf(a.s, 0.0, track.length), a.d, 0.0)
	p.y = _ground(a.s, a.d) + a.h
	var basis := Basis.looking_at(heading.normalized(), Vector3.UP).scaled_local(squash * float(SCALE.get(a.kind, 1.0)))
	a.node.global_transform = Transform3D(basis, p)
	a.node.visible = true


func _hear(pos: Vector3, name: String, db: float, pitch: float = 1.0) -> void:
	if race.hazards.in_quiet(race.player.s):
		return
	Sfx.play_at(name, pos, db, pitch)


# --- the frame --------------------------------------------------------------------------------------------------------------

func _process(dt: float) -> void:
	if race == null or race.player == null:
		return
	var p := race.player
	_scan -= dt
	_bark_cd = maxf(0.0, _bark_cd - dt)
	if _scan <= 0.0:
		_scan = 0.3
		_manage_dogs(p)
		_manage_cranes(p)
		_manage_marmots(p)
		if _kiang_on and race.started and not race.ended:
			_manage_kiang(p)
	for a in dogs:
		_tick_dog(a, p, dt)
	for a in kiang:
		_tick_kiang(a, p, dt)
	for a in cranes:
		_tick_crane(a, p, dt)
	for a in marmots:
		_tick_marmot(a, p, dt)
	count_alive = dogs.size() + kiang.size() + cranes.size() + marmots.size()


func _cull(list: Array[Actor], p: Rider, behind: float, ahead: float) -> void:
	var i := list.size() - 1
	while i >= 0:
		var a := list[i]
		if a.state == "gone" or a.s < p.s - behind or a.s > p.s + ahead:
			if not a.spot.is_empty():
				a.spot["actor"] = null
			_free(a)
			list.remove_at(i)
		i -= 1


# --- mastiffs -------------------------------------------------------------------------------------------------------------------

func _manage_dogs(p: Rider) -> void:
	_cull(dogs, p, 70.0, 230.0)
	if dogs.size() >= MAX_DOGS:
		return
	for spot in _dog_spots:
		if spot["actor"] != null:
			continue
		var s: float = spot["s"]
		if s < p.s - 40.0 or s > p.s + 170.0:
			continue
		var a := _spawn("dog", "dog", true)
		a.s = s
		a.d = float(spot["d"])
		a.home_s = s
		a.home_d = a.d
		a.side = 1.0 if a.d >= 0.0 else -1.0
		a.state = "idle"
		a.spot = spot
		a.phase = rng.randf() * TAU
		a.aux = rng.randf_range(3.8, 5.6)
		a.face = a.side * PI * 0.5 + rng.randf_range(-0.5, 0.5)
		# the dressing's own dog lying there steps aside for this one
		for sn in _statics:
			if is_instance_valid(sn):
				var sp := track.point(s, a.d, 0.0)
				if Vector2(sn.global_position.x - sp.x, sn.global_position.z - sp.z).length() < 9.0:
					a.static_node = sn
					sn.visible = false
					break
		spot["actor"] = a
		dogs.append(a)
		_place(a)
		if dogs.size() >= MAX_DOGS:
			break


func _tick_dog(a: Actor, p: Rider, dt: float) -> void:
	a.t += dt
	a.pulse = maxf(0.0, a.pulse - dt * 5.0)
	var lane := a.side * (_hw(a.s) + a.aux)
	match a.state:
		"idle":
			a.vs = 0.0
			a.vd = 0.0
			_stride(a.node, a.phase, 0.0)
			# the hooves wake it: a rider coming down the road, a few seconds before it passes
			if p.s > a.home_s - 75.0 and p.s < a.home_s + 25.0 and p.speed > 6.0:
				a.state = "run"
				a.t = 0.0
				a.timer = rng.randf_range(8.0, 10.0)
				a.bark = rng.randf_range(0.2, 0.6)
			_place(a)
		"run":
			# out to the verge near its own patch, then after the player, at a dog's best speed
			var aim_s := maxf(p.s + 15.0 + 3.0 * sin(a.t * 2.3), a.home_s - 6.0)
			var to_s := aim_s - a.s
			var to_d := lane - a.d
			var dist := Vector2(to_s, to_d).length()
			var want := minf(DOG_TOP_SPEED, 5.0 + dist * 2.2)
			var dir := Vector2(to_s, to_d) / maxf(dist, 0.01)
			a.vs = lerpf(a.vs, dir.x * want, 1.0 - exp(-dt / 0.25))
			a.vd = lerpf(a.vd, dir.y * want, 1.0 - exp(-dt / 0.25))
			a.s += a.vs * dt
			a.d += a.vd * dt
			_keep_off_road(a)
			var speed := Vector2(a.vs, a.vd).length()
			a.phase += TAU * speed * dt / _stride_length(a.node)
			_stride(a.node, a.phase, clampf(speed / 6.0, 0.0, 1.0))
			a.bark -= dt
			if a.bark <= 0.0:
				a.bark = rng.randf_range(0.65, 0.95)
				a.pulse = 1.0
				if _bark_cd <= 0.0:
					_bark_cd = 0.25
					_hear(a.node.global_position + Vector3(0, 0.8, 0), "dog_bark", -7.0, rng.randf_range(0.9, 1.1))
			# a hop with each stride, and the whole dog swells a little with every bark
			a.h = 0.08 * absf(sin(a.phase))
			_place(a, Vector3.ONE * (1.0 + 0.07 * a.pulse))
			if a.t > a.timer or p.s - a.s > 28.0:
				a.state = "back"
				a.t = 0.0
		"back":
			var to_home := Vector2(a.home_s - a.s, a.home_d - a.d)
			var dist2 := to_home.length()
			if dist2 < 1.2:
				a.state = "idle"
				a.vs = 0.0
				a.vd = 0.0
			else:
				var v := to_home / dist2 * 5.5
				a.vs = lerpf(a.vs, v.x, 1.0 - exp(-dt / 0.3))
				a.vd = lerpf(a.vd, v.y, 1.0 - exp(-dt / 0.3))
				a.s += a.vs * dt
				a.d += a.vd * dt
				a.phase += TAU * 5.5 * dt / _stride_length(a.node) * 1.6
				_stride(a.node, a.phase, 0.8)
			_keep_off_road(a)
			_place(a)


func _keep_off_road(a: Actor) -> void:
	var limit := _hw(a.s) + 3.2
	if absf(a.d) < limit:
		a.d = signf(a.d if absf(a.d) > 0.01 else a.side) * limit


# --- kiang ----------------------------------------------------------------------------------------------------------------------

func _manage_kiang(p: Rider) -> void:
	_cull(kiang, p, 130.0, 150.0)
	if p.s < _next_herd or not p.is_riding():
		return
	_next_herd = p.s + rng.randf_range(520.0, 840.0)
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	var lane := _hw(p.s) + rng.randf_range(5.0, 11.0)
	var n := rng.randi_range(4, 6)
	# they start just behind the camera and overtake the pack on the verge, so nobody pops into view
	var base_s := p.s - rng.randf_range(26.0, 36.0)
	var lead := rng.randf_range(20.0, 38.0)
	for i in n:
		var a := _spawn("kiang", "kiang", true)
		a.s = base_s + rng.randf_range(-6.0, 6.0) - float(i) * 1.5
		a.aux = lead + rng.randf_range(-6.0, 9.0)
		a.side = side
		a.d = side * (lane + rng.randf_range(-3.5, 6.0))
		if not _flat_enough(a.s, a.d):
			a.d = side * (_hw(a.s) + 9.0)
		a.vs = maxf(p.speed, 12.0)
		a.timer = rng.randf_range(11.0, 14.0)
		a.phase = rng.randf() * TAU
		a.state = "run"
		kiang.append(a)
		_place(a)


func _tick_kiang(a: Actor, p: Rider, dt: float) -> void:
	a.t += dt
	# run up alongside and hold a place ahead of the player, then peel away from the road and slow
	var pace := minf(maxf(p.speed, 12.0) + clampf((p.s + a.aux - a.s) * 0.4, -3.0, 7.0), 26.0)
	if a.t > a.timer:
		pace = maxf(p.speed, 12.0) * 0.55
	a.vs = lerpf(a.vs, pace, 1.0 - exp(-dt / 0.5))
	a.vd = lerpf(a.vd, a.side * (4.5 if a.t > a.timer else 0.0), 1.0 - exp(-dt / 0.6))
	a.s += a.vs * dt
	a.d += a.vd * dt
	_keep_off_road(a)
	var speed := Vector2(a.vs, a.vd).length()
	a.phase += TAU * speed * dt / _stride_length(a.node)
	_stride(a.node, a.phase, clampf(speed / 5.0, 0.0, 1.0))
	a.h = 0.1 * maxf(0.0, sin(a.phase * 2.0))
	_place(a)
	if a.t > a.timer + 7.0:
		a.state = "gone"


# --- cranes ---------------------------------------------------------------------------------------------------------------------

func _manage_cranes(p: Rider) -> void:
	_cull(cranes, p, 60.0, 200.0)
	if cranes.size() >= MAX_CRANES:
		return
	for spot in _crane_spots:
		if spot["actor"] != null or spot["gone"]:
			continue
		var s: float = spot["s"]
		if s < p.s - 20.0 or s > p.s + 150.0:
			continue
		for k in 2:
			var a := _spawn("crane", "crane", false)
			a.s = s + float(k) * 2.4
			a.d = float(spot["d"]) + float(k) * 1.2 * signf(float(spot["d"]))
			a.side = signf(float(spot["d"]))
			a.state = "stand"
			a.spot = spot
			a.timer = rng.randf_range(0.0, 0.35) + float(k) * 0.2
			a.phase = rng.randf() * TAU
			a.face = rng.randf() * TAU
			cranes.append(a)
			_place(a)
		spot["actor"] = cranes[cranes.size() - 1]
		if cranes.size() >= MAX_CRANES:
			break


func _tick_crane(a: Actor, p: Rider, dt: float) -> void:
	match a.state:
		"stand":
			# the whole bird sways a touch, like a head turning
			a.phase += dt * 1.1
			a.node.rotation.z = 0.03 * sin(a.phase)
			if p.s > a.s - 22.0 and p.s < a.s + 40.0 and p.speed > 5.0:
				a.timer -= dt
				if a.timer <= 0.0:
					a.state = "rise"
					a.t = 0.0
					_add_wings(a)
					a.vs = rng.randf_range(6.0, 9.0)
					a.vd = a.side * rng.randf_range(1.5, 3.5)
					a.vh = rng.randf_range(4.5, 6.5)
					if a.spot.get("honked", false) == false:
						a.spot["honked"] = true
						_hear(a.node.global_position + Vector3(0, 1.0, 0), "crane_call", -6.0, rng.randf_range(0.92, 1.08))
					a.spot["gone"] = true
		"rise":
			a.t += dt
			a.s += a.vs * dt
			a.d += a.vd * dt
			a.h += a.vh * dt
			a.vh = move_toward(a.vh, 1.4, 2.2 * dt)
			a.vs = move_toward(a.vs, 12.0, 3.0 * dt)
			_place(a)
			# the bird tips into the climb while its wings beat
			a.node.rotate_object_local(Vector3.RIGHT, 0.35)
			var wings: Array = a.node.get_meta("wings", [])
			var beat := sin(a.t * 13.0 + a.phase)
			for k in wings.size():
				(wings[k] as Node3D).rotation.z = (1.0 if k == 0 else -1.0) * (0.2 + 0.85 * beat)
			if a.t > 7.0 or a.h > 22.0:
				a.state = "gone"
		_:
			pass


## Two flat wings, white with black tips, folded away on the standing crane until it takes off.
func _add_wings(a: Actor) -> void:
	var wings: Array[Node3D] = []
	for side in [1.0, -1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.12 * side, 1.15, -0.1)
		var inner := BoxMesh.new()
		inner.size = Vector3(0.8, 0.035, 0.62)
		var mi := _flat(inner, "a", Color("ece8df"))
		mi.position = Vector3(0.4 * side, 0.0, 0.0)
		pivot.add_child(mi)
		var tip := BoxMesh.new()
		tip.size = Vector3(0.5, 0.035, 0.5)
		var mt := _flat(tip, "b", Color("1b181c"))
		mt.position = Vector3(1.05 * side, 0.0, 0.03)
		pivot.add_child(mt)
		a.node.add_child(pivot)
		wings.append(pivot)
	a.node.set_meta("wings", wings)


const FLAT_SLOTS := {"a": 0, "b": 1, "c": 2, "d": 3}


## A mesh in one flat palette colour: UVs on the atlas's slot row, the colour in an instance uniform.
func _flat(mesh: Mesh, slot: String, col: Color) -> MeshInstance3D:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs := PackedVector2Array()
	var u := 0.0625 + 0.125 * float(FLAT_SLOTS.get(slot, 0))
	uvs.resize(verts.size())
	for k in verts.size():
		uvs[k] = Vector2(u, 0.015)
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = ArtKit.toon(ArtKit.CLASS_PROP)
	mi.set_instance_shader_parameter("slot_" + slot, col)
	return mi


# --- marmots --------------------------------------------------------------------------------------------------------------------

func _manage_marmots(p: Rider) -> void:
	_cull(marmots, p, 40.0, 200.0)
	if marmots.size() >= MAX_MARMOTS:
		return
	for spot in _marmot_spots:
		if spot["actor"] != null or spot["done"]:
			continue
		var s: float = spot["s"]
		if s < p.s + 10.0 or s > p.s + 120.0:
			continue
		var a := _spawn("marmot", "marmot", false)
		a.s = s
		a.d = float(spot["d"])
		a.side = signf(a.d)
		a.state = "hidden"
		a.face = a.side * PI * 0.5
		a.h = -1.1
		a.spot = spot
		a.timer = rng.randf_range(0.0, 0.6)
		# a few stones around the burrow, so the hole reads before anyone is home
		var rock := ArtKit.prop("rock_a")
		rock.scale = Vector3(0.28, 0.2, 0.28)
		rock.position = Vector3(0.0, -0.05, 0.0)
		a.node.add_child(rock)
		a.node.set_meta("rock", rock)
		marmots.append(a)
		spot["actor"] = a
		_place(a)
		if marmots.size() >= MAX_MARMOTS:
			break


func _tick_marmot(a: Actor, p: Rider, dt: float) -> void:
	var gap := a.s - p.s
	match a.state:
		"hidden":
			if gap < 70.0 and gap > 6.0 and p.speed > 5.0:
				a.timer -= dt
				if a.timer <= 0.0:
					a.state = "up"
					a.t = 0.0
					_hear(a.node.global_position + Vector3(0, 0.7, 0), "marmot_whistle", -5.0, rng.randf_range(0.95, 1.12))
		"up":
			a.t += dt
			a.h = lerpf(a.h, 0.0, 1.0 - exp(-dt / 0.07))
			# up on its hind legs, looking along the road
			a.node.rotation.y += 0.0
			if gap < 12.0 or a.t > 3.0 or gap < -4.0:
				a.state = "duck"
				a.t = 0.0
		"duck":
			a.t += dt
			a.h = lerpf(a.h, -1.1, 1.0 - exp(-dt / 0.05))
			if a.t > 0.35:
				a.state = "down"
				a.spot["done"] = true
		_:
			pass
	_place(a)
	# the marmot itself rises out of the hole; the stones stay put
	if a.node.has_meta("rock"):
		var rock: Node3D = a.node.get_meta("rock")
		rock.position.y = (-0.05 - a.h) / float(SCALE["marmot"])
