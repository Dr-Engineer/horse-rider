class_name Screen
extends Control
## Base for every menu screen. Builds into `safe`, a 640x360 area centred in the real window (which may be larger).
## Subclasses override build(), and back() if Escape or the B button should do something.

var safe: Control
var back_enabled := true


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	mouse_filter = Control.MOUSE_FILTER_PASS
	safe = Control.new()
	safe.name = "Safe"
	safe.anchor_left = 0.5
	safe.anchor_right = 0.5
	safe.anchor_top = 0.5
	safe.anchor_bottom = 0.5
	safe.offset_left = -UI.SAFE.x * 0.5
	safe.offset_right = UI.SAFE.x * 0.5
	safe.offset_top = -UI.SAFE.y * 0.5
	safe.offset_bottom = UI.SAFE.y * 0.5
	safe.grow_horizontal = Control.GROW_DIRECTION_BOTH
	safe.grow_vertical = Control.GROW_DIRECTION_BOTH
	safe.mouse_filter = Control.MOUSE_FILTER_PASS


func _ready() -> void:
	add_child(safe)
	build()


## Override: create the widgets, parented to `safe` (or to a Backdrop added to self first).
func build() -> void:
	pass


## Override: Escape, B button.
func back() -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if back_enabled and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Sfx.play("ui_back", -3.0)
		back()


## Standard vertical stack of buttons inside `parent`, snapping in one after another. Returns the buttons.
func button_column(parent: Control, labels: Array, width: float = 150.0, pos: Vector2 = Vector2.ZERO) -> Array[WButton]:
	var out: Array[WButton] = []
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.position = pos
	parent.add_child(box)
	var i := 0
	for l in labels:
		var b := WButton.new(str(l))
		b.custom_minimum_size = Vector2(width, 20)
		b.modulate.a = 0.0
		box.add_child(b)
		out.append(b)
		i += 1
	for j in out.size():
		out[j].snap_in.call_deferred(0.12 + 0.05 * j)
	return out


## Put keyboard and gamepad focus on a control after the layout has settled.
func focus_later(c: Control) -> void:
	c.grab_focus.call_deferred()
