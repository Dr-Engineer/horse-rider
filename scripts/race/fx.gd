class_name Fx
extends Node3D
## Dust at hooves (tinted to the road), hit bursts of ink-and-colour shards, coloured paper squares, and big comic words.
## Words use the headline font in Label3D, tilted, at most two at once, gone in under 0.6 s.
## Also: mud clods and the lens splatter of a mud ford, hats that fly off and lie on the road, the thud of a thrown rider
## landing, a whinny for a riderless horse, Samdup's bells and the confetti at the finish. Own random numbers.

const FONT_PATH := "res://assets/fonts/headline.fnt"
const WORD_LIFE := 0.55
const MAX_WORDS := 2
const FLAG_COLOURS := [Color("2f6fd0"), Color("f2efe4"), Color("d63a22"), Color("2fa05a"), Color("f2c632")]
const MUD_COLOURS := [Color("4a3626"), Color("5c4430"), Color("3a2a1e")]
const HAT_LIFE := 26.0
const MAX_HATS := 8
const HAT_GRAVITY := 18.0
const HAT_CHANCE_HIT := 0.4
const HAT_CHANCE_UNSEAT := 0.75


## Brown lens splatter and the white flash of a big knockdown, drawn over the race and under the HUD.
class Splat extends Control:
	var blobs: Array[Dictionary] = []
	var flash_until := 0
	var flash_ms := 1

	func add_blobs(count: int, life: float) -> void:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for i in count:
			var edge := rng.randf()
			var pos := Vector2(rng.randf_range(0.05, 0.95) * size.x, size.y * (0.5 + 0.48 * edge))
			var r := rng.randf_range(7.0, 19.0) * (size.y / 360.0)
			var shape := PackedFloat32Array()
			for k in 11:
				shape.append(rng.randf_range(0.72, 1.25))
			var drops := PackedVector3Array()
			for k in rng.randi_range(3, 6):
				var ang := rng.randf() * TAU
				drops.append(Vector3(cos(ang), sin(ang), rng.randf_range(0.12, 0.3)))
			blobs.append({"pos": pos, "r": r, "shape": shape, "drops": drops, "born": Time.get_ticks_msec(), "life": life * rng.randf_range(0.7, 1.15), "drip": rng.randf_range(14.0, 46.0)})

	func flash(ms: int) -> void:
		flash_until = Time.get_ticks_msec() + ms
		flash_ms = ms

	func _process(_dt: float) -> void:
		var now := Time.get_ticks_msec()
		var i := blobs.size() - 1
		while i >= 0:
			if float(now - int(blobs[i]["born"])) / 1000.0 > float(blobs[i]["life"]):
				blobs.remove_at(i)
			i -= 1
		visible = not blobs.is_empty() or now < flash_until
		queue_redraw()

	func _draw() -> void:
		var now := Time.get_ticks_msec()
		if now < flash_until:
			var a := float(flash_until - now) / float(flash_ms)
			draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.97, 0.88, 0.26 * a))
		for b in blobs:
			var u := float(now - int(b["born"])) / 1000.0 / float(b["life"])
			var alpha := 1.0 if u < 0.55 else 1.0 - (u - 0.55) / 0.45
			var pos: Vector2 = b["pos"]
			var r: float = b["r"] * (1.0 + 0.2 * minf(u * 3.0, 1.0))
			var shape: PackedFloat32Array = b["shape"]
			var edge := PackedVector2Array()
			var fill := PackedVector2Array()
			for k in shape.size():
				var a := TAU * float(k) / float(shape.size())
				edge.append(pos + Vector2(cos(a), sin(a)) * r * shape[k] * 1.14)
				fill.append(pos + Vector2(cos(a), sin(a)) * r * shape[k])
			draw_colored_polygon(edge, Color(0.12, 0.08, 0.06, 0.95 * alpha))
			draw_colored_polygon(fill, Color(0.3, 0.21, 0.15, 0.96 * alpha))
			draw_colored_polygon(PackedVector2Array([pos + Vector2(-r * 0.5, -r * 0.35), pos + Vector2(-r * 0.05, -r * 0.55), pos + Vector2(-r * 0.15, -r * 0.2)]), Color(0.43, 0.32, 0.22, 0.9 * alpha))
			for d: Vector3 in b["drops"]:
				var dp := pos + Vector2(d.x, d.y) * r * 1.6
				draw_circle(dp, r * d.z * 1.15, Color(0.12, 0.08, 0.06, 0.95 * alpha))
				draw_circle(dp, r * d.z, Color(0.3, 0.21, 0.15, 0.96 * alpha))
			var drip_len: float = float(b["drip"]) * minf(u * 1.6, 1.0)
			if drip_len > 1.0:
				var w := r * 0.28
				draw_colored_polygon(PackedVector2Array([pos + Vector2(-w, r * 0.5), pos + Vector2(w, r * 0.5), pos + Vector2(w * 0.6, r * 0.5 + drip_len), pos + Vector2(-w * 0.6, r * 0.5 + drip_len)]), Color(0.3, 0.21, 0.15, 0.96 * alpha))
				draw_circle(pos + Vector2(0.0, r * 0.5 + drip_len), w * 0.8, Color(0.3, 0.21, 0.15, 0.96 * alpha))

var race: Race
var track: Track
var font: Font = null
var words: Array[Dictionary] = []
var dust: Dictionary = {}          # Rider -> CPUParticles3D
var bursts: Array[CPUParticles3D] = []
var papers: Array[CPUParticles3D] = []
var clods: Array[CPUParticles3D] = []
var hats: Array[Dictionary] = []
var splat: Splat = null
var dust_colour := Color(0.86, 0.78, 0.6)
var _burst_i := 0
var _paper_i := 0
var _clod_i := 0
var _camera: Camera3D = null
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _mud_t: Dictionary = {}        # Rider -> seconds until the next clod
var _bell_t: Dictionary = {}
var _landed: Dictionary = {}       # Rider -> true once a thrown body has hit the ground
var _whinny_until := 0.0


func bind(p_race: Race) -> void:
	race = p_race
	track = race.track
	_rng.randomize()
	dust_colour = _course_dust()
	if ResourceLoader.exists(FONT_PATH):
		font = load(FONT_PATH)
	for i in 5:
		var b := _make_burst()
		add_child(b)
		bursts.append(b)
	for i in 3:
		var p := _make_papers()
		add_child(p)
		papers.append(p)
	for i in 4:
		var c := _make_clods()
		add_child(c)
		clods.append(c)
	for r in race.riders:
		var d := _make_dust()
		add_child(d)
		dust[r] = d
	var overlay := CanvasLayer.new()
	overlay.layer = 12
	overlay.name = "Overlay"
	add_child(overlay)
	splat = Splat.new()
	splat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splat.visible = false
	overlay.add_child(splat)
	splat.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	race.rider_hit.connect(_on_hit)
	race.rider_crashed.connect(_on_crashed)
	race.rider_event.connect(_on_event)


static var _puff: GradientTexture2D = null


static func puff_texture() -> GradientTexture2D:
	if _puff == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.set_offset(0, 0.0)
		g.set_offset(1, 1.0)
		_puff = GradientTexture2D.new()
		_puff.gradient = g
		_puff.width = 64
		_puff.height = 64
		_puff.fill = GradientTexture2D.FILL_RADIAL
		_puff.fill_from = Vector2(0.5, 0.5)
		_puff.fill_to = Vector2(1.0, 0.5)
	return _puff


func _soft_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = puff_texture()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	return m


func _make_dust() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 18
	p.lifetime = 0.9
	p.local_coords = false
	p.emitting = false
	p.direction = Vector3(0, 0.5, 1.0)
	p.spread = 35.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, -0.4, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(dust_colour, 0.55))
	ramp.set_color(1, Color(dust_colour, 0.0))
	p.color_ramp = ramp
	var qm := QuadMesh.new()
	qm.size = Vector2(0.7, 0.7)
	p.mesh = qm
	p.material_override = _soft_mat(Color.WHITE)
	return p


## The road's average colour, lightened: dust that matches the ground it is kicked up from.
func _course_dust() -> Color:
	var col := Color(0.86, 0.78, 0.6)
	if race.road_material != null:
		var tex: Variant = race.road_material.get_shader_parameter("tile")
		if tex is Texture2D:
			var img := (tex as Texture2D).get_image()
			if img != null and not img.is_empty():
				if img.is_compressed():
					img.decompress()
				var sum := Vector3.ZERO
				var n := 0
				var step_x := maxi(img.get_width() / 12, 1)
				var step_y := maxi(img.get_height() / 12, 1)
				for y in range(0, img.get_height(), step_y):
					for x in range(0, img.get_width(), step_x):
						var px := img.get_pixel(x, y)
						sum += Vector3(px.r, px.g, px.b)
						n += 1
				if n > 0:
					sum /= float(n)
					col = Color(sum.x, sum.y, sum.z)
	return col.lerp(Color.WHITE, 0.32)


func _make_clods() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 14
	p.lifetime = 0.75
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.92
	p.local_coords = false
	p.direction = Vector3(0, 1, 0)
	p.spread = 58.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 7.5
	p.gravity = Vector3(0, -17.0, 0)
	p.angular_velocity_min = -300.0
	p.angular_velocity_max = 300.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.1
	var grad := Gradient.new()
	grad.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	grad.set_color(0, MUD_COLOURS[0])
	grad.set_color(1, MUD_COLOURS[2])
	grad.add_point(0.5, MUD_COLOURS[1])
	p.color_initial_ramp = grad
	var sm := SphereMesh.new()
	sm.radius = 0.1
	sm.height = 0.15
	sm.radial_segments = 5
	sm.rings = 3
	p.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	p.material_override = m
	return p


func _make_burst() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 9
	p.lifetime = 0.36
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 1.0
	p.local_coords = false
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 7.5
	p.gravity = Vector3(0, -12.0, 0)
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var grad := Gradient.new()
	grad.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	grad.set_color(0, Color("19121a"))
	grad.add_point(0.5, Color("f4efe4"))
	grad.set_color(1, Color("ffd24a"))
	p.color_initial_ramp = grad
	var bm := BoxMesh.new()
	bm.size = Vector3(0.11, 0.11, 0.03)
	p.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	p.material_override = m
	return p


func _make_papers() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 34
	p.lifetime = 1.8
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.9
	p.local_coords = false
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 9.0
	p.gravity = Vector3(0, -2.2, 0)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.damping_min = 1.5
	p.damping_max = 3.0
	var grad := Gradient.new()
	grad.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	grad.set_color(0, FLAG_COLOURS[0])
	grad.set_color(1, FLAG_COLOURS[4])
	grad.add_point(0.2, FLAG_COLOURS[1])
	grad.add_point(0.4, FLAG_COLOURS[2])
	grad.add_point(0.6, FLAG_COLOURS[3])
	p.color_initial_ramp = grad
	var qm := QuadMesh.new()
	qm.size = Vector2(0.26, 0.26)
	p.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	p.material_override = m
	return p


# ---------------------------------------------------------------------------------------------

func _process(dt: float) -> void:
	_t += dt
	if race == null or race.player == null:
		return
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()
	var pr := race.player
	# dust at hooves of riders near the camera
	for r: Rider in dust:
		var d: CPUParticles3D = dust[r]
		var near := absf(r.s - pr.s) < 60.0
		var on_ground := (r.state == "ride" or r.state == "finished") and r.height < 0.05
		var hs := r.horse_speed if r.state != "ride" else r.speed
		var go := near and on_ground and hs > 5.0
		if r.state != "ride" and r.state != "finished":
			go = near and r.horse_speed > 5.0 and r.height < 0.05
		d.emitting = go
		if go:
			var tf := track.frame(r.horse_s, r.horse_d, 0.15)
			d.global_transform = Transform3D(tf.basis, tf.origin + tf.basis.z * 0.8)
			d.amount = 18
			d.initial_velocity_max = 1.5 + hs * 0.13
			d.direction = Vector3(0.0, 0.45, 1.0)
			var mat := d.material_override as StandardMaterial3D
			mat.albedo_color = Color(1, 1, 1, 1.0 if r == pr else 0.8)
	_riders_tick(dt, pr)
	_update_hats(dt)
	# comic words
	var i := words.size() - 1
	while i >= 0:
		var w: Dictionary = words[i]
		w["age"] = float(w["age"]) + dt
		var age: float = w["age"]
		var node: Label3D = w["node"]
		if age >= WORD_LIFE or not is_instance_valid(node):
			if is_instance_valid(node):
				node.queue_free()
			words.remove_at(i)
		else:
			var u := age / WORD_LIFE
			var pop := 1.0 + 0.15 * maxf(0.0, 1.0 - u * 6.0)
			var sc: float = w["scale"]
			var pos: Vector3 = w["pos"]
			pos.y += u * 0.7 + float(w["slot"]) * 0.75
			node.global_position = pos
			if _camera != null:
				var cb := _camera.global_basis
				node.global_basis = cb * Basis(Vector3(0, 0, 1), float(w["tilt"]))
			var cdist := 8.0
			if _camera != null:
				cdist = _camera.global_position.distance_to(pos)
			node.scale = Vector3.ONE * sc * pop * clampf(cdist / 8.0, 0.45, 1.7)
			node.modulate.a = 1.0 if u < 0.7 else (1.0 - (u - 0.7) / 0.3)
			node.outline_modulate.a = node.modulate.a
		i -= 1


## Per-rider extras: mud clods, Samdup's bells, the thud of a thrown rider landing.
func _riders_tick(dt: float, pr: Rider) -> void:
	for r in race.riders:
		var gap := absf(r.s - pr.s)
		if r.mud and r.is_riding() and r.speed > 4.0 and gap < 50.0:
			var t: float = float(_mud_t.get(r, 0.0)) - dt
			if t <= 0.0:
				_clod(r, 0.6)
				t = _rng.randf_range(0.1, 0.17)
			_mud_t[r] = t
		if r.rival_id == "samdup" and r.state == "ride" and r.speed > 5.0 and gap < 38.0 and not _quiet_here(r):
			var bt: float = float(_bell_t.get(r, 0.0)) - dt
			if bt <= 0.0:
				Sfx.play_at("harness_bells", race.visual_pos(r), -13.0, _rng.randf_range(0.96, 1.07))
				bt = _rng.randf_range(0.7, 1.1) * clampf(16.0 / r.speed, 0.6, 1.6)
			_bell_t[r] = bt
		if r.state == "falling":
			if not bool(_landed.get(r, false)) and r.phase_age > 0.12 and r.height <= 0.02:
				_landed[r] = true
				_thud(r, pr)
		elif bool(_landed.get(r, false)):
			_landed[r] = false


func _quiet_here(r: Rider) -> bool:
	return race.hazards != null and race.hazards.in_quiet(r.s)


## A brown spray behind a rider's hooves.
func _clod(r: Rider, power: float) -> void:
	var c := clods[_clod_i % clods.size()]
	_clod_i += 1
	var at_s := r.horse_s if not r.is_riding() else r.s
	var tf := track.frame(at_s, r.d, 0.2)
	c.global_position = tf.origin + tf.basis.z * 0.9
	var side := tf.basis.x * _rng.randf_range(-1.0, 1.0)
	c.direction = (Vector3.UP * 1.1 + tf.basis.z * 0.7 + side * 0.9).normalized()
	c.initial_velocity_max = (4.0 + r.speed * 0.22) * power
	c.initial_velocity_min = c.initial_velocity_max * 0.4
	c.restart()
	c.emitting = true


func _thud(r: Rider, pr: Rider) -> void:
	if r != pr and absf(r.s - pr.s) > 40.0:
		return
	var at := track.point(r.s, r.d, 0.2)
	Sfx.play_at("land", at, -2.0 if r != pr else 0.0, 0.7)
	burst(at, Vector3(0, 1, 0), Color("d9c49a"), 0.8)
	race.rider_event.emit("thud", r, {})


## The riderless horse, a moment after the fall: a whinny, if the player is close enough to hear it.
func _riderless(r: Rider) -> void:
	if absf(r.s - race.player.s) > 45.0:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < _whinny_until or _quiet_here(r):
		return
	_whinny_until = now + 3.0
	get_tree().create_timer(0.45).timeout.connect(func() -> void:
		if is_instance_valid(self) and race != null and race.track != null:
			Sfx.play_at("whinny", track.point(r.horse_s, r.horse_d, 1.3), -3.0, _rng.randf_range(0.92, 1.1)))


# --- hats ------------------------------------------------------------------------------------------------------------

## Rolls for a hat to fly off a rider who is near the player. A rider without a hat, or already bare, loses nothing.
func _try_hat(victim: Rider, by: Rider, chance: float) -> bool:
	if victim.hat_off or victim.hat_piece() == "" or not _near_player(victim, 42.0):
		return false
	if _rng.randf() > chance:
		return false
	var v: Node3D = race.visuals.get(victim)
	if v == null:
		return false
	var got: Dictionary = v.call("shed_hat")
	if got.is_empty():
		return false
	var tf: Transform3D = got["xf"]
	var mesh: Mesh = got["mesh"]
	var aabb := mesh.get_aabb()
	var centre := aabb.get_center()
	var pivot := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = got["material"]
	mi.set_instance_shader_parameter("slot_b", got["colour"])
	mi.position = -centre
	pivot.add_child(mi)
	add_child(pivot)
	var world_c := tf * centre
	pivot.global_transform = Transform3D(tf.basis.orthonormalized(), world_c)
	var away := 1.0 if _rng.randf() < 0.5 else -1.0
	if by != null:
		away = 1.0 if victim.d >= by.d else -1.0
	var road_y := track.point(victim.s, victim.d, 0.0).y
	hats.append({
		"node": pivot, "s": victim.s, "d": victim.d, "h": world_c.y - road_y, "r": clampf(aabb.size.y * 0.5, 0.1, 0.3),
		"vs": victim.speed * 0.92 + _rng.randf_range(-1.5, 1.5), "vd": away * _rng.randf_range(2.5, 5.0) + victim.lateral * 0.4,
		"vh": _rng.randf_range(5.0, 7.5), "spin": Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.5, 0.5), _rng.randf_range(-1, 1)).normalized() * _rng.randf_range(9.0, 15.0),
		"state": "air", "age": 0.0, "flip": _rng.randf() < 0.25, "yaw": _rng.randf() * TAU,
	})
	while hats.size() > MAX_HATS:
		var old: Dictionary = hats.pop_front()
		if is_instance_valid(old["node"]):
			(old["node"] as Node).queue_free()
	var by_player := by != null and by.is_player
	var head := world_c + Vector3(0, 0.5, 0)
	word("HAT! +%d" % Race.HAT_SILVER if by_player else "HAT!", head, Color("ffd24a"), 1.1)
	Sfx.play_at("hat_pop", head, -1.0, _rng.randf_range(0.95, 1.1))
	burst(world_c, Vector3(0, 1, 0), Color("f4efe4"), 0.6)
	race.note_hat(victim, by)
	return true


func _update_hats(dt: float) -> void:
	var i := hats.size() - 1
	while i >= 0:
		var h: Dictionary = hats[i]
		var node: Node3D = h["node"]
		if not is_instance_valid(node):
			hats.remove_at(i)
			i -= 1
			continue
		h["age"] = float(h["age"]) + dt
		var age: float = h["age"]
		var state: String = h["state"]
		var s: float = h["s"]
		var d: float = h["d"]
		var ht: float = h["h"]
		var vs: float = h["vs"]
		var vd: float = h["vd"]
		var spin: Vector3 = h["spin"]
		var basis := node.global_basis.orthonormalized()
		if state == "air":
			var vh: float = float(h["vh"]) - HAT_GRAVITY * dt
			ht += vh * dt
			vs *= exp(-0.6 * dt)
			h["vh"] = vh
			if ht <= float(h["r"]) and vh < 0.0:
				ht = float(h["r"])
				if absf(vh) > 2.4:
					h["vh"] = -vh * 0.38
					vs *= 0.6
					vd *= 0.55
					spin *= 0.55
				else:
					state = "slide"
		elif state == "slide":
			vs = move_toward(vs, 0.0, 7.0 * dt)
			vd = move_toward(vd, 0.0, 7.0 * dt)
			spin *= exp(-5.0 * dt)
			if absf(vs) + absf(vd) < 0.2:
				state = "rest"
		if state == "air" or state == "slide":
			if spin.length() > 0.05:
				basis = Basis(spin.normalized(), spin.length() * dt) * basis
		else:
			var flat := Basis(Vector3.UP, float(h["yaw"]))
			if h["flip"]:
				flat = flat * Basis(Vector3.RIGHT, PI)
			basis = Basis(basis.get_rotation_quaternion().slerp(flat.get_rotation_quaternion(), 1.0 - exp(-9.0 * dt)))
		s += vs * dt
		d += vd * dt
		var hw := track.half_width_at(s) - 0.6
		d = clampf(d, -hw, hw)
		var pos := track.point(s, d, ht)
		var scale_k := 1.0
		if age > HAT_LIFE:
			scale_k = clampf(1.0 - (age - HAT_LIFE) / 0.8, 0.0, 1.0)
		node.global_transform = Transform3D(basis.scaled(Vector3.ONE * scale_k), pos)
		h["s"] = s
		h["d"] = d
		h["h"] = ht
		h["vs"] = vs
		h["vd"] = vd
		h["spin"] = spin
		h["state"] = state
		if age > HAT_LIFE + 0.8:
			node.queue_free()
			hats.remove_at(i)
		i -= 1


func _on_screen(pos: Vector3) -> bool:
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()
	if _camera == null:
		return true
	if _camera.is_position_behind(pos) or _camera.global_position.distance_to(pos) < 3.2:
		return false
	var vp := get_viewport().get_visible_rect().size
	var sp := _camera.unproject_position(pos)
	return sp.x > vp.x * 0.1 and sp.x < vp.x * 0.9 and sp.y > vp.y * 0.12 and sp.y < vp.y * 0.85


func word(text: String, at: Vector3, col: Color = Color("f4efe4"), sc: float = 1.0) -> void:
	if not _on_screen(at):
		return
	while words.size() >= MAX_WORDS:
		var old: Dictionary = words.pop_front()
		if is_instance_valid(old["node"]):
			(old["node"] as Node).queue_free()
	var l := Label3D.new()
	l.text = text
	if font != null:
		l.font = font
	l.font_size = 66
	l.pixel_size = 0.0042
	l.outline_size = 4
	l.outline_modulate = Color("120c12")
	l.modulate = col
	l.no_depth_test = true
	l.render_priority = 50
	l.shaded = false
	l.alpha_cut = Label3D.ALPHA_CUT_DISABLED
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	add_child(l)
	l.global_position = at
	var slot := 0
	for other in words:
		if int(other["slot"]) == slot:
			slot = 1
	words.append({"node": l, "age": 0.0, "pos": at, "scale": sc, "slot": slot, "tilt": deg_to_rad(randf_range(-11.0, 11.0))})


func burst(at: Vector3, away: Vector3, tint: Color = Color("ffd24a"), scale_v: float = 1.0) -> void:
	var b := bursts[_burst_i % bursts.size()]
	_burst_i += 1
	b.global_position = at
	b.direction = (away + Vector3(0, 0.6, 0)).normalized()
	b.spread = 60.0
	b.initial_velocity_max = 7.5 * scale_v
	b.color_initial_ramp.set_color(1, tint)
	b.restart()
	b.emitting = true


func confetti(at: Vector3) -> void:
	var p := papers[_paper_i % papers.size()]
	_paper_i += 1
	p.global_position = at
	p.restart()
	p.emitting = true


## Paper squares over the line: a burst ahead of the rider now, more as the horse slows into them (one if off the podium).
func _finish_confetti(r: Rider) -> void:
	var bursts_n := 3 if r.place <= 3 else 1
	for k in bursts_n:
		var at_s := r.s + 10.0 + 13.0 * float(k)
		get_tree().create_timer(0.45 * float(k) + 0.05).timeout.connect(func() -> void:
			if is_instance_valid(self) and track != null:
				confetti(track.point(at_s, r.d * 0.5, 3.2)))


func _near_player(r: Rider, dist: float = 14.0) -> bool:
	var pr := race.player
	return r == pr or (absf(r.s - pr.s) < dist and absf(r.d - pr.d) < dist)


func _chest(r: Rider) -> Vector3:
	return track.point(r.s, r.d, 1.5 + r.height)


func _on_hit(attacker: Rider, victim: Rider, info: Dictionary) -> void:
	if not (victim == race.player or attacker == race.player or _near_player(victim, 9.0)):
		return
	if info.get("ignored", false):
		return
	var klass: String = info.get("klass", "body")
	var kind: String = info.get("kind", "")
	var at := _chest(victim)
	var away := track.right_at(victim.s) * float(-info.get("side", 1)) * -1.0
	if info.get("parried", false):
		burst(at, away, Color("ffffff"), 1.0)
		word("CLANG", at + Vector3(0, 0.9, 0), Color("fff2a8"), 1.15)
		return
	if info.get("blocked", false):
		burst(at, away, Color("c9d2dc"), 0.7)
		word("CLANG", at + Vector3(0, 0.9, 0), Color("e6edf5"), 1.0)
		return
	var impact: float = info.get("impact", 0.0)
	var tint := Color("ffd24a") if klass != "ranged" else Color("f4efe4")
	if impact >= 14.0:
		tint = Color("ff6a3a")
	burst(at, away, tint, clampf(impact / 20.0, 0.6, 1.5))
	var txt := "OOF"
	var col := Color("ffd24a")
	match kind:
		"sword", "knife", "key", "spear":
			txt = "THWACK" if kind != "key" else "CLANG"
		"whip", "pencase":
			txt = "THWACK"
		"fists", "kick", "barge":
			txt = "OOF"
		_:
			txt = "OOF" if klass == "ranged" else "THWACK"
	if klass == "ranged":
		col = Color("f4efe4")
	elif impact >= 22.0:
		col = Color("ff7a3a")
	if info.get("slam", false):
		txt = "SLAM!"
		col = Color("ff7a3a")
	var hat_flew := false
	if (klass == "melee" and impact >= 19.0) or kind == "kick":
		hat_flew = _try_hat(victim, attacker, HAT_CHANCE_HIT)
	if info.get("crashed", false) or hat_flew:
		return
	word(txt, at + Vector3(0, 1.0, 0), col, 1.0 if impact < 20.0 else 1.2)


func _on_crashed(r: Rider, reason: String) -> void:
	var by: Rider = r.last_hitter if (r.last_hit_age < 2.0 and r.last_hitter != r) else null
	_try_hat(r, by, HAT_CHANCE_UNSEAT if reason == "impact" else 0.45)
	_riderless(r)
	if not _near_player(r, 18.0):
		return
	var at := track.point(r.s, r.d, 2.0)
	burst(at, Vector3(0, 1, 0), Color("ff6a3a"), 1.5)
	if by == race.player and reason != "hazard":
		# the player's knockdown: a second ring of shards, a white flash and a heavy thump
		burst(at + Vector3(0, 0.2, 0), Vector3(0, 1, 0), Color("ffffff"), 2.0)
		if splat != null:
			splat.flash(110)
		Sfx.play_at("hit_heavy", at, 1.0, 0.78)
	if r == race.player:
		return   # the HUD already calls the player's crash out
	match reason:
		"impact":
			word("UNSEATED!", at + Vector3(0, 0.8, 0), Color("ff5a3a"), 1.35)
		"health":
			word("DOWN!", at + Vector3(0, 0.8, 0), Color("ff5a3a"), 1.35)
		_:
			word("OOF", at + Vector3(0, 0.8, 0), Color("ffd24a"), 1.2)


func _on_event(kind: String, r: Rider, info: Dictionary) -> void:
	match kind:
		"head_shot":
			_try_hat(r, info.get("by", null), 1.0)
		"pass_cry":
			if r == race.player:
				confetti(track.point(r.s + 3.0, r.d, 3.0))
		"second_wind":
			if _near_player(r, 30.0):
				confetti(track.point(r.s + 2.0, r.d, 2.5))
		"h_scarf":
			if r == race.player:
				confetti(track.point(r.s + 2.0, r.d, 1.8))
		"quiet_enter":
			if r == race.player:
				word("HANDS DOWN", _chest(r) + Vector3(0, 1.5, 0), Color("c9d2dc"), 0.9)
		"land":
			if _near_player(r, 20.0):
				burst(track.point(r.s, r.d, 0.2), Vector3(0, 1, 0), Color("d9c49a"), 0.6)
		"mud":
			if _near_player(r, 40.0):
				_clod(r, 1.3)
			if r == race.player and splat != null:
				splat.add_blobs(7, 0.9)
		"finish":
			if r == race.player:
				_finish_confetti(r)
