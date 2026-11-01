class_name Projectile
extends RefCounted
## An arrow, a sling stone or a thrown roped spear, flying in track space.

var kind := "arrow"          # "arrow" | "stone" | "spear"
var shooter: Rider
var weapon_id := ""
var s := 0.0
var d := 0.0
var h := 1.5
var vs := 0.0
var vd := 0.0
var power := 0.0
var damage := 0.0
var impact := 0.0
var life := 0.0
var max_life := 1.0
var alive := true
var returning := false
var hit_any := false
var out_dist := 0.0
var max_out := 18.0
var node: Node3D = null
var rope: MeshInstance3D = null


func step(dt: float) -> void:
	life += dt
	if kind == "spear" and returning:
		# hauled back along the rope to the thrower's hand
		var ts := shooter.s - s
		var td := shooter.d - d
		var dist := sqrt(ts * ts + td * td)
		var haul := 52.0 * dt
		if dist < haul + 1.2:
			alive = false
			return
		s += ts / dist * haul
		d += td / dist * haul
		return
	var ps := s
	var pd := d
	s += vs * dt
	d += vd * dt
	h = maxf(0.4, h - 0.9 * dt)
	if kind == "spear":
		out_dist += sqrt((s - ps) * (s - ps) + (d - pd) * (d - pd))
		if out_dist >= max_out:
			returning = true
	elif life >= max_life:
		alive = false
