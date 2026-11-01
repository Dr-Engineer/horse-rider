class_name RiderVisual
extends Node3D
## Draws one rider from the simulation: horse.glb plus rider.glb in the toon material, wardrobe by name,
## instance colours, weapons on the grip bones, animation by state, lean, flash and the thrown tumble.
## Everything is read from Rider each frame; nothing here changes gameplay.

const HORSE_PATH := "res://assets/models/horse.glb"
const RIDER_PATH := "res://assets/models/rider.glb"
# ground speed (m/s) at which each horse loop plays at speed_scale 1, to cut foot-skate
const GAIT_REF := {"gallop": 15.0, "canter": 9.0, "trot": 5.5, "walk": 1.7}
const WEAPON_ROT := Vector3(0, 0, 0)

var rider: Rider
var track: Track
var race: Race

var horse_root: Node3D
var horse_ap: AnimationPlayer
var horse_skel: Skeleton3D
var saddle_att: BoneAttachment3D
var rider_root: Node3D          # rider.glb instance
var rider_ap: AnimationPlayer
var rider_skel: Skeleton3D
var grip_r: BoneAttachment3D
var grip_l: BoneAttachment3D
var weapon_node: Node3D
var weapon_id_shown := "?"
var ranged_node: Node3D
var shield_node: Node3D
var horse_meshes: Array[MeshInstance3D] = []
var rider_meshes: Array[MeshInstance3D] = []
var _horse_anim := ""
var _rider_anim := ""
var _detached := false
var _prev_state := "ride"
var _spin := 0.0
var _t := 0.0
var _lean := 0.0
var _roll := 0.0
var _scoop := 0.0
var _last_shake_pos := Vector3.ZERO
var _loose_t := 0.0
var _was_drawing := false
var _look_height := 0.0


func setup(p_rider: Rider, p_track: Track, p_race: Race) -> void:
	rider = p_rider
	track = p_track
	race = p_race
	var rmat := ArtKit.toon(ArtKit.CLASS_RIDER, 0.25)
	if ResourceLoader.exists(HORSE_PATH):
		horse_root = (load(HORSE_PATH) as PackedScene).instantiate()
		add_child(horse_root)
		ArtKit.apply(horse_root, rmat)
		horse_ap = _first(horse_root, "AnimationPlayer") as AnimationPlayer
		horse_skel = _first(horse_root, "Skeleton3D") as Skeleton3D
		for mi: MeshInstance3D in horse_root.find_children("*", "MeshInstance3D", true, false):
			horse_meshes.append(mi)
			mi.set_instance_shader_parameter("slot_c", rider.horse["coat"])
			mi.set_instance_shader_parameter("slot_d", _v3(rider.horse["mane"]))
			mi.set_instance_shader_parameter("slot_b", _v3(rider.horse["rug"]))
			mi.set_instance_shader_parameter("slot_a", _v3(rider.colour_a))
		for name in ["gallop", "canter", "trot", "walk", "idle"]:
			if horse_ap != null and horse_ap.has_animation(name):
				horse_ap.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	else:
		horse_root = Node3D.new()
		add_child(horse_root)
		var bm := BoxMesh.new()
		bm.size = Vector3(0.7, 1.0, 2.2)
		var mi2 := MeshInstance3D.new()
		mi2.mesh = bm
		mi2.position.y = 0.9
		horse_root.add_child(mi2)
	if horse_skel != null:
		saddle_att = BoneAttachment3D.new()
		saddle_att.bone_name = "saddle"
		horse_skel.add_child(saddle_att)
	if ResourceLoader.exists(RIDER_PATH):
		rider_root = (load(RIDER_PATH) as PackedScene).instantiate()
		ArtKit.apply(rider_root, rmat)
		rider_ap = _first(rider_root, "AnimationPlayer") as AnimationPlayer
		rider_skel = _first(rider_root, "Skeleton3D") as Skeleton3D
		for mi3: MeshInstance3D in rider_root.find_children("*", "MeshInstance3D", true, false):
			rider_meshes.append(mi3)
			mi3.set_instance_shader_parameter("slot_a", _v3(rider.colour_a))
			mi3.set_instance_shader_parameter("slot_b", _v3(rider.colour_b))
		for name in ["ride", "ride_slow", "ride_whip", "wobble", "run", "rest_sit", "victory", "stand", "block", "bow_hold", "lie"]:
			if rider_ap != null and rider_ap.has_animation(name):
				rider_ap.get_animation(name).loop_mode = Animation.LOOP_LINEAR
		_apply_wardrobe()
		_attach_rider(true)
		_make_weapon_attachments()
	else:
		rider_root = Node3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.3
		cm.height = 1.6
		var mi4 := MeshInstance3D.new()
		mi4.mesh = cm
		mi4.position.y = 0.8
		rider_root.add_child(mi4)
		add_child(rider_root)
	_refresh_weapons()
	sync(0.0)


func rider_horse_coat() -> Color:
	return rider.horse["coat"]


func _v3(c: Color) -> Color:
	# instance uniforms are `vec3 : source_color`, so they want a Color
	return c


func _first(n: Node, cls: String) -> Node:
	var found := n.find_children("*", cls, true, false)
	return found[0] if found.size() > 0 else null


# ---------------------------------------------------------------------------------------------
# Wardrobe and attachments
# ---------------------------------------------------------------------------------------------

func _apply_wardrobe() -> void:
	var names: Dictionary = {}
	for mi in rider_meshes:
		names[String(mi.name)] = mi
	var want: Array = rider.wardrobe.duplicate()
	# fall back gracefully while the Characters stream is still adding pieces
	var has_body := false
	var has_head := false
	for w: String in want:
		if w.begins_with("body_") and names.has(w):
			has_body = true
		if w.begins_with("head_") and names.has(w):
			has_head = true
	if not has_body:
		for fb in ["body_chuba", "body_oneoff"]:
			if names.has(fb):
				want.append(fb)
				break
	if not has_head:
		for fb2 in ["head_plain", "head_young"]:
			if names.has(fb2):
				want.append(fb2)
				break
	for key: String in names:
		var mi: MeshInstance3D = names[key]
		mi.visible = want.has(key)


func _make_weapon_attachments() -> void:
	if rider_skel == null:
		return
	grip_r = BoneAttachment3D.new()
	grip_r.bone_name = "grip.R"
	rider_skel.add_child(grip_r)
	grip_l = BoneAttachment3D.new()
	grip_l.bone_name = "grip.L"
	rider_skel.add_child(grip_l)


func _weapon_model(model: String, fallback_len: float) -> Node3D:
	var path := "res://assets/models/weapons/%s.glb" % model
	if model != "" and ResourceLoader.exists(path):
		var n: Node3D = (load(path) as PackedScene).instantiate()
		ArtKit.apply(n, ArtKit.toon(ArtKit.CLASS_RIDER, 0.15))
		return n
	# plain stick so the reach reads while models arrive
	var holder := Node3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.035
	cm.bottom_radius = 0.045
	cm.height = fallback_len
	cm.radial_segments = 5
	var arrays := cm.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs := PackedVector2Array()
	uvs.resize(verts.size())
	for i in verts.size():
		uvs[i] = Vector2(0.0625, 0.015)
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = ArtKit.toon(ArtKit.CLASS_RIDER)
	mi.set_instance_shader_parameter("slot_a", Color(0.55, 0.55, 0.6))
	mi.position = Vector3(0, 0, -fallback_len * 0.5)
	mi.rotation_degrees.x = 90.0
	holder.add_child(mi)
	return holder


func _refresh_weapons() -> void:
	if grip_r == null:
		return
	if weapon_id_shown == rider.weapon_id and weapon_node != null:
		return
	weapon_id_shown = rider.weapon_id
	if weapon_node != null:
		weapon_node.queue_free()
		weapon_node = null
	if rider.weapon_id != "fists":
		var w: Dictionary = GameData.weapon(rider.weapon_id)
		var model: String = w["model"]
		var reach: float = w["reach"]
		weapon_node = _weapon_model(model, clampf(reach * 0.55, 0.6, 3.0))
		var holder := Node3D.new()
		holder.rotation_degrees = WEAPON_ROT
		holder.add_child(weapon_node)
		grip_r.add_child(holder)
		weapon_node = holder
	if ranged_node == null and rider.ranged_id != "":
		var rw: Dictionary = GameData.weapon(rider.ranged_id)
		var m: String = rw["model"]
		var n := _weapon_model(m, 0.9)
		var holder2 := Node3D.new()
		holder2.rotation_degrees = WEAPON_ROT
		holder2.add_child(n)
		if rider.ranged_id == "bow":
			grip_l.add_child(holder2)
		else:
			grip_r.add_child(holder2)
		ranged_node = holder2
	if shield_node == null and rider.has_shield and grip_l != null:
		var sn := _weapon_model("shield", 0.9)
		var holder3 := Node3D.new()
		holder3.rotation_degrees = WEAPON_ROT
		holder3.add_child(sn)
		grip_l.add_child(holder3)
		shield_node = holder3


func _attach_rider(on_horse: bool) -> void:
	if rider_root == null:
		return
	var parent := rider_root.get_parent()
	if parent != null:
		parent.remove_child(rider_root)
	if on_horse and saddle_att != null:
		saddle_att.add_child(rider_root)
		rider_root.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, -0.9, 0.0))
		_detached = false
	else:
		add_child(rider_root)
		_detached = true


# ---------------------------------------------------------------------------------------------
# Per-frame sync
# ---------------------------------------------------------------------------------------------

func _frac() -> float:
	return clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0) / 60.0


func visual_s() -> float:
	return rider.s + (rider.speed * _frac() if rider.is_riding() else 0.0)


func sync(dt: float) -> void:
	_t += dt
	if rider == null or track == null:
		return
	_refresh_weapons()
	if ranged_node != null and rider.ranged_id == "roped_spear":
		ranged_node.visible = not rider.rope_out
	var st := rider.state
	var mounted := st == "ride" or st == "airborne" or st == "finished" or st == "mount"
	if st != _prev_state:
		_on_state_change(_prev_state, st)
		_prev_state = st
	# --- horse transform ---
	var fr := _frac()
	var hs := rider.horse_s + rider.horse_speed * fr
	var hd := rider.horse_d
	var hh := rider.height if (st == "airborne" or st == "ride") else 0.0
	var tf := track.frame(hs, hd, hh)
	var yaw := -rider.yaw if mounted else 0.0
	var kappa := track.curve_at(rider.s)
	var lean_target := clampf(kappa * rider.speed * rider.speed * 0.011, -0.32, 0.32) if st == "ride" or st == "airborne" else 0.0
	_lean = lerpf(_lean, lean_target, 1.0 - exp(-dt / 0.12))
	var roll := -_lean
	if st == "ride":
		roll += sin(_t * 9.0 + float(rider.slot)) * rider.wobble_amount * 0.22
		roll += clampf(-rider.lateral * 0.012, -0.12, 0.12)
	tf.basis = tf.basis * Basis(Vector3.UP, yaw) * Basis(Vector3(0, 0, 1), roll)
	transform = tf
	# --- animations ---
	_update_horse_anim()
	_update_rider_anim(dt)
	# --- detached rider body ---
	if _detached:
		_place_body(dt)
	elif rider_root != null and st == "ride" and rider.scooping_t > 0.0:
		pass
	_update_flash()
	_update_extras()


func _on_state_change(prev: String, now: String) -> void:
	if now == "falling":
		_attach_rider(false)
		_spin = 0.0
	elif now == "mount":
		pass
	elif now == "ride" and prev == "mount":
		_attach_rider(true)
	elif now == "ride" and _detached:
		_attach_rider(true)


func _place_body(dt: float) -> void:
	if not is_inside_tree():
		return
	var st := rider.state
	var bs := rider.s
	var bd := rider.d
	var h := rider.height
	var tf := track.frame(bs, bd, h)
	var fwd_yaw := 0.0
	var extra := Basis.IDENTITY
	match st:
		"falling":
			_spin += dt * 9.0
			var spin_amt := clampf(1.0 - rider.phase_age / 0.9, 0.0, 1.0)
			extra = Basis(Vector3.RIGHT, -_spin * spin_amt * 0.9) * Basis(Vector3(0, 0, 1), sin(_spin * 0.5) * 0.4 * spin_amt)
			fwd_yaw = 0.0
		"down", "rest":
			extra = Basis.IDENTITY
		"run":
			var to_horse := rider.horse_s - rider.s
			var side := rider.horse_d - rider.d
			fwd_yaw = -atan2(side, maxf(to_horse, 0.5)) * 0.8
		"mount":
			pass
	tf.basis = tf.basis * Basis(Vector3.UP, fwd_yaw) * extra
	rider_root.global_transform = tf


func _update_flash() -> void:
	var f := clampf(rider.flash_t / 0.12, 0.0, 1.0)
	if f <= 0.0 and rider.second_wind_t <= 0.0:
		if _prev_flash == 0.0:
			return
	_prev_flash = f
	var v := f
	if rider.second_wind_t > 0.0:
		v = maxf(v, 0.25 + 0.15 * sin(_t * 18.0))
	for mi in rider_meshes:
		mi.set_instance_shader_parameter("flash", v)
	for mi2 in horse_meshes:
		mi2.set_instance_shader_parameter("flash", v * 0.3)

var _prev_flash := 0.0


func _update_extras() -> void:
	pass


# ---------------------------------------------------------------------------------------------
# Animation selection
# ---------------------------------------------------------------------------------------------

func _horse_gait() -> String:
	var hs := rider.horse_speed
	var top: float = rider.horse["speed"]
	var f := hs / maxf(top, 1.0)
	if hs < 0.6:
		return "idle"
	if f < 0.12 or hs < 2.5:
		return "walk"
	if f < 0.4:
		return "trot"
	if f < 0.74:
		return "canter"
	return "gallop"


func _play_horse(name: String, blend: float, speed_scale: float) -> void:
	if horse_ap == null or not horse_ap.has_animation(name):
		return
	if _horse_anim != name:
		_horse_anim = name
		horse_ap.play(name, blend)
	horse_ap.speed_scale = speed_scale


func _update_horse_anim() -> void:
	if horse_ap == null:
		return
	var st := rider.state
	if st == "airborne":
		_play_horse("leap", 0.1, 0.7)
		return
	if st == "falling":
		_play_horse("stumble", 0.05, 1.0)
		return
	var g := _horse_gait()
	var scale := 1.0
	if GAIT_REF.has(g):
		scale = clampf(rider.horse_speed / float(GAIT_REF[g]), 0.5, 1.9)
	_play_horse(g, 0.18, scale)


func _play_rider(name: String, blend: float, speed_scale: float = 1.0) -> void:
	if rider_ap == null or not rider_ap.has_animation(name):
		return
	if _rider_anim != name:
		_rider_anim = name
		rider_ap.play(name, blend)
	rider_ap.speed_scale = speed_scale


func _swing_anim() -> String:
	var side := "R" if rider.swing_side >= 0 else "L"
	match rider.swing_kind:
		"kick":
			return "kick_" + side
		_:
			match rider.swing_weapon:
				"fists":
					return "fist_" + side
				"spear", "key":
					return "thrust_" + side
				_:
					return "swing_" + side


func _update_rider_anim(dt: float) -> void:
	if rider_ap == null:
		return
	var st := rider.state
	match st:
		"ride", "airborne":
			if rider.swing_t >= 0.0:
				var anim := _swing_anim()
				var len_a := rider_ap.get_animation(anim).length if rider_ap.has_animation(anim) else 0.5
				_play_rider(anim, 0.04, len_a / maxf(rider.swing_total, 0.1))
			elif rider.drawing:
				if rider.draw_amount >= 0.98:
					_play_rider("bow_hold", 0.06)
				else:
					var dl := 0.53
					_play_rider("bow_draw", 0.06, dl / maxf(float(GameData.WEAPONS[rider.ranged_id]["draw"]), 0.2))
				_was_drawing = true
			elif _was_drawing:
				_was_drawing = false
				_loose_t = 0.4
				_play_rider("bow_loose" if rider.ranged_id == "bow" else "throw", 0.03, 1.2)
			elif _loose_t > 0.0:
				_loose_t -= dt
			elif rider.blocking:
				_play_rider("block", 0.06)
			elif rider.hit_age < 0.32:
				_play_rider("hit_R" if rider.hit_side > 0 else "hit_L", 0.04, 1.3)
			elif rider.shake >= Rider.WOBBLE_AT:
				_play_rider("wobble", 0.12, 0.8 + rider.wobble_amount * 0.7)
			elif rider.whip_on:
				_play_rider("ride_whip", 0.1, clampf(rider.speed / 20.0, 0.7, 1.5))
			elif rider.speed < 9.0:
				_play_rider("ride_slow", 0.15, clampf(rider.speed / 6.0, 0.6, 1.4))
			else:
				_play_rider("ride", 0.15, clampf(rider.speed / 18.0, 0.8, 1.6))
		"finished":
			_play_rider("victory", 0.2)
		"falling":
			_play_rider("tumble", 0.04, 0.53 / 0.9)
		"down":
			if rider.phase_age < 0.15:
				_play_rider("lie", 0.05)
			else:
				_play_rider("getup", 0.08, 0.93 / maxf(0.7 - 0.15, 0.3))
		"rest":
			if rider.phase_age < 0.3:
				_play_rider("lie", 0.1)
			else:
				_play_rider("rest_sit", 0.25)
		"run":
			_play_rider("run", 0.1, clampf(1.0 + 0.0, 0.8, 1.4))
		"mount":
			_play_rider("mount", 0.05, 1.0)
	# lean forward to scoop a scarf
	if rider_root != null and not _detached:
		if rider.scooping_t > 0.0:
			_scoop = lerpf(_scoop, 1.0, 1.0 - exp(-dt / 0.05))
		else:
			_scoop = lerpf(_scoop, 0.0, 1.0 - exp(-dt / 0.12))
		if st == "ride":
			rider_root.rotation = Vector3(0.0, 0.0, -rider.scoop_side * _scoop * 0.6)
		else:
			rider_root.rotation = Vector3.ZERO
	if st == "ride" or st == "airborne":
		rider.scooping_t = maxf(0.0, rider.scooping_t - dt)
