class_name WChoice
extends Control
## A labelled setting with a few named values: left and right change it, Enter or a click steps on, and it wraps round.

signal value_changed(index: int)

var caption := ""
var options: Array[String] = []
var index := 0:
	set(v):
		index = clampi(v, 0, maxi(options.size() - 1, 0))
		queue_redraw()


func _init(caption_text: String = "", names: Array[String] = [], start: int = 0) -> void:
	caption = caption_text
	options = names
	index = start
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(250, 20)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(_on_hover)


func _on_hover() -> void:
	if not has_focus():
		grab_focus()
		Sfx.play("ui_move", -6.0)


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_step(-1)
		accept_event()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_accept"):
		_step(1)
		accept_event()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_step(-1 if (event as InputEventMouseButton).position.x < size.x * 0.45 else 1)
		accept_event()


func _step(d: int) -> void:
	if options.size() < 2:
		return
	index = (index + d + options.size()) % options.size()
	value_changed.emit(index)
	Sfx.play("ui_move", -6.0)


func _draw() -> void:
	var focused := has_focus()
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, UI.ORPIMENT if focused else UI.SOOT)
	UI.rect_frame(self, r, UI.CONCH if focused else UI.OCHRE, 1.0)
	UI.text(self, Vector2(6, 4), caption, 1, UI.INK if focused else UI.CONCH, false)
	var shown := "< %s >" % options[index] if options.size() > 1 else (options[index] if options.size() > 0 else "")
	UI.text_r(self, size.x - 6.0, 4.0, shown, 1, UI.INK if focused else UI.ORPIMENT, false)
