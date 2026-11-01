class_name Track
extends RefCounted
## A race course. Everything on it lives in track space: s is metres along the centreline,
## d is metres to the right of it. See docs/TECH_ARCHITECTURE.md.

const STEP := 2.0

var positions := PackedVector3Array()
var tangents := PackedVector3Array()
var rights := PackedVector3Array()
var curvature := PackedFloat32Array()
var half_widths := PackedFloat32Array()
var length := 0.0
var count := 0


## segments: Array of [length_m, turn_degrees (+ is right), rise_m] and optionally half_width.
func build(segments: Array, default_half_width: float, start: Vector3 = Vector3.ZERO) -> void:
	var kappa := PackedFloat32Array()
	var rise := PackedFloat32Array()
	var widths := PackedFloat32Array()
	for seg: Array in segments:
		var seg_len: float = seg[0]
		var n: int = maxi(1, int(round(seg_len / STEP)))
		var k: float = deg_to_rad(float(seg[1])) / seg_len
		var r: float = float(seg[2]) / float(n)
		var w: float = float(seg[3]) if seg.size() > 3 else default_half_width
		for i in n:
			kappa.append(k)
			rise.append(r)
			widths.append(w)
	kappa = _smooth(_smooth(kappa, 12), 12)
	rise = _smooth(_smooth(rise, 20), 20)
	widths = _smooth(_smooth(widths, 15), 15)

	count = kappa.size()
	length = (count - 1) * STEP
	positions.resize(count)
	tangents.resize(count)
	rights.resize(count)
	curvature = kappa
	half_widths = widths
	var heading := 0.0
	var p := start
	for i in count:
		var dir := Vector3(sin(heading), 0.0, -cos(heading))
		var tangent := Vector3(dir.x * STEP, rise[i], dir.z * STEP).normalized()
		positions[i] = p
		tangents[i] = tangent
		rights[i] = Vector3(cos(heading), 0.0, sin(heading))
		p += dir * STEP
		p.y += rise[i]
		heading += kappa[i] * STEP


static func _smooth(a: PackedFloat32Array, radius: int) -> PackedFloat32Array:
	var n := a.size()
	var out := PackedFloat32Array()
	out.resize(n)
	var sum := 0.0
	var window := 0
	for i in range(0, mini(radius + 1, n)):
		sum += a[i]
		window += 1
	for i in n:
		out[i] = sum / float(window)
		var add := i + radius + 1
		var drop := i - radius
		if add < n:
			sum += a[add]
			window += 1
		if drop >= 0:
			sum -= a[drop]
			window -= 1
	return out


func point(s: float, d: float = 0.0, h: float = 0.0) -> Vector3:
	var f := clampf(s / STEP, 0.0, float(count - 1) - 0.001)
	var i := int(f)
	var t := f - float(i)
	var p := positions[i].lerp(positions[i + 1], t)
	var r := rights[i].lerp(rights[i + 1], t)
	return p + r * d + Vector3.UP * h


func tangent_at(s: float) -> Vector3:
	var f := clampf(s / STEP, 0.0, float(count - 1) - 0.001)
	var i := int(f)
	return tangents[i].lerp(tangents[i + 1], f - float(i)).normalized()


func right_at(s: float) -> Vector3:
	var f := clampf(s / STEP, 0.0, float(count - 1) - 0.001)
	var i := int(f)
	return rights[i].lerp(rights[i + 1], f - float(i)).normalized()


func curve_at(s: float) -> float:
	return curvature[clampi(int(s / STEP), 0, count - 1)]


func half_width_at(s: float) -> float:
	return half_widths[clampi(int(s / STEP), 0, count - 1)]


func slope_at(s: float) -> float:
	return tangents[clampi(int(s / STEP), 0, count - 1)].y


## Transform for something standing on the track, facing along it (-Z forward).
func frame(s: float, d: float = 0.0, h: float = 0.0) -> Transform3D:
	var fwd := tangent_at(s)
	var right := right_at(s)
	var up := right.cross(fwd).normalized()
	return Transform3D(Basis(right, up, -fwd), point(s, d, h))


## Smallest distance between stretches of track at least min_gap metres apart along it.
func self_clearance(min_gap: float = 300.0) -> float:
	var best := INF
	var skip := int(min_gap / STEP)
	for i in range(0, count, 10):
		for j in range(i + skip, count, 10):
			best = minf(best, positions[i].distance_to(positions[j]))
	return best
