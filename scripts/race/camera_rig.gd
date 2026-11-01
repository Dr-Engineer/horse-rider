class_name CameraRig
extends Node3D
## Chase camera: FOV widens with speed, leans into curves, shakes with impacts and the shake meter,
## hit-stop on heavy hits, short slow motion on a knockdown near the player, and a crash camera that follows the thrown rider.

var race: Race
var track: Track
var cam: Camera3D
var target: Rider

var cam_s := 0.0
var cam_d := 0.0
var cam_h := 3.0
var look_s := 0.0
var look_d := 0.0
var look_h := 1.4
var fov := 62.0
var roll := 0.0
var shake_amp := 0.0
var crash_blend := 0.0
var _hitstop_until := 0
var _slowmo_until := 0
var _slowmo_scale := 0.4
var _t := 0.0
var _inited := false
var intro_t := 0.0
var lines: CPUParticles3D = null


func bind(p_race: Race) -> void:
	race = p_race
	track = race.track
	target = race.player
	cam = Camera3D.new()
	cam.name = "Camera"
	cam.far = 3000.0
	cam.near = 0.15
	cam.fov = fov

	add_child(cam)
	cam.current = true
	_make_speed_lines()
	race.rider_hit.connect(_on_hit)
	race.rider_crashed.connect(_on_crashed)
	race.rider_event.connect(_on_event)
	_snap()


func _make_speed_lines() -> void:
	lines = CPUParticles3D.new()
	lines.amount = 26
	lines.lifetime = 0.32
	lines.local_coords = true
	lines.emitting = false
	lines.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	lines.emission_ring_axis = Vector3(0, 0, 1)
	lines.emission_ring_radius = 5.2
	lines.emission_ring_inner_radius = 3.4
	lines.emission_ring_height = 0.1
	lines.direction = Vector3(0, 0, 1)
	lines.spread = 0.0
	lines.initial_velocity_min = 55.0
	lines.initial_velocity_max = 75.0
	lines.gravity = Vector3.ZERO
	var bm := BoxMesh.new()
	bm.size = Vector3(0.025, 0.025, 2.4)
	lines.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 1, 1, 0.32)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lines.material_override = m
	lines.position = Vector3(0, 0, -16.0)
	cam.add_child(lines)


func reset_time() -> void:
	_hitstop_until = 0
	_slowmo_until = 0
	Engine.time_scale = 1.0


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _snap() -> void:
	if target == null:
		return
	cam_s = target.s - 7.0
	cam_d = target.d * 0.8
	look_s = target.s + 10.0
	look_d = target.d
	_inited = true
	_apply(0.0)


func _on_hit(attacker: Rider, victim: Rider, info: Dictionary) -> void:
	if target == null:
		return
	var impact: float = info.get("impact", 0.0)
	if victim == target:
		shake_amp = minf(shake_amp + impact * 0.012, 0.7)
		if impact >= 14.0 and not info.get("blocked", false):
			_hit_stop(50 + int(minf(impact, 40.0) * 0.6))
	elif attacker == target and impact >= 20.0 and not info.get("blocked", false):
		shake_amp = minf(shake_amp + impact * 0.006, 0.4)
		_hit_stop(45 + int(minf(impact, 40.0) * 0.5))


func _on_crashed(r: Rider, reason: String) -> void:
	if target == null:
		return
	if r == target:
		shake_amp = minf(shake_amp + 0.5, 0.8)
		return
	if reason != "hazard" and absf(r.s - target.s) < 26.0 and absf(r.d - target.d) < 14.0:
		_slow_mo(0.38, 600)
	elif absf(r.s - target.s) < 14.0:
		_slow_mo(0.6, 350)


func _on_event(kind: String, r: Rider, _info: Dictionary) -> void:
	if r == target:
		match kind:
			"second_wind":
				shake_amp = minf(shake_amp + 0.25, 0.5)
			"land":
				shake_amp = minf(shake_amp + 0.08, 0.3)


func _hit_stop(ms: int) -> void:
	var now := Time.get_ticks_msec()
	_hitstop_until = maxi(_hitstop_until, now + ms)
	Engine.time_scale = 0.04


func _slow_mo(scale: float, ms: int) -> void:
	_slowmo_scale = scale
	_slowmo_until = Time.get_ticks_msec() + ms


func _process(dt: float) -> void:
	if not _inited or race == null or target == null:
		return
	# time scale management uses real time so it always ends
	var now := Time.get_ticks_msec()
	if now < _hitstop_until:
		Engine.time_scale = 0.04
	elif now < _slowmo_until:
		Engine.time_scale = _slowmo_scale
	else:
		Engine.time_scale = 1.0
	var real_dt: float = dt / maxf(Engine.time_scale, 0.04)
	_t += real_dt
	_apply(minf(real_dt, 0.05))


func _apply(dt: float) -> void:
	var r := target
	var fr := clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0) / 60.0
	var down := not r.is_riding() and r.state != "finished"
	crash_blend = lerpf(crash_blend, 1.0 if (r.state == "falling" or r.state == "down" or r.state == "rest") else 0.0, 1.0 - exp(-dt / 0.35))
	var spd := r.speed
	var top: float = r.horse["speed"]
	var f_speed := clampf(spd / maxf(top, 1.0), 0.0, 1.3)
	var focus_s := r.s + (spd * fr if r.is_riding() else 0.0)
	var focus_d := r.d
	if r.state == "mount" or r.state == "run":
		focus_s = r.s
	# desired chase pose in track space
	var back := 5.4 + f_speed * 1.2
	var height := 2.5 + f_speed * 0.45
	var want_s := focus_s - back
	var want_d := focus_d * 0.8
	var want_h := height + r.height * 0.6
	var look_ahead := 8.0 + f_speed * 5.0
	var want_ls := focus_s + look_ahead
	var want_ld := focus_d * 0.92
	var want_lh := 1.5 + r.height * 0.5
	if crash_blend > 0.01:
		# follow the thrown rider, from a little higher and further back
		want_s = lerpf(want_s, focus_s - 6.5, crash_blend)
		want_h = lerpf(want_h, 3.6, crash_blend)
		want_ls = lerpf(want_ls, focus_s + 1.0, crash_blend)
		want_ld = lerpf(want_ld, focus_d, crash_blend)
		want_lh = lerpf(want_lh, 0.9 + r.height, crash_blend)
	var k_s := 1.0 - exp(-dt / (0.045 if crash_blend < 0.5 else 0.2))
	cam_s = lerpf(cam_s, want_s, 1.0 if dt == 0.0 else k_s)
	cam_d = lerpf(cam_d, want_d, 1.0 - exp(-dt / 0.22)) if dt > 0.0 else want_d
	cam_h = lerpf(cam_h, want_h, 1.0 - exp(-dt / 0.3)) if dt > 0.0 else want_h
	look_s = lerpf(look_s, want_ls, 1.0 - exp(-dt / 0.08)) if dt > 0.0 else want_ls
	look_d = lerpf(look_d, want_ld, 1.0 - exp(-dt / 0.2)) if dt > 0.0 else want_ld
	look_h = lerpf(look_h, want_lh, 1.0 - exp(-dt / 0.25)) if dt > 0.0 else want_lh
	# keep the camera from lagging behind past a limit when fast
	cam_s = clampf(cam_s, focus_s - back - 3.0, focus_s - 2.0)
	var pos := track.point(cam_s, cam_d, cam_h)
	var look := track.point(look_s, look_d, look_h)
	# shake
	var meter := clampf(r.shake / 100.0, 0.0, 1.0)
	var amp := shake_amp + meter * meter * 0.06 + f_speed * 0.012
	shake_amp = maxf(0.0, shake_amp - dt * 1.6)
	var off := Vector3(sin(_t * 61.0), sin(_t * 47.0 + 1.3), sin(_t * 53.0 + 2.1)) * amp
	cam.global_position = pos + off * 0.5
	cam.look_at(look + off * 0.3, Vector3.UP)
	# lean into the curve
	var kappa := track.curve_at(focus_s)
	var roll_target := clampf(-kappa * spd * spd * 0.0055, -0.1, 0.1) - clampf(r.lateral * 0.0035, -0.04, 0.04)
	roll = lerpf(roll, roll_target, 1.0 - exp(-dt / 0.25)) if dt > 0.0 else roll_target
	cam.rotate_object_local(Vector3(0, 0, 1), roll + off.x * 0.02)
	# FOV widens with speed, extra when whipping or in Second Wind
	var fov_t := 58.0 + 14.0 * clampf(f_speed, 0.0, 1.2)
	if r.whip_on:
		fov_t += 3.0
	if r.second_wind_t > 0.0:
		fov_t += 5.0
	fov = lerpf(fov, fov_t, 1.0 - exp(-dt / 0.3)) if dt > 0.0 else fov_t
	cam.fov = fov
	if lines != null:
		var go := f_speed > 0.82 or r.whip_on or r.second_wind_t > 0.0
		lines.emitting = go and r.is_riding()
		lines.amount = 34 if (r.whip_on or r.second_wind_t > 0.0) else 22
