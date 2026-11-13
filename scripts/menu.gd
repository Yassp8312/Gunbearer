extends Node
# Menú principal, perfil del jugador, sala de espera, opciones y créditos.
# De fondo corre una partida de puros bots. Todo el aspecto sale de scripts/ui.gd.

const UI = preload("res://scripts/ui.gd")
const CharacterScript = preload("res://scripts/character.gd")
const ArenasScript = preload("res://scripts/arenas.gd")

const DIFF: Array = ["Fácil", "Normal", "Difícil"]
const MAX_PLAYERS: int = 8

var _root: Control
var _holder: HBoxContainer        # aquí va la pantalla actual (uno o dos paneles)
var _screen: String = "main"
var _msg: String = ""

# Piezas de la pantalla actual que hay que refrescar
var _ip_edit: LineEdit = null
var _games_box: VBoxContainer = null
var _rows_box: VBoxContainer = null     # filas de la sala
var _info_label: Label = null
var _bind_buttons: Dictionary = {}      # id de acción -> Button
var _waiting_bind: String = ""          # acción que espera una tecla nueva

# Vista previa del personaje
var _preview_holder: Node3D = null
var _preview_char = null
var _char_label: Label = null
var _class_label: Label = null
var _pro_label: Label = null
var _con_label: Label = null

# Atajos de prueba
var _auto_host: int = 0
var _auto_join: bool = false


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.muted = true
	Music.play("menu")

	var demo = load("res://scenes/main.tscn").instantiate()
	demo.demo = true
	add_child(demo)

	var layer := CanvasLayer.new()
	add_child(layer)
	_root = Control.new()
	_root.theme = UI.theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(UI.BG, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	_holder = HBoxContainer.new()
	_holder.add_theme_constant_override("separation", 28)
	_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(_holder)

	# Pie: marca a la izquierda, enlace a la derecha
	var brand: Label = UI.label("Yassper Design", UI.F_SMALL, UI.MUTED)
	brand.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	brand.offset_left = 18.0
	brand.offset_top = -34.0
	brand.offset_right = 220.0
	brand.offset_bottom = -12.0
	_root.add_child(brand)
	var link := LinkButton.new()
	link.text = "Jorge Coffee"
	link.uri = "https://jorge-coffee.onrender.com/"
	link.add_theme_font_size_override("font_size", UI.F_SMALL)
	link.add_theme_color_override("font_color", UI.MUTED)
	link.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	link.offset_left = -110.0
	link.offset_top = -34.0
	link.offset_right = -18.0
	link.offset_bottom = -12.0
	_root.add_child(link)

	Net.lobby_changed.connect(_refresh)
	Net.games_changed.connect(_refresh)
	Net.net_error.connect(_on_error)
	if Net.last_error != "":
		_msg = Net.last_error
		Net.last_error = ""
	# Si venimos de una partida en red, se vuelve a la sala.
	if Net.mode == "host":
		_show("host")
		Net.push_lobby()
	elif Net.mode == "client":
		_show("client")
	else:
		_show("main")
	_run_test_args()


# Atajos de prueba (ver Net._read_test_args). Cada uno se usa una sola vez.
func _run_test_args() -> void:
	if Net.test.has("screen"):
		_show(str(Net.test["screen"]))
		Net.test.erase("screen")
	if Net.test.has("host"):
		_auto_host = 2 if str(Net.test["host"]) == "" else maxi(1, int(Net.test["host"]))
		Net.test.erase("host")
		_host()
	elif Net.test.has("join"):
		var ip: String = str(Net.test["join"])
		Net.test.erase("join")
		if ip == "auto":
			_auto_join = true
			_open_join()
		else:
			_join(ip if ip != "" else "127.0.0.1")


func _exit_tree() -> void:
	Net.stop_listening()


func _process(delta: float) -> void:
	if _preview_holder != null:
		_preview_holder.rotation.y += delta * 0.9


func _input(event: InputEvent) -> void:
	# Esperando una tecla nueva para un control
	if _waiting_bind != "":
		if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
			_waiting_bind = ""
			_refresh_binds()
			get_viewport().set_input_as_handled()
			return
		var b: Dictionary = Settings.from_event(event)
		if not b.is_empty():
			Settings.bind(_waiting_bind, b)
			_waiting_bind = ""
			_refresh_binds()
			Sfx.play_ui("ui_click")
			get_viewport().set_input_as_handled()
		return
	# Esc vuelve atrás en las pantallas que no son de red
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		if _screen == "solo" or _screen == "options" or _screen == "credits":
			_back()
		elif _screen == "join":
			_close_join()


# ---------- Armado de pantallas ----------

func _show(screen: String) -> void:
	_screen = screen
	for c in _holder.get_children():
		_holder.remove_child(c)
		c.queue_free()
	_ip_edit = null
	_games_box = null
	_rows_box = null
	_info_label = null
	_bind_buttons = {}
	_waiting_bind = ""
	_preview_holder = null
	_preview_char = null
	_char_label = null
	_class_label = null
	_pro_label = null
	_con_label = null
	if screen == "solo":
		_build_solo()
	elif screen == "host":
		_build_lobby(true)
	elif screen == "client":
		_build_lobby(false)
	elif screen == "join":
		_build_join()
	elif screen == "options":
		_build_options()
	elif screen == "credits":
		_build_credits()
	else:
		_screen = "main"
		_build_main()
	_refresh()
	Net.tlog("menú: pantalla %s, %d en la sala" % [_screen, Net.lobby_players.size()])


# Añade un panel a la pantalla y devuelve su columna.
func _panel(width: float) -> VBoxContainer:
	var pv: Array = UI.panel(width)
	pv[0].size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_holder.add_child(pv[0])
	return pv[1]


func _back() -> void:
	Sfx.play_ui("ui_back")
	_show("main")


func _build_main() -> void:
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_holder.add_child(left)
	left.add_child(UI.title("GUNBEARER"))
	var sub: Label = UI.title("Solo uno tiene el arma. Y tenerla te convierte en el blanco.", UI.F_BODY, UI.TEXT)
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	left.add_child(sub)
	left.add_child(UI.gap(10))
	var pv: Array = UI.panel(440.0)
	left.add_child(pv[0])
	var col: VBoxContainer = pv[1]
	col.add_child(UI.button("Jugar contra bots", _show.bind("solo"), true))
	col.add_child(UI.button("Crear partida en red local", _host))
	col.add_child(UI.button("Unirse a una partida", _open_join))
	col.add_child(UI.rule())
	var two := HBoxContainer.new()
	two.add_theme_constant_override("separation", UI.GAP)
	var b1: Button = UI.button("Opciones", _show.bind("options"))
	var b2: Button = UI.button("Créditos", _show.bind("credits"))
	b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	two.add_child(b1)
	two.add_child(b2)
	col.add_child(two)
	col.add_child(UI.button("Salir", _quit))
	if _msg != "":
		col.add_child(UI.label(_msg, UI.F_BODY, UI.BAD, true))
		_msg = ""
	_build_profile()


# Tarjeta "Tu jugador": personaje con vista previa y nombre.
func _build_profile() -> void:
	var col: VBoxContainer = _panel(330.0)
	col.add_child(UI.label("TU JUGADOR", UI.F_SMALL, UI.MUTED, true))

	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = Vector2(274, 210)
	col.add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = true
	sv.msaa_3d = Viewport.MSAA_4X
	svc.add_child(sv)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, 25.0, 0.0)
	sun.light_energy = 0.9
	sv.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 34.0
	sv.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.25, 4.1), Vector3(0, 0.95, 0), Vector3.UP)
	_preview_holder = Node3D.new()
	sv.add_child(_preview_holder)

	var pick := HBoxContainer.new()
	pick.add_theme_constant_override("separation", UI.GAP)
	var prev: Button = UI.button("<", _step_char.bind(-1))
	var next: Button = UI.button(">", _step_char.bind(1))
	prev.custom_minimum_size = Vector2(48, 48)
	next.custom_minimum_size = Vector2(48, 48)
	_char_label = UI.label("", UI.F_H2, UI.TEXT, true)
	_char_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_char_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	pick.add_child(prev)
	pick.add_child(_char_label)
	pick.add_child(next)
	col.add_child(pick)
	# Clase del personaje: su ventaja y su costo.
	_class_label = UI.label("", UI.F_BODY, UI.ACCENT, true)
	_pro_label = UI.label("", UI.F_SMALL, UI.GOOD, true)
	_con_label = UI.label("", UI.F_SMALL, UI.BAD, true)
	col.add_child(_class_label)
	col.add_child(_pro_label)
	col.add_child(_con_label)

	col.add_child(UI.label("Nombre", UI.F_SMALL, UI.MUTED))
	var name_edit := LineEdit.new()
	name_edit.text = Net.my_name
	name_edit.max_length = 14
	name_edit.placeholder_text = "Jugador"
	name_edit.custom_minimum_size = Vector2(0, 42)
	name_edit.text_changed.connect(_on_name_changed)
	col.add_child(name_edit)
	_set_preview(Net.my_char)


func _set_preview(index: int) -> void:
	Net.my_char = posmod(index, CharacterScript.count())
	if _char_label != null:
		_char_label.text = CharacterScript.name_of(Net.my_char)
		var cls: Dictionary = Tuning.class_of(Net.my_char)
		_class_label.text = str(cls["name"]).to_upper()
		_pro_label.text = "+  " + str(cls["pro"])
		_con_label.text = "-  " + str(cls["con"])
	if _preview_holder == null:
		return
	if _preview_char != null:
		_preview_char.queue_free()
	_preview_char = CharacterScript.new()
	if _preview_char.setup(CharacterScript.DEFAULT_PACK, Net.my_char, Color.WHITE):
		_preview_holder.add_child(_preview_char)
	else:
		_preview_char.free()
		_preview_char = null


func _step_char(d: int) -> void:
	_set_preview(Net.my_char + d)
	Net.save_cfg()


func _on_name_changed(t: String) -> void:
	var clean: String = t.strip_edges()
	Net.my_name = clean if clean != "" else "Jugador"


# Control "− valor +" con el mismo aspecto que los botones.
func _stepper(value: int, lo: int, hi: int, on_change: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var state: Array = [clampi(value, lo, hi)]
	var lbl: Label = UI.label(str(state[0]), UI.F_H2, UI.TEXT, true)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	var step := func(d: int) -> void:
		state[0] = clampi(state[0] + d, lo, hi)
		lbl.text = str(state[0])
		on_change.call(state[0])
	var minus: Button = UI.button("-", step.bind(-1))
	var plus: Button = UI.button("+", step.bind(1))
	minus.custom_minimum_size = Vector2(46, 42)
	plus.custom_minimum_size = Vector2(46, 42)
	h.add_child(minus)
	h.add_child(lbl)
	h.add_child(plus)
	return h


func _diff_option() -> OptionButton:
	var ob := OptionButton.new()
	for d in DIFF:
		ob.add_item(d)
	ob.selected = Net.difficulty
	ob.item_selected.connect(_on_diff_changed)
	return ob


func _arena_option() -> OptionButton:
	var ob := OptionButton.new()
	ob.add_item("Aleatorio")
	for i in ArenasScript.count():
		ob.add_item(ArenasScript.name_of(i))
	ob.selected = Net.arena + 1
	ob.item_selected.connect(_on_arena_changed)
	return ob


func _on_bots_changed(v: int) -> void:
	Net.bot_count = v
	if Net.mode == "host":
		Net.push_lobby()


func _on_diff_changed(i: int) -> void:
	Net.difficulty = i
	if Net.mode == "host":
		Net.push_lobby()


func _on_arena_changed(i: int) -> void:
	Net.arena = i - 1
	if Net.mode == "host":
		Net.push_lobby()


func _build_solo() -> void:
	var col: VBoxContainer = _panel(500.0)
	col.add_child(UI.label("Contra bots", UI.F_H1, UI.ACCENT))
	col.add_child(UI.label("Tú contra la máquina. Elige cuántos rivales, qué tan duros y dónde.", UI.F_BODY, UI.MUTED))
	col.add_child(UI.gap(4))
	Net.bot_count = clampi(Net.bot_count, 1, 7)
	col.add_child(UI.row("Bots", _stepper(Net.bot_count, 1, 7, _on_bots_changed)))
	col.add_child(UI.row("Dificultad", _diff_option()))
	col.add_child(UI.row("Campo", _arena_option()))
	col.add_child(UI.gap(4))
	col.add_child(UI.button("¡Jugar!", _play_solo, true))
	col.add_child(UI.button("Volver", _back))


# Sala de espera. La ven igual el host y los clientes; solo el host puede cambiar cosas.
func _build_lobby(is_host: bool) -> void:
	var col: VBoxContainer = _panel(600.0)
	col.add_child(UI.label("Sala de espera", UI.F_H1, UI.ACCENT))
	if is_host:
		var ips: Array = Net.local_ips()
		var hint: String = "Tus amigos entran con «Unirse a una partida»: les debe salir sola."
		if ips.size() > 0:
			hint += " Si no sale, que escriban tu IP: %s" % "  o  ".join(PackedStringArray(ips))
		col.add_child(UI.label(hint, UI.F_SMALL, UI.MUTED))
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 4)
	col.add_child(_rows_box)

	# A la derecha: los ajustes de la partida y los botones.
	var side: VBoxContainer = _panel(400.0)
	side.add_child(UI.label("La partida", UI.F_H2, UI.TEXT))
	if is_host:
		side.add_child(UI.row("Bots de relleno", _stepper(Net.bot_count, 0, 7, _on_bots_changed), 170.0))
		side.add_child(UI.row("Dificultad", _diff_option(), 170.0))
		side.add_child(UI.row("Campo", _arena_option(), 170.0))
		side.add_child(UI.rule())
		side.add_child(UI.button("¡Empezar!", _start_host, true))
		side.add_child(UI.button("Cerrar la sala", _cancel_net))
	else:
		_info_label = UI.label("", UI.F_BODY, UI.MUTED)
		side.add_child(_info_label)
		side.add_child(UI.rule())
		side.add_child(UI.label("Esperando a que el host empiece…", UI.F_BODY, UI.TEXT))
		side.add_child(UI.button("Salir de la sala", _cancel_net))


# Una fila de la sala: color, nombre, personaje y etiqueta.
func _lobby_row(color: Color, who: String, detail: String, tag: String, filled: bool) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = UI.PANEL_SOFT if filled else Color(UI.PANEL_SOFT, 0.35)
	s.set_corner_radius_all(8)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	p.add_theme_stylebox_override("panel", s)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	h.add_child(UI.chip(color if filled else Color(color, 0.3)))
	var n: Label = UI.label(who, UI.F_BODY, UI.TEXT if filled else UI.MUTED.darkened(0.2))
	n.autowrap_mode = TextServer.AUTOWRAP_OFF
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(n)
	var d: Label = UI.label(detail, UI.F_SMALL, UI.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(d)
	if tag != "":
		var t: Label = UI.label(tag, UI.F_SMALL, UI.ACCENT)
		t.autowrap_mode = TextServer.AUTOWRAP_OFF
		t.custom_minimum_size = Vector2(44, 0)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(t)
	return p


func _build_join() -> void:
	var col: VBoxContainer = _panel(520.0)
	col.add_child(UI.label("Unirse a una partida", UI.F_H1, UI.ACCENT))
	col.add_child(UI.label("Partidas en tu red", UI.F_SMALL, UI.MUTED))
	_games_box = VBoxContainer.new()
	_games_box.add_theme_constant_override("separation", 8)
	col.add_child(_games_box)
	col.add_child(UI.rule())
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "192.168.1.20"
	_ip_edit.text_submitted.connect(_join_typed)
	col.add_child(UI.row("O escribe la IP del host", _ip_edit, 200.0))
	col.add_child(UI.button("Conectar a esa IP", _join_typed.bind("")))
	col.add_child(UI.button("Volver", _close_join))


func _build_options() -> void:
	var col: VBoxContainer = _panel(430.0)
	col.add_child(UI.label("Controles", UI.F_H1, UI.ACCENT))
	col.add_child(UI.label("Pulsa un control y luego la tecla o el botón del mouse que quieras. Esc cancela.", UI.F_SMALL, UI.MUTED))
	for a in Settings.ACTIONS:
		var id: String = a["id"]
		var b: Button = UI.button("", _start_bind.bind(id))
		b.custom_minimum_size = Vector2(0, 38)
		_bind_buttons[id] = b
		col.add_child(UI.row(str(a["label"]), b, 170.0))
		b.custom_minimum_size = Vector2(170, 36)
	col.add_child(UI.button("Restablecer controles", _reset_controls))

	var col2: VBoxContainer = _panel(400.0)
	col2.add_child(UI.label("Juego", UI.F_H1, UI.ACCENT))
	var sens := HSlider.new()
	sens.min_value = 0.3
	sens.max_value = 2.5
	sens.step = 0.05
	sens.value = Settings.sens
	sens.value_changed.connect(_on_sens)
	col2.add_child(UI.row("Sensibilidad del mouse", sens, 170.0))
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = Settings.volume
	vol.value_changed.connect(_on_volume)
	col2.add_child(UI.row("Volumen general", vol, 170.0))
	var mus := HSlider.new()
	mus.min_value = 0.0
	mus.max_value = 1.0
	mus.step = 0.05
	mus.value = Settings.music
	mus.value_changed.connect(_on_music)
	col2.add_child(UI.row("Música", mus, 170.0))
	var full := CheckButton.new()
	full.button_pressed = Settings.fullscreen
	full.toggled.connect(_on_fullscreen)
	col2.add_child(UI.row("Pantalla completa", full, 170.0))
	col2.add_child(UI.rule())
	col2.add_child(UI.label("Fijas: Esc abre el menú de la partida, Q sale al menú principal y Enter lanza otra ronda.", UI.F_SMALL, UI.MUTED))
	col2.add_child(UI.gap(4))
	col2.add_child(UI.button("Volver", _back, true))
	_refresh_binds()


func _start_bind(id: String) -> void:
	_waiting_bind = id
	_refresh_binds()


func _refresh_binds() -> void:
	for id in _bind_buttons:
		_bind_buttons[id].text = "Pulsa una tecla…" if id == _waiting_bind else Settings.key_name(id)


func _reset_controls() -> void:
	Settings.reset_controls()
	_refresh_binds()


func _on_sens(v: float) -> void:
	Settings.sens = v
	Settings.save()


func _on_volume(v: float) -> void:
	Settings.volume = v
	Settings.apply()
	Settings.save()


func _on_music(v: float) -> void:
	Settings.music = v
	Settings.apply()
	Settings.save()


func _on_fullscreen(on: bool) -> void:
	Settings.fullscreen = on
	Settings.apply()
	Settings.save()


func _credit(col: VBoxContainer, role: String, who: String, note: String = "") -> void:
	col.add_child(UI.label(role.to_upper(), UI.F_SMALL, UI.MUTED, true))
	col.add_child(UI.label(who, UI.F_H2, UI.TEXT, true))
	if note != "":
		col.add_child(UI.label(note, UI.F_SMALL, UI.MUTED, true))
	col.add_child(UI.gap(6))


func _build_credits() -> void:
	var col: VBoxContainer = _panel(560.0)
	col.add_child(UI.label("Créditos", UI.F_H1, UI.ACCENT, true))
	col.add_child(UI.label("Un juego de Yassper Design", UI.F_BODY, UI.MUTED, true))
	col.add_child(UI.rule())
	col.add_child(UI.gap(2))
	_credit(col, "Idea original y dirección", "Jorge Ricardo Cintra Rad")
	_credit(col, "Programación", "Jorge Ricardo Cintra Rad\nJesús Luis Pérez Martínez")
	_credit(col, "Arte", "Kenney", "Mini Characters  ·  kenney.nl  ·  licencia Creative Commons CC0")
	_credit(col, "Motor", "Godot Engine", "godotengine.org  ·  licencia MIT")
	col.add_child(UI.button("Volver", _back, true))


# ---------- Refresco de lo que cambia solo ----------

func _refresh() -> void:
	if _auto_host > 0 and Net.mode == "host" and Net.lobby_players.size() >= _auto_host:
		_auto_host = 0
		Net.start_match.call_deferred()
	if _auto_join and not Net.found_games.is_empty():
		_auto_join = false
		Net.tlog("partida encontrada: %s" % str(Net.found_games.values()[0]))
		_join.call_deferred(str(Net.found_games.values()[0]["ip"]))

	if _rows_box != null:
		for c in _rows_box.get_children():
			_rows_box.remove_child(c)
			c.queue_free()
		var humans: int = Net.lobby_players.size()
		var bots: int = clampi(Net.bot_count, 0, MAX_PLAYERS - humans)
		if humans + bots < 2:
			bots = 2 - humans
		var me: int = Net.my_id()
		for i in MAX_PLAYERS:
			var color: Color = UI.PLAYER_COLORS[i]
			if i < humans:
				var p: Dictionary = Net.lobby_players[i]
				var tag: String = "HOST" if int(p["peer"]) == 1 else ""
				var who: String = str(p["name"])
				if int(p["peer"]) == me:
					who += "  (tú)"
				var ci: int = int(p.get("char", 0))
				_rows_box.add_child(_lobby_row(color, who, "%s  ·  %s" % [CharacterScript.name_of(ci), str(Tuning.class_of(ci)["name"])], tag, true))
			elif i < humans + bots:
				_rows_box.add_child(_lobby_row(color, "Bot de relleno", DIFF[clampi(Net.difficulty, 0, 2)], "BOT", true))
			elif humans == 0:
				_rows_box.add_child(_lobby_row(color, "Conectando…" if i == 0 else "", "", "", false))
			else:
				_rows_box.add_child(_lobby_row(color, "Esperando jugador…", "", "", false))
	if _info_label != null and Net.lobby_players.size() > 0:
		_info_label.text = "Campo: %s\nDificultad de los bots: %s" % [ArenasScript.name_of(Net.arena), DIFF[clampi(Net.difficulty, 0, 2)]]
	if _games_box != null:
		for c in _games_box.get_children():
			_games_box.remove_child(c)
			c.queue_free()
		if Net.found_games.is_empty():
			_games_box.add_child(UI.label("Buscando partidas…", UI.F_BODY, UI.MUTED, true))
		for key in Net.found_games:
			var g: Dictionary = Net.found_games[key]
			_games_box.add_child(UI.button("Partida de %s   ·   %d dentro" % [str(g["name"]), int(g["players"])], _join.bind(str(g["ip"])), true))


# ---------- Acciones ----------

func _play_solo() -> void:
	Net.close()
	Net.start_match()


func _host() -> void:
	Net.save_cfg()
	if Net.host_game():
		_show("host")
	else:
		_msg = Net.last_error
		Net.last_error = ""
		_show("main")


func _start_host() -> void:
	Net.start_match()


func _open_join() -> void:
	Net.save_cfg()
	Net.start_listening()
	_show("join")


func _close_join() -> void:
	Net.stop_listening()
	_back()


func _join_typed(_t: String) -> void:
	if _ip_edit == null:
		return
	var ip: String = _ip_edit.text.strip_edges()
	if ip != "":
		_join(ip)


func _join(ip: String) -> void:
	Net.stop_listening()
	if Net.join_game(ip):
		_show("client")
	else:
		_msg = Net.last_error
		Net.last_error = ""
		_show("main")


func _cancel_net() -> void:
	Net.close()
	_back()


func _on_error(text: String) -> void:
	Net.last_error = ""
	_msg = text
	_show("main")


func _quit() -> void:
	get_tree().quit()
