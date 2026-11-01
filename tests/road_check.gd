extends SceneTree
## Measures every course in every season: how hard it bends, whether the road comes near itself, and whether a
## landmark ended up on the road. Saves a top-down map of each layout.
## Usage: Godot --headless --path . -s res://tests/road_check.gd -- <out_dir>

const LANDMARK_SIZE := {
	"potala": 150.0, "dzong": 90.0, "monastery": 70.0, "chakpori_hill": 110.0, "kumbum": 34.0, "gate_chorten": 0.0, "bridge_cant": 0.0,
}
const MIN_RADIUS := 26.0      # tighter than this and the inside of the road folds up
const MIN_CLEARANCE := 45.0   # the road never comes closer to itself than this, on stretches 300 m apart


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else ""
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
	var bad := 0
	for index in Courses.count():
		for season in 3:
			bad += _check(index, season, out_dir)
	print("RESULT: %s (%d)" % ["PASS" if bad == 0 else "FAIL", bad])
	quit(1 if bad > 0 else 0)


func _check(index: int, season: int, out_dir: String) -> int:
	var c := Courses.get_course(index, season)
	var t := Track.new()
	t.build(c["segments"], c["half_width"])
	var bad := 0
	var min_r := INF
	var bent := 0
	var sum_turn := 0.0
	var max_heading := 0.0
	var heading := 0.0
	for i in t.count:
		var k := absf(t.curvature[i])
		sum_turn += k * Track.STEP
		heading += t.curvature[i] * Track.STEP
		max_heading = maxf(max_heading, absf(heading))
		if k > 0.0001:
			min_r = minf(min_r, 1.0 / k)
		if k > 1.0 / 150.0:
			bent += 1
	var clear := t.self_clearance()
	var min_w := INF
	for w in t.half_widths:
		min_w = minf(min_w, w)
	print("%-24s season %d  %5.0f m  half width %.1f..%.1f  tightest R %5.1f  turning %4.0f deg/km  bent %3.0f%%  heading max %4.0f  self clearance %5.0f" % [
		c["id"], season, t.length, min_w, float(c["half_width"]), min_r, rad_to_deg(sum_turn) / (t.length / 1000.0), 100.0 * float(bent) / float(t.count), rad_to_deg(max_heading), clear])
	if min_r < MIN_RADIUS:
		print("  FAIL: bend tighter than %.0f m" % MIN_RADIUS)
		bad += 1
	if clear < MIN_CLEARANCE:
		print("  FAIL: road comes within %.0f m of itself" % clear)
		bad += 1
	for sp: Dictionary in c["set_pieces"]:
		var prop: String = sp["prop"]
		var size: float = LANDMARK_SIZE.get(prop, -1.0)
		if size <= 0.0:
			continue
		var p := _world(t, float(sp["s"]), float(sp.get("d", 0.0)))
		var nearest := _nearest(t, p)
		if nearest < size:
			print("  FAIL: %s at s=%.0f d=%.0f is %.0f m from the road (needs %.0f)" % [prop, float(sp["s"]), float(sp.get("d", 0.0)), nearest, size])
			bad += 1
	if out_dir != "":
		_map(t, c, "%s/%s_%d.png" % [out_dir, c["id"], season])
	return bad


func _world(t: Track, s: float, d: float) -> Vector3:
	if s <= t.length:
		return t.point(maxf(s, 0.0), d)
	return t.point(t.length, d) + t.tangent_at(t.length) * (s - t.length)


func _nearest(t: Track, p: Vector3) -> float:
	var best := INF
	for i in range(0, t.count, 4):
		var q := t.positions[i]
		best = minf(best, Vector2(q.x - p.x, q.z - p.z).length())
	return best


## A plan view, north up, with a dot every 100 m. The start is green and the finish red, landmarks blue.
func _map(t: Track, c: Dictionary, path: String) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for q in t.positions:
		lo = lo.min(Vector2(q.x, q.z))
		hi = hi.max(Vector2(q.x, q.z))
	var pad := 30.0
	var scale_m := maxf(hi.x - lo.x + pad * 2.0, hi.y - lo.y + pad * 2.0) / 560.0
	var img := Image.create(600, 600, false, Image.FORMAT_RGB8)
	img.fill(Color(0.96, 0.95, 0.9))
	var to_px := func(x: float, z: float) -> Vector2i:
		return Vector2i(int((x - lo.x + pad) / scale_m) + 20, int((z - lo.y + pad) / scale_m) + 20)
	for i in t.count:
		var q := t.positions[i]
		var r := int(ceil(t.half_widths[i] / scale_m))
		var px: Vector2i = to_px.call(q.x, q.z)
		_dot(img, px, r, Color(0.35, 0.3, 0.28))
	var s := 0.0
	while s < t.length:
		var q := t.point(s)
		_dot(img, to_px.call(q.x, q.z), 2, Color(1, 0.8, 0.2))
		s += 100.0
	var a := t.point(0.0)
	var b := t.point(t.length)
	_dot(img, to_px.call(a.x, a.z), 6, Color(0.1, 0.7, 0.2))
	_dot(img, to_px.call(b.x, b.z), 6, Color(0.9, 0.1, 0.1))
	for sp: Dictionary in c["set_pieces"]:
		if LANDMARK_SIZE.has(sp["prop"]):
			var p := _world(t, float(sp["s"]), float(sp.get("d", 0.0)))
			_dot(img, to_px.call(p.x, p.z), 4, Color(0.1, 0.3, 0.9))
	img.save_png(path)


func _dot(img: Image, at: Vector2i, r: int, col: Color) -> void:
	for y in range(at.y - r, at.y + r + 1):
		for x in range(at.x - r, at.x + r + 1):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() and (x - at.x) * (x - at.x) + (y - at.y) * (y - at.y) <= r * r:
				img.set_pixel(x, y, col)
