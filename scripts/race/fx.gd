class_name Fx
extends Node3D
## Dust at hooves, hit bursts of ink-and-colour shards, coloured paper squares, and big comic words.
## Words use the headline font in Label3D, tilted, at most two at once, gone in under 0.6 s.

const FONT_PATH := "res://assets/fonts/headline.fnt"
const WORD_LIFE := 0.55
const MAX_WORDS := 2
const FLAG_COLOURS := [Color("2f6fd0"), Color("f2efe4"), Color("d63a22"), Color("2fa05a"), Color("f2c632")]

var race: Race
var track: Track
var font: Font = null
var words: Array[Dictionary] = []
var dust: Dictionary = {}          # Rider -> CPUParticles3D
var bursts: Array[CPUParticles3D] = []
var papers: Array[CPUParticles3D] = []
var _burst_i := 0
var _paper_i := 0
var _camera: Camera3D = null
var _t := 0.0
var reticle: MeshInstance3D = null


func bind(p_race: Race) -> void:
	race = p_race
	track = race.track
	if ResourceLoader.exists(FONT_PATH):
		font = load(FONT_PATH)
	for i in 5:
		var b := _make_burst()
		add_child(b)
		bursts.append(b)
	for i in 2:
		var p := _make_papers()
		add_child(p)
		papers.append(p)
	for r in race.riders:
		var d := _make_dust()
		add_child(d)
		dust[r] = d
	reticle = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.62
	tm.outer_radius = 0.72
	tm.rings = 16
	tm.ring_segments = 6
	reticle.mesh = tm
	reticle.rotation_degrees.x = 90.0
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color("ff5a3a")
	rm.no_depth_test = true
	rm.render_priority = 40
	reticle.material_override = rm
	reticle.visible = false
	var holder := Node3D.new()
	holder.name = "ReticleHolder"
	holder.add_child(reticle)
	add_child(holder)
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
	ramp.set_color(0, Color(0.86, 0.78, 0.6, 0.55))
	ramp.set_color(1, Color(0.86, 0.78, 0.6, 0.0))
	p.color_ramp = ramp
	var qm := QuadMesh.new()
	qm.size = Vector2(0.7, 0.7)
	p.mesh = qm
	p.material_override = _soft_mat(Color.WHITE)
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
	# aiming reticle for the player's ranged lock
	if reticle != null:
		var shown := false
		if pr.drawing and pr.is_riding():
			var at := Vector3.ZERO
			if pr.target_lock != null and pr.target_lock.is_riding():
				at = track.point(pr.target_lock.s, pr.target_lock.d, 1.4)
				shown = true
			elif pr.ranged_id != "":
				var pole := race._pole_in_view(pr, float(GameData.WEAPONS[pr.ranged_id]["reach"]))
				if not pole.is_empty():
					at = track.point(float(pole["s"]), float(pole["d"]), 2.3)
					shown = true
			if shown:
				var holder := reticle.get_parent() as Node3D
				holder.global_position = at
				if _camera != null:
					holder.global_basis = _camera.global_basis
				var k := 1.0 + (1.0 - pr.draw_amount) * 1.2
				var dist_c := _camera.global_position.distance_to(at) if _camera != null else 10.0
				holder.scale = Vector3.ONE * k * clampf(dist_c / 14.0, 0.5, 2.4)
		reticle.visible = shown
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
			var pop := 1.0 + 0.35 * maxf(0.0, 1.0 - u * 6.0)
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
	l.pixel_size = 0.0068
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
	if info.get("crashed", false):
		return
	word(txt, at + Vector3(0, 1.0, 0), col, 1.0 if impact < 20.0 else 1.2)


func _on_crashed(r: Rider, reason: String) -> void:
	if not _near_player(r, 18.0):
		return
	var at := track.point(r.s, r.d, 2.0)
	burst(at, Vector3(0, 1, 0), Color("ff6a3a"), 1.5)
	if r == race.player:
		return   # the HUD already calls the player's crash out
	match reason:
		"impact":
			word("UNSEATED!", at + Vector3(0, 0.8, 0), Color("ff5a3a"), 1.35)
		"health":
			word("DOWN!", at + Vector3(0, 0.8, 0), Color("ff5a3a"), 1.35)
		_:
			word("OOF", at + Vector3(0, 0.8, 0), Color("ffd24a"), 1.2)


func _on_event(kind: String, r: Rider, _info: Dictionary) -> void:
	match kind:
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
