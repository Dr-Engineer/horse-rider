class_name Hazards
extends RefCounted
## Course events: spawns and simulates boulders, logs, mud, ramps, sacred sites, Quiet Ground, the pass, scarves,
## target poles, moving yak herds, sheep, caravans, dropped weapons and race stewards.
## Sacred sites throw the rider and are never damaged. Gameplay objects only; scenery is TrackDressing's job.

signal happened(kind: String, rider: Rider, info: Dictionary)

const SACRED := ["mani_wall", "chorten"]
const FLAT_SLOTS := {"a": 0, "b": 1, "c": 2, "d": 3}
const POLE_HEIGHT := 4.2     # a shot above this goes over a target pole

var track: Track
var season := 0
var rng: RandomNumberGenerator
var start_s := 8.0
var finish_s := 0.0
var statics: Array[Dictionary] = []     # sorted by s0
var quiet: Array[Vector2] = []
var movers: Array[Dictionary] = []
var poles: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var stewards: Array[Dictionary] = []
var pass_points: Array[float] = []
var max_ext := 8.0
var root: Node3D = null
var time := 0.0
var _next_id := 1


func setup(p_track: Track, events: Array, p_season: int, p_rng: RandomNumberGenerator) -> void:
	track = p_track
	season = p_season
	rng = p_rng
	finish_s = track.length - 60.0
	for ev_v in events:
		var ev: Dictionary = ev_v
		var t: String = ev.get("type", "")
		var es: float = ev.get("s", 0.0)
		var ed: float = ev.get("d", 0.0)
		match t:
			"start":
				start_s = es
			"finish":
				finish_s = es
			"quiet_zone":
				quiet.append(Vector2(float(ev.get("s0", 0.0)), float(ev.get("s1", 0.0))))
			"pass":
				pass_points.append(es)
				_add_static({"type": "pass", "s": es, "d": 0.0, "ext": 1.0})
			"boulder":
				var br: float = float(ev.get("size", 1.1)) * 1.25
				_add_static({"type": t, "s": es, "d": ed, "r": br, "size": ev.get("size", 1.1), "ext": br + 1.2})
			"log":
				var llen: float = ev.get("len", 5.5)
				var lyaw: float = deg_to_rad(float(ev.get("yaw", 0.0)))
				var lhalf: float = llen * 0.5
				_add_static({"type": t, "s": es, "d": ed, "len": llen, "yaw": lyaw, "w": absf(cos(lyaw)) * llen, "ext": lhalf * absf(sin(lyaw)) + 1.8})
			"mud":
				var ln: float = ev.get("len", 22.0)
				_add_static({"type": t, "s": es, "d": ed, "len": ln, "w": ev.get("w", 8.0), "ext": ln * 0.5})
			"ramp":
				var rl: float = ev.get("len", 9.0)
				_add_static({"type": t, "s": es, "d": ed, "len": rl, "w": ev.get("w", 6.5), "rise": ev.get("rise", 1.4), "ext": rl * 0.5})
			"mani_wall":
				var wl: float = ev.get("len", 12.0)
				_add_static({"type": t, "s": es, "d": ed, "len": wl, "w": ev.get("w", 2.4), "ext": wl * 0.5})
			"chorten":
				_add_static({"type": t, "s": es, "d": ed, "r": ev.get("r", 2.3), "ext": float(ev.get("r", 2.3)) + 1.0})
			"scarf":
				_add_static({"type": t, "s": es, "d": ed, "color": int(ev.get("color", 0)), "ext": 1.5})
			"target_pole":
				var pole := {"type": t, "s": es, "d": ed, "ext": 1.0}
				_add_static(pole)
				poles.append(pole)
			"yak_herd":
				_add_herd(ev)
			"sheep":
				_add_sheep(ev)
			"caravan":
				_add_caravan(ev)
			_:
				pass
	statics.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s0"]) < float(b["s0"]))
	if season >= 1:
		_add_stewards()


func _add_static(e: Dictionary) -> void:
	var ext: float = e["ext"]
	e["s0"] = float(e["s"]) - ext
	e["s1"] = float(e["s"]) + ext
	e["id"] = _next_id
	_next_id += 1
	max_ext = maxf(max_ext, ext)
	statics.append(e)


func _add_herd(ev: Dictionary) -> void:
	var n: int = int(ev.get("count", ev.get("n", 6)))
	var dir: float = float(ev.get("dir", 1.0 if rng.randf() < 0.5 else -1.0))
	if dir == 0.0:
		dir = 1.0
	var es: float = ev["s"]
	var hw := track.half_width_at(es)
	var herd_speed: float = ev.get("speed", 2.5)
	for i in n:
		var yak := {
			"kind": "yak", "s": es + (float(i) - float(n - 1) * 0.5) * 4.2 + rng.randf_range(-1.0, 1.0),
			"d": -dir * (hw + 5.0 + rng.randf_range(0.0, 3.0)), "vs": 0.0, "vd": 0.0, "r": 1.35, "rs": 0.95, "rd": 1.9, "dir": dir,
			"trigger_s": es - 140.0, "go": false, "speed": herd_speed * rng.randf_range(0.75, 1.0), "hw": hw, "home_s": es, "id": _next_id,
		}
		_next_id += 1
		movers.append(yak)


func _add_sheep(ev: Dictionary) -> void:
	var n: int = int(ev.get("count", ev.get("n", 6)))
	var es: float = ev["s"]
	var ed: float = ev.get("d", 0.0)
	var drift: float = float(ev.get("dir", 1)) * float(ev.get("speed", 2.0)) * 0.35
	for i in n:
		movers.append({
			"kind": "sheep", "s": es + rng.randf_range(-6.0, 6.0), "d": ed + rng.randf_range(-3.5, 3.5), "vs": 0.0, "vd": drift,
			"r": 0.6, "rs": 0.7, "rd": 0.7, "scatter": false, "id": _next_id, "yaw": rng.randf() * TAU, "drift": drift,
		})
		_next_id += 1


func _add_caravan(ev: Dictionary) -> void:
	var n: int = int(ev.get("count", ev.get("n", 5)))
	var es: float = ev["s"]
	var ed: float = ev.get("d", 0.0)
	var sp: float = ev.get("speed", ev.get("vs", 4.0))
	for i in n:
		movers.append({
			"kind": "mule", "s": es - float(i) * 3.8, "d": ed, "vs": sp, "vd": 0.0, "r": 1.0, "rs": 1.5, "rd": 0.85, "id": _next_id,
		})
		_next_id += 1


func _add_stewards() -> void:
	var count := 2 + season
	for i in count:
		var home := track.length * (0.2 + 0.6 * float(i) / float(maxi(1, count - 1)))
		var hw := track.half_width_at(home)
		stewards.append({
			"s": home, "d": (hw + 1.6) * (1.0 if i % 2 == 0 else -1.0), "home_s": home, "home_d": (hw + 1.6) * (1.0 if i % 2 == 0 else -1.0),
			"stagger": 0.0, "target": null, "dir": 1.0, "phase": rng.randf() * TAU,
		})


func in_quiet(at_s: float) -> bool:
	for q in quiet:
		if at_s >= q.x and at_s <= q.y:
			return true
	return false


func quiet_ahead(at_s: float, dist: float) -> bool:
	for q in quiet:
		if q.y >= at_s and q.x <= at_s + dist:
			return true
	return false


func drop_weapon(weapon_id: String, at_s: float, at_d: float) -> void:
	var p := {"weapon": weapon_id, "s": at_s, "d": at_d, "ttl": 30.0, "node": null, "id": _next_id}
	_next_id += 1
	pickups.append(p)
	if root != null:
		_make_pickup_visual(p)


# ---------------------------------------------------------------------------------------------
# Simulation
# ---------------------------------------------------------------------------------------------

func update(dt: float, riders: Array[Rider]) -> void:
	time += dt
	# leader progress wakes herds
	var lead_s := 0.0
	for r in riders:
		lead_s = maxf(lead_s, r.s)
	for m in movers:
		var kind: String = m["kind"]
		match kind:
			"yak":
				if not m["go"] and lead_s >= float(m["trigger_s"]):
					m["go"] = true
				if m["go"]:
					var dir: float = m["dir"]
					var target_d: float = dir * (float(m["hw"]) + 6.0)
					var dd: float = target_d - float(m["d"])
					if absf(dd) > 0.2:
						m["vd"] = signf(dd) * float(m["speed"])
					else:
						m["vd"] = 0.0
					m["d"] = float(m["d"]) + float(m["vd"]) * dt
					m["s"] = float(m["s"]) + 0.15 * dt
			"mule":
				m["s"] = float(m["s"]) + float(m["vs"]) * dt
			"sheep":
				if not m["scatter"]:
					for r in riders:
						if absf(float(m["s"]) - r.s) < 9.0 and r.is_riding() and r.s < float(m["s"]) and absf(float(m["d"]) - r.d) < 6.0:
							m["scatter"] = true
							m["vd"] = signf(float(m["d"]) - r.d + 0.01) * rng.randf_range(2.5, 4.0)
							m["vs"] = rng.randf_range(0.0, 2.0)
							break
				m["d"] = float(m["d"]) + float(m["vd"]) * dt
				m["s"] = float(m["s"]) + float(m["vs"]) * dt
				if m["scatter"]:
					m["vd"] = float(m["vd"]) * (1.0 - 0.5 * dt)
					m["vs"] = float(m["vs"]) * (1.0 - 0.5 * dt)
	# pickups age
	var i := pickups.size() - 1
	while i >= 0:
		var p: Dictionary = pickups[i]
		p["ttl"] = float(p["ttl"]) - dt
		if float(p["ttl"]) <= 0.0:
			var n: Variant = p["node"]
			if n != null and is_instance_valid(n):
				(n as Node).queue_free()
			pickups.remove_at(i)
		i -= 1
	_update_stewards(dt, riders)


func _update_stewards(dt: float, riders: Array[Rider]) -> void:
	for st in stewards:
		st["stagger"] = maxf(0.0, float(st["stagger"]) - dt)
		var tgt: Rider = null
		var best := 60.0
		for r in riders:
			if r.state == "falling" or r.state == "down" or r.state == "rest":
				var dist := absf(r.s - float(st["s"]))
				if dist < best:
					best = dist
					tgt = r
		if float(st["stagger"]) > 0.0:
			continue
		if tgt != null:
			var ds := tgt.s - float(st["s"])
			var dd := tgt.d - float(st["d"])
			var dist := sqrt(ds * ds + dd * dd)
			if dist > 1.8:
				var sp := 5.0 * dt / dist
				st["s"] = float(st["s"]) + ds * sp
				st["d"] = float(st["d"]) + dd * sp
			elif tgt.state != "run" and tgt.state != "mount":
				var key := "fined_%d" % tgt.crashes
				if not tgt.scarf_taken.has(key):
					tgt.scarf_taken[key] = true
					var amount := GameData.fine(season)
					if tgt.steward_hits > 0:
						amount *= 2
					tgt.fines += amount
					happened.emit("fined", tgt, {"amount": amount})
		else:
			# wander back home
			var home_s: float = st["home_s"]
			var home_d: float = st["home_d"]
			var dist_h := Vector2(home_s - float(st["s"]), home_d - float(st["d"]))
			if dist_h.length() > 0.5:
				var step := minf(2.0 * dt, dist_h.length())
				var dirv := dist_h.normalized()
				st["s"] = float(st["s"]) + dirv.x * step
				st["d"] = float(st["d"]) + dirv.y * step
			else:
				st["phase"] = float(st["phase"]) + dt
				st["s"] = home_s + sin(float(st["phase"]) * 0.5) * 6.0


func _lower_bound(v: float) -> int:
	var lo := 0
	var hi := statics.size()
	while lo < hi:
		var mid := (lo + hi) >> 1
		if float(statics[mid]["s0"]) < v:
			lo = mid + 1
		else:
			hi = mid
	return lo


## Called every tick for every rider, after the rider has moved from prev_s to r.s.
func check_rider(r: Rider, prev_s: float) -> void:
	if not r.is_riding():
		return
	r.mud = false
	r.in_quiet = in_quiet(r.s)
	var airborne := r.state == "airborne"
	var i := _lower_bound(prev_s - max_ext - 3.0)
	var n := statics.size()
	while i < n:
		var e: Dictionary = statics[i]
		if float(e["s0"]) > r.s + 3.0:
			break
		i += 1
		if float(e["s1"]) < prev_s - 3.0:
			continue
		var t: String = e["type"]
		var es: float = e["s"]
		var ed: float = e["d"]
		var rel_d := ed - r.d
		var crossed := prev_s < es and r.s >= es
		match t:
			"pass":
				if crossed and not r.scarf_taken.has(e["id"]):
					r.scarf_taken[e["id"]] = true
					r.add_lungta(1.5)
					happened.emit("pass", r, {"s": es})
			"boulder":
				var rr: float = e["r"]
				var ds := (r.s - es) / (rr + 0.9)
				var dd := (r.d - ed) / (rr + 0.6)
				if ds * ds + dd * dd < 1.0 and r.height < 1.9:
					_throw(r, "boulder", rel_d)
					return
			"log":
				var ya: float = e["yaw"]
				var rs_ := r.s - es
				var rd_ := r.d - ed
				var u := rs_ * sin(ya) + rd_ * cos(ya)
				var v := rs_ * cos(ya) - rd_ * sin(ya)
				if absf(v) < 0.95 and absf(u) < float(e["len"]) * 0.5 + 0.3 and r.height < 0.95:
					if r.speed > 7.0:
						_throw(r, "log", rel_d)
						return
					else:
						r.speed = minf(r.speed, 3.0)
			"mud":
				if absf(r.s - es) < float(e["len"]) * 0.5 and absf(r.d - ed) < float(e["w"]) * 0.5 and not airborne:
					r.mud = true
			"ramp":
				if not airborne and r.height <= 0.0 and r.land_cooldown <= 0.0 and r.speed > 8.0 and absf(r.s - es) < float(e["len"]) * 0.5 and absf(r.d - ed) < float(e["w"]) * 0.5:
					var key := "ramp_%d" % int(e["id"])
					if not r.scarf_taken.has(key) or r.age - float(r.scarf_taken[key]) > 4.0:
						r.scarf_taken[key] = r.age
						r.leap_now(6.2 + r.speed * 0.09)
						r.speed += 1.2
						r.silver_bonus += 4
						r.add_lungta(0.25)
						happened.emit("ramp", r, {"s": es})
			"mani_wall":
				var half_len: float = float(e["len"]) * 0.5
				var half_w: float = float(e["w"]) * 0.5
				if crossed and not r.scarf_taken.has(e["id"]) and absf(rel_d) < 10.0:
					r.scarf_taken[e["id"]] = true
					_site_pass(r, rel_d, es)
				if absf(r.s - es) < half_len + 0.5 and absf(r.d - ed) < half_w + 0.5 and r.height < 1.3:
					_throw(r, "site", rel_d)
					return
			"chorten":
				var rc: float = e["r"]
				if crossed and not r.scarf_taken.has(e["id"]) and absf(rel_d) < 10.0:
					r.scarf_taken[e["id"]] = true
					_site_pass(r, rel_d, es)
				var cds := (r.s - es) / (rc + 0.8)
				var cdd := (r.d - ed) / (rc + 0.5)
				if cds * cds + cdd * cdd < 1.0 and r.height < 2.0:
					_throw(r, "site", rel_d)
					return
			"scarf":
				var sk := "scarf_%d" % int(e["id"])
				if not r.scarf_taken.has(sk) and absf(r.s - es) < 1.3 and absf(r.d - ed) < 1.5 and not airborne:
					r.scarf_taken[sk] = true
					r.scoops += 1
					r.silver_bonus += 8
					r.add_lungta(0.3)
					r.scooping_t = 0.5
					r.scoop_side = signf(ed - r.d) if absf(ed - r.d) > 0.05 else 1.0
					happened.emit("scarf", r, {"s": es, "d": ed})
	# movers
	for m in movers:
		var ms: float = m["s"]
		if absf(ms - r.s) > 4.0:
			continue
		var rs: float = m.get("rs", m["r"])
		var rd: float = m.get("rd", m["r"])
		var ds2 := (r.s - ms) / (rs + 0.6)
		var dd2 := (r.d - float(m["d"])) / (rd + 0.5)
		if ds2 * ds2 + dd2 * dd2 >= 1.0:
			continue
		var kind: String = m["kind"]
		if kind == "sheep":
			if r.height < 0.6 and not m["scatter"]:
				m["scatter"] = true
				m["vd"] = signf(float(m["d"]) - r.d + 0.01) * 4.0
				m["vs"] = 3.0
				r.speed *= 0.6
				r.shake = minf(r.shake + 10.0, 100.0)
				happened.emit("sheep", r, {})
		else:
			if r.height < 1.1:
				var mvs: float = m.get("vs", 0.0)
				if r.speed - mvs > (10.0 if kind == "yak" else 7.5):
					_throw(r, kind, float(m["d"]) - r.d)
					return
				# a gentle bump: ease to the mover's pace and slide clear
				r.speed = minf(r.speed, mvs + 1.0)
				r.d += signf(r.d - float(m["d"]) + 0.01) * 3.0 * get_physics_dt()
	# dropped weapons
	if r.state == "ride":
		for k in range(pickups.size() - 1, -1, -1):
			var p: Dictionary = pickups[k]
			if absf(float(p["s"]) - r.s) < 2.2 and absf(float(p["d"]) - r.d) < 1.6:
				var wid: String = p["weapon"]
				if GameData.weapon_value(wid) > GameData.weapon_value(r.weapon_id):
					r.weapon_id = wid
					var node: Variant = p["node"]
					if node != null and is_instance_valid(node):
						(node as Node).queue_free()
					pickups.remove_at(k)
					happened.emit("pickup", r, {"weapon": wid})


func _site_pass(r: Rider, rel_d: float, at_s: float) -> void:
	var good := (rel_d > 0.0) != r.bon
	if good:
		r.add_lungta(1.0)
		happened.emit("site_good", r, {"s": at_s})
	else:
		r.add_lungta(-0.6)
		happened.emit("site_bad", r, {"s": at_s})


static var debug := false


func get_physics_dt() -> float:
	return 1.0 / 60.0


func _throw(r: Rider, what: String, rel_d: float) -> void:
	if debug:
		var near := ""
		for m in movers:
			if absf(float(m["s"]) - r.s) < 6.0:
				near += " [%s s=%.1f d=%.1f]" % [m["kind"], m["s"], m["d"]]
		print("THROW %s by %s at s=%.1f d=%.2f v=%.1f lat=%.1f%s" % [r.display_name, what, r.s, r.d, r.speed, r.lateral, near])
	r.crash_what = what
	r.crash("hazard", signf(rel_d))
	happened.emit("thrown", r, {"what": what})


## Called by Race when a projectile passes close to a target pole. Returns true if it scored.
func pole_shot(r: Rider, proj_s: float, proj_d: float, proj_h: float) -> bool:
	for pole in poles:
		var key := "pole_%d" % int(pole["id"])
		if r.scarf_taken.has(key):
			continue
		if absf(float(pole["s"]) - proj_s) < 1.6 and absf(float(pole["d"]) - proj_d) < 1.3 and proj_h < POLE_HEIGHT:
			r.scarf_taken[key] = true
			r.silver_bonus += 10
			r.add_lungta(0.4)
			pole["hit"] = true
			happened.emit("pole", r, {"s": pole["s"], "d": pole["d"]})
			return true
	return false


# ---------------------------------------------------------------------------------------------
# AI queries
# ---------------------------------------------------------------------------------------------

## A shot or a blow reaching a sheep on the road. It bolts, and this says whether there was one there. h is how high a shot is.
func sheep_struck(at_s: float, at_d: float, reach: float, h: float = 0.0) -> bool:
	if h > 1.3:
		return false
	for m in movers:
		if m["kind"] == "sheep" and Vector2(float(m["s"]) - at_s, float(m["d"]) - at_d).length() < reach:
			m["scatter"] = true
			m["vd"] = signf(float(m["d"]) - at_d + 0.01) * 4.0
			m["vs"] = 3.0
			return true
	return false


## Obstacles ahead of at_s within dist metres: [{s, d, r, kind, sacred, leap}]. For look-ahead avoidance.
func obstacles_ahead(at_s: float, dist: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var i := _lower_bound(at_s - max_ext - 2.0)
	var n := statics.size()
	while i < n:
		var e: Dictionary = statics[i]
		i += 1
		if float(e["s0"]) > at_s + dist:
			break
		if float(e["s1"]) < at_s - 2.0:
			continue
		var t: String = e["type"]
		match t:
			"boulder":
				out.append({"s": e["s"], "d": e["d"], "r": float(e["r"]) + 0.5, "hl": e["r"], "kind": t, "sacred": false, "leap": false})
			"log":
				out.append({"s": e["s"], "d": e["d"], "r": maxf(float(e["w"]) * 0.5, 0.8), "hl": 0.9, "kind": t, "sacred": false, "leap": true})
			"mani_wall":
				out.append({"s": e["s"], "d": e["d"], "r": float(e["w"]) * 0.5 + 0.4, "hl": float(e["len"]) * 0.5, "kind": t, "sacred": true, "leap": false})
			"chorten":
				out.append({"s": e["s"], "d": e["d"], "r": float(e["r"]) + 0.5, "hl": float(e["r"]) + 0.5, "kind": t, "sacred": true, "leap": false})
			"mud":
				out.append({"s": e["s"], "d": e["d"], "r": float(e["w"]) * 0.5, "hl": float(e["len"]) * 0.5, "kind": t, "sacred": false, "leap": false, "soft": true})
			"ramp":
				out.append({"s": e["s"], "d": e["d"], "r": float(e["w"]) * 0.5, "hl": float(e["len"]) * 0.5, "kind": t, "sacred": false, "leap": false, "want": true})
			"scarf":
				out.append({"s": e["s"], "d": e["d"], "r": 1.0, "hl": 1.0, "kind": t, "sacred": false, "leap": false, "want": true})
	for m in movers:
		var ms: float = m["s"]
		if ms > at_s - 3.0 and ms < at_s + dist:
			var k: String = m["kind"]
			if k == "yak" and not m["go"]:
				# not moving yet, but will be crossing: treat the whole span as dangerous
				out.append({"s": ms, "d": float(m["d"]) * 0.0, "r": float(m["hw"]) , "hl": 2.0, "kind": "yak", "sacred": false, "leap": false, "soon": true})
			else:
				var vd: float = m["vd"]
				out.append({"s": ms, "d": float(m["d"]) + vd * 1.0, "r": float(m["r"]) + 0.6 + absf(vd) * 0.5, "hl": float(m.get("rs", m["r"])) + 0.6, "kind": k, "sacred": false, "leap": false, "vd": vd, "vs": float(m.get("vs", 0.0)), "soft": k == "sheep"})
	return out


# ---------------------------------------------------------------------------------------------
# Visuals
# ---------------------------------------------------------------------------------------------

func _flat(mesh: Mesh, slot: String, col: Color) -> MeshInstance3D:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs := PackedVector2Array()
	var u := 0.0625 + 0.125 * float(FLAT_SLOTS.get(slot, 0))
	uvs.resize(verts.size())
	for k in verts.size():
		uvs[k] = Vector2(u, 0.015)
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = ArtKit.toon(ArtKit.CLASS_PROP)
	mi.set_instance_shader_parameter("slot_" + slot, col)
	return mi


func _prop_or(name: String, walker := false) -> Node3D:
	if ResourceLoader.exists("res://assets/models/props/%s.glb" % name):
		return ArtKit.prop_walker(name) if walker else ArtKit.prop(name)
	return null


func _fallback(kind: String, e: Dictionary) -> Node3D:
	var n := Node3D.new()
	match kind:
		"boulder":
			var sm := SphereMesh.new()
			var rr: float = e.get("r", 1.4)
			sm.radius = rr
			sm.height = rr * 1.5
			sm.radial_segments = 7
			sm.rings = 4
			var mi := _flat(sm, "a", Color("6d6a6c"))
			mi.position.y = rr * 0.55
			n.add_child(mi)
		"log":
			var cm := CylinderMesh.new()
			cm.top_radius = 0.38
			cm.bottom_radius = 0.38
			cm.height = float(e.get("w", 5.0))
			cm.radial_segments = 6
			var mi2 := _flat(cm, "a", Color("6a4328"))
			mi2.rotation_degrees = Vector3(0, 0, 90)
			mi2.position.y = 0.4
			n.add_child(mi2)
		"mud":
			return _mud_patch(e)
		"ramp":
			var bm := BoxMesh.new()
			bm.size = Vector3(float(e.get("w", 4.5)), 0.8, float(e.get("len", 6.0)))
			var mi4 := _flat(bm, "a", Color("8a6a40"))
			mi4.position.y = 0.2
			mi4.rotation_degrees.x = 7.0
			n.add_child(mi4)
		"mani_wall":
			var wm := BoxMesh.new()
			wm.size = Vector3(float(e.get("w", 1.6)), 1.3, float(e.get("len", 14.0)))
			var mi5 := _flat(wm, "a", Color("b9b2a2"))
			mi5.position.y = 0.65
			n.add_child(mi5)
			var cap := BoxMesh.new()
			cap.size = Vector3(float(e.get("w", 1.6)) * 1.1, 0.25, float(e.get("len", 14.0)) * 1.02)
			var mi5b := _flat(cap, "b", Color("d9d2c0"))
			mi5b.position.y = 1.4
			n.add_child(mi5b)
		"chorten":
			var base := CylinderMesh.new()
			base.top_radius = 1.8
			base.bottom_radius = 2.2
			base.height = 1.2
			base.radial_segments = 8
			var mb := _flat(base, "a", Color("efe9db"))
			mb.position.y = 0.6
			n.add_child(mb)
			var dome := SphereMesh.new()
			dome.radius = 1.5
			dome.height = 2.6
			dome.radial_segments = 8
			dome.rings = 4
			var md := _flat(dome, "a", Color("f4efe4"))
			md.position.y = 2.2
			n.add_child(md)
			var spire := CylinderMesh.new()
			spire.top_radius = 0.0
			spire.bottom_radius = 0.7
			spire.height = 2.4
			spire.radial_segments = 8
			var msp := _flat(spire, "b", Color("d2a92c"))
			msp.position.y = 4.3
			n.add_child(msp)
		"scarf":
			var pm := PlaneMesh.new()
			pm.size = Vector2(1.2, 0.5)
			var cols := [Color("2a74c4"), Color("d63a22"), Color("2a9a5a"), Color("f2b632")]
			var ms := _flat(pm, "b", cols[int(e.get("id", 0)) % cols.size()])
			ms.position.y = 0.06
			n.add_child(ms)
		"target_pole":
			var pol := CylinderMesh.new()
			pol.top_radius = 0.08
			pol.bottom_radius = 0.1
			pol.height = 2.8
			pol.radial_segments = 5
			var mp := _flat(pol, "a", Color("6a4328"))
			mp.position.y = 1.4
			n.add_child(mp)
			var cl := BoxMesh.new()
			cl.size = Vector3(0.9, 0.9, 0.05)
			var mc := _flat(cl, "b", Color("d63a22"))
			mc.position.y = 2.4
			n.add_child(mc)
		"yak":
			var yb := BoxMesh.new()
			yb.size = Vector3(1.2, 1.4, 2.4)
			var my := _flat(yb, "d", Color("1e1a1c"))
			my.position.y = 1.1
			n.add_child(my)
		"mule":
			var mb2 := BoxMesh.new()
			mb2.size = Vector3(0.8, 1.2, 1.9)
			var mm := _flat(mb2, "c", Color("7a6a58"))
			mm.position.y = 1.0
			n.add_child(mm)
			var load_m := BoxMesh.new()
			load_m.size = Vector3(1.0, 0.7, 1.2)
			var ml := _flat(load_m, "b", Color("b3262b"))
			ml.position.y = 1.9
			n.add_child(ml)
		"sheep":
			var sb := SphereMesh.new()
			sb.radius = 0.5
			sb.height = 0.8
			sb.radial_segments = 6
			sb.rings = 3
			var msh := _flat(sb, "a", Color("efe8d8"))
			msh.position.y = 0.45
			n.add_child(msh)
		"steward":
			var cb := CapsuleMesh.new()
			cb.radius = 0.35
			cb.height = 1.7
			cb.radial_segments = 6
			var mst := _flat(cb, "a", Color("2a3a8a"))
			mst.position.y = 0.85
			n.add_child(mst)
			var hat := CylinderMesh.new()
			hat.top_radius = 0.34
			hat.bottom_radius = 0.58
			hat.height = 0.34
			hat.radial_segments = 8
			var mh := _flat(hat, "b", Color("f2c632"))
			mh.position.y = 1.95
			n.add_child(mh)
			var sash := BoxMesh.new()
			sash.size = Vector3(0.9, 0.22, 0.9)
			var msh := _flat(sash, "b", Color("f2c632"))
			msh.position.y = 1.15
			n.add_child(msh)
		_:
			pass
	return n


## A patch of churned mud lying on the road: a grid that follows the road surface (curve and slope included) over the
## event's width and length, painted by shaders/mud.gdshader into an irregular stair-stepped blob. The mesh is built in
## the frame of the event, so the node just takes the usual static transform. Every patch gets its own seed.
func _mud_patch(e: Dictionary) -> Node3D:
	var es: float = e["s"]
	var ed: float = e["d"]
	var hx: float = float(e.get("w", 8.0)) * 0.5
	var hy: float = float(e.get("len", 22.0)) * 0.5
	# The blob wanders out a little past the event's box, so the grid is a little bigger than it.
	var gx := hx * 1.2 + 1.0
	var gy := hy * 1.2 + 1.0
	var nx := maxi(int(ceil(gx * 2.0 / 1.5)), 4)
	var nz := maxi(int(ceil(gy * 2.0 / 1.5)), 4)
	var frame := track.frame(es, ed, 0.0)
	var inv := frame.affine_inverse()
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	for iz in nz + 1:
		var s := es - gy + 2.0 * gy * float(iz) / float(nz)
		var sc := clampf(s, 0.0, track.length)
		var hw := track.half_width_at(sc)
		for ix in nx + 1:
			var d := ed - gx + 2.0 * gx * float(ix) / float(nx)
			verts.append(inv * track.point(sc, d, 0.075))
			uvs.append(Vector2(d - ed, s - es))
			uv2s.append(Vector2(d, hw))
	var idx := PackedInt32Array()
	for iz in nz:
		for ix in nx:
			var a := iz * (nx + 1) + ix
			var b := a + 1
			var c := a + nx + 1
			var dd := c + 1
			# clockwise seen from above, like the road ribbon
			idx.append_array(PackedInt32Array([a, c, b, b, c, dd]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = ArtKit.mud_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var holder := Node3D.new()
	holder.add_child(mi)
	var seed_v := fposmod(float(e.get("id", 1)) * 7.31 + es * 0.013, 97.0)
	mi.set_instance_shader_parameter("seed", seed_v)
	mi.set_instance_shader_parameter("half_size", Vector2(hx, hy))
	return holder


func _visual_for(kind: String, e: Dictionary) -> Node3D:
	if kind == "mud":
		e["is_prop"] = false
		return _mud_patch(e)
	var prop_names := {
		"boulder": "boulder", "mani_wall": "mani_wall", "chorten": "chorten", "ramp": "ramp", "scarf": "scarf", "log": "log",
		"target_pole": "target_pole", "yak": "yak", "mule": "mule", "sheep": "sheep",
	}
	if prop_names.has(kind):
		var pname: String = prop_names[kind]
		# Every third mule carries the second load.
		if kind == "mule" and int(e.get("id", 0)) % 3 == 1 and ResourceLoader.exists("res://assets/models/props/mule_b.glb"):
			pname = "mule_b"
		var p: Node3D = null
		if ArtKit.WALKERS.has(pname):
			p = _prop_or(pname, true)
		else:
			p = _prop_or(pname)
		if p != null:
			e["is_prop"] = true
			return p
	e["is_prop"] = false
	return _fallback(kind, e)


## Placement and scale that match each prop model to its event numbers.
func _static_transform(e: Dictionary) -> Transform3D:
	var t: String = e["type"]
	var tf := track.frame(float(e["s"]), float(e["d"]), 0.0)
	if not e.get("is_prop", false):
		if t == "log":
			tf.basis = tf.basis * Basis(Vector3.UP, PI * 0.5 + float(e["yaw"]))
		return tf
	match t:
		"boulder":
			var sz: float = e.get("size", 1.1)
			tf.basis = tf.basis * Basis(Vector3.UP, float(int(e["id"]) % 7)) * Basis.from_scale(Vector3.ONE * sz)
		"log":
			var k: float = float(e["len"]) / 5.7
			tf.basis = tf.basis * Basis(Vector3.UP, PI * 0.5 + float(e["yaw"])) * Basis.from_scale(Vector3(1.0, 0.8, k))
		"mani_wall":
			tf.basis = tf.basis * Basis.from_scale(Vector3(1.0, 1.0, float(e["len"]) / 12.0))
		"ramp":
			tf.basis = tf.basis * Basis.from_scale(Vector3(float(e["w"]) / 8.4, 1.0, float(e["len"]) / 9.0))
		"scarf":
			tf.basis = tf.basis * Basis(Vector3.UP, float(int(e["id"]) % 5))
	return tf


func build_visuals(parent: Node3D) -> void:
	root = Node3D.new()
	root.name = "Hazards"
	parent.add_child(root)
	for e in statics:
		var t: String = e["type"]
		if t == "pass":
			continue
		var n := _visual_for(t, e)
		root.add_child(n)
		e["node"] = n
		n.transform = _static_transform(e)
		if t == "scarf":
			_tint_scarf(n, int(e.get("color", 0)))
	for m in movers:
		var n2 := _visual_for(m["kind"], m)
		root.add_child(n2)
		m["node"] = n2
	var steward_i := 0
	for st in stewards:
		var n3 := _steward_visual(st, steward_i)
		steward_i += 1
		root.add_child(n3)
		st["node"] = n3
	for p in pickups:
		_make_pickup_visual(p)


func _tint_scarf(n: Node3D, colour_index: int) -> void:
	var cols := [Color("2f6fd0"), Color("d9697a"), Color("d63a22"), Color("2fa05a"), Color("f2c632")]
	# silk catches the light: a little brighter than the plain colour, never white
	var col: Color = (cols[colour_index % cols.size()] as Color).lightened(0.14)
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		mi.set_instance_shader_parameter("slot_a", col)
		mi.set_instance_shader_parameter("slot_b", col)


func _make_pickup_visual(p: Dictionary) -> void:
	var wid: String = p["weapon"]
	var w: Dictionary = GameData.weapon(wid)
	var model: String = w.get("model", "")
	var holder := Node3D.new()
	var path := "res://assets/models/weapons/%s.glb" % model
	if model != "" and ResourceLoader.exists(path):
		var scn: PackedScene = load(path)
		var inst: Node3D = scn.instantiate()
		ArtKit.apply(inst, ArtKit.toon(ArtKit.CLASS_RIDER))
		# Stands upright and turns at grabbing height, so it reads as loot from a gallop.
		var spin := Node3D.new()
		spin.position.y = 0.55
		holder.add_child(spin)
		inst.rotation.x = PI * 0.5
		spin.add_child(inst)
	else:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 0.12, 1.1)
		var mi := _flat(bm, "a", Color("8a8f98"))
		mi.position.y = 0.15
		holder.add_child(mi)
	var ring := _flat(_ring_mesh(), "b", Color("f2c632"))
	ring.position.y = 0.05
	ring.scale = Vector3(0.55, 1.0, 0.55)
	holder.add_child(ring)
	root.add_child(holder)
	p["node"] = holder
	holder.transform = track.frame(float(p["s"]), float(p["d"]), 0.0)
	for child in holder.get_children():
		if child.get_child_count() > 0 and child.has_method("create_tween"):
			child.create_tween().set_loops().tween_property(child, "rotation:y", TAU, 1.4).from(0.0)


func _ring_mesh() -> Mesh:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.7
	cm.bottom_radius = 0.7
	cm.height = 0.04
	cm.radial_segments = 10
	return cm


var _vis_us := 0


## Move visuals to match the simulation. Cheap: only movers and stewards.
func update_visuals() -> void:
	if root == null:
		return
	var now_us := Time.get_ticks_usec()
	var dt := clampf(float(now_us - _vis_us) * 0.000001, 0.0, 0.1) if _vis_us > 0 else 0.016
	_vis_us = now_us
	for m in movers:
		var n: Variant = m.get("node", null)
		if n == null or not is_instance_valid(n):
			continue
		var node: Node3D = n
		var tf := track.frame(float(m["s"]), float(m["d"]), 0.0)
		var kind: String = m["kind"]
		var vs := float(m.get("vs", 0.0)) if kind != "yak" else 0.0
		var vd := float(m.get("vd", 0.0))
		var speed := Vector2(vs, vd).length()
		var yaw := float(m.get("_yaw", 0.0))
		if kind == "yak":
			# walk sideways across the road: face along the motion
			var face: float = float(m["dir"]) if absf(vd) < 0.1 else signf(vd)
			yaw = lerp_angle(yaw, -face * PI * 0.5, 1.0 - exp(-dt * 6.0)) if m.has("_yaw") else -face * PI * 0.5
		elif kind == "sheep":
			# idle sheep keep their own heading; one that is running faces where it runs
			if m.has("_yaw"):
				if speed > 0.5:
					yaw = lerp_angle(yaw, atan2(-vd, vs), 1.0 - exp(-dt * 8.0))
			else:
				yaw = float(m["yaw"])
		m["_yaw"] = yaw
		tf.basis = tf.basis * Basis(Vector3.UP, yaw)
		node.transform = tf
		if node.has_meta("walker_meshes"):
			# Legs swing with the distance covered; a standing animal only nods its head.
			var stride := ArtKit.walker_stride_length(node)
			var phase := float(m.get("_ph", float(int(m["id"]) % 13) * 0.9)) + speed * dt / stride * TAU
			var amp_target := clampf(speed / (stride * 1.3), 0.0, 1.0)
			var amp := lerpf(float(m.get("_amp", 0.0)), amp_target, 1.0 - exp(-dt * 8.0))
			phase = fposmod(phase, TAU)
			m["_ph"] = phase
			m["_amp"] = amp
			ArtKit.set_stride(node, phase, amp)
	for st in stewards:
		_update_steward_visual(st, dt)
	for pole in poles:
		var nn: Variant = pole.get("node", null)
		if nn != null and is_instance_valid(nn) and pole.get("hit", false):
			(nn as Node3D).rotation.z = 0.0


# ---------------------------------------------------------------------------------------------
# Race stewards: rider.glb on foot
# ---------------------------------------------------------------------------------------------

const STEWARD_SKINS: Array[Color] = [Color("d19a6e"), Color("b97f54"), Color("96603c")]
const STEWARD_FACES: Array[String] = ["head_old", "head_young", "head_old"]


## A steward on foot: the rider model in an indigo robe and a yellow basin hat. Wardrobe rules from docs/INTERFACES.md: one
## body, one head (tone variant by name), one hat; slot A robe, slot B trim and hat, slot C bare skin, slot D hair.
func _steward_visual(st: Dictionary, index: int) -> Node3D:
	var path := "res://assets/models/rider.glb"
	if not ResourceLoader.exists(path):
		return _fallback("steward", st)
	var holder := Node3D.new()
	var body: Node3D = (load(path) as PackedScene).instantiate()
	ArtKit.apply(body, ArtKit.toon(ArtKit.CLASS_RIDER, 0.25))
	holder.add_child(body)
	var tone := index % 3
	var face: String = STEWARD_FACES[tone]
	var head := "%s%s" % [face, ["_lt", "", "_dp"][tone]]
	var old := face == "head_old"
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mi.name)
		mi.visible = nm == "body_chuba" or nm == head or nm == "hat_basin"
		mi.set_instance_shader_parameter("slot_a", Color("2a2a66"))
		mi.set_instance_shader_parameter("slot_b", Color("f2b632"))
		mi.set_instance_shader_parameter("slot_c", STEWARD_SKINS[tone])
		mi.set_instance_shader_parameter("slot_d", Color("9b9595") if old else Color("1c171c"))
	var ap := body.find_children("*", "AnimationPlayer", true, false)
	if not ap.is_empty():
		var player: AnimationPlayer = ap[0]
		for nm2 in ["run", "stand"]:
			if player.has_animation(nm2):
				player.get_animation(nm2).loop_mode = Animation.LOOP_LINEAR
		if player.has_animation("stand"):
			player.play("stand")
		st["ap"] = player
		st["anim"] = "stand"
	st["body"] = body
	st["yaw"] = 0.0
	st["_lx"] = float(st["s"])
	st["_ld"] = float(st["d"])
	st["_spd"] = 0.0
	return holder


func _update_steward_visual(st: Dictionary, dt: float) -> void:
	var n2: Variant = st.get("node", null)
	if n2 == null or not is_instance_valid(n2):
		return
	var node: Node3D = n2
	var tf := track.frame(float(st["s"]), float(st["d"]), 0.0)
	if not st.has("ap"):
		node.transform = tf
		return
	# Speed and heading from how far the steward moved since the last frame, smoothed.
	var ds := float(st["s"]) - float(st["_lx"])
	var dd := float(st["d"]) - float(st["_ld"])
	st["_lx"] = float(st["s"])
	st["_ld"] = float(st["d"])
	var inst := Vector2(ds, dd).length() / maxf(dt, 0.001)
	var spd := lerpf(float(st["_spd"]), inst, 1.0 - exp(-dt * 7.0))
	st["_spd"] = spd
	var yaw := float(st["yaw"])
	if inst > 0.2:
		yaw = lerp_angle(yaw, atan2(-dd, ds), 1.0 - exp(-dt * 9.0))
	elif spd < 0.3:
		# standing at their post, they face the road
		yaw = lerp_angle(yaw, signf(float(st["d"])) * PI * 0.5, 1.0 - exp(-dt * 3.0))
	st["yaw"] = yaw
	tf.basis = tf.basis * Basis(Vector3.UP, yaw)
	# A struck steward reels.
	var stagger := float(st.get("stagger", 0.0))
	if stagger > 0.0:
		tf.basis = tf.basis * Basis(Vector3(0, 0, 1), sin(Time.get_ticks_msec() * 0.03) * 0.28 * minf(stagger, 1.0))
	node.transform = tf
	var player: AnimationPlayer = st["ap"]
	var want: String = String(st["anim"])
	if want == "stand" and spd > 0.8:
		want = "run"
	elif want == "run" and spd < 0.4:
		want = "stand"
	if want != String(st["anim"]) and player.has_animation(want):
		st["anim"] = want
		player.play(want, 0.2)
	if String(st["anim"]) == "run":
		player.speed_scale = clampf(spd / 3.6, 0.45, 1.5)
	else:
		player.speed_scale = 1.0
