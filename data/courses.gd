class_name Courses
extends RefCounted
## The five courses. Turtle-style segments in track space (see docs/INTERFACES.md), a biome for TrackBuilder,
## an env for ArtKit.make_world, gameplay events for Hazards and a dressing recipe for TrackDressing.
##
## Event fields beyond type, s and d (all lengths in metres, d is metres right of centre):
##   boulder {size}  log {len, yaw}  mud {w, len}  ramp {w, len, rise}  mani_wall {len, yaw}  chorten {}
##   yak_herd {count, dir, speed}   sheep {count, dir, speed}   caravan {count, speed}
##   scarf {color: 0..4, group}     target_pole {}       quiet_zone {s0, s1}   pass {s}   start {s}   finish {s}
##   bullseye {}   wolf_flock {sheep, wolves}: these two stand off the road, see scripts/race/roadside.gd
## Season scales length (about 2.0, 2.6 and 3.2 km) and event density. Fixed set pieces keep their fraction.
## A bend keeps its radius in every season: a longer course turns further, it doesn't turn more gently.
##
## Dressing (course.dress) is read by TrackDressing: layers of scatter plus set_pieces placed by s and d.

const SEASON_LENGTH: Array[float] = [2000.0, 2600.0, 3200.0]
const SEASON_DENSITY: Array[float] = [1.0, 1.4, 1.8]
# Scarf colours for the scarf scoop, indexed by the event's color: blue, saffron, red, green, yellow. Never white:
# white khata stay off the ground, so index 1 is saffron here and is never emitted by the course data.
const SCARF_COLORS: Array[Color] = [Color("2f6fd0"), Color("e8871e"), Color("d63a22"), Color("2fa05a"), Color("f2c632")]
const SCARF_PICKS: Array[int] = [0, 2, 3, 4]
const IDS: Array[String] = ["tea_horse_road", "grass_sea", "turquoise_pass", "gallop_behind_the_fort", "western_gate"]
const BULLSEYE_OUT := 6.5     # metres past the road's edge: out of reach from the road, and a horse in the scrub can't quite touch it
const FLOCK_OUT := 10.0       # the middle of a flock

# Palette hex values, copied from art/tools/atlas_palette.py. Terrain only ever uses these.
const PAL := {
	"ink": "#17131A", "soot": "#2B2630", "charcoal": "#453D46", "slate": "#6B6570", "ash": "#9B9595",
	"bone": "#D9CDB2", "chalk": "#EFE6D2", "conch": "#FBF5E6",
	"lapis": "#1F4FA8", "lapis_deep": "#12306E", "azure": "#4A8FD9", "sky_pale": "#BFE0E8",
	"turquoise": "#2FB7B0", "turquoise_light": "#7FD9CE", "water_deep": "#17779B",
	"umber": "#5A3D2B", "sienna": "#8C5A33", "tan": "#B98D5A", "sand": "#D8BE8E", "khaki": "#A89A63",
	"rock_red": "#9C4E36", "rock_grey": "#7D7A78", "rock_dark": "#544F52", "rock_purple": "#6F5A6B",
	"grass_gold": "#B6A94F", "grass_green": "#7E9A41", "grass_deep": "#4F7A3A", "pine": "#2F5540", "orpiment": "#F2B632",
	"juniper": "#3C6B52", "barley": "#D9C75A", "snow": "#F6FBFF", "snow_shadow": "#BFD2E8", "ochre": "#C9953F",
}


static func count() -> int:
	return IDS.size()


static func _c(name: String) -> Color:
	return Color(PAL[name])


static func _mix(a: String, b: String, t: float) -> Color:
	return _c(a).lerp(_c(b), t)


static func _colors(grass_a: Color, grass_b: Color, grass_c: Color, verge: Color, rock: Color, rock_dark: Color) -> Dictionary:
	return {
		"grass_a": grass_a, "grass_b": grass_b, "grass_c": grass_c, "verge": verge,
		"rock": rock, "rock_dark": rock_dark, "snow": _c("snow"), "snow_shade": _c("snow_shadow"),
	}


static func get_course(index: int, season: int) -> Dictionary:
	index = clampi(index, 0, count() - 1)
	season = clampi(season, 0, 2)
	var def: Dictionary
	match index:
		0: def = _tea_horse_road()
		1: def = _grass_sea()
		2: def = _turquoise_pass()
		3: def = _gyantse()
		_: def = _western_gate()
	var course := _assemble(index, season, def)
	_apply_season(course)
	return course


## The look of each Season, laid over the course's own colours (env and biome only, never the layout or events):
##   Spring Meets    crisp and green, cool light, small clean clouds, more snow on the heights
##   Summer Festival bright and saturated, a high sun, big clouds
##   Harvest Final   golden, a low warm sun with long shadows, thin high cloud, grass gone to barley
## Everything is mixed from the palette above. Foliage gets a tint that TrackDressing multiplies into plants.
static func _apply_season(course: Dictionary) -> void:
	var season: int = course["season"]
	var env: Dictionary = course["env"]
	var biome: Dictionary = course["biome"]
	var colors: Dictionary = biome["colors"]
	var dress: Dictionary = course["dress"]
	var rot: Vector3 = env.get("sun_rot", Vector3(-42.0, -38.0, 0.0))
	match season:
		0:
			env["sun_color"] = Color(0.94, 0.975, 1.0)
			env["sun_energy"] = 0.52
			env["ambient"] = Color(0.78, 0.86, 1.0)
			env["ambient_energy"] = 0.65
			env["sky_top"] = _mix("lapis", "lapis_deep", 0.12)
			env["sky_horizon"] = _mix("sky_pale", "turquoise_light", 0.14)
			env["fog_color"] = _mix("sky_pale", "snow", 0.4)
			env["fog_density"] = float(env.get("fog_density", 0.9)) * 0.85
			env["fog_end"] = float(env.get("fog_end", 3500.0)) * 1.2
			env["cloud_cover"] = 0.34
			env["cloud_scale"] = 1.35
			colors["grass_a"] = (colors["grass_a"] as Color).lerp(_c("grass_green"), 0.5)
			colors["grass_b"] = (colors["grass_b"] as Color).lerp(_c("grass_deep"), 0.3).lerp(_c("grass_green"), 0.15)
			colors["grass_c"] = (colors["grass_c"] as Color).lerp(_c("grass_green"), 0.35)
			colors["verge"] = (colors["verge"] as Color).lerp(_c("grass_deep"), 0.15)
			biome["snow_line"] = float(biome.get("snow_line", 150.0)) * 0.8
			biome["far_snow_line"] = float(biome.get("far_snow_line", 420.0)) * 0.85
			dress["foliage_tint"] = Color(0.93, 1.08, 0.96)
		1:
			env["sun_color"] = Color(1.0, 0.965, 0.87)
			env["sun_energy"] = 0.56
			rot.x = -57.0
			env["sun_rot"] = rot
			env["ambient"] = Color(0.86, 0.88, 1.0)
			env["ambient_energy"] = 0.66
			env["sky_top"] = _c("lapis")
			env["sky_horizon"] = _mix("sky_pale", "azure", 0.28)
			env["fog_color"] = _mix("sky_pale", "snow", 0.45)
			env["fog_end"] = float(env.get("fog_end", 3500.0)) * 1.1
			env["cloud_cover"] = 0.86
			env["cloud_scale"] = 0.62
			for key in ["grass_a", "grass_b", "grass_c"]:
				var g: Color = colors[key]
				colors[key] = Color.from_hsv(g.h, minf(g.s * 1.28, 1.0), minf(g.v * 1.06, 1.0))
			colors["verge"] = (colors["verge"] as Color).lightened(0.05)
			dress["foliage_tint"] = Color(0.96, 1.1, 0.9)
		_:
			env["sun_color"] = _mix("conch", "orpiment", 0.42)
			env["sun_energy"] = 0.62
			rot.x = -31.0
			env["sun_rot"] = rot
			env["ambient"] = Color(0.9, 0.86, 0.84)
			env["ambient_energy"] = 0.8
			env["sky_top"] = _mix("lapis", "azure", 0.12)
			env["sky_mid"] = Color(0.5, 0.6, 0.88)
			env["sky_horizon"] = _mix("conch", "orpiment", 0.28)
			env["fog_color"] = _mix("sand", "conch", 0.35)
			env["fog_density"] = float(env.get("fog_density", 0.9)) * 1.05
			env["cloud_cover"] = 0.42
			env["cloud_scale"] = 0.9
			env["cloud_light"] = Color(1.0, 0.93, 0.8)
			env["cloud_shade"] = Color(0.8, 0.7, 0.76)
			env["sun_size"] = 0.05
			colors["grass_a"] = _c("grass_gold").lerp(_c("barley"), 0.55)
			colors["grass_b"] = _mix("grass_gold", "ochre", 0.4)
			colors["grass_c"] = _mix("khaki", "ochre", 0.4)
			colors["verge"] = _mix("tan", "khaki", 0.4)
			colors["rock"] = (colors["rock"] as Color).lerp(_c("rock_red"), 0.15)
			biome["snow_line"] = float(biome.get("snow_line", 150.0)) * 1.25
			dress["foliage_tint"] = Color(1.28, 1.0, 0.62)


## Scales the base layout to the season, then places fixed events, then fills the rest.
static func _assemble(index: int, season: int, def: Dictionary) -> Dictionary:
	var base_len := 0.0
	for seg: Array in def.segments:
		base_len += float(seg[0])
	var k: float = SEASON_LENGTH[season] / base_len
	var segs: Array = []
	var total := 0.0
	for seg: Array in def.segments:
		var out: Array = [float(seg[0]) * k, float(seg[1]) * k, float(seg[2]) * k]
		if seg.size() > 3:
			out.append(float(seg[3]))
		segs.append(out)
		total += roundf(float(seg[0]) * k / 2.0) * 2.0
	var length: float = total - 2.0
	var half_width: float = def.half_width
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * (index + 1) + 104729 * (season + 1)

	var events: Array = []
	events.append({"type": "start", "s": 24.0, "d": 0.0})
	events.append({"type": "finish", "s": length - 40.0, "d": 0.0})
	for q: Array in def.get("quiet", []):
		events.append({"type": "quiet_zone", "s0": q[0] * length, "s1": q[1] * length})
	for f in def.get("pass", []):
		events.append({"type": "pass", "s": float(f) * length, "d": 0.0})
	for ev: Dictionary in def.get("fixed", []):
		var e: Dictionary = ev.duplicate()
		e["s"] = float(e["f"]) * length
		e.erase("f")
		events.append(e)

	var density: float = SEASON_DENSITY[season]
	_fill_events(events, def.get("fill", {}), density, length, half_width, rng, def.get("quiet", []))

	# Narrow stretches change the road width, so fit each event to the width where it sits.
	var fit := Track.new()
	fit.build(segs, half_width)
	for e: Dictionary in events:
		if not e.has("d") or not e.has("s"):
			continue
		var hwl := fit.half_width_at(clampf(float(e["s"]), 0.0, fit.length))
		var side := 1.0 if float(e["d"]) >= 0.0 else -1.0
		match String(e["type"]):
			"mani_wall":
				e["d"] = side * (hwl - 0.6)
			"chorten":
				e["d"] = side * (hwl + 0.2)
			"target_pole":
				e["d"] = side * (hwl + 2.5)
			"bullseye":
				e["d"] = side * (hwl + BULLSEYE_OUT)
			"wolf_flock":
				e["d"] = side * (hwl + FLOCK_OUT)
			"boulder", "log", "mud", "ramp", "scarf", "caravan", "sheep", "yak_herd":
				e["d"] = clampf(float(e["d"]), -(hwl - 2.2), hwl - 2.2)
		# Mud and ramps never close the whole road: there is always a way round.
		match String(e["type"]):
			"mud":
				e["w"] = minf(float(e.get("w", 6.0)), hwl * 1.1)
			"ramp":
				e["w"] = minf(float(e.get("w", 5.0)), hwl * 0.85)

	var biome: Dictionary = def.biome.duplicate(true)
	biome["half_width"] = half_width
	biome["seed"] = 100 + index * 17
	# Fractions in biome zones (ledges, notches, lake) become metres here.
	for key in ["ledges", "notches"]:
		if biome.has(key):
			var zones: Array = []
			for z: Dictionary in biome[key]:
				var zz := z.duplicate()
				zz["s0"] = float(z["f0"]) * length
				zz["s1"] = float(z["f1"]) * length
				zones.append(zz)
			biome[key] = zones

	if biome.has("river") and biome.river.has("narrow"):
		var nr: Array = biome.river.narrow
		biome.river["narrow"] = [float(nr[0]) * length, float(nr[1]) * length]
	var set_pieces: Array = []
	for sp: Dictionary in def.get("set_pieces", []):
		var p := sp.duplicate()
		if p.has("f"):
			p["s"] = float(p["f"]) * length
		if p.has("from_end"):
			p["s"] = length + float(p["from_end"])
		set_pieces.append(p)

	var dress: Dictionary = def.get("dress", {}).duplicate(true)
	dress["season"] = season
	dress["length"] = length
	# Era details. No comment, no text: survey stakes from Season 1, one truck parked at the Western Gate in Season 2.
	dress["survey_stakes"] = season >= 1
	dress["truck"] = season >= 2 and index == 4
	dress["plumes"] = season >= 2          # far columns of dust on the plain, Season 3 only
	dress["milestones"] = true

	return {
		"id": IDS[index], "index": index, "season": season,
		"name": def.name, "region": def.region, "blurb": def.blurb,
		"segments": segs, "length": length, "half_width": half_width,
		"biome": biome, "env": def.env, "events": events,
		"set_pieces": set_pieces, "dress": dress,
	}


static func _in_quiet(s: float, quiet: Array, length: float, margin: float = 40.0) -> bool:
	for q: Array in quiet:
		if s > q[0] * length - margin and s < q[1] * length + margin:
			return true
	return false


static func _fill_events(events: Array, fill: Dictionary, density: float, length: float, hw: float, rng: RandomNumberGenerator, quiet: Array) -> void:
	var taken: Array = []   # [a, b] ranges of s already used
	var taken_beside: Array = []   # the same for what stands off the road, which road events leave plenty of room for
	for e: Dictionary in events:
		if e.has("s"):
			taken.append([float(e["s"]), float(e["s"])])
	for type: String in fill.keys():
		var n := int(roundf(float(fill[type]) * density * length / 2000.0))
		var used: Array = taken_beside if type in ["bullseye", "wolf_flock"] else taken
		for i in n:
			for attempt in 60:
				var span := 45.0 if type == "scarf" else 0.0
				var s := rng.randf_range(260.0, length - 220.0 - span)
				if _in_quiet(s, quiet, length) or _in_quiet(s + span, quiet, length):
					continue
				var ok := true
				for t: Array in used:
					if s < float(t[1]) + 30.0 and s + span > float(t[0]) - 30.0:
						ok = false
						break
				if not ok:
					continue
				used.append([s, s + span])
				if type == "scarf":
					var color: int = SCARF_PICKS[rng.randi() % SCARF_PICKS.size()]
					var side := 1.0 if rng.randf() < 0.5 else -1.0
					var width := rng.randf_range(0.3, 0.55) * hw
					for j in 4:
						var dj := side * width * sin(float(j) * 0.9 - 0.7)
						events.append({"type": "scarf", "s": s + j * 15.0, "d": dj, "color": color, "group": i})
				else:
					events.append(_detail(type, s, hw, rng))
				break


static func _detail(type: String, s: float, hw: float, rng: RandomNumberGenerator) -> Dictionary:
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	var e := {"type": type, "s": s, "d": 0.0}
	match type:
		"boulder":
			e["d"] = rng.randf_range(-hw + 2.5, hw - 2.5)
			e["size"] = rng.randf_range(0.9, 1.5)
		"log":
			e["d"] = rng.randf_range(-hw * 0.6, hw * 0.6)
			e["len"] = rng.randf_range(4.5, 6.5)
			e["yaw"] = rng.randf_range(-35.0, 35.0)
		"mud":
			e["d"] = rng.randf_range(-hw * 0.5, hw * 0.5)
			e["w"] = rng.randf_range(0.7, 1.1) * hw
			e["len"] = rng.randf_range(12.0, 20.0)
		"ramp":
			e["d"] = side * hw * 0.4
			e["w"] = 5.0
			e["len"] = 9.0
			e["rise"] = 1.4
		"sheep":
			e["d"] = side * hw * 0.5
			e["count"] = rng.randi_range(6, 10)
			e["dir"] = int(side)
			e["speed"] = 2.0
		"caravan":
			e["d"] = side * hw * 0.45
			e["count"] = rng.randi_range(4, 6)
			e["speed"] = 4.0
		"yak_herd":
			e["count"] = rng.randi_range(5, 8)
			e["dir"] = int(side)
			e["speed"] = 2.5
		"mani_wall":
			e["d"] = side * (hw - 0.6)
			e["len"] = 12.0
			e["yaw"] = 0.0
		"chorten":
			e["d"] = side * (hw + 0.2)
		"target_pole":
			e["d"] = side * (hw + 2.5)
		"bullseye":
			e["d"] = side * (hw + BULLSEYE_OUT)
		"wolf_flock":
			e["d"] = side * (hw + FLOCK_OUT)
			e["sheep"] = rng.randi_range(4, 6)
			e["wolves"] = rng.randi_range(1, 2)
	return e


# --- scenery recipes ---------------------------------------------------------------------------------------

static func _layer(prop: String, n: float, d0: float, d1: float, extra: Dictionary = {}) -> Dictionary:
	var l := {"prop": prop, "n": n, "d0": d0, "d1": d1}
	l.merge(extra, true)
	return l


# 1. Tea Horse Road: Kham gorge. Climbing ledge road, river below on the right, red log houses.
static func _tea_horse_road() -> Dictionary:
	return {
		"name": "Tea Horse Road", "region": "Kham",
		"blurb": "A mule road cut into a red gorge. The river is a long way down, and the mules are in no hurry.",
		"half_width": 6.0,
		"segments": [
			[130, 0, 0], [90, -65, 6], [100, 85, 6], [70, -60, 5], [90, 75, 7], [110, -100, 8], [60, 45, 4], [60, 0, 2],
			[90, 70, 6], [130, -100, 8], [140, 0, 1, 4.5],   # the bridge, on a straight
			[90, 70, 5], [80, -75, 5, 5.0], [100, 95, 6], [90, -85, 5], [70, 55, 3], [110, -110, 5], [90, 80, 3],
			[80, -60, 0], [90, 60, -6], [130, 0, 0],
		],
		"biome": {
			"rugged": 11.0, "mountain": 320.0, "mountain_start": 24.0, "mountain_end": 360.0,
			"snow_line": 210.0, "far_snow_line": 250.0, "horizon": 700.0, "rock_slope": 0.5,
			"drop_start": 12.0, "drop_end": 38.0, "bank_blend": 6.0,
			"river": {"offset": 60.0, "width": 34.0, "depth": 32.0, "open_offset": 112.0, "open_width": 46.0, "open_depth": 24.0, "open_end": 84.0, "narrow": [0.34, 0.58]},
			"notches": [{"f0": 0.49, "f1": 0.515, "depth": 22.0}],
			"road_tex": "tea",
			"colors": _colors(_c("grass_deep"), _mix("grass_deep", "grass_green", 0.6), _c("khaki"), _c("tan"), _c("rock_red"), _c("rock_purple")),
		},
		"env": {
			"sun_color": Color(1.0, 0.92, 0.78), "sun_energy": 0.5, "sun_rot": Vector3(-40.0, -48.0, 0.0),
			"ambient": Color(0.84, 0.86, 1.0), "ambient_energy": 0.62,
			"sky_top": _c("lapis"), "sky_horizon": _c("sky_pale"), "fog_color": Color("c9dde4"), "fog_density": 0.9,
			"fog_begin": 50.0, "fog_end": 3300.0, "cloud_cover": 0.45,
		},
		"quiet": [],
		"pass": [],
		"fixed": [
			{"type": "caravan", "f": 0.17, "d": 4.0, "count": 5, "speed": 4.0},
			{"type": "mani_wall", "f": 0.30, "d": -8.4, "len": 12.0, "yaw": 0.0},
			{"type": "chorten", "f": 0.43, "d": -7.5},
			{"type": "caravan", "f": 0.62, "d": -3.0, "count": 6, "speed": 4.0},
			{"type": "ramp", "f": 0.70, "d": 3.0, "w": 5.0, "len": 9.0, "rise": 1.4},
			{"type": "scarf", "f": 0.80, "d": 0.0, "color": 2, "group": 90},
			{"type": "scarf", "f": 0.8075, "d": 2.0, "color": 2, "group": 90},
			{"type": "scarf", "f": 0.815, "d": 3.0, "color": 2, "group": 90},
		],
		"fill": {"boulder": 3, "log": 2, "mud": 2, "scarf": 2, "sheep": 1, "ramp": 1, "bullseye": 4, "wolf_flock": 2},
		"set_pieces": [
			{"prop": "house_kham", "f": 0.07, "d": -40.0, "face": "road", "scale": 1.0},
			{"prop": "house_kham", "f": 0.092, "d": -50.0, "face": "road", "scale": 1.12},
			{"prop": "house_kham", "f": 0.112, "d": -38.0, "face": "road", "scale": 0.95},
			{"prop": "house_kham", "f": 0.086, "d": -72.0, "face": "road", "scale": 1.05},
			{"prop": "mule", "f": 0.079, "d": -27.0, "face": "road", "scale": 1.0, "yaw": 60.0},
			{"prop": "mule", "f": 0.083, "d": -26.0, "face": "road", "scale": 1.0, "yaw": -20.0},
			{"prop": "flagpole", "f": 0.1, "d": -24.0, "face": "road", "scale": 1.0},
			{"prop": "drying_rack", "f": 0.082, "d": -33.0, "face": "road", "scale": 1.0},
			{"prop": "wool_bale", "f": 0.104, "d": -29.0, "face": "road", "scale": 1.0},
			{"prop": "dog", "f": 0.088, "d": -22.0, "face": "road", "scale": 1.0},
			{"prop": "house_kham", "f": 0.58, "d": -58.0, "face": "road", "scale": 1.05},
			{"prop": "house_kham", "f": 0.605, "d": -44.0, "face": "road", "scale": 0.95},
			{"prop": "tea_brick_stack", "f": 0.59, "d": -30.0, "face": "road", "scale": 1.0},
			{"prop": "bridge_cant", "f": 0.5025, "d": 0.0, "face": "track", "scale": 1.0, "sink": 0.0},
			{"prop": "cairn", "f": 0.44, "d": -22.0, "face": "road", "scale": 1.2},
			{"prop": "flagpole", "f": 0.865, "d": -18.0, "face": "road", "scale": 1.15},
			{"prop": "chorten", "f": 0.9, "d": -20.0, "face": "road", "scale": 1.0},
		],
		"dress": {
			"layers": [
				_layer("spruce", 15.0, 1.0, 110.0, {"bias": 1.6, "scale": [0.9, 1.7], "slope": 0.72, "cull": 1100, "shadow": true}),
				_layer("juniper", 10.0, 1.5, 60.0, {"bias": 1.6, "scale": [0.8, 1.5], "slope": 0.7, "cull": 650, "shadow": true}),
				_layer("bush", 26.0, 0.6, 45.0, {"bias": 1.7, "scale": [0.8, 1.6], "slope": 0.7, "cull": 380}),
				_layer("grass_tuft", 260.0, 0.1, 34.0, {"ink_class": 0.85, "bias": 1.7, "scale": [0.6, 1.2], "slope": 0.75, "cull": 300, "shadow": false}),
				_layer("grass_tall", 22.0, 0.6, 40.0, {"ink_class": 0.85, "bias": 1.6, "scale": [0.8, 1.3], "slope": 0.7, "cull": 240, "shadow": false}),
				_layer("flowers", 40.0, 0.4, 30.0, {"ink_class": 0.85, "bias": 1.5, "scale": [0.9, 1.4], "slope": 0.7, "cull": 150, "shadow": false}),
				_layer("rock_a", 4.0, 1.5, 70.0, {"bias": 1.5, "scale": [0.8, 1.9], "slope": 0.95, "cull": 700, "shadow": true, "tint": [Color(1.15, 0.8, 0.7), Color(1.0, 0.85, 0.85)]}),
				_layer("rock_b", 4.0, 1.5, 70.0, {"bias": 1.5, "scale": [0.8, 1.9], "slope": 0.95, "cull": 700, "shadow": true, "tint": [Color(1.15, 0.8, 0.7), Color(1.0, 0.85, 0.85)]}),
				_layer("rock_c", 4.0, 1.5, 70.0, {"bias": 1.5, "scale": [0.8, 1.9], "slope": 0.95, "cull": 700, "shadow": true, "tint": [Color(1.15, 0.8, 0.7), Color(1.0, 0.85, 0.85)]}),
				_layer("boulder", 1.0, 6.0, 80.0, {"bias": 1.5, "scale": [1.0, 2.4], "slope": 0.95, "cull": 900, "shadow": true}),
				_layer("flag_string", 1.1, 0.5, 14.0, {"align": true, "scale": [1.0, 1.3], "slope": 0.5, "cull": 500, "nodes": true}),
				_layer("mani_wall", 0.25, 1.5, 22.0, {"align": true, "scale": [1.0, 1.4], "slope": 0.4, "cull": 600, "nodes": true}),
				_layer("wall_stone", 0.7, 3.0, 22.0, {"align": true, "scale": [1.0, 1.0], "slope": 0.3, "cull": 500, "nodes": true}),
				_layer("chorten", 0.2, 3.0, 24.0, {"align": true, "scale": [0.9, 1.3], "slope": 0.4, "cull": 700, "nodes": true}),
				_layer("yak", 0.35, 8.0, 70.0, {"side": -1, "scale": [1.0, 1.15], "slope": 0.45, "cull": 450, "herd": 3, "nodes": true}),
			],
		},
	}


# 2. Grass Sea: Nagchu. Open plain, huge sky, black tents, yak herds, wide and fast.
static func _grass_sea() -> Dictionary:
	return {
		"name": "Grass Sea", "region": "Nagchu",
		"blurb": "The plain runs out to the edge of the sky. Yaks cross where they like, and you will go around.",
		"half_width": 7.5,
		"segments": [
			[150, 0, 0], [130, 70, 1], [130, -85, -1], [110, 70, 1], [140, -100, 1], [120, 80, -1], [110, 0, 0],
			[120, -75, 1], [130, 90, 0], [120, -85, 1], [130, 100, -1], [120, -90, 0], [140, 60, -1], [100, -30, 0], [150, 0, 0],
		],
		"biome": {
			"rugged": 2.0, "mountain": 120.0, "mountain_start": 900.0, "mountain_end": 2800.0,
			"snow_line": 260.0, "far_snow_line": 190.0, "horizon": 460.0, "rock_slope": 0.7, "bank_blend": 20.0,
			"road_tex": "grass", "fields": false, "patch": 0.1,
			"colors": _colors(_c("grass_gold"), _mix("grass_gold", "grass_green", 0.5), _mix("grass_gold", "khaki", 0.6), _c("khaki"), _c("rock_grey"), _c("rock_dark")),
		},
		"env": {
			"sun_color": Color(1.0, 0.95, 0.82), "sun_energy": 0.5, "sun_rot": Vector3(-52.0, -30.0, 0.0),
			"ambient": Color(0.84, 0.86, 1.0), "ambient_energy": 0.62,
			"sky_top": _mix("lapis", "azure", 0.25), "sky_horizon": _c("sky_pale"), "fog_color": Color("cde3e6"), "fog_density": 0.85,
			"fog_begin": 90.0, "fog_end": 4200.0, "cloud_cover": 0.62,
		},
		"quiet": [],
		"pass": [],
		"fixed": [
			{"type": "yak_herd", "f": 0.22, "d": 0.0, "count": 7, "dir": 1, "speed": 2.5},
			{"type": "sheep", "f": 0.36, "d": -4.0, "count": 8, "dir": -1, "speed": 2.0},
			{"type": "yak_herd", "f": 0.48, "d": 0.0, "count": 6, "dir": -1, "speed": 2.5},
			{"type": "mani_wall", "f": 0.40, "d": 12.4, "len": 12.0, "yaw": 0.0},
			{"type": "caravan", "f": 0.60, "d": 5.0, "count": 5, "speed": 4.0},
			{"type": "yak_herd", "f": 0.74, "d": 0.0, "count": 8, "dir": 1, "speed": 2.5},
			{"type": "ramp", "f": 0.30, "d": -3.0, "w": 5.0, "len": 9.0, "rise": 1.4},
			{"type": "ramp", "f": 0.86, "d": 3.0, "w": 5.0, "len": 9.0, "rise": 1.4},
		],
		"fill": {"boulder": 2, "mud": 3, "scarf": 3, "log": 1, "sheep": 1, "bullseye": 3, "wolf_flock": 3},
		"set_pieces": [
			{"prop": "tent_black", "f": 0.12, "d": -60.0, "face": "road", "scale": 1.25},
			{"prop": "tent_black", "f": 0.128, "d": -74.0, "face": "road", "scale": 1.4},
			{"prop": "tent_black", "f": 0.116, "d": -84.0, "face": "road", "scale": 1.15},
			{"prop": "yak", "f": 0.122, "d": -50.0, "face": "road", "scale": 1.0},
			{"prop": "yak", "f": 0.135, "d": -56.0, "face": "road", "scale": 1.0},
			{"prop": "dog", "f": 0.118, "d": -48.0, "face": "road", "scale": 1.0},
			{"prop": "flagpole", "f": 0.124, "d": -42.0, "face": "road", "scale": 1.1},
			{"prop": "tent_black", "f": 0.55, "d": 70.0, "face": "road", "scale": 1.3},
			{"prop": "tent_black", "f": 0.562, "d": 86.0, "face": "road", "scale": 1.15},
			{"prop": "churn", "f": 0.556, "d": 58.0, "face": "road", "scale": 1.0},
			{"prop": "dung_stack", "f": 0.548, "d": 62.0, "face": "road", "scale": 1.0},
			{"prop": "dog", "f": 0.558, "d": 60.0, "face": "road", "scale": 1.0},
			{"prop": "tent_black", "f": 0.88, "d": -90.0, "face": "road", "scale": 1.25},
			{"prop": "wool_bale", "f": 0.882, "d": -76.0, "face": "road", "scale": 1.0},
			{"prop": "cairn", "f": 0.33, "d": 45.0, "face": "road", "scale": 1.3},
		],
		"dress": {
			"layers": [
				_layer("grass_tuft", 150.0, 0.3, 170.0, {"ink_class": 0.85, "bias": 1.5, "scale": [0.6, 1.2], "slope": 0.7, "cull": 340, "shadow": false}),
				_layer("grass_tall", 30.0, 0.6, 120.0, {"ink_class": 0.85, "bias": 1.4, "scale": [0.8, 1.4], "slope": 0.6, "cull": 260, "shadow": false}),
				_layer("flowers", 70.0, 0.4, 110.0, {"ink_class": 0.85, "bias": 1.3, "scale": [0.9, 1.5], "slope": 0.6, "cull": 170, "shadow": false}),
				_layer("bush", 4.0, 4.0, 140.0, {"bias": 1.2, "scale": [0.8, 1.4], "slope": 0.5, "cull": 420}),
				_layer("rock_a", 2.0, 3.0, 160.0, {"bias": 1.2, "scale": [0.7, 1.5], "slope": 0.6, "cull": 600, "shadow": true}),
				_layer("rock_b", 2.0, 3.0, 160.0, {"bias": 1.2, "scale": [0.7, 1.5], "slope": 0.6, "cull": 600, "shadow": true}),
				_layer("yak", 2.4, 16.0, 240.0, {"scale": [1.0, 1.15], "slope": 0.4, "cull": 650, "herd": 6, "nodes": true}),
				_layer("sheep", 1.6, 16.0, 240.0, {"scale": [0.9, 1.1], "slope": 0.4, "cull": 500, "herd": 8, "nodes": true}),
				_layer("kiang", 0.35, 70.0, 300.0, {"scale": [1.0, 1.1], "slope": 0.4, "cull": 800, "herd": 4, "nodes": true}),
				_layer("marmot", 1.0, 6.0, 70.0, {"scale": [1.0, 1.2], "slope": 0.4, "cull": 250, "nodes": true}),
				_layer("tent_black", 0.22, 40.0, 200.0, {"face_road": true, "scale": [1.05, 1.4], "slope": 0.3, "cull": 800, "herd": 2, "nodes": true}),
				_layer("flag_string", 0.5, 0.5, 20.0, {"align": true, "scale": [1.0, 1.3], "slope": 0.5, "cull": 600, "nodes": true}),
				_layer("cairn", 0.3, 4.0, 60.0, {"scale": [1.0, 1.4], "slope": 0.4, "cull": 700, "nodes": true}),
				_layer("crane", 0.2, 30.0, 200.0, {"scale": [1.0, 1.2], "slope": 0.3, "cull": 500, "herd": 2, "nodes": true}),
			],
		},
	}


# 3. Turquoise Pass: Kamba La and Yamdrok. Climb to the cairn, then down beside the lake.
static func _turquoise_pass() -> Dictionary:
	return {
		"name": "Turquoise Pass", "region": "Kamba La",
		"blurb": "Up through the switchbacks to the cairn, then down to a lake the colour of a good bead.",
		"half_width": 5.5,
		"segments": [
			[100, 0, 0], [80, -85, 8], [95, 125, 10], [90, -125, 10], [100, 135, 12], [85, -120, 10], [100, 130, 12],
			[80, -85, 8], [60, 25, 3], [100, 0, 5], [140, 0, 0, 8.5],   # the pass opens out around the cairn
			[80, -50, -8], [100, 110, -14], [90, -105, -13], [85, 90, -11], [100, -110, -14], [90, 100, -12], [90, -70, -8],
			[60, 35, -5], [120, 0, -2],
		],
		"biome": {
			"rugged": 11.0, "mountain": 280.0, "mountain_start": 40.0, "mountain_end": 600.0,
			"snow_line": 85.0, "far_snow_line": 260.0, "horizon": 900.0, "rock_slope": 0.52, "bank_blend": 10.0,
			"ledges": [{"f0": 0.5, "f1": 1.02, "side": 1, "depth": 34.0, "start": 10.0, "end": 34.0, "noise": 6.0}],
			"lake": {"level": -20.0},
			"road_tex": "pass",
			"colors": _colors(_c("grass_gold"), _mix("khaki", "rock_grey", 0.4), _c("rock_grey"), _c("ash"), _c("rock_grey"), _c("rock_purple")),
		},
		"env": {
			"sun_color": Color(1.0, 0.97, 0.9), "sun_energy": 0.5, "sun_rot": Vector3(-41.0, 40.0, 0.0),
			"ambient": Color(0.84, 0.86, 1.0), "ambient_energy": 0.62,
			"sky_top": _c("lapis_deep"), "sky_horizon": _c("sky_pale"), "fog_color": Color("cfe2ea"), "fog_density": 0.85,
			"fog_begin": 60.0, "fog_end": 3800.0, "cloud_cover": 0.4,
		},
		"quiet": [],
		"pass": [0.5],
		"fixed": [
			{"type": "caravan", "f": 0.13, "d": 3.5, "count": 5, "speed": 3.6},
			{"type": "boulder", "f": 0.2, "d": -4.0, "size": 1.3},
			{"type": "boulder", "f": 0.215, "d": 3.0, "size": 1.1},
			{"type": "mani_wall", "f": 0.285, "d": -8.4, "len": 12.0, "yaw": 0.0},
			{"type": "mud", "f": 0.42, "d": 1.5, "w": 6.0, "len": 18.0},
			{"type": "scarf", "f": 0.56, "d": 0.0, "color": 3, "group": 91},
			{"type": "scarf", "f": 0.5675, "d": 3.0, "color": 3, "group": 91},
			{"type": "scarf", "f": 0.575, "d": -3.0, "color": 3, "group": 91},
			{"type": "yak_herd", "f": 0.7, "d": 0.0, "count": 6, "dir": 1, "speed": 2.5},
			{"type": "log", "f": 0.82, "d": 1.0, "len": 5.5, "yaw": 20.0},
			{"type": "ramp", "f": 0.9, "d": -2.0, "w": 4.5, "len": 9.0, "rise": 1.4},
		],
		"fill": {"boulder": 3, "mud": 2, "log": 1, "scarf": 1, "sheep": 1, "bullseye": 3, "wolf_flock": 2},
		"set_pieces": [
			{"prop": "cairn", "f": 0.5, "d": -16.0, "face": "road", "scale": 2.4},
			{"prop": "flagpole", "f": 0.495, "d": -22.0, "face": "road", "scale": 1.5},
			{"prop": "flagpole", "f": 0.505, "d": -24.0, "face": "road", "scale": 1.3},
			{"prop": "flagpole", "f": 0.5, "d": 24.0, "face": "road", "scale": 1.4},
			{"prop": "chorten", "f": 0.51, "d": 26.0, "face": "road", "scale": 1.0},
			{"prop": "tent_black", "f": 0.1, "d": -50.0, "face": "road", "scale": 1.0},
			{"prop": "yak", "f": 0.104, "d": -40.0, "face": "road", "scale": 1.0},
			{"prop": "mule", "f": 0.615, "d": -28.0, "face": "road", "scale": 1.0},
			{"prop": "chorten", "f": 0.92, "d": -24.0, "face": "road", "scale": 1.0},
		],
		"dress": {
			"layers": [
				_layer("rock_a", 5.0, 2.0, 120.0, {"bias": 1.4, "scale": [0.8, 2.0], "slope": 0.9, "cull": 800, "shadow": true}),
				_layer("rock_b", 5.0, 2.0, 120.0, {"bias": 1.4, "scale": [0.8, 2.0], "slope": 0.9, "cull": 800, "shadow": true}),
				_layer("rock_c", 5.0, 2.0, 120.0, {"bias": 1.4, "scale": [0.8, 2.0], "slope": 0.9, "cull": 800, "shadow": true}),
				_layer("boulder", 1.5, 5.0, 100.0, {"bias": 1.4, "scale": [1.0, 2.6], "slope": 0.95, "cull": 900, "shadow": true}),
				_layer("grass_tuft", 26.0, 0.3, 40.0, {"ink_class": 0.85, "bias": 1.8, "scale": [0.6, 1.1], "slope": 0.6, "cull": 280, "shadow": false}),
				_layer("flowers", 16.0, 0.4, 30.0, {"ink_class": 0.85, "bias": 1.6, "scale": [0.8, 1.2], "slope": 0.6, "cull": 140, "shadow": false}),
				_layer("juniper", 1.2, 4.0, 40.0, {"bias": 1.5, "scale": [0.6, 1.0], "slope": 0.5, "cull": 450, "shadow": true}),
				_layer("flag_string", 0.5, 0.5, 18.0, {"align": true, "scale": [1.0, 1.4], "slope": 0.5, "cull": 700, "nodes": true}),
				_layer("flag_string", 5.0, 0.5, 18.0, {"align": true, "scale": [1.0, 1.4], "slope": 0.5, "cull": 700, "nodes": true, "f0": 0.44, "f1": 0.56}),
				_layer("cairn", 0.3, 3.0, 28.0, {"scale": [0.9, 1.5], "slope": 0.5, "cull": 600, "nodes": true}),
				_layer("marmot", 0.4, 5.0, 50.0, {"scale": [1.0, 1.2], "slope": 0.5, "cull": 250, "nodes": true}),
				_layer("yak", 0.25, 25.0, 140.0, {"scale": [1.0, 1.15], "slope": 0.45, "cull": 500, "herd": 3, "nodes": true}),
			],
		},
	}


# 4. Gallop Behind the Fort: Gyantse. Barley fields, stone villages, the dzong on its rock, Kumbum, tent city.
static func _gyantse() -> Dictionary:
	return {
		"name": "Gallop Behind the Fort", "region": "Gyantse",
		"blurb": "Behind the fort the barley is cut and the whole valley has come to watch. Mind the poles and the monastery.",
		"half_width": 5.5,
		"segments": [
			[130, 0, 0], [100, 75, 1], [100, -90, 1], [90, 80, 0], [90, -70, 0], [100, 60, 1], [100, -75, 0], [60, 20, 0],
			[120, 0, 0, 4.5], [90, -85, 1, 4.5], [100, 100, 0, 4.5], [100, -85, 0, 4.5],   # narrow through the quiet ground
			[60, 40, 0], [100, 80, 0], [100, -95, 1], [90, 85, 0], [100, -100, 1], [90, 70, 0], [80, -50, 0], [200, 0, 0],
		],
		"biome": {
			"rugged": 2.5, "mountain": 230.0, "mountain_start": 380.0, "mountain_end": 1300.0,
			"snow_line": 330.0, "far_snow_line": 330.0, "horizon": 640.0, "rock_slope": 0.55, "bank_blend": 14.0,
			"road_tex": "gyantse", "fields": true,
			"colors": _colors(_c("barley"), _c("grass_green"), _c("grass_gold"), _c("khaki"), _c("rock_grey"), _c("rock_red")),
		},
		"env": {
			"sun_color": Color(1.0, 0.9, 0.74), "sun_energy": 0.5, "sun_rot": Vector3(-41.0, -62.0, 0.0),
			"ambient": Color(0.84, 0.86, 1.0), "ambient_energy": 0.62,
			"sky_top": _c("lapis"), "sky_horizon": _c("sky_pale"), "fog_color": Color("d3e0e2"), "fog_density": 0.88,
			"fog_begin": 70.0, "fog_end": 3400.0, "cloud_cover": 0.5,
		},
		"quiet": [[0.46, 0.62]],
		"pass": [],
		"fixed": [
			{"type": "target_pole", "f": 0.22, "d": 11.5},
			{"type": "target_pole", "f": 0.26, "d": -11.5},
			{"type": "target_pole", "f": 0.30, "d": 11.5},
			{"type": "chorten", "f": 0.50, "d": -7.4},
			{"type": "mani_wall", "f": 0.545, "d": 7.4, "len": 12.0, "yaw": 0.0},
			{"type": "target_pole", "f": 0.72, "d": -11.5},
			{"type": "target_pole", "f": 0.76, "d": 11.5},
			{"type": "target_pole", "f": 0.80, "d": -11.5},
			{"type": "caravan", "f": 0.38, "d": 3.0, "count": 5, "speed": 4.0},
		],
		"fill": {"boulder": 1, "mud": 2, "scarf": 3, "log": 1, "sheep": 1, "ramp": 1, "bullseye": 4, "wolf_flock": 1},
		"set_pieces": [
			{"prop": "dzong", "f": 0.40, "d": -230.0, "face": "road", "scale": 1.0, "sink": 8.0, "far": true},
			{"prop": "kumbum", "f": 0.54, "d": 70.0, "face": "road", "scale": 0.8, "sink": 1.0},
			{"prop": "monastery", "f": 0.57, "d": 150.0, "face": "road", "scale": 1.0, "sink": 6.0, "far": true},
			{"prop": "house_tsang", "f": 0.08, "d": -44.0, "face": "road", "scale": 1.0},
			{"prop": "house_tsang", "f": 0.098, "d": -56.0, "face": "road", "scale": 1.1},
			{"prop": "house_tsang", "f": 0.115, "d": -42.0, "face": "road", "scale": 0.95},
			{"prop": "drying_rack", "f": 0.1, "d": -34.0, "face": "road", "scale": 1.0},
			{"prop": "house_tsang", "f": 0.84, "d": 46.0, "face": "road", "scale": 1.0},
			{"prop": "house_tsang", "f": 0.858, "d": 60.0, "face": "road", "scale": 1.1},
			{"prop": "festival_tent", "f": 0.15, "d": 28.0, "face": "road", "scale": 1.0},
			{"prop": "festival_tent", "f": 0.165, "d": 30.0, "face": "road", "scale": 1.0},
			{"prop": "food_booth", "f": 0.158, "d": 22.0, "face": "road", "scale": 1.0},
			{"prop": "festival_tent", "f": 0.9, "d": -30.0, "face": "road", "scale": 1.0},
			{"prop": "festival_tent", "f": 0.915, "d": -32.0, "face": "road", "scale": 1.0},
			{"prop": "food_booth", "f": 0.907, "d": -23.0, "face": "road", "scale": 1.0},
			{"prop": "banner", "f": 0.19, "d": -14.0, "face": "road", "scale": 1.0},
			{"prop": "banner", "f": 0.88, "d": 14.0, "face": "road", "scale": 1.0},
		],
		"dress": {
			"layers": [
				_layer("barley_patch", 12.0, 3.0, 90.0, {"ink_class": 0.85, "bias": 1.1, "scale": [1.0, 1.6], "slope": 0.25, "cull": 520, "shadow": false}),
				_layer("grass_tuft", 30.0, 0.3, 40.0, {"ink_class": 0.85, "bias": 2.0, "scale": [0.6, 1.1], "slope": 0.6, "cull": 260, "shadow": false}),
				_layer("grass_tall", 12.0, 0.6, 40.0, {"ink_class": 0.85, "bias": 1.8, "scale": [0.8, 1.3], "slope": 0.6, "cull": 220, "shadow": false}),
				_layer("flowers", 28.0, 0.4, 36.0, {"ink_class": 0.85, "bias": 1.6, "scale": [0.9, 1.3], "slope": 0.6, "cull": 140, "shadow": false}),
				_layer("willow", 3.0, 4.0, 90.0, {"bias": 1.4, "scale": [0.9, 1.4], "slope": 0.4, "cull": 1000, "shadow": true}),
				_layer("rock_a", 1.5, 3.0, 100.0, {"bias": 1.3, "scale": [0.7, 1.4], "slope": 0.7, "cull": 600, "shadow": true}),
				_layer("rock_b", 1.5, 3.0, 100.0, {"bias": 1.3, "scale": [0.7, 1.4], "slope": 0.7, "cull": 600, "shadow": true}),
				_layer("bush", 4.0, 2.0, 60.0, {"bias": 1.4, "scale": [0.7, 1.3], "slope": 0.5, "cull": 360}),
				_layer("house_tsang", 0.5, 24.0, 130.0, {"face_road": true, "scale": [0.9, 1.2], "slope": 0.2, "cull": 1100, "nodes": true}),
				_layer("drying_rack", 0.3, 10.0, 50.0, {"align": true, "scale": [1.0, 1.0], "slope": 0.2, "cull": 500, "nodes": true}),
				_layer("wall_stone", 2.4, 4.0, 40.0, {"align": true, "scale": [1.0, 1.0], "slope": 0.25, "cull": 600, "nodes": true}),
				_layer("flag_string", 0.5, 0.5, 14.0, {"align": true, "scale": [1.0, 1.3], "slope": 0.5, "cull": 500, "nodes": true}),
				_layer("chorten", 0.2, 3.0, 28.0, {"align": true, "scale": [0.9, 1.3], "slope": 0.3, "cull": 800, "nodes": true}),
				_layer("mani_wall", 0.2, 2.0, 24.0, {"align": true, "scale": [1.0, 1.3], "slope": 0.3, "cull": 600, "nodes": true}),
				_layer("crowd_a", 0.5, 1.0, 6.0, {"align": true, "scale": [1.0, 1.0], "slope": 0.3, "cull": 300, "nodes": true, "f0": 0.1, "f1": 0.35}),
				_layer("crowd_b", 0.5, 1.0, 6.0, {"align": true, "scale": [1.0, 1.0], "slope": 0.3, "cull": 300, "nodes": true, "f0": 0.65, "f1": 0.92}),
			],
		},
	}


# 5. The Western Gate: Lhasa. Willow groves, white walls, Potala and Chakpori, the gate chorten over the road.
static func _western_gate() -> Dictionary:
	return {
		"name": "The Western Gate", "region": "Lhasa",
		"blurb": "Willows, whitewash and the whole city out on the road. Through the gate it goes quiet. After, it does not.",
		"half_width": 6.5,
		"segments": [
			[140, 0, 0], [100, 70, 1], [100, -85, 1], [90, 75, 0], [100, -80, 0], [90, 60, 1], [80, -40, 0],
			[200, 0, 0, 5.0], [80, -60, 0, 5.0], [80, 60, 0, 5.0], [180, 0, 0, 5.0],   # the straight through the gate
			[90, -70, 0], [100, 85, 1], [90, -85, 0], [100, 90, 1], [90, -80, 0], [80, 60, 0], [240, 0, 0],
		],
		"biome": {
			"rugged": 2.5, "mountain": 220.0, "mountain_start": 420.0, "mountain_end": 1500.0,
			"snow_line": 340.0, "far_snow_line": 330.0, "horizon": 620.0, "rock_slope": 0.55, "bank_blend": 16.0,
			"road_tex": "lhasa", "fields": true,
			"colors": _colors(_c("grass_green"), _mix("grass_green", "grass_deep", 0.5), _mix("grass_green", "grass_gold", 0.5), _c("khaki"), _c("rock_grey"), _c("rock_dark")),
		},
		"env": {
			"sun_color": Color(1.0, 0.94, 0.82), "sun_energy": 0.5, "sun_rot": Vector3(-44.0, -20.0, 0.0),
			"ambient": Color(0.84, 0.86, 1.0), "ambient_energy": 0.62,
			"sky_top": _c("lapis"), "sky_horizon": _c("sky_pale"), "fog_color": Color("d2e2e6"), "fog_density": 0.88,
			"fog_begin": 80.0, "fog_end": 3600.0, "cloud_cover": 0.42,
		},
		"quiet": [[0.5, 0.64]],
		"pass": [],
		"fixed": [
			{"type": "target_pole", "f": 0.18, "d": 14.5},
			{"type": "target_pole", "f": 0.22, "d": -14.5},
			{"type": "target_pole", "f": 0.26, "d": 14.5},
			{"type": "caravan", "f": 0.34, "d": 4.0, "count": 5, "speed": 4.0},
			{"type": "chorten", "f": 0.425, "d": -9.5},
			{"type": "chorten", "f": 0.425, "d": 9.5},
			{"type": "mani_wall", "f": 0.69, "d": -10.2, "len": 12.0, "yaw": 0.0},
			{"type": "target_pole", "f": 0.76, "d": -14.5},
			{"type": "target_pole", "f": 0.80, "d": 14.5},
			{"type": "sheep", "f": 0.87, "d": -5.0, "count": 8, "dir": -1, "speed": 2.0},
		],
		"fill": {"boulder": 1, "mud": 1, "scarf": 3, "log": 1, "ramp": 1, "bullseye": 4, "wolf_flock": 1},
		"set_pieces": [
			{"prop": "gate_chorten", "f": 0.57, "d": 0.0, "face": "track", "scale": 1.0, "sink": 0.0},
			{"prop": "potala", "from_end": 330.0, "d": 0.0, "face": "back", "scale": 1.5, "sink": 12.0, "far": true},
			{"prop": "chakpori_hill", "from_end": 250.0, "d": -330.0, "face": "back", "scale": 1.3, "sink": 10.0, "far": true},
			{"prop": "house_white", "f": 0.06, "d": -42.0, "face": "road", "scale": 1.0},
			{"prop": "house_white", "f": 0.075, "d": -58.0, "face": "road", "scale": 1.1},
			{"prop": "house_white", "f": 0.085, "d": 46.0, "face": "road", "scale": 1.0},
			{"prop": "house_white", "f": 0.31, "d": 52.0, "face": "road", "scale": 1.05},
			{"prop": "house_white", "f": 0.325, "d": 44.0, "face": "road", "scale": 0.95},
			{"prop": "house_white", "f": 0.47, "d": -40.0, "face": "road", "scale": 1.05},
			{"prop": "house_white", "f": 0.52, "d": 40.0, "face": "road", "scale": 1.0},
			{"prop": "house_white", "f": 0.58, "d": -44.0, "face": "road", "scale": 1.1},
			{"prop": "house_white", "f": 0.63, "d": 46.0, "face": "road", "scale": 1.0},
			{"prop": "monastery", "f": 0.72, "d": -190.0, "face": "road", "scale": 0.8, "sink": 6.0, "far": true},
			{"prop": "festival_tent", "f": 0.9, "d": 36.0, "face": "road", "scale": 1.0},
			{"prop": "festival_tent", "f": 0.915, "d": 38.0, "face": "road", "scale": 1.0},
			{"prop": "festival_tent", "f": 0.93, "d": -36.0, "face": "road", "scale": 1.0},
			{"prop": "food_booth", "f": 0.905, "d": 28.0, "face": "road", "scale": 1.0},
			{"prop": "food_booth", "f": 0.925, "d": -27.0, "face": "road", "scale": 1.0},
			{"prop": "banner", "f": 0.88, "d": -17.0, "face": "road", "scale": 1.0},
			{"prop": "banner", "f": 0.96, "d": 17.0, "face": "road", "scale": 1.0},
			{"prop": "flagpole", "f": 0.1, "d": 24.0, "face": "road", "scale": 1.1},
		],
		"dress": {
			"layers": [
				_layer("willow", 7.0, 3.0, 80.0, {"bias": 1.3, "scale": [0.9, 1.5], "slope": 0.4, "cull": 1000, "shadow": true}),
				_layer("grass_tuft", 30.0, 0.3, 40.0, {"ink_class": 0.85, "bias": 2.0, "scale": [0.6, 1.1], "slope": 0.6, "cull": 260, "shadow": false}),
				_layer("grass_tall", 12.0, 0.6, 40.0, {"ink_class": 0.85, "bias": 1.8, "scale": [0.8, 1.3], "slope": 0.6, "cull": 220, "shadow": false}),
				_layer("flowers", 28.0, 0.4, 36.0, {"ink_class": 0.85, "bias": 1.6, "scale": [0.9, 1.3], "slope": 0.6, "cull": 140, "shadow": false}),
				_layer("bush", 5.0, 2.0, 60.0, {"bias": 1.4, "scale": [0.7, 1.3], "slope": 0.5, "cull": 360}),
				_layer("barley_patch", 4.0, 6.0, 90.0, {"ink_class": 0.85, "bias": 1.2, "scale": [1.0, 1.5], "slope": 0.25, "cull": 520, "shadow": false}),
				_layer("rock_a", 1.0, 3.0, 100.0, {"bias": 1.3, "scale": [0.7, 1.4], "slope": 0.7, "cull": 600, "shadow": true}),
				_layer("rock_b", 1.0, 3.0, 100.0, {"bias": 1.3, "scale": [0.7, 1.4], "slope": 0.7, "cull": 600, "shadow": true}),
				_layer("house_white", 0.8, 18.0, 90.0, {"face_road": true, "scale": [0.9, 1.2], "slope": 0.2, "cull": 1100, "nodes": true}),
				_layer("wall_white", 1.6, 5.0, 24.0, {"align": true, "scale": [1.0, 1.0], "slope": 0.25, "cull": 700, "nodes": true}),
				_layer("flag_string", 0.6, 0.5, 14.0, {"align": true, "scale": [1.0, 1.3], "slope": 0.5, "cull": 500, "nodes": true}),
				_layer("chorten", 0.2, 3.0, 28.0, {"align": true, "scale": [0.9, 1.3], "slope": 0.3, "cull": 800, "nodes": true}),
				_layer("crowd_a", 0.7, 1.0, 5.0, {"align": true, "scale": [1.0, 1.0], "slope": 0.3, "cull": 300, "nodes": true, "f0": 0.12, "f1": 0.4}),
				_layer("crowd_b", 0.7, 1.0, 5.0, {"align": true, "scale": [1.0, 1.0], "slope": 0.3, "cull": 300, "nodes": true, "f0": 0.66, "f1": 0.97}),
				_layer("crowd_c", 0.7, 1.0, 5.0, {"align": true, "scale": [1.0, 1.0], "slope": 0.3, "cull": 300, "nodes": true, "f0": 0.66, "f1": 0.97}),
			],
		},
	}
