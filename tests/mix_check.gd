extends Node
## Measures the real mix. The scene plays through the actual Sfx autoload and buses, and Godot's Movie Maker records the
## master bus (limiter included) into the .avi, which tests/mix_check.py then reads and measures.
##
## Movie Maker needs a real renderer, so run it through tools/run_hidden.ps1 (an invisible desktop: never open a visible window):
##   powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_hidden.ps1 -Timeout 600 -Log <scratch>\run.log -GodotArgs
##     "res://tests/mix_check.tscn --write-movie <scratch>\mix.avi --fixed-fps 60 -- <mode> [seconds] [music] [sfx] [voice] [seed] [extras]"
## then measure the recording with the voice tools' Python:  python tests/mix_check.py <scratch>\mix.avi --log <scratch>\run.log
## (add --relative for voices heard over a race). The race log lists "VOICE_AT <second> <length> <who>" for every voice line.
##
## Modes
##   race   a bot races (player_ai) with the HUD, real music, hooves and hits. Extra arguments after the seed: "chatter" has
##          nearby rivals shout a line every few seconds through Sfx.say, so the voices are measured in the mix;
##          "loops_only" keeps just the hooves, wind and crowd, "oneshots_only" just the hits and other one-shots (to
##          see what each part adds to the mix).
##   menu   menu music with the usual button sounds and one spoken menu line
##   voices only voices: flat lines, then positioned lines at 5, 15 and 30 m (set music and sfx to 0 for a clean read)
##   tone   a 1 kHz sine at -20 dBFS on a bus: "tone Music" (or SFX, Voice, Master), to read each bus's gain and the limiter
##
## Volumes are 0..1 slider positions, set on the autoload at run time. Nothing here saves the settings or the game: Game
## already sends res://tests runs to scratch files, and this scene points both paths at the temp folder as well.

var mode := "race"
var seconds := 100.0
var elapsed := 0.0
var race: Race
var chatter := false
var _next_chatter := 4.0
var _rng := RandomNumberGenerator.new()
var _menu_t := 0.0
var _voice_i := 0
var _voice_wait := 1.0
var _cam: Camera3D
var _finish_wait := -1.0
var _tone_bus := "Music"
var _tone: AudioStreamPlayer
var _last_music_db := 99.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	mode = args[0] if args.size() > 0 else "race"
	seconds = float(args[1]) if args.size() > 1 else 100.0
	var mv := float(args[2]) if args.size() > 2 else 0.8
	var sv := float(args[3]) if args.size() > 3 else 0.9
	var vv := float(args[4]) if args.size() > 4 else 0.85
	var seed_v := int(args[5]) if args.size() > 5 else 99
	var extras := args.slice(6) if args.size() > 6 else PackedStringArray()
	chatter = "chatter" in extras
	if mode == "tone" and args.size() > 6:
		_tone_bus = args[6]
	_rng.seed = seed_v
	# Movie Maker always records the window at the project's 1600x900 (--resolution is ignored), and a race frame is about
	# 400 kB of JPEG, so a 2 minute race would pass the 4 GB limit of an .avi. Only the sound matters here, so switch the
	# 3D picture off; black frames are about 20 kB.
	get_viewport().disable_3d = true
	# The player's own settings and save stay untouched: volumes change only in memory, and both files point at the temp folder.
	var tmp := OS.get_temp_dir()
	Game.save_path = tmp.path_join("windhorse_mix_check_save.cfg")
	if Game.get("settings_path") != null:
		Game.set("settings_path", tmp.path_join("windhorse_mix_check_settings.cfg"))
	if Game.save_path.begins_with("user://") and not Game.save_path.contains("test"):
		push_error("mix_check: refusing to run with the real save path")
		get_tree().quit(1)
		return
	if str(Game.get("settings_path")) == "user://settings.cfg":
		push_error("mix_check: refusing to run with the real settings path")
		get_tree().quit(1)
		return
	Sfx.set_music_volume(mv)
	Sfx.set_sfx_volume(sv)
	if Sfx.has_method("set_voice_volume"):
		Sfx.call("set_voice_volume", vv)
	print("mix_check: mode %s, %.0f s, music %.2f sfx %.2f voice %.2f, chatter %s %s" % [mode, seconds, mv, sv, vv, str(chatter), str(extras)])
	_solo(extras)
	match mode:
		"race":
			_start_race(seed_v)
		"menu":
			# "final" or "race_music" in the extras plays that track instead, to measure each tune on its own.
			Sfx.music("final" if "final" in extras else ("race" if "race_music" in extras else "menu"))
		"voices":
			_cam = Camera3D.new()
			add_child(_cam)
			_cam.current = true
		"tone":
			_start_tone()


## Sends the loops or the one-shots to a muted bus, so a recording holds only the other kind.
func _solo(extras: PackedStringArray) -> void:
	if not ("loops_only" in extras or "oneshots_only" in extras):
		return
	AudioServer.add_bus()
	var mute_i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(mute_i, "MixCheckMute")
	AudioServer.set_bus_mute(mute_i, true)
	var players: Array = []
	if "loops_only" in extras:
		players.append_array(Sfx.get("_pool"))
		players.append_array(Sfx.get("_pool3d"))
	else:
		players.append_array((Sfx.get("_loop_players") as Dictionary).values())
	for p in players:
		p.bus = "MixCheckMute"


func _start_race(seed_v: int) -> void:
	race = Race.new()
	race.auto_begin = false
	race.player_ai = true
	add_child(race)
	race.begin({"season": 0, "seed": seed_v, "course_index": 0, "weapon_id": "sword", "ranged_id": "", "has_shield": true})
	race.race_finished.connect(_on_finished)
	if race.hud != null:
		(race.hud as CanvasLayer).visible = false


func _on_finished(_results: Array) -> void:
	# The HUD would now change to the results scene and free this test, so tell Game it is already changing scene.
	Game.set("_changing", true)
	_finish_wait = 3.0
	print("mix_check: race finished at %.1f s of recording" % elapsed)


func _start_tone() -> void:
	var rate := 32000
	var n := rate * 4
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v := int(roundf(sin(TAU * 1000.0 * float(i) / float(rate)) * 0.1 * 32767.0))   # -20 dBFS peak
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = n
	_tone = AudioStreamPlayer.new()
	_tone.stream = wav
	_tone.bus = _tone_bus
	add_child(_tone)
	_tone.play()


func _process(dt: float) -> void:
	elapsed += dt
	match mode:
		"menu":
			_menu(dt)
		"voices":
			_voices(dt)
		"race":
			_race(dt)
	if _finish_wait >= 0.0:
		_finish_wait -= dt
		if _finish_wait < 0.0:
			_quit("race finished")
	if elapsed >= seconds:
		_quit("time limit")


func _race(_dt: float) -> void:
	if not chatter or race == null or race.player == null or not race.started:
		return
	if race.race_time < _next_chatter or not Sfx.has_method("say"):
		return
	_next_chatter = race.race_time + _rng.randf_range(5.0, 8.0)
	var near: Array[Rider] = []
	for r: Rider in race.riders:
		if not r.is_player and absf(r.s - race.player.s) < 45.0:
			near.append(r)
	if near.is_empty():
		return
	var who: Rider = near[_rng.randi() % near.size()]
	var cats := ["pass_by", "passed", "hit_you", "hurt", "near", "gloat"]
	# A Callable keeps the voice on the rider as it gallops on, the way Race should pass moving speakers.
	var follow := func() -> Vector3: return race.visual_pos(who)
	var line: Dictionary = Sfx.call("say", who.rival_id, cats[_rng.randi() % cats.size()], follow)
	if not line.is_empty():
		print("VOICE_AT %.3f %.3f %s %s: %s (%s)" % [elapsed, float(line.get("d", 0.0)), who.rival_id, line.get("l", ""), line.get("t", ""), line.get("f", "")])


func _menu(dt: float) -> void:
	_menu_t += dt
	# Report how far the music bus is pulled down while the menu line speaks, to see it ease in and out.
	var music_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	if absf(music_db - _last_music_db) > 0.4:
		_last_music_db = music_db
		print("MUSIC_BUS %.2f s  %.1f dB" % [elapsed, music_db])
	if int(_menu_t * 0.8) != int((_menu_t - dt) * 0.8):
		Sfx.play("ui_move", -6.0)
	if int(_menu_t / 5.0) != int((_menu_t - dt) / 5.0):
		Sfx.play("ui_ok", -3.0)
	if int(_menu_t) == 3 and int(_menu_t - dt) == 2 and Sfx.has_method("say_text"):
		var rival: Dictionary = GameData.RIVALS.get("wangyal", {})
		var texts: Array = (rival.get("lines", {}) as Dictionary).get("intro", [])
		if not texts.is_empty():
			var secs: float = Sfx.call("say_text", "wangyal", String(texts[0]))
			print("VOICE_AT %.3f %.3f say_text wangyal menu line" % [elapsed, secs])


## Lines in a fixed order: flat ones first, then positioned at growing distance.
const VOICE_PLAN := [
	["wangyal", "pass_by", "", 0.0], ["pema", "hurt", "", 0.0], ["karma", "near", "", 0.0], ["drukmo", "hit_you", "", 0.0],
	["joru", "p_hurt", "", 0.0], ["yangkyi", "p_knock", "", 0.0], ["chakri", "gloat", "", 0.0], ["diki", "near", "", 0.0],
	["wangyal", "near", "bo", 0.0], ["pema", "pass_by", "bo", 0.0], ["thupden", "hit_you", "bo", 0.0], ["ama", "near", "bo", 0.0],
	["wangyal", "pass_by", "en", 5.0], ["wangyal", "near", "en", 15.0], ["wangyal", "gloat", "en", 30.0], ["karma", "near", "bo", 5.0], ["karma", "pass_by", "bo", 15.0],
	["karma", "gloat", "bo", 30.0],
]


func _voices(dt: float) -> void:
	if not Sfx.has_method("say"):
		return
	_voice_wait -= dt
	if _voice_wait > 0.0 or Sfx.call("voice_playing"):
		return
	if _voice_i == 0:
		# First a menu line through say_text, the way a menu screen calls it.
		_voice_i = 1
		var rival: Dictionary = GameData.RIVALS.get("wangyal", {})
		var texts: Array = (rival.get("lines", {}) as Dictionary).get("intro", [])
		if not texts.is_empty():
			var secs: float = Sfx.call("say_text", "wangyal", String(texts[0]))
			print("VOICE_AT %.3f %.3f say_text wangyal menu line" % [elapsed, secs])
			_voice_wait = 0.8
			return
	if _voice_i > VOICE_PLAN.size():
		_quit("plan done")
		return
	var row: Array = VOICE_PLAN[_voice_i - 1]
	_voice_i += 1
	var pos: Variant = null
	if float(row[3]) > 0.0:
		pos = Vector3(3.0, 1.5, -float(row[3]))
	var line: Dictionary = Sfx.call("say", row[0], row[1], pos, 0.0, row[2])
	print("VOICE_AT %.3f %.3f %s %s dist %.0f lang %s: %s" % [elapsed, float(line.get("d", 0.0)), row[0], row[1], float(row[3]), line.get("l", "-"), line.get("t", "(nothing)")])
	_voice_wait = 0.9


func _quit(why: String) -> void:
	if race != null and race.get("chatter_node") != null:
		# Race brings its own Chatter, which speaks through Sfx.say whenever the voices are not muted.
		print("mix_check: Race's own Chatter said %s lines" % str(race.get("chatter_node").get("lines_total")))
	print("mix_check: done (%s) after %.1f s" % [why, elapsed])
	set_process(false)
	get_tree().quit()
