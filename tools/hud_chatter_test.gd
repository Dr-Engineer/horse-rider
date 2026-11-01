# Puts the real HUD on a fake race and feeds it chatter and readouts: English and Tibetan subtitles, a long line, a speaker
# with no rider, and a pile of readouts that must not pile up.
# Usage: Godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/hud_chatter_test.gd -- <out_dir>
extends SceneTree

const RIDER_SRC := """extends RefCounted
var display_name := "RIDER"
var rival_id := ""
var is_player := false
var s := 100.0
var d := 0.0
var speed := 18.0
var top_speed := 22.0
var health := 100.0
var max_health := 100.0
var shake := 0.0
var stamina := 80.0
var max_stamina := 100.0
var lungta := 2.0
var state := "ride"
var rest_left := 0.0
var weapon_id := "sword"
var ranged_id := "bow"
var ammo := 9
var has_shield := true
var blocking := false
var drawing := false
var draw_amount := 0.0
var place := 3
var portrait := ""
"""
const TRACK_SRC := """extends RefCounted
var length := 2400.0
"""
const RACE_SRC := """extends Node3D
signal announcement(text: String, kind: String)
signal race_started
signal race_finished(results: Array)
signal rider_hit(attacker, victim, info: Dictionary)
signal rider_crashed(rider, reason: String)
signal chatter(rider, line: Dictionary)
var player
var riders: Array = []
var track
var course := {"events": []}
var countdown := 0.0
var paused_for_ui := false
func standings() -> Array:
	return riders
"""

var out_dir := "/tmp/hud_chatter"
var hud: Node
var race: Node
var me: RefCounted
var rivals: Dictionary = {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _wait(sec: float) -> void:
	await create_timer(sec).timeout
	await process_frame


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, n])
	print("shot ", n)


func _make(src: String) -> GDScript:
	var g := GDScript.new()
	g.source_code = src
	g.reload()
	return g


func _rider(src: GDScript, nm: String, id: String, s: float, d: float) -> RefCounted:
	var r: RefCounted = src.new()
	r.set("display_name", nm)
	r.set("rival_id", id)
	r.set("s", s)
	r.set("d", d)
	r.set("portrait", "res://assets/ui/portraits/%s.png" % id)
	rivals[id] = r
	return r


func _say(id: String, speaker: String, t: String, g: String, lang: String, secs: float) -> void:
	var who: Variant = rivals.get(id)
	race.emit_signal("chatter", who, {"f": "x", "t": t, "g": g, "l": lang, "d": secs, "speaker": speaker})


func _run() -> void:
	await _wait(0.3)
	var bg := ColorRect.new()
	bg.color = Color("8fb8d8")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var ground := ColorRect.new()
	ground.color = Color("d8be8e")
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.anchor_top = 0.55
	root.add_child(ground)
	var rider_src := _make(RIDER_SRC)
	race = _make(RACE_SRC).new()
	root.add_child(race)
	race.set("track", _make(TRACK_SRC).new())
	me = _rider(rider_src, "JORU", "joru", 200.0, 0.0)
	me.set("is_player", true)
	var wangyal := _rider(rider_src, "PON WANGYAL DORJE", "wangyal", 214.0, 1.5)
	var genden := _rider(rider_src, "GENDEN GYAL", "genden", 195.0, -1.8)
	var serkhar := _rider(rider_src, "SERKHAR TASHI GYALTSEN", "serkhar", 420.0, 0.0)
	race.set("player", me)
	race.set("riders", [me, wangyal, genden, serkhar, _rider(rider_src, "KARMA TOBGYE", "karma", 100.0, 2.0)])
	var game := root.get_node("Game")
	game.set("wager", 25)
	game.set("wager_rival", "wangyal")
	hud = load("res://scripts/ui/hud.gd").new()
	root.add_child(hud)
	hud.call("bind", race)
	await _wait(0.5)

	# 1. a short English line with the rival plate showing
	_say("karma", "karma", "EYES UP, BOY.", "", "en", 1.0)
	await _wait(0.5)
	await _shot("c1_english_short")
	await _wait(2.2)

	# 2. Tibetan with its gloss
	_say("wangyal", "wangyal", "NGA NAMYANG PHAM NYONG ME!", "I HAVE NEVER LOST!", "bo", 1.53)
	await _wait(0.5)
	await _shot("c2_tibetan_gloss")
	await _wait(3.0)

	# 3. long English
	_say("genden", "genden", "DON'T MOVE! ACTUALLY, DO. YOU'RE BLOCKING THE ROAD.", "", "en", 3.1)
	await _wait(0.5)
	await _shot("c3_english_long")
	await _wait(4.6)

	# 4. no rider: the starter, then a steward
	_say("", "starter", "TAPA-TSO, DRADRIK GYI!", "RIDERS, GET READY!", "bo", 1.6)
	await _wait(0.5)
	await _shot("c4_starter_no_portrait")
	await _wait(3.0)
	_say("", "steward", "NO LYING ABOUT ON THE ROAD!", "", "en", 1.8)
	await _wait(0.5)
	await _shot("c4b_steward")
	await _wait(3.5)

	# 5. a very long line, and two lines at once (the second waits)
	_say("serkhar", "serkhar", "WHEN THE CROWD SHOUTS YOUR NAME, LOOK WHO IS BEHIND YOU, AND IF YOU MUST FALL OFF, FALL FORWARD, IT IS CLOSER TO THE FINISH LINE", "", "en", 4.0)
	await _wait(0.5)
	await _shot("c5_very_long")
	_say("genden", "genden", "SAB SAB GYI!", "BE CAREFUL!", "bo", 0.8)
	await _wait(0.4)
	await _shot("c5b_second_waits")
	await _wait(1.2)
	await _shot("c5c_second_shown")
	await _wait(3.0)

	# 6. the player's own, with no rival near
	wangyal.set("s", 900.0)
	genden.set("s", 800.0)
	await _wait(0.8)
	_say("joru", "joru", "TELL THE AUNT THE INTEREST IS PAID.", "", "en", 2.0)
	await _wait(0.5)
	await _shot("c6_player_no_plate")
	await _wait(3.5)

	# 7. readouts: a heap of info lines, and a streak that grows, must stay tidy
	wangyal.set("s", 214.0)
	genden.set("s", 195.0)
	for t in ["SCARF!  +8", "NEAR MISS!", "HAT KNOCKED OFF", "STREAK X2", "KNOCKDOWN  +15", "OVERTAKE"]:
		race.emit_signal("announcement", t, "info")
	for i in 4:
		race.emit_signal("announcement", "STREAK X%d" % (i + 3), "good")
	race.emit_signal("announcement", "NEAR MISS!  X3", "good")
	race.emit_signal("announcement", "A VERY LONG READOUT THAT WOULD NOT FIT AT SIZE FOUR", "bad")
	await _wait(0.2)
	await _shot("c7_readouts")
	await _wait(2.6)

	# 8. the rival you have a bet with: a coin on their plate, and a red bead on the progress thread
	genden.set("s", 700.0)
	wangyal.set("s", 206.0)
	await _wait(0.8)
	_say("wangyal", "wangyal", "KARE CHE-GYI YO?", "WHAT ARE YOU DOING?", "bo", 1.26)
	await _wait(0.5)
	await _shot("c8_bet_rival_plate")
	quit()
