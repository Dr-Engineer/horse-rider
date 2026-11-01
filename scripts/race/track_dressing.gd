class_name TrackDressing
extends RefCounted
## Static scenery for a course, built from course data (dress layers, set pieces, gates, era details).
##
##   TrackDressing.new(track, course, rng).build_into(parent)
##
## Layers (course.dress.layers): {prop, n per 100 m, d0, d1 (metres beyond half width + 3), bias, side, scale [a, b],
## slope (max 0..1), cull (metres), shadow, align, face_road, herd, nodes, f0, f1, tint}. Grass, rocks, trees and
## bushes become MultiMeshInstance3D chunks along the course. Nothing ever spawns inside half width + 3 m except the
## start and finish gates and the set pieces that are meant to span the road.

const CHUNK := 260.0
const CLEAR := 3.0
const START_CLEAR := 28.0

var track: Track
var course: Dictionary
var rng: RandomNumberGenerator

var _b: TrackBuilder
var _r := RandomNumberGenerator.new()
var _root: Node3D
var _chunks := {}
var _hw := 10.0
var _lake_y := -INF
var _river: Dictionary = {}
var _keep_out: Array = []
## Every scatter and node placement as {prop, pos}, so tests can check clearances.
var placed: Array = []


func _init(p_track: Track, p_course: Dictionary, p_rng: RandomNumberGenerator = null) -> void:
	track = p_track
	course = p_course
	rng = p_rng
	_hw = float(course.get("half_width", 10.0))


func build_into(parent: Node3D) -> void:
	_b = TrackBuilder.new(track, course.biome)
	_b.prepare()
	_r.seed = int(course.biome.get("seed", 1)) * 7919 + int(course.get("season", 0)) * 101
	if course.biome.has("lake"):
		_lake_y = track.positions[0].y + float(course.biome.lake.level)
	if course.biome.has("river"):
		_river = course.biome.river
	_root = Node3D.new()
	_root.name = "Dressing"
	parent.add_child(_root)

	for ev: Dictionary in course.events:
		if ev.type == "start" or ev.type == "finish":
			_keep_out.append([float(ev.s) - 30.0, float(ev.s) + 30.0])
		elif ev.type == "bullseye" or ev.type == "wolf_flock":
			_keep_out.append([float(ev.s) - 12.0, float(ev.s) + 12.0])     # a clear view of them from the road
	for sp: Dictionary in course.get("set_pieces", []):
		if sp.prop == "bridge_cant" or sp.prop == "gate_chorten":
			_keep_out.append([float(sp.s) - 40.0, float(sp.s) + 40.0])

	var dress: Dictionary = course.get("dress", {})
	for layer: Dictionary in dress.get("layers", []):
		if layer.get("nodes", false):
			_scatter_nodes(layer)
		else:
			_scatter_multi(layer)
	_flush_chunks()
	for sp: Dictionary in course.get("set_pieces", []):
		_place_piece(sp)
	_gates_and_crowds()
	if dress.get("survey_stakes", false):
		_survey_stakes()
	if dress.get("truck", false):
		_place_truck()
	if dress.get("milestones", true):
		_milestones()
	if dress.get("plumes", false):
		_dust_plumes()


# --- helpers ------------------------------------------------------------------------------------------------------

func _has_prop(name: String) -> bool:
	return ResourceLoader.exists("res://assets/models/props/%s.glb" % name)


func _in_keep_out(s: float) -> bool:
	for k: Array in _keep_out:
		if s > float(k[0]) and s < float(k[1]):
			return true
	return false


func _yaw_along(s: float) -> float:
	var fwd := track.tangent_at(clampf(s, 0.0, track.length))
	return -atan2(fwd.x, -fwd.z)


func _yaw_to_road(s: float, lat: float) -> float:
	var right := track.right_at(clampf(s, 0.0, track.length))
	var to_road := -right * signf(lat)
	return -atan2(to_road.x, -to_road.z)


func _wet(x: float, z: float, y: float, s: float, lat: float) -> bool:
	if _lake_y > -INF and y < _lake_y + 0.6:
		return true
	if not _river.is_empty():
		var q := _b.river_at(int(s / Track.STEP))
		if absf(lat - float(q.offset)) < float(q.width) * 0.5 + 4.0:
			var ry := track.point(s).y - float(q.depth) - 0.18 + float(_river.get("lift", 1.1))
			if y < ry + 0.8:
				return true
	return false


func _slope_at(x: float, z: float) -> float:
	var h := 1.6
	var dx := _b.ground_y(x + h, z) - _b.ground_y(x - h, z)
	var dz := _b.ground_y(x, z + h) - _b.ground_y(x, z - h)
	var n := Vector3(-dx, 2.0 * h, -dz).normalized()
	return 1.0 - n.y


## Picks a spot for a layer: returns {} when rejected. lat is metres right of the road centre.
func _pick(layer: Dictionary, s: float, side: int, lat_in: float = NAN, extent: float = 0.0) -> Dictionary:
	if _in_keep_out(s):
		return {}
	var hw := track.half_width_at(s)
	var lat := lat_in
	if is_nan(lat):
		var d0: float = layer.get("d0", 1.0)
		var d1: float = layer.get("d1", 40.0)
		var u := pow(_r.randf(), float(layer.get("bias", 1.0)))
		lat = float(side) * (hw + CLEAR + d0 + (d1 - d0) * u)
	# Big props keep their whole footprint off the road, not just their centre.
	if absf(lat) < hw + CLEAR + extent:
		lat = signf(lat) * (hw + CLEAR + extent + 0.2)
	if absf(lat) < hw + CLEAR:
		return {}
	var p := track.point(s, lat)
	var y := _b.ground_y(p.x, p.z)
	if _wet(p.x, p.z, y, s, lat):
		return {}
	if _slope_at(p.x, p.z) > float(layer.get("slope", 0.6)):
		return {}
	# Far enough out from this stretch of road can still be on another, across the inside of a tight bend.
	if _b.road_gap(p.x, p.z) < hw + CLEAR:
		return {}
	return {"pos": Vector3(p.x, y, p.z), "s": s, "lat": lat}


var _radius_cache := {}


## Half the footprint of a prop. Props that run along the road (align) only count their narrow side.
func _prop_radius(prop: String, aligned: bool) -> float:
	var key := "%s_%s" % [prop, aligned]
	if _radius_cache.has(key):
		return _radius_cache[key]
	var r := 1.0
	var mesh := ArtKit.prop_mesh(prop)
	if mesh != null:
		var size := mesh.get_aabb().size
		r = maxf(size.x, size.z) * 0.5
		if aligned:
			r = minf(size.x, size.z) * 0.5
	_radius_cache[key] = r
	return r


const FOLIAGE: Array[String] = ["grass_tuft", "bush", "willow", "juniper", "barley_patch"]


func _tint(layer: Dictionary) -> Color:
	var t: Array = layer.get("tint", [])
	var c := Color.WHITE
	if t.size() >= 2:
		c = (t[0] as Color).lerp(t[1] as Color, _r.randf())
	elif t.size() == 1:
		c = t[0]
	var v := _r.randf_range(0.9, 1.08)
	if FOLIAGE.has(String(layer.get("prop", ""))):
		# the Season's colour for plants (data/courses.gd)
		var st: Color = course.get("dress", {}).get("foliage_tint", Color.WHITE)
		c = Color(c.r * st.r, c.g * st.g, c.b * st.b)
	return Color(c.r * v, c.g * v, c.b * v)


func _pick_count(layer: Dictionary) -> int:
	var f0 := float(layer.get("f0", 0.0))
	var f1 := float(layer.get("f1", 1.0))
	var span := (f1 - f0) * track.length
	var n := float(layer.n)
	if String(layer.get("prop", "")) == "flowers":
		# meadows are in bloom in Spring and nearly done by the Harvest
		n *= [1.5, 1.0, 0.3][clampi(int(course.get("season", 0)), 0, 2)]
	return int(round(n * span / 100.0))


func _s_range(layer: Dictionary) -> Vector2:
	var f0 := float(layer.get("f0", 0.0))
	var f1 := float(layer.get("f1", 1.0))
	return Vector2(maxf(f0 * track.length, 6.0), minf(f1 * track.length, track.length - 6.0))


# --- multimesh scatter -------------------------------------------------------------------------------------------

func _scatter_multi(layer: Dictionary) -> void:
	var prop: String = layer.prop
	if not _has_prop(prop):
		return
	var count := _pick_count(layer)
	var rg := _s_range(layer)
	var side_mode := int(layer.get("side", 0))
	var sc: Array = layer.get("scale", [1.0, 1.0])
	var align: bool = layer.get("align", false)
	var made := 0
	var attempts := 0
	while made < count and attempts < count * 3 + 6:
		attempts += 1
		var s := _r.randf_range(rg.x, rg.y)
		var side := side_mode if side_mode != 0 else (1 if _r.randf() < 0.5 else -1)
		var k := _r.randf_range(float(sc[0]), float(sc[1]))
		var spot := _pick(layer, s, side, NAN, _prop_radius(prop, align) * k * 0.8)
		if spot.is_empty():
			continue
		var yaw := _r.randf() * TAU if not align else _yaw_along(s) + _r.randf_range(-0.2, 0.2)
		var squash := Vector3(k * _r.randf_range(0.9, 1.15), k * _r.randf_range(0.85, 1.2), k * _r.randf_range(0.9, 1.15))
		var basis := Basis(Vector3.UP, yaw).scaled(squash)
		var pos: Vector3 = spot.pos
		pos.y -= 0.12 * k
		var key := "%s_%d" % [prop, int(s / CHUNK)]
		if not _chunks.has(key):
			_chunks[key] = {"prop": prop, "xf": [], "col": [], "cull": float(layer.get("cull", 500.0)), "shadow": layer.get("shadow", false), "cls": float(layer.get("ink_class", ArtKit.CLASS_PROP))}
		(_chunks[key].xf as Array).append(Transform3D(basis, pos))
		placed.append({"prop": prop, "pos": pos})
		(_chunks[key].col as Array).append(_tint(layer))
		made += 1


func _flush_chunks() -> void:
	var holder := Node3D.new()
	holder.name = "Scatter"
	_root.add_child(holder)
	for key: String in _chunks.keys():
		var ch: Dictionary = _chunks[key]
		var xf: Array = ch.xf
		if xf.is_empty():
			continue
		var mesh := ArtKit.prop_mesh(ch.prop)
		if mesh == null:
			continue
		var centre := Vector3.ZERO
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		for t: Transform3D in xf:
			centre += t.origin
			lo = lo.min(t.origin)
			hi = hi.max(t.origin)
		centre /= float(xf.size())
		var radius := maxf((hi - lo).length() * 0.5, 20.0)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = xf.size()
		for i in xf.size():
			var t: Transform3D = xf[i]
			t.origin -= centre
			mm.set_instance_transform(i, t)
			mm.set_instance_color(i, (ch.col as Array)[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.name = key
		mmi.position = centre
		mmi.material_override = ArtKit.grass_material() if float(ch.cls) > 0.7 else ArtKit.toon(float(ch.cls))
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if ch.shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = float(ch.cull) + radius
		mmi.custom_aabb = AABB(lo - centre - Vector3.ONE * 12.0, hi - lo + Vector3.ONE * 24.0)
		holder.add_child(mmi)


# --- node scatter (houses, animals, flags, crowds) -------------------------------------------------------------

func _set_range(node: Node, far: float) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).visibility_range_end = far
	for c in node.get_children():
		_set_range(c, far)


func _scatter_nodes(layer: Dictionary) -> void:
	var prop: String = layer.prop
	if not _has_prop(prop):
		return
	var count := _pick_count(layer)
	var herd := maxi(int(layer.get("herd", 1)), 1)
	var clusters := maxi(int(round(float(count) / float(herd))), 1) if count > 0 else 0
	var rg := _s_range(layer)
	var side_mode := int(layer.get("side", 0))
	var sc: Array = layer.get("scale", [1.0, 1.0])
	var made := 0
	var attempts := 0
	while made < clusters and attempts < clusters * 5 + 8:
		attempts += 1
		var s := _r.randf_range(rg.x, rg.y)
		var side := side_mode if side_mode != 0 else (1 if _r.randf() < 0.5 else -1)
		var ext := _prop_radius(prop, layer.get("align", false)) * float(sc[1]) * 0.8
		var spot := _pick(layer, s, side, NAN, ext)
		if spot.is_empty():
			continue
		made += 1
		var members := herd
		for m in members:
			var pos: Vector3 = spot.pos
			var yaw := _r.randf() * TAU
			var s_m: float = s
			var lat_m: float = spot.lat
			if m > 0:
				s_m = s + _r.randf_range(-7.0, 7.0)
				lat_m = float(spot.lat) + _r.randf_range(-6.0, 6.0)
				var sub := _pick(layer, clampf(s_m, 6.0, track.length - 6.0), side, lat_m, ext)
				if sub.is_empty():
					continue
				pos = sub.pos
			var node := ArtKit.prop(prop)
			var k := _r.randf_range(float(sc[0]), float(sc[1]))
			placed.append({"prop": prop, "pos": pos})
			node.scale = Vector3.ONE * k
			if layer.get("align", false):
				# Flag strings run along the road and always read blue first from the road: lay them by side.
				yaw = _yaw_along(s_m) + (PI * 0.5 * float(-side) if prop == "flag_string" else 0.0) + _r.randf_range(-0.12, 0.12)
			elif layer.get("face_road", false):
				yaw = _yaw_to_road(s_m, lat_m) + _r.randf_range(-0.15, 0.15)
			node.rotation.y = yaw
			node.position = pos - Vector3(0, 0.25 * k if prop.begins_with("house") else 0.1, 0)
			_set_range(node, float(layer.get("cull", 600.0)) + 40.0)
			if prop.begins_with("crowd"):
				_colour_crowd(node)
			_root.add_child(node)


func _colour_crowd(node: Node3D) -> void:
	var robes := [Color("d63a22"), Color("1f4fa8"), Color("2e9e78"), Color("e8871e"), Color("6b2f5b"), Color("f2b632"), Color("7a1c22"), Color("4a8fd9")]
	_set_slots(node, robes[_r.randi() % robes.size()], robes[_r.randi() % robes.size()])


func _set_slots(node: Node, a: Color, b: Color) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).set_instance_shader_parameter("slot_a", a)
		(node as GeometryInstance3D).set_instance_shader_parameter("slot_b", b)
		if String(node.name).begins_with("crowd"):
			# every crowd group bobs and cheers on its own beat
			(node as GeometryInstance3D).set_instance_shader_parameter("phase_shift", fposmod(float(node.get_instance_id()) * 0.6180339, 1.0))
	for c in node.get_children():
		_set_slots(c, a, b)


# --- set pieces ----------------------------------------------------------------------------------------------------

func _place_piece(sp: Dictionary) -> void:
	var prop: String = sp.prop
	if not _has_prop(prop):
		return
	var s: float = sp.s
	var d: float = sp.get("d", 0.0)
	var p := _b.world_point(s, d)
	var y := _b.ground_y(p.x, p.z) - float(sp.get("sink", 0.35))
	if prop == "bridge_cant" or prop == "gate_chorten":
		y = track.point(clampf(s, 0.0, track.length)).y
	var yaw := 0.0
	match String(sp.get("face", "road")):
		"track":
			yaw = _yaw_along(s)
		"back":
			yaw = _yaw_along(s) + PI
		_:
			yaw = _yaw_to_road(s, d) if absf(d) > 1.0 else _yaw_along(s)
	yaw += deg_to_rad(float(sp.get("yaw", 0.0)))
	var node := ArtKit.prop(prop)
	var k := float(sp.get("scale", 1.0))
	node.scale = Vector3.ONE * k
	if prop == "bridge_cant":
		node.scale = Vector3(k * (track.half_width_at(clampf(s, 0.0, track.length)) + 3.5) / 11.5, k, k)
	node.rotation.y = yaw
	node.position = Vector3(p.x, y, p.z)
	_set_range(node, 4500.0 if sp.get("far", false) or float(sp.get("scale", 1.0)) > 4.0 else 1500.0)
	_root.add_child(node)


# --- gates, crowds, era ---------------------------------------------------------------------------------------------

func _gates_and_crowds() -> void:
	for ev: Dictionary in course.events:
		if ev.type != "start" and ev.type != "finish":
			continue
		var s: float = ev.s
		var is_finish: bool = ev.type == "finish"
		var gate_name := "finish_gate" if is_finish else "start_gate"
		var hw := track.half_width_at(s)
		if _has_prop(gate_name):
			var gate := ArtKit.prop(gate_name)
			var p := track.point(s)
			gate.scale = Vector3((hw + 4.0) / 17.0, 1.0, 1.0)
			gate.rotation.y = _yaw_along(s)
			gate.position = p
			_set_range(gate, 1800.0)
			_root.add_child(gate)
		# Spectators and banners along both edges.
		var groups := 9 if is_finish else 6
		for side in [-1, 1]:
			for i in groups:
				var ss := s + (-52.0 + float(i) * (104.0 / float(groups))) + _r.randf_range(-4.0, 4.0)
				if absf(ss - s) < 7.0:
					continue
				var lat := float(side) * (track.half_width_at(clampf(ss, 0.0, track.length)) + CLEAR + _r.randf_range(2.0, 9.0) + (i % 2) * 4.0)
				var spot := _pick({"slope": 0.5}, clampf(ss, 4.0, track.length - 4.0), side, lat)
				if spot.is_empty():
					continue
				var prop_name: String = ["crowd_a", "crowd_b", "crowd_c"][_r.randi() % 3]
				if not _has_prop(prop_name):
					continue
				var node := ArtKit.prop(prop_name)
				node.rotation.y = _yaw_to_road(ss, lat) + _r.randf_range(-0.2, 0.2)
				node.position = spot.pos
				_set_range(node, 420.0)
				_colour_crowd(node)
				_root.add_child(node)
			if _has_prop("banner"):
				var lat_b := float(side) * (hw + CLEAR + 1.5)
				var bs := s + (-26.0 if side < 0 else 26.0)
				var spot_b := _pick({"slope": 0.5}, clampf(bs, 4.0, track.length - 4.0), side, lat_b)
				if not spot_b.is_empty():
					var banner := ArtKit.prop("banner")
					banner.rotation.y = _yaw_to_road(bs, lat_b)
					banner.position = spot_b.pos
					_set_range(banner, 900.0)
					_root.add_child(banner)


## Stacked-stone road markers every 250 m or so, alternating sides, at the edge of the verge.
func _milestones() -> void:
	if not _has_prop("milestone"):
		return
	var s := 140.0
	var side := 1 if _r.randf() < 0.5 else -1
	while s < track.length - 120.0:
		var lat := float(side) * (track.half_width_at(s) + CLEAR + 0.9)
		var spot := _pick({"slope": 0.5}, s, side, lat)
		if not spot.is_empty():
			var m := ArtKit.prop("milestone")
			var k := _r.randf_range(0.95, 1.2)
			m.scale = Vector3.ONE * k
			m.position = (spot.pos as Vector3) - Vector3(0, 0.06, 0)
			m.rotation.y = _r.randf() * TAU
			_set_range(m, 360.0)
			_root.add_child(m)
		side = -side
		s += 250.0 + _r.randf_range(-30.0, 30.0)


## Far columns of dust, kilometres off across the plain, for the third Season: the world quietly changing. No comment.
func _dust_plumes() -> void:
	if not _has_prop("dust_plume"):
		return
	var count := 5
	for i in count:
		var s := track.length * (0.12 + 0.76 * (float(i) + _r.randf() * 0.7) / float(count))
		var side := 1 if i % 2 == 0 else -1
		var lat := float(side) * _r.randf_range(1400.0, 3000.0)
		var p := track.point(s, lat)
		var y := _b.ground_y(p.x, p.z)
		var node := ArtKit.prop("dust_plume")
		var k := _r.randf_range(1.8, 2.8)
		node.scale = Vector3(k * 0.8, k, k * 0.8)
		node.position = Vector3(p.x, y - 8.0, p.z)
		node.rotation.y = _r.randf() * TAU
		_set_range(node, 5200.0)
		_root.add_child(node)


func _survey_stakes() -> void:
	if not _has_prop("survey_stake"):
		return
	# Lines of stakes along the verge, each leaning a little, appearing in pairs every few hundred metres.
	var s := 150.0
	while s < track.length - 150.0:
		var side := 1 if _r.randf() < 0.5 else -1
		for i in 5:
			var ss := s + float(i) * 22.0
			var lat := float(side) * (track.half_width_at(ss) + CLEAR + 1.8 + _r.randf_range(0.0, 1.5))
			var spot := _pick({"slope": 0.5}, ss, side, lat)
			if spot.is_empty():
				continue
			var st := ArtKit.prop("survey_stake")
			st.position = spot.pos
			st.rotation = Vector3(_r.randf_range(-0.08, 0.08), _r.randf() * TAU, _r.randf_range(-0.08, 0.08))
			_set_range(st, 380.0)
			_root.add_child(st)
		s += _r.randf_range(380.0, 620.0)


func _place_truck() -> void:
	if not _has_prop("truck"):
		return
	var s := track.length * 0.77
	var side := 1
	var lat := float(side) * (track.half_width_at(s) + 42.0)
	var p := track.point(s, lat)
	var y := _b.ground_y(p.x, p.z) - 0.05
	var t := ArtKit.prop("truck")
	t.position = Vector3(p.x, y, p.z)
	t.rotation.y = _yaw_along(s) + deg_to_rad(8.0)
	_set_range(t, 1200.0)
	_root.add_child(t)
