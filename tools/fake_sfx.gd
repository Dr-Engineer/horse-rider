extends Node
## A stand-in for the Sfx autoload in tests. It makes no sound and logs the voice calls, so a test can check what each menu
## asked to be spoken. tools/voice_check.gd swaps it in with set_script on the live autoload.

var log: Array[String] = []
var say_secs := 3.0
var voice_volume := 1.0
var music_volume := 0.8
var sfx_volume := 0.9


func play(_sound: String = "", _db: float = 0.0, _pitch: float = 1.0) -> void:
	pass


func play_at(_sound: String = "", _pos: Vector3 = Vector3.ZERO, _db: float = 0.0, _pitch: float = 1.0) -> void:
	pass


func music(_track: String) -> void:
	pass


func stop_music() -> void:
	pass


func stop_loops() -> void:
	pass


func duck(_on: bool) -> void:
	pass


func set_gallop(_f: float) -> void:
	pass


func set_ambience(_wind: float, _crowd: float) -> void:
	pass


func set_music_volume(v: float) -> void:
	music_volume = v


func set_sfx_volume(v: float) -> void:
	sfx_volume = v


func set_voice_volume(v: float) -> void:
	voice_volume = v
	log.append("voice_volume %.1f" % v)


func say(speaker: String, category: String, _pos: Variant = null, _db: float = 0.0, lang: String = "") -> Dictionary:
	log.append("say %s %s %s" % [speaker, category, lang])
	return {"f": "fake", "t": "TAPA-TSO, DRADRIK GYI!", "g": "RIDERS, GET READY!", "l": "bo", "d": 1.0}


func say_text(speaker: String, text: String, _db: float = 0.0) -> float:
	log.append("say_text %s %s" % [speaker, text.substr(0, 28)])
	return say_secs


func say_file(file: String, _db: float = 0.0) -> float:
	log.append("say_file %s" % file)
	return say_secs


func stop_voice() -> void:
	log.append("stop_voice")


func voice_playing() -> bool:
	return false
