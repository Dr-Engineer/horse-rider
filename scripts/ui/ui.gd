class_name UI
extends RefCounted
## The shared look of every screen: palette, the headline font at integer sizes, thangka frames, bars, flags, icons.
## The game draws its UI on a 640x360 canvas scaled by whole numbers, so one logical pixel is a fat, crisp pixel.
## Font sizes are BASE times a whole number (k = 1, 2, 3 ...); never anything else.

const BASE := 11
const ASCENT := 9          # baseline of the BMFont at BASE, in pixels from the top of the line
const SAFE := Vector2(640, 360)

const INK := Color("17131A")
const SOOT := Color("2B2630")
const CHARCOAL := Color("453D46")
const SLATE := Color("6B6570")
const ASH := Color("9B9595")
const BONE := Color("D9CDB2")
const CHALK := Color("EFE6D2")
const CONCH := Color("FBF5E6")
const VERMILION := Color("D63A22")
const CINNABAR := Color("9E2418")
const MADDER := Color("7A1C22")
const PEMA := Color("6E2A25")
const ORPIMENT := Color("F2B632")
const GOLD := Color("D9A227")
const AMBER := Color("C47A1A")
const OCHRE := Color("C9953F")
const MALACHITE := Color("2E9E78")
const MALACHITE_DARK := Color("1B6B58")
const TURQUOISE := Color("2FB7B0")
const LAPIS := Color("1F4FA8")
const LAPIS_DEEP := Color("12306E")
const AZURE := Color("4A8FD9")
const INDIGO := Color("2A2A66")
const SAFFRON := Color("E8871E")
const PLUM := Color("6B2F5B")
const ROSE := Color("D9697A")
const SNOW := Color("F6FBFF")

## Prayer-flag order: blue, white, red, green, yellow.
const LUNGTA_COLORS: Array[Color] = [AZURE, CONCH, VERMILION, MALACHITE, ORPIMENT]

static var _font: Font
static var _theme: Theme
static var _icons: Dictionary = {}


static func font() -> Font:
	if _font == null:
		_font = load("res://assets/fonts/headline.fnt") as Font
	return _font


static func icon(icon_name: String) -> Texture2D:
	if _icons.has(icon_name):
		return _icons[icon_name]
	var path := "res://assets/ui/icons/%s.png" % icon_name
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_icons[icon_name] = tex
	return tex


## A texture by path, loaded once.
static func texture(path: String) -> Texture2D:
	if _icons.has(path):
		return _icons[path]
	var tex: Texture2D = null
	if path != "" and ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_icons[path] = tex
	return tex


static func portrait(id: String) -> Texture2D:
	var key := "portrait_" + id
	if _icons.has(key):
		return _icons[key]
	var path := "res://assets/ui/portraits/%s.png" % id
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_icons[key] = tex
	return tex


# ------------------------------------------------------------------ text

static func text_width(s: String, k: int = 1) -> float:
	return font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, BASE * k).x


## Draws text with its top-left at pos. Outline is ink at one font-pixel, so it stays chunky at every size.
static func text(ci: CanvasItem, pos: Vector2, s: String, k: int = 1, color: Color = CONCH, outline: bool = true, alpha: float = 1.0) -> void:
	var f := font()
	var size := BASE * k
	var p := Vector2(roundf(pos.x), roundf(pos.y) + ASCENT * k)
	if outline:
		var oc := Color(INK, alpha)
		for o: Vector2 in [Vector2(k, 0), Vector2(-k, 0), Vector2(0, k), Vector2(0, -k), Vector2(k, k)]:
			ci.draw_string(f, p + o, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, oc)
	ci.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color, color.a * alpha))


static func text_c(ci: CanvasItem, center_x: float, y: float, s: String, k: int = 1, color: Color = CONCH, outline: bool = true, alpha: float = 1.0) -> void:
	text(ci, Vector2(center_x - text_width(s, k) * 0.5, y), s, k, color, outline, alpha)


static func text_r(ci: CanvasItem, right_x: float, y: float, s: String, k: int = 1, color: Color = CONCH, outline: bool = true, alpha: float = 1.0) -> void:
	text(ci, Vector2(right_x - text_width(s, k), y), s, k, color, outline, alpha)


static func label(txt: String, k: int = 1, color: Color = CONCH, align: int = HORIZONTAL_ALIGNMENT_LEFT, shadow: bool = true) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = align as HorizontalAlignment
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", BASE * k)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("line_spacing", 2 * k)
	if shadow:
		l.add_theme_color_override("font_shadow_color", INK)
		l.add_theme_constant_override("shadow_offset_x", k)
		l.add_theme_constant_override("shadow_offset_y", k)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func wrapped(txt: String, width: float, k: int = 1, color: Color = CONCH) -> Label:
	var l := label(txt, k, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l


# ------------------------------------------------------------------ frames and bars

static func rect_frame(ci: CanvasItem, r: Rect2, c: Color, w: float = 1.0) -> void:
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, w)), c)
	ci.draw_rect(Rect2(Vector2(r.position.x, r.end.y - w), Vector2(r.size.x, w)), c)
	ci.draw_rect(Rect2(r.position, Vector2(w, r.size.y)), c)
	ci.draw_rect(Rect2(Vector2(r.end.x - w, r.position.y), Vector2(w, r.size.y)), c)


## A brocade strip: madder silk with a repeating gold lozenge and a vermilion eye.
static func brocade(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(r, MADDER)
	var x := r.position.x + 1.0
	var y := r.position.y
	var h := r.size.y
	var mid := floorf(h * 0.5)
	var end_x := r.end.x - 1.0
	while x + 7.0 <= end_x:
		for row in int(h):
			var d := absf(float(row) - mid)
			var half := maxf(0.0, 3.0 - d * (3.0 / maxf(mid, 1.0)))
			var w := half * 2.0 + 1.0
			ci.draw_rect(Rect2(x + 3.0 - half, y + row, w, 1.0), GOLD)
		ci.draw_rect(Rect2(x + 3.0, y + mid, 1.0, 1.0), VERMILION)
		x += 8.0
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1.0), AMBER)
	ci.draw_rect(Rect2(r.position.x, r.end.y - 1.0, r.size.x, 1.0), AMBER)


## The thangka mount: ink panel, gold line, brocade silk top and bottom.
static func draw_panel(ci: CanvasItem, r: Rect2, with_brocade: bool = true, fill: Color = INK, strip: int = 5) -> void:
	ci.draw_rect(r, fill)
	rect_frame(ci, Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2)), GOLD, 1.0)
	if with_brocade and r.size.y > 24.0 and r.size.x > 24.0:
		brocade(ci, Rect2(r.position.x + 3.0, r.position.y + 3.0, r.size.x - 6.0, strip))
		brocade(ci, Rect2(r.position.x + 3.0, r.end.y - 3.0 - strip, r.size.x - 6.0, strip))


static func bar(ci: CanvasItem, r: Rect2, frac: float, fill: Color, back: Color = SOOT, trail: float = -1.0) -> void:
	ci.draw_rect(r, INK)
	var inner := Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2))
	ci.draw_rect(inner, back)
	if trail > frac:   # the part you just lost, draining away
		ci.draw_rect(Rect2(inner.position, Vector2(floorf(inner.size.x * clampf(trail, 0.0, 1.0)), inner.size.y)), CONCH)
	var w := floorf(inner.size.x * clampf(frac, 0.0, 1.0))
	if w > 0.0:
		ci.draw_rect(Rect2(inner.position, Vector2(w, inner.size.y)), fill)
		ci.draw_rect(Rect2(inner.position, Vector2(w, 1.0)), fill.lightened(0.35))
		if inner.size.y >= 4.0:
			ci.draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - 1.0), Vector2(w, 1.0)), fill.darkened(0.3))


## Prayer flags on a string, in order blue, white, red, green, yellow. `lungta` is 0..5. Flags fill from the bottom.
static func draw_flags(ci: CanvasItem, pos: Vector2, lungta: float, flash: bool = false, fw: int = 10, fh: int = 9) -> void:
	var gap := 2
	var total := 5 * fw + 4 * gap
	ci.draw_rect(Rect2(pos.x - 2.0, pos.y, total + 4.0, 1.0), BONE)
	for i in 5:
		var x := pos.x + i * (fw + gap)
		var y := pos.y + 1.0
		var col: Color = LUNGTA_COLORS[i]
		var f := clampf(lungta - float(i), 0.0, 1.0)
		ci.draw_rect(Rect2(x - 1.0, y, fw + 2.0, fh + 1.0), INK)
		ci.draw_rect(Rect2(x, y, fw, fh), col.darkened(0.6).lerp(INK, 0.15))
		var fill_h := floorf(fh * f)
		if fill_h > 0.0:
			var c2 := col.lightened(0.5) if flash else col
			ci.draw_rect(Rect2(x, y + fh - fill_h, fw, fill_h), c2)
			if f >= 1.0:
				ci.draw_rect(Rect2(x + floorf(fw * 0.5) - 1.0, y + 3.0, 2.0, 2.0), col.darkened(0.45))   # abstract block print
		ci.draw_rect(Rect2(x + fw - 2.0, y + fh, 2.0, 1.0), INK)   # swallow-tail notch


## A dusk backdrop for menu screens: stepped sky, two ranges of snow peaks, an ink foreground. Pure rects, so it costs nothing.
static func draw_backdrop(ci: CanvasItem, r: Rect2, seed_value: float = 0.0, horizon: float = 0.62) -> void:
	var bands: Array[Color] = [LAPIS_DEEP, INDIGO.lerp(LAPIS_DEEP, 0.4), INDIGO, PLUM.lerp(INDIGO, 0.5), PLUM, MADDER.lerp(PLUM, 0.5), MADDER]
	var sky_h := r.size.y * horizon
	var bh := sky_h / bands.size()
	for i in bands.size():
		ci.draw_rect(Rect2(r.position.x, r.position.y + i * bh, r.size.x, bh + 1.0), bands[i])
	var cw := 4.0
	var cols := int(r.size.x / cw) + 1
	var base_y := r.position.y + sky_h
	for layer in 2:
		var col_body: Color = INDIGO.lerp(SLATE, 0.35) if layer == 0 else SOOT
		var amp := 38.0 if layer == 0 else 26.0
		var lift := 26.0 if layer == 0 else 4.0
		for c in cols:
			var x := c * cw
			var u := x * (0.011 if layer == 0 else 0.019) + seed_value * 3.1 + layer * 5.0
			var hgt := lift + amp * (0.55 + 0.3 * sin(u) + 0.22 * sin(u * 2.3 + 1.7) + 0.12 * sin(u * 5.1 + 0.4))
			hgt = floorf(hgt / 2.0) * 2.0
			var top := base_y - hgt
			ci.draw_rect(Rect2(r.position.x + x, top, cw, r.end.y - top), col_body)
			if hgt > lift + amp * 0.95:
				ci.draw_rect(Rect2(r.position.x + x, top, cw, 4.0 if layer == 0 else 5.0), SNOW if layer == 0 else CHALK)
				ci.draw_rect(Rect2(r.position.x + x, top + 4.0, cw, 2.0), SNOW.darkened(0.25) if layer == 0 else BONE)
	ci.draw_rect(Rect2(r.position.x, base_y + 6.0, r.size.x, r.end.y - base_y), INK)


# ------------------------------------------------------------------ theme

static func _box(bg: Color, border: Color, mx: int = 6, my: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.content_margin_left = mx
	s.content_margin_right = mx
	s.content_margin_top = my
	s.content_margin_bottom = my
	s.anti_aliasing = false
	return s


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = BASE
	t.set_color("font_color", "Label", CONCH)
	t.set_constant("line_spacing", "Label", 2)
	t.set_stylebox("normal", "Button", _box(SOOT, OCHRE))
	t.set_stylebox("hover", "Button", _box(ORPIMENT, CONCH))
	t.set_stylebox("pressed", "Button", _box(GOLD, CONCH))
	t.set_stylebox("disabled", "Button", _box(INK, CHARCOAL))
	t.set_stylebox("focus", "Button", _box(ORPIMENT, CONCH))
	t.set_color("font_color", "Button", CONCH)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_hover_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", SLATE)
	t.set_constant("h_separation", "Button", 4)
	t.set_stylebox("panel", "PanelContainer", _box(INK, GOLD, 6, 6))
	_theme = t
	return t


## Wires focus by hand for controls in a row or a column, so the arrow keys stay among them. Godot looks for the next control
## by geometry across the whole screen, which lets a panel that sits over a menu hand focus to the menu behind it.
## Call it once the controls are in the tree.
static func focus_chain(items: Array, vertical: bool = true, wrap: bool = true) -> void:
	var n := items.size()
	for i in n:
		var c := items[i] as Control
		var back_i := (i - 1 + n) % n if wrap else maxi(i - 1, 0)
		var next_i := (i + 1) % n if wrap else mini(i + 1, n - 1)
		var back_path := (items[back_i] as Control).get_path()
		var next_path := (items[next_i] as Control).get_path()
		var self_path := c.get_path()
		if vertical:
			c.focus_neighbor_top = back_path
			c.focus_neighbor_bottom = next_path
			c.focus_neighbor_left = self_path
			c.focus_neighbor_right = self_path
		else:
			c.focus_neighbor_left = back_path
			c.focus_neighbor_right = next_path
			c.focus_neighbor_top = self_path
			c.focus_neighbor_bottom = self_path


## The key hints at the foot of a menu, for whichever device was used last.
static func hint(select_text: String = "SELECT", back_text: String = "BACK") -> String:
	if Input.get_connected_joypads().size() > 0:
		return "A %s    B %s" % [select_text, back_text]
	return "ENTER %s    ESC %s" % [select_text, back_text]


## Money as it reads in a plate: "150 SRANG".
static func srang(n: int) -> String:
	return "%d SRANG" % n


static func ordinal(n: int) -> String:
	var suffix := "TH"
	if n % 100 < 11 or n % 100 > 13:
		match n % 10:
			1: suffix = "ST"
			2: suffix = "ND"
			3: suffix = "RD"
	return "%d%s" % [n, suffix]


static func time_text(secs: float) -> String:
	if secs <= 0.0:
		return "--:--.--"
	var m := int(secs / 60.0)
	var s := secs - m * 60.0
	return "%d:%05.2f" % [m, s]
