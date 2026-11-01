# Puts the real HUD on a fake race so every state can be seen without playing: rest overlay, teetering, second wind,
# quiet ground, comic words, edge chevrons, the rival plate.
# Usage: Godot --path . --resolution 1600x900 -s res://tools/hud_test.gd -- <out_dir>
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
var lungta := 0.0
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
var player
var riders: Array = []
var track
var course := {"events": [{"type": "quiet_zone", "s0": 180.0, "s1": 320.0}]}
var countdown := 0.0
var paused_for_ui := false
func standings() -> Array:
	return riders
"""

var out_dir := "/tmp/hud_shots"
var hud: Node
var race: Node
var me: RefCounted


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


func _rider(src: GDScript, nm: String, id: String, s: float, d: float) -> RefCounted:
	var r: RefCounted = src.new()
	r.set("display_name", nm)
	r.set("rival_id", id)
	r.set("s", s)
	r.set("d", d)
	r.set("portrait", "res://assets/ui/portraits/%s.png" % id)
	return r


func _make(src: String) -> GDScript:
	var g := GDScript.new()
	g.source_code = src
	g.reload()
	return g


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
	var track: RefCounted = _make(TRACK_SRC).new()
	race.set("track", track)
	me = _rider(rider_src, "JORU", "", 200.0, 0.0)
	me.set("is_player", true)
	var rv := _rider(rider_src, "LHACHAM DIKI YANGDOL", "diki", 214.0, 1.5)
	var behind := _rider(rider_src, "KARMA TOBGYE", "karma", 195.0, -1.8)
	var far := _rider(rider_src, "TEMBA TINLE", "temba", 420.0, 0.0)
	race.set("player", me)
	race.set("riders", [me, rv, behind, far, _rider(rider_src, "PEMA", "pema", 100.0, 2.0)])
	hud = load("res://scripts/ui/hud.gd").new()
	root.add_child(hud)
	hud.call("bind", race)
	await _wait(0.6)
	await _shot("h1_normal_rival")
	me.set("shake", 82.0)
	me.set("health", 55.0)
	me.set("lungta", 5.0)
	me.set("stamina", 30.0)
	race.emit_signal("announcement", "THWACK", "good")
	race.emit_signal("announcement", "UNSEATED!", "bad")
	await _wait(0.12)
	await _shot("h2_teeter_windfull_comic")
	await _wait(1.0)
	race.emit_signal("announcement", "KI KI SO SO!", "big")
	race.emit_signal("announcement", "KNOCKDOWN  +15", "info")
	race.emit_signal("announcement", "SCARF!  +8", "info")
	me.set("s", 250.0)
	me.set("lungta", 2.4)
	me.set("shake", 20.0)
	await _wait(0.5)
	await _shot("h3_big_quiet")
	await _wait(2.5)
	me.set("state", "rest")
	me.set("rest_left", 6.2)
	await _wait(0.3)
	await _shot("h4_rest")
	me.set("state", "ride")
	me.set("s", 500.0)
	me.set("drawing", true)
	me.set("draw_amount", 0.6)
	race.set("countdown", 2.4)
	await _wait(0.5)
	await _shot("h5_countdown_draw")
	race.set("countdown", 0.0)
	race.emit_signal("announcement", "3", "big")
	await _wait(0.2)
	await _shot("h6_count_three")
	quit()
