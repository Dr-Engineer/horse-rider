class_name PhrasebookScreen
extends Screen
## Every Tibetan phrase the riders shout, with what it means. Pick one to hear it. No Tibetan script is shown: the phrases
## are spelled as they sound, and they still await review by a Tibetan speaker.

var _list: PhraseList
var _status: TextArt
var _status_t := 0.0


func build() -> void:
	Sfx.music("menu")
	var bd := Backdrop.new(4.4, 0.52)
	add_child(bd)
	move_child(bd, 0)

	var head := TextArt.new("PHRASEBOOK", 2, UI.ORPIMENT)
	head.position = Vector2(14, 10)
	safe.add_child(head)
	var sub := TextArt.new("WHAT THE RIDERS SHOUT, AND WHAT IT MEANS", 1, UI.CONCH)
	sub.position = Vector2(16, 36)
	safe.add_child(sub)

	_list = PhraseList.new(Speak.phrases())
	_list.position = Vector2(14, 54)
	_list.size = Vector2(612, 210)
	_list.chosen.connect(_play)
	safe.add_child(_list)

	var note := TextArt.new(StoryText.PHRASEBOOK_NOTE, 1, UI.ORPIMENT)
	note.position = Vector2(16, 272)
	safe.add_child(note)
	if Game.voice_volume <= 0.001:
		var muted := TextArt.new("VOICES ARE MUTED. TURN THEM UP IN OPTIONS TO HEAR THE PHRASES.", 1, UI.ROSE)
		muted.position = Vector2(16, 288)
		muted.name = "MutedNote"
		safe.add_child(muted)
	_status = TextArt.new("", 1, UI.BONE)
	_status.position = Vector2(16, 304)
	safe.add_child(_status)

	var back_btn := WButton.new("BACK")
	back_btn.custom_minimum_size = Vector2(96, 22)
	back_btn.position = Vector2(14, 326)
	back_btn.pressed.connect(back)
	safe.add_child(back_btn)
	var hint := TextArt.new(UI.hint("HEAR IT", "BACK"), 1, UI.BONE)
	hint.position = Vector2(126, 331)
	safe.add_child(hint)
	_list.focus_neighbor_bottom = back_btn.get_path()
	back_btn.focus_neighbor_top = _list.get_path()
	focus_later(_list)


func _process(delta: float) -> void:
	if _status_t > 0.0:
		_status_t -= delta
		if _status_t <= 0.0:
			_status.set_text("")


func _play(i: int) -> void:
	var e: Dictionary = _list.items[i]
	_list.flash()
	var secs := Speak.file(str(e.get("f", "")))
	if secs > 0.0:
		return
	if Game.voice_volume <= 0.001:
		_say("VOICES ARE MUTED.")
	else:
		_say("NO RECORDING OF THAT ONE YET.")
	Sfx.play("ui_back", -6.0)


func _say(message: String) -> void:
	_status.set_text(message)
	_status_t = 2.5


func back() -> void:
	Game.go("title")
