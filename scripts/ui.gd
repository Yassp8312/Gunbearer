extends RefCounted
# Estilo único de toda la interfaz: colores, tamaños y piezas (títulos, botones, paneles).
# Menú, sala, opciones, créditos, pausa y pantalla final salen de aquí, para que todo
# se vea igual. Si hay que cambiar un color o un tamaño, se cambia aquí y en ningún otro lado.

const BG: Color = Color("0e1326")
const PANEL: Color = Color("161d3a")
const PANEL_SOFT: Color = Color("202a52")
const LINE: Color = Color("33407a")
const ACCENT: Color = Color("ffe14d")
const ACCENT_DARK: Color = Color("1a1500")
const TEXT: Color = Color("f2f5ff")
const MUTED: Color = Color("9aa6d1")
const GOOD: Color = Color("7dffb0")
const BAD: Color = Color("ff8a8a")

# Tamaños de letra. Solo se usan estos.
const F_TITLE: int = 76
const F_H1: int = 38
const F_H2: int = 24
const F_BODY: int = 18
const F_SMALL: int = 14

const RADIUS: int = 12
const GAP: int = 10

# Colores de jugador, por puesto. Es la misma lista que usa la partida.
const PLAYER_COLORS: Array = [Color("ff5a5f"), Color("3fa7ff"), Color("ffd23f"), Color("4cd964"), Color("b86bff"), Color("ff9f1c"), Color("2ee6c8"), Color("ff7ac8")]

static var _theme: Theme = null


static func _flat(bg: Color, border: Color = Color.TRANSPARENT, border_w: int = 0, pad_h: int = 18, pad_v: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(RADIUS)
	s.set_border_width_all(border_w)
	s.border_color = border
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	return s


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = F_BODY

	# Botones
	t.set_stylebox("normal", "Button", _flat(PANEL_SOFT, LINE, 2))
	t.set_stylebox("hover", "Button", _flat(PANEL_SOFT.lightened(0.12), ACCENT, 2))
	t.set_stylebox("pressed", "Button", _flat(ACCENT, ACCENT, 2))
	t.set_stylebox("focus", "Button", _flat(Color.TRANSPARENT, ACCENT, 2))
	t.set_stylebox("disabled", "Button", _flat(PANEL, LINE, 2))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ACCENT_DARK)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", MUTED.darkened(0.3))
	t.set_font_size("font_size", "Button", F_BODY + 2)

	# Listas desplegables: mismo aspecto que un botón
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		t.set_stylebox(st, "OptionButton", t.get_stylebox(st, "Button"))
	t.set_color("font_color", "OptionButton", TEXT)
	t.set_color("font_pressed_color", "OptionButton", ACCENT_DARK)
	t.set_stylebox("panel", "PopupMenu", _flat(PANEL, LINE, 2, 8, 8))
	t.set_stylebox("hover", "PopupMenu", _flat(PANEL_SOFT.lightened(0.12), Color.TRANSPARENT, 0, 8, 4))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", ACCENT)
	t.set_font_size("font_size", "PopupMenu", F_BODY)

	# Campos de texto
	t.set_stylebox("normal", "LineEdit", _flat(BG, LINE, 2, 14, 8))
	t.set_stylebox("focus", "LineEdit", _flat(BG, ACCENT, 2, 14, 8))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", MUTED.darkened(0.2))
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_font_size("font_size", "LineEdit", F_BODY)

	# Texto y paneles
	t.set_color("font_color", "Label", TEXT)
	t.set_font_size("font_size", "Label", F_BODY)
	t.set_stylebox("panel", "PanelContainer", _flat(Color(PANEL, 0.94), LINE, 2, 28, 24))

	# Deslizadores y casillas
	var track := _flat(BG, LINE, 2, 0, 4)
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", _flat(ACCENT, Color.TRANSPARENT, 0, 0, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", _flat(ACCENT, Color.TRANSPARENT, 0, 0, 4))
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_hover_color", "CheckButton", Color.WHITE)
	t.set_color("font_pressed_color", "CheckButton", ACCENT)
	_theme = t
	return t


# ---------- Piezas ----------

static func label(text: String, size: int = F_BODY, color: Color = TEXT, centered: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if size <= F_H2:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


# Título con contorno, para ponerlo directamente sobre la partida de fondo.
static func title(text: String, size: int = F_TITLE, color: Color = ACCENT) -> Label:
	var l: Label = label(text, size, color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", maxi(6, int(size * 0.16)))
	return l


# Botón normal. Con primary = true es la acción principal de la pantalla (amarillo).
static func button(text: String, cb: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	if primary:
		b.add_theme_stylebox_override("normal", _flat(ACCENT, ACCENT, 2))
		b.add_theme_stylebox_override("hover", _flat(ACCENT.lightened(0.25), Color.WHITE, 2))
		b.add_theme_stylebox_override("pressed", _flat(ACCENT.darkened(0.15), ACCENT, 2))
		b.add_theme_color_override("font_color", ACCENT_DARK)
		b.add_theme_color_override("font_hover_color", ACCENT_DARK)
		b.add_theme_color_override("font_focus_color", ACCENT_DARK)
	b.mouse_entered.connect(Sfx.play_ui.bind("ui_hover"))
	b.pressed.connect(Sfx.play_ui.bind("ui_click"))
	b.pressed.connect(cb)
	return b


# Fila "etiqueta ........ control", para formularios.
static func row(text: String, control: Control, control_width: float = 230.0) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	var l: Label = label(text, F_BODY, MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	control.custom_minimum_size = Vector2(control_width, 42)
	h.add_child(control)
	return h


static func gap(px: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, px)
	return c


# Línea fina para separar bloques dentro de un panel.
static func rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = LINE
	r.custom_minimum_size = Vector2(0, 2)
	return r


# Panel con columna dentro. Devuelve [panel, columna]: se añade el panel y se llena la columna.
static func panel(width: float) -> Array:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(width, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", GAP)
	p.add_child(v)
	return [p, v]


# Cuadradito de color (el color de un jugador).
static func chip(color: Color, size: float = 18.0) -> Panel:
	var c := Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(int(size * 0.5))
	c.add_theme_stylebox_override("panel", s)
	c.custom_minimum_size = Vector2(size, size)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return c
