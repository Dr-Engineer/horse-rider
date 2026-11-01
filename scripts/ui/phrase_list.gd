class_name PhraseList
extends Control
## A scrolling list of phrases drawn in the thangka style: the phrase on the left, what it means on the right. Up and down
## (keys, D-pad or stick) move, Enter or A picks, the wheel scrolls, and a click picks. At either end the arrow keys let go of
## the list, so focus can move on to the buttons below it.

signal chosen(index: int)

const ROW_H := 22
const PAD := 5

var items: Array = []
var selected := 0
var _top := 0
var _flash := 0.0
var _t := 0.0


func _init(entries: Array = []) -> void:
	items = entries
	focus_mode = Control.FOCUS_ALL
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func rows_visible() -> int:
	return maxi(int((size.y - 2.0 * PAD) / ROW_H), 1)


func flash() -> void:
	_flash = 0.35


func _process(delta: float) -> void:
	_t += delta
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		queue_redraw()


func _select(i: int, quiet: bool = false) -> void:
	var n := clampi(i, 0, maxi(items.size() - 1, 0))
	if n != selected and not quiet:
		Sfx.play("ui_move", -8.0)
	selected = n
	var vis := rows_visible()
	if selected < _top:
		_top = selected
	elif selected >= _top + vis:
		_top = selected - vis + 1
	_top = clampi(_top, 0, maxi(items.size() - vis, 0))
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if items.is_empty():
		return
	if event.is_action_pressed("ui_down", true):
		if selected < items.size() - 1:
			_select(selected + 1)
			accept_event()
	elif event.is_action_pressed("ui_up", true):
		if selected > 0:
			_select(selected - 1)
			accept_event()
	elif event.is_action_pressed("ui_page_down", true):
		_select(selected + rows_visible())
		accept_event()
	elif event.is_action_pressed("ui_page_up", true):
		_select(selected - rows_visible())
		accept_event()
	elif event.is_action_pressed("ui_home"):
		_select(0)
		accept_event()
	elif event.is_action_pressed("ui_end"):
		_select(items.size() - 1)
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		chosen.emit(selected)
		accept_event()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_top = clampi(_top + 2, 0, maxi(items.size() - rows_visible(), 0))
			queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_top = clampi(_top - 2, 0, maxi(items.size() - rows_visible(), 0))
			queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			var i := _row_at(mb.position.y)
			if i >= 0:
				_select(i, true)
				chosen.emit(i)
		accept_event()
	elif event is InputEventMouseMotion:
		var i := _row_at((event as InputEventMouseMotion).position.y)
		if i >= 0 and i != selected:
			if not has_focus():
				grab_focus()
			_select(i)


func _row_at(y: float) -> int:
	var i := _top + int((y - PAD) / ROW_H)
	if y < PAD or i >= items.size() or i >= _top + rows_visible():
		return -1
	return i


func _draw() -> void:
	UI.draw_panel(self, Rect2(Vector2.ZERO, size), false)
	if items.is_empty():
		UI.text_c(self, size.x * 0.5, size.y * 0.5 - 6.0, "NO PHRASES YET.", 1, UI.BONE)
		return
	var focused := has_focus()
	var vis := rows_visible()
	var right := size.x - PAD - 8.0
	for k in vis:
		var i := _top + k
		if i >= items.size():
			break
		var e: Dictionary = items[i]
		var y := PAD + k * ROW_H
		var is_sel := i == selected
		var bg := UI.INK
		var fg := UI.CONCH
		var sub := UI.BONE
		if is_sel:
			if _flash > 0.0:
				bg = UI.CONCH
			else:
				bg = UI.ORPIMENT if focused else UI.CHARCOAL
			fg = UI.INK if (focused or _flash > 0.0) else UI.CONCH
			sub = UI.INK if (focused or _flash > 0.0) else UI.BONE
		elif i % 2 == 1:
			bg = UI.SOOT
		draw_rect(Rect2(PAD, y, right - PAD, ROW_H - 2), bg)
		if is_sel:
			UI.rect_frame(self, Rect2(PAD, y, right - PAD, ROW_H - 2), UI.CONCH if focused else UI.OCHRE, 1.0)
		var gloss := str(e.get("g", ""))
		if gloss == "":
			gloss = "(LAUGHTER)" if str(e.get("t", "")).begins_with("HA") else ""
		UI.text(self, Vector2(PAD + 8, y + 5), ("> " if is_sel else "") + str(e.get("t", "")), 1, fg, false)
		UI.text_r(self, right - 8.0, y + 5, gloss, 1, sub, false)
	# the scroll thread
	if items.size() > vis:
		var track := Rect2(size.x - PAD - 4.0, PAD, 3.0, size.y - 2.0 * PAD)
		draw_rect(track, UI.CHARCOAL)
		var th := maxf(12.0, track.size.y * float(vis) / items.size())
		var ty := track.position.y + (track.size.y - th) * float(_top) / maxf(items.size() - vis, 1)
		draw_rect(Rect2(track.position.x, ty, track.size.x, th), UI.GOLD)
