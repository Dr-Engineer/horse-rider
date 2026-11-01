class_name Projectile
extends RefCounted
## An arrow, a sling stone or a thrown roped spear. It flies through the world, not along the road: it leaves the hand with
## the shooter's own velocity added to the launch, gravity pulls it down and the air slows it. It also keeps track of where
## it is in track space (s, d, h), for the ground and the target poles.

const GRAVITY := 9.8
const DRAG := {"arrow": 0.0012, "stone": 0.002, "spear": 0.0016}   # deceleration is this times speed squared
const HAUL_SPEED := 52.0
const MAX_LIFE := 5.0

var kind := "arrow"          # "arrow" | "stone" | "spear"
var shooter: Rider
var weapon_id := ""
var track: Track
var pos := Vector3.ZERO
var last_pos := Vector3.ZERO
var vel := Vector3.ZERO
var s := 0.0
var d := 0.0
var h := 1.5
var power := 0.0
var damage := 0.0
var impact := 0.0
var life := 0.0
var alive := true
var returning := false
var hit_any := false
var max_out := 18.0
var path: PackedVector3Array = []  # where it has been, for the line drawn behind the player's own shots
var node: Node3D = null
var rope: MeshInstance3D = null
var tracer: MeshInstance3D = null


func launch(p_track: Track, from: Vector3, from_s: float, p_vel: Vector3) -> void:
	track = p_track
	pos = from
	last_pos = from
	vel = p_vel
	s = from_s
	_locate()


func step(dt: float) -> void:
	life += dt
	last_pos = pos
	if kind == "spear" and returning:
		# hauled back along the rope to the thrower's hand
		var to := shooter.hand_point(track) - pos
		var dist := to.length()
		var haul := HAUL_SPEED * dt
		if dist < haul + 1.2:
			alive = false
			return
		pos += to / dist * haul
		_locate()
		return
	vel += (Vector3.DOWN * GRAVITY - vel * vel.length() * float(DRAG[kind])) * dt
	pos += vel * dt
	_locate()
	if kind == "spear":
		if pos.distance_to(shooter.hand_point(track)) >= max_out or h <= 0.1:
			returning = true
	elif life >= MAX_LIFE:
		alive = false


## Finds the nearest point of the road: a couple of steps from the last answer is plenty at these speeds.
func _locate() -> void:
	for i in 2:
		s = clampf(s + (pos - track.point(s)).dot(track.tangent_at(s)), 0.0, track.length)
	var c := track.point(s)
	d = (pos - c).dot(track.right_at(s))
	h = pos.y - c.y
