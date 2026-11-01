class_name RiderVisual
extends Node3D
## Draws one rider from the simulation: horse.glb plus rider.glb in the toon material, wardrobe by name,
## instance colours, weapons on the grip bones, animation by state, lean, flash and the thrown tumble.
## Everything is read from Rider each frame; nothing here changes gameplay.

const HORSE_PATH := "res://assets/models/horse.glb"
const RIDER_PATH := "res://assets/models/rider.glb"
const HOOFS := ["f_hoof.L", "f_hoof.R", "r_hoof.L", "r_hoof.R"]
## Cadence (cycles a second) a loop plays at the slow and the fast end of its speed band. As authored, the loops carry
## the horse only 0.5 to 2.4 m a cycle (measured from the animation tracks, see tests/gait_check.gd), a third of what the
## ground speed asks for, so the hooves skated. A believable cadence can't close that gap, so these numbers buy what they
## can and lengthen_strides closes the rest by stretching the legs' swing.
const GAIT_HZ := {"gallop": Vector2(2.7, 3.5), "canter": Vector2(2.2, 2.9), "trot": Vector2(2.0, 3.0), "walk": Vector2(0.8, 1.6)}
## A typical ground speed in each gait (a 20 m/s horse in the middle of its band), what fraction of it the planted hooves
## should keep up with, and the most the swing may be stretched.
const GAIT_TYPICAL := {"gallop": 19.2, "canter": 11.4, "trot": 5.3, "walk": 1.5}
const GAIT_GRIP := 0.7
const SWING_K_MAX := 1.8
const SWING_BONES := ["f_arm.L", "f_arm.R", "f_can.L", "f_can.R", "r_thigh.L", "r_thigh.R", "r_gas.L", "r_gas.R", "r_can.L", "r_can.R"]
## The rider's ride loops are one gallop stride long, so they follow the horse's cadence instead of the speed.
const RIDE_LOOP := 0.4667
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
var _hat_mi: MeshInstance3D = null
var _horse_hz := 1.0
var _horse_gait_name := "idle"
var _slump := 0.0
var _rear_left := 0.0
var _reared := false


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
		if horse_ap != null and horse_skel != null:
			lengthen_strides(horse_ap, horse_skel)
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
	_hat_mi = null
	for key: String in names:
		var mi: MeshInstance3D = names[key]
		mi.visible = want.has(key)
		if mi.visible and key.begins_with("hat_"):
			_hat_mi = mi


## Knocks the hat off. The skinned hat is hidden and Fx gets what it needs to fling a loose copy:
## {mesh, material, xf (puts the mesh where the hat sat), colour}. Returns {} when there is no hat left to lose.
func shed_hat() -> Dictionary:
	if _hat_mi == null or not _hat_mi.visible or rider_skel == null or not is_inside_tree():
		return {}
	var head := rider_skel.find_bone("head")
	if head < 0:
		return {}
	_hat_mi.visible = false
	rider.hat_off = true
	# Riders who wear a hat have no hair mesh, and nobody came to this race bald.
	var has_hair := false
	for mi in rider_meshes:
		has_hair = has_hair or (mi.visible and String(mi.name).begins_with("hair_"))
	if not has_hair:
		var woman := str(rider.wardrobe).contains("head_woman")
		for mi in rider_meshes:
			if String(mi.name) == ("hair_plaits" if woman else "hair_short"):
				mi.visible = true
	var xf :=rider_skel.global_transform * rider_skel.get_bone_global_pose(head) * rider_skel.get_bone_global_rest(head).affine_inverse()
	return {"mesh": _hat_mi.mesh, "material": _hat_mi.material_override, "xf": xf, "colour": rider.colour_b}


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


## Where a shot leaves from: the bow in the left hand, the sling or spear in the right, wherever the animation has put them.
func shot_point() -> Vector3:
	if ranged_node != null and is_instance_valid(ranged_node) and ranged_node.is_inside_tree():
		return ranged_node.global_position
	return rider.hand_point(track)


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
	_update_horse_anim(dt)
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


## What a gait loop carries the horse, read from its animation tracks: the backward speed of a hoof, relative to the body,
## while it is on the ground, averaged over the four hooves ("ref", m/s at speed_scale 1: the ground speed at which the
## feet would not skate), plus the lowest height any hoof reaches ("low"). Walks the skeleton by hand, so it needs no frames.
static func stride_ref(skel: Skeleton3D, an: Animation) -> Dictionary:
	var steps := 120
	var rot := {}
	var pos := {}
	for t in an.get_track_count():
		var bone := skel.find_bone(String(an.track_get_path(t)).get_slice(":", 1))
		if bone < 0:
			continue
		if an.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			rot[bone] = t
		elif an.track_get_type(t) == Animation.TYPE_POSITION_3D:
			pos[bone] = t
	var hoofs: Array[int] = []
	for h: String in HOOFS:
		hoofs.append(skel.find_bone(h))
	if hoofs.has(-1) or rot.is_empty():
		return {"ref": 0.0, "low": 0.0, "stance": 0.0, "hoofs": []}
	var ys: Array = []
	var zs: Array = []
	for k in hoofs.size():
		ys.append([])
		zs.append([])
	for i in steps + 1:
		var time := an.length * float(i) / float(steps)
		var world: Array[Transform3D] = []
		world.resize(skel.get_bone_count())
		for b in skel.get_bone_count():
			var rest := skel.get_bone_rest(b)
			var q := rest.basis.get_rotation_quaternion()
			var p := rest.origin
			if rot.has(b):
				q = an.rotation_track_interpolate(rot[b], time)
			if pos.has(b):
				p = an.position_track_interpolate(pos[b], time)
			var local := Transform3D(Basis(q), p)
			var parent := skel.get_bone_parent(b)
			world[b] = local if parent < 0 else world[parent] * local
		for k in hoofs.size():
			ys[k].append(world[hoofs[k]].origin.y)
			zs[k].append(-world[hoofs[k]].origin.z)
	var dt := an.length / float(steps)
	var speeds: Array[float] = []
	var stance := 0.0
	var low := 1.0e9
	for k in hoofs.size():
		var y_arr: Array = ys[k]
		var z_arr: Array = zs[k]
		var lo: float = y_arr.min()
		var hi: float = y_arr.max()
		low = minf(low, lo)
		var limit := lo + 0.18 * (hi - lo) + 0.01
		var n := 0
		var travel := 0.0
		for i in steps:
			var back: float = float(z_arr[i]) - float(z_arr[i + 1])
			if float(y_arr[i]) < limit and float(y_arr[i + 1]) < limit and back > 0.0:
				n += 1
				travel += back
		speeds.append(travel / maxf(float(n) * dt, 0.0001))
		stance += float(n) / float(steps)
	var mean := 0.0
	for v in speeds:
		mean += v
	return {"ref": mean / float(speeds.size()), "low": low, "stance": stance / float(hoofs.size()), "hoofs": speeds}


## Stretches the swing of the legs in a loop by k, about each bone's mean pose, so the feet stroke k times as far.
static func stretch_swing(an: Animation, k: float) -> void:
	for t in an.get_track_count():
		if an.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		if not String(an.track_get_path(t)).get_slice(":", 1) in SWING_BONES:
			continue
		var n := an.track_get_key_count(t)
		var first: Quaternion = an.track_get_key_value(t, 0)
		var sum := Vector4.ZERO
		for i in n:
			var q: Quaternion = an.track_get_key_value(t, i)
			sum += Vector4(q.x, q.y, q.z, q.w) * (1.0 if q.dot(first) >= 0.0 else -1.0)
		var mean := Quaternion(sum.x, sum.y, sum.z, sum.w).normalized()
		for i in n:
			var q: Quaternion = an.track_get_key_value(t, i)
			if q.dot(mean) < 0.0:
				q = -q
			var delta := (mean.inverse() * q).normalized()
			var ang := delta.get_angle()
			var axis := Vector3(delta.x, delta.y, delta.z).normalized() if ang > 0.0001 else Vector3.UP
			an.track_set_key_value(t, i, mean * Quaternion(axis, ang * k))


## Closes the gap between how far the gait loops carry the horse and how fast the ground goes by: each loop's swing is
## stretched (once; the animations are shared by every horse) until the hooves keep up with GAIT_GRIP of a typical ground
## speed at the cadence they play at, up to SWING_K_MAX. A loop that already strides far enough is left alone.
static func lengthen_strides(ap: AnimationPlayer, skel: Skeleton3D) -> void:
	for g: String in GAIT_HZ:
		if not ap.has_animation(g):
			continue
		var an := ap.get_animation(g)
		if an.has_meta("swing_k"):
			continue
		var ref := float(stride_ref(skel, an)["ref"])
		var hz: Vector2 = GAIT_HZ[g]
		var foot := ref * 0.5 * (hz.x + hz.y) * an.length
		var k := 1.0
		if ref > 0.05:
			k = clampf(GAIT_GRIP * float(GAIT_TYPICAL[g]) / maxf(foot, 0.01), 1.0, SWING_K_MAX)
		an.set_meta("swing_k", k)
		if k > 1.02:
			stretch_swing(an, k)


## Cycles a second for a gait loop at this ground speed: slow end of the band to fast end, so a quicker horse
## visibly works harder inside a gait and the loop never runs faster than a horse's legs could read.
## top is the horse's top speed (the gait bands are fractions of it, as in Rider.gait).
static func cadence(g: String, hs: float, top: float) -> float:
	var walk_top := maxf(0.12 * top, 2.5)
	var band := Vector2.ZERO
	match g:
		"walk":
			band = Vector2(0.6, walk_top)
		"trot":
			band = Vector2(walk_top, 0.4 * top)
		"canter":
			band = Vector2(0.4 * top, 0.74 * top)
		_:
			band = Vector2(0.74 * top, 1.18 * top)
	var hz: Vector2 = GAIT_HZ[g]
	return lerpf(hz.x, hz.y, clampf((hs - band.x) / maxf(band.y - band.x, 0.5), 0.0, 1.0))


func _update_horse_anim(dt: float) -> void:
	if horse_ap == null:
		return
	var st := rider.state
	if st == "airborne":
		_play_horse("leap", 0.1, 0.7)
		_horse_gait_name = "leap"
		return
	if st == "falling":
		_play_horse("stumble", 0.05, 1.0)
		_horse_gait_name = "stumble"
		return
	if st == "finished" and rider.place == 1 and not _reared and rider.horse_speed < 5.5 and horse_ap.has_animation("rear"):
		_reared = true
		_rear_left = horse_ap.get_animation("rear").length
		horse_ap.get_animation("rear").loop_mode = Animation.LOOP_NONE
	if _rear_left > 0.0:
		_rear_left -= dt
		_play_horse("rear", 0.15, 1.0)
		_horse_gait_name = "rear"
		return
	var g := _horse_gait()
	var scale := 1.0
	if GAIT_HZ.has(g) and horse_ap.has_animation(g):
		_horse_hz = cadence(g, rider.horse_speed, float(rider.horse["speed"]))
		scale = _horse_hz * horse_ap.get_animation(g).length
	_horse_gait_name = g
	_play_horse(g, 0.18, scale)


## The rider's ride loops are one gallop stride long, so at a canter or gallop they bob in step with the horse's legs.
func _ride_scale(fallback: float) -> float:
	if _horse_gait_name == "gallop" or _horse_gait_name == "canter":
		return _horse_hz * RIDE_LOOP
	return fallback


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
				_play_rider("ride_whip", 0.1, _ride_scale(clampf(rider.speed / 20.0, 0.7, 1.5)))
			elif rider.speed < 9.0:
				_play_rider("ride_slow", 0.15, clampf(rider.speed / 6.0, 0.6, 1.4))
			else:
				_play_rider("ride", 0.15, _ride_scale(clampf(rider.speed / 18.0, 0.8, 1.6)))
		"finished":
			if rider.place <= 3:
				_play_rider("victory", 0.2)
			else:
				_play_rider("ride_slow", 0.4, 0.45)
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
	# lean forward to scoop a scarf, or slump in the saddle after a finish outside the top three
	if rider_root != null and not _detached:
		if rider.scooping_t > 0.0:
			_scoop = lerpf(_scoop, 1.0, 1.0 - exp(-dt / 0.05))
		else:
			_scoop = lerpf(_scoop, 0.0, 1.0 - exp(-dt / 0.12))
		_slump = lerpf(_slump, 1.0 if (st == "finished" and rider.place > 3) else 0.0, 1.0 - exp(-dt / 0.7))
		if st == "ride":
			rider_root.rotation = Vector3(0.0, 0.0, -rider.scoop_side * _scoop * 0.6)
		elif _slump > 0.01:
			var pitch := Basis(Vector3.RIGHT, -0.42 * _slump)
			var hips := Vector3(0.0, 0.92, 0.0)
			rider_root.transform = Transform3D(pitch, Vector3(0.0, -0.9, 0.0) + hips - pitch * hips)
		else:
			rider_root.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, -0.9, 0.0))
	if st == "ride" or st == "airborne":
		rider.scooping_t = maxf(0.0, rider.scooping_t - dt)
