class_name Chatter
extends Node
## The voices of the race. Watches the race and the riders, decides who says what, and hands each line to Sfx.say.
## Pacing matters more than volume: one voice at a time, 3 to 4 s from one line to the next, about 12 s before the same
## rival speaks again, and only riders within 40 m. A rival with a grudge, and the featured rival, talk more. Bigger
## moments jump the queue. Quiet Ground silences everyone but the steward. Own random numbers, nothing touches Race.rng.

const NEAR_RANGE := 40.0
const GAP := Vector2(3.0, 4.0)        # seconds from the start of one line to the start of the next
const RIVAL_GAP := 12.0
const TALKATIVE_GAP := 6.5
const PLAYER_CAT_GAP := 14.0          # the player does not repeat a kind of cry inside this
const HOLD_TTL := 2.0                 # a line that has to wait for the voice to be free is dropped after this
const ALONGSIDE_TIME := 2.2
const JUMP_AFTER := 1.2               # a bigger moment may start this long after the last line began
const STARTER := ["ready", "three", "two", "one", "go"]
## category: [priority, chance that an event tries to speak]. Rivals who do not talk much are asked less often.
const CATS := {
	"hat": [5, 1.0], "p_win": [5, 1.0], "p_lose": [5, 1.0],
	"down": [4, 0.85], "win": [4, 1.0],
	"hit_you": [3, 0.7], "hurt": [3, 0.6], "gloat": [3, 0.8], "p_down": [3, 0.9], "p_knock": [3, 0.7],
	"pass_by": [2, 0.6], "passed": [2, 0.65], "p_wind": [2, 0.9], "p_cry": [2, 0.9],
	"cry": [1, 0.7], "scarf": [1, 0.55], "near": [1, 0.9], "start": [1, 0.8],
	"p_hurt": [1, 0.35], "p_remount": [1, 0.4], "p_scarf": [1, 0.5],
}

var race: Race
var rng := RandomNumberGenerator.new()
var debug := false                    # tests: print every line, and fall back to the voice bank when Sfx has no say()
var trace := false                    # tests: also print every request that was turned down, and why
var said: Dictionary = {}             # category -> lines spoken, for the tests
var spoken: Array[Dictionary] = []     # every line spoken: {at, speaker, cat, prio, dur, gap (to the player, m), rival}
var lines_total := 0

var _busy_until := 0.0
var _gap_until := 0.0
var _last_start := -99.0
var _last_prio := 0
var _spoke: Dictionary = {}           # speaker id -> clock of their last line
var _said_at: Dictionary = {}         # category -> clock of the last line in it
var _hold: Dictionary = {}
var _ahead: Dictionary = {}           # Rider -> 1 when it is ahead of the player, -1 behind
var _side_t: Dictionary = {}          # Rider -> seconds alongside (negative while cooling down)
var _talkative: Dictionary = {}       # rival id -> true for grudges and the featured rival
var _wins := 0
var _call_lang := ""
var _later_calls: Array[Dictionary] = []
var _vb_lines: Variant = null


func bind(p_race: Race) -> void:
	race = p_race
	rng.randomize()
	var featured := String(race.config.get("featured_rival", ""))
	for r in race.riders:
		if r.is_player:
			continue
		var g: Variant = race.grudges.get(r.rival_id, false)
		var grudge := bool(g) if typeof(g) == TYPE_BOOL else int(g) > 0
		if grudge or r.rival_id == featured:
			_talkative[r.rival_id] = true
	race.rider_hit.connect(_on_hit)
	race.rider_crashed.connect(_on_crashed)
	race.rider_remounted.connect(_on_remounted)
	race.rider_event.connect(_on_event)
	race.race_started.connect(_on_started)
	race.announcement.connect(_on_announcement)


## Seconds on the clock the pacing runs by: the real one (the voices play in real time, even in slow motion), or the
## race's own clock when a test runs the race headless and faster than real time.
func _now() -> float:
	return race.race_time if race.headless else Time.get_ticks_msec() * 0.001


func _process(dt: float) -> void:
	if race == null or race.player == null:
		return
	var now := _now()
	var i := _later_calls.size() - 1
	while i >= 0:
		if now >= float(_later_calls[i]["at"]):
			var fn: Callable = _later_calls[i]["fn"]
			_later_calls.remove_at(i)
			fn.call()
		i -= 1
	if not _hold.is_empty():
		if now > float(_hold["until"]):
			_hold = {}
		elif _can_speak(int(_hold["prio"])):
			var req := _hold
			_hold = {}
			# by the time the voice is free, a rider who was waiting to speak may have dropped out of earshot
			var who: Variant = req.get("rider")
			if who == null or String(req["cat"]) == "win" or _near(who as Rider):
				_speak(req)
	if race.started and not race.ended:
		_watch_riders(dt)


func _later(secs: float, fn: Callable) -> void:
	_later_calls.append({"at": _now() + secs, "fn": fn})


# --- who is near and who is talkative -------------------------------------------------------------------------------

func _near(r: Rider) -> bool:
	return r == race.player or absf(r.s - race.player.s) <= NEAR_RANGE


func _both_riding(a: Rider, b: Rider) -> bool:
	return a.is_riding() and b.is_riding() and a.invuln_t <= 0.0 and b.invuln_t <= 0.0


func _nearest_rival(to: Rider, within: float) -> Rider:
	var best: Rider = null
	var best_d := within
	for r in race.riders:
		if r == to or r.is_player or not r.is_riding():
			continue
		var d := Vector2(r.s - to.s, (r.d - to.d) * 1.5).length()
		if d < best_d:
			best_d = d
			best = r
	return best


func _quiet_now() -> bool:
	var p := race.player
	return p.in_quiet or race.hazards.in_quiet(p.s) or race.hazards.quiet_ahead(p.s, 10.0)


## A voice that follows its rider as they gallop (Sfx.say takes a Callable that returns the position).
func _pos(r: Rider) -> Callable:
	return Callable(race, "visual_pos").bind(r)


# --- asking to speak ---------------------------------------------------------------------------------------------------

## An event wants a rival's (or the player's) voice. The pacing rules decide whether it gets one.
func _ask(cat: String, rider: Rider, opts: Dictionary = {}) -> bool:
	if race == null or not CATS.has(cat):
		return false
	var info: Array = CATS[cat]
	var prio: int = info[0]
	var chance: float = info[1]
	var is_player := rider.is_player
	var speaker := rider.rival_id
	if race.ended and prio < 5:
		return _no(cat, speaker, "the race is over")
	if _quiet_now() or (not is_player and race.hazards.in_quiet(rider.s)):
		return _no(cat, speaker, "Quiet Ground")
	if rider.finished and cat != "win" and not is_player:
		return _no(cat, speaker, "already finished")
	if is_player:
		# the player's own cries come round slowly, so "Got it!" is not said for every scarf
		if _now() - float(_said_at.get(cat, -99.0)) < PLAYER_CAT_GAP and prio < 5:
			return _no(cat, speaker, "said that lately")
	else:
		var talk: bool = _talkative.get(speaker, false)
		var since := _now() - float(_spoke.get(speaker, -99.0))
		if since < (TALKATIVE_GAP if talk else RIVAL_GAP) and prio < 5:
			return _no(cat, speaker, "spoke %.1f s ago" % since)
		chance *= 1.4 if talk else 0.85
	if rng.randf() > minf(chance, 1.0):
		return _no(cat, speaker, "not this time")
	# a winner's cry is heard from the finish whoever is near it, so it is flat; every other voice follows its rider
	var req := {
		"speaker": speaker, "cat": cat, "rider": rider, "prio": prio,
		"pos": null if (is_player or cat == "win") else _pos(rider), "until": _now() + HOLD_TTL, "subtitle": true,
	}
	req.merge(opts, true)
	if _can_speak(prio):
		return _speak(req)
	if prio >= 2:
		if _hold.is_empty() or prio > int(_hold["prio"]):
			req["until"] = _now() + HOLD_TTL
			_hold = req
			return _no(cat, speaker, "waits for the voice")
		return _no(cat, speaker, "a bigger line is waiting")
	return _no(cat, speaker, "the voice is busy")


## Turned down: false, and with trace on, say why.
func _no(cat: String, speaker: String, why: String) -> bool:
	if trace:
		print("[chatter %6.1f]   no %s/%s: %s" % [race.race_time, speaker, cat, why])
	return false


func _can_speak(prio: int) -> bool:
	var now := _now()
	if now < _busy_until:
		return false
	if not race.headless and Sfx.has_method("voice_playing") and bool(Sfx.call("voice_playing")):
		return false
	if now >= _gap_until:
		return true
	return prio > _last_prio and now - _last_start >= JUMP_AFTER


## Speak now: the rules were checked, or this is the starter.
func _speak(req: Dictionary) -> bool:
	var speaker: String = req["speaker"]
	var cat: String = req["cat"]
	var vol := 0.0
	var who: Variant = req.get("rider")
	if who != null and not (who as Rider).is_player:
		vol = -1.0 - 3.0 * clampf(absf((who as Rider).s - race.player.s) / NEAR_RANGE, 0.0, 1.0)
	var line := _say(speaker, cat, req.get("pos"), vol, String(req.get("lang", "")))
	if line.is_empty():
		return false
	var now := _now()
	var dur := float(line.get("d", 0.0))
	if dur <= 0.05:
		dur = 0.7 + 0.055 * String(line.get("t", "")).length()
	_busy_until = now + dur + 0.2
	_gap_until = now + rng.randf_range(GAP.x, GAP.y)
	_last_start = now
	_last_prio = int(req["prio"])
	_spoke[speaker] = now
	_said_at[cat] = now
	said[cat] = int(said.get(cat, 0)) + 1
	lines_total += 1
	if cat == "win":
		_wins += 1
	var near_m := absf((who as Rider).s - race.player.s) if who != null else 0.0
	spoken.append({"at": now, "speaker": speaker, "cat": cat, "prio": int(req["prio"]), "dur": dur, "gap": near_m, "rival": who != null and not (who as Rider).is_player, "quiet": _quiet_now(), "subtitle": bool(req.get("subtitle", true))})
	var out := line.duplicate()
	out["speaker"] = speaker
	if debug:
		print("[chatter %6.1f] %s/%s (p%d) \"%s\"" % [race.race_time, speaker, cat, int(req["prio"]), String(line.get("t", ""))])
	if req.get("subtitle", true):
		race.chatter.emit(req.get("rider"), out)
	return true


func _say(speaker: String, cat: String, pos: Variant, vol: float, lang: String = "") -> Dictionary:
	if Sfx.has_method("say"):
		var got: Variant = Sfx.call("say", speaker, cat, pos, vol, lang)
		return got if typeof(got) == TYPE_DICTIONARY else {}
	if debug:
		return _dry_line(speaker, cat)
	return {}


## Tests only: pick a line from the voice bank without any sound, so the pacing can be watched before Sfx can speak.
func _dry_line(speaker: String, cat: String) -> Dictionary:
	if _vb_lines == null:
		var vb: GDScript = load("res://data/voice_bank.gd")
		_vb_lines = vb.get_script_constant_map().get("LINES", {}) if vb != null else {}
	var by_speaker: Variant = (_vb_lines as Dictionary).get(speaker, {})
	var arr: Variant = (by_speaker as Dictionary).get(cat, [])
	if (arr as Array).is_empty():
		return {}
	return ((arr as Array)[rng.randi() % (arr as Array).size()] as Dictionary).duplicate()


## The starter's call is never rationed: it cuts in front of anything else and has no subtitle unless it is words.
func _starter(cat: String, subtitle: bool) -> void:
	if Sfx.has_method("stop_voice"):
		Sfx.call("stop_voice")
	_busy_until = 0.0
	if cat == "ready":
		# the whole call, "ready" to "go", comes in one language, whichever the player's setting leaves open
		_call_lang = ""
		var setting: Variant = Game.get("voice_language")
		if int(setting if setting != null else 0) == 0:
			_call_lang = "en" if rng.randf() < 0.5 else "bo"
	var req := {"speaker": "starter", "cat": cat, "rider": null, "prio": 9, "pos": null, "subtitle": subtitle, "lang": _call_lang}
	_speak(req)
	_gap_until = _now() + 0.8


# --- watching the pack ---------------------------------------------------------------------------------------------------

func _watch_riders(dt: float) -> void:
	var p := race.player
	for r in race.riders:
		if r == p:
			continue
		var ds := r.s - p.s
		var dd := r.d - p.d
		var st := int(_ahead.get(r, 0))
		var now_st := st
		if ds > 2.0:
			now_st = 1
		elif ds < -2.0:
			now_st = -1
		if st != 0 and now_st != st and absf(dd) < 7.0 and _both_riding(p, r) and race.race_time > 4.0:
			_ask("pass_by" if now_st == 1 else "passed", r)
		_ahead[r] = now_st
		var t := float(_side_t.get(r, 0.0))
		if t < 0.0:
			t = minf(t + dt, 0.0)
		elif _both_riding(p, r) and absf(ds) < 6.0 and absf(dd) < 6.0:
			t += dt
			if t >= ALONGSIDE_TIME - (0.8 if _talkative.get(r.rival_id, false) else 0.0):
				t = -12.0
				_ask("near", r)
		else:
			t = maxf(t - 2.0 * dt, 0.0)
		_side_t[r] = t


# --- race signals ----------------------------------------------------------------------------------------------------------

func _on_announcement(text: String, _kind: String) -> void:
	if text == "READY":
		_later(0.15, func() -> void: _starter("ready", true))


func _on_started() -> void:
	_starter("go", false)
	# somebody wishes the field luck, a moment after the horses are away
	var who: Rider = null
	var featured := String(race.config.get("featured_rival", ""))
	for r in race.riders:
		if not r.is_player and r.rival_id == featured:
			who = r
	if who == null:
		who = _nearest_rival(race.player, 14.0)
	if who != null:
		var pick := who
		_later(1.6, func() -> void: _ask("start", pick))


func _on_hit(attacker: Rider, victim: Rider, info: Dictionary) -> void:
	if info.get("ignored", false):
		return
	var p := race.player
	if victim == p and attacker != p:
		if not info.get("parried", false):
			_ask("hit_you", attacker)
		if float(info.get("impact", 0.0)) >= 12.0 and not info.get("blocked", false):
			_ask("p_hurt", p)
	elif attacker == p and victim != p and not info.get("blocked", false) and _near(victim):
		_ask("hurt", victim)


func _on_crashed(r: Rider, reason: String) -> void:
	var p := race.player
	if r == p:
		var gloater := _nearest_rival(p, 25.0)
		if gloater != null and rng.randf() < 0.65:
			_later(0.9, func() -> void: _ask("gloat", gloater))
		else:
			_ask("p_down", p)
		return
	if not _near(r):
		return
	if r.last_hitter == p and r.last_hit_age < 4.0 and reason != "hazard" and rng.randf() < 0.4:
		_later(0.5, func() -> void: _ask("p_knock", p))
	else:
		_later(0.2, func() -> void: _ask("down", r))


func _on_remounted(r: Rider) -> void:
	if r == race.player:
		_ask("p_remount", r)


func _on_event(kind: String, r: Rider, info: Dictionary) -> void:
	var p := race.player
	match kind:
		"count":
			var n := int(info.get("n", 0))
			if n >= 1 and n <= 3:
				_starter(STARTER[4 - n], false)
		"quiet_enter":
			if r == p:
				_steward("quiet", null)
		"h_fined":
			if r != null and _near(r):
				_steward("fine", r)
		"second_wind":
			if r == p:
				_ask("p_wind", p)
		"pass_cry":
			if r == p:
				Sfx.play("cheer_kiki", -7.0)
				_ask("p_cry", p)
			elif _near(r):
				_ask("cry", r)
		"h_scarf":
			if r == p:
				_ask("p_scarf", p)
			elif _near(r):
				_ask("scarf", r)
		"hat":
			if r != p:
				_ask("hat", r)
		"finish":
			_on_finish(r)


func _on_finish(r: Rider) -> void:
	var p := race.player
	if r == p:
		_cheer_finish(r.place)
		Sfx.play_at("snort", race.track.point(r.s, r.d, 1.2), -2.0, rng.randf_range(0.92, 1.05))
		_later(0.6, func() -> void: _ask("p_win" if p.place <= 3 else "p_lose", p, {"until": _now() + 4.0}))
	elif not p.finished and r.place <= 2 and _wins < 2:
		_ask("win", r)


## The crowd on the line. A winner gets the whole hillside, 4th and below a polite ripple.
func _cheer_finish(place: int) -> void:
	var db := -6.0 if place <= 3 else -12.0
	Sfx.play("cheer_lha", db)
	_later(0.5, func() -> void: Sfx.play("cheer_shuk", db - 1.0))
	if place == 1:
		_later(1.1, func() -> void: Sfx.play("cheer_kiki", db))
		_later(1.8, func() -> void: Sfx.play("cheer_ala", db - 2.0))
	elif place <= 3:
		_later(1.2, func() -> void: Sfx.play("cheer_ala", db - 1.0))


## The steward's calls (the only voice that speaks on Quiet Ground). who is the rider being fined, or null.
func _steward(cat: String, who: Rider) -> void:
	var at: Variant = null
	var best := 60.0
	for st in race.hazards.stewards:
		var d := absf(float(st["s"]) - race.player.s)
		if d < best:
			best = d
			at = race.track.point(float(st["s"]), float(st["d"]), 1.7)
	if at == null and who != null:
		at = _pos(who)
	var req := {"speaker": "steward", "cat": cat, "rider": null, "prio": 6, "pos": at, "subtitle": true}
	if _can_speak(6):
		_speak(req)
	else:
		req["until"] = _now() + HOLD_TTL
		_hold = req
