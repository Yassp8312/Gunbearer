extends Node
# Menú principal y sala de espera. De fondo corre una partida de puros bots.

const DIFF: Array = ["Fácil", "Normal", "Difícil"]

var _ui: Control
var _panel: VBoxContainer
var _screen: String = "main"
var _msg: String = ""
var _ip_edit: LineEdit = null
var _players_label: Label = null
var _info_label: Label = null
var _games_box: VBoxContainer = null
var _auto_host: int = 0
var _auto_join: bool = false


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.muted = true

	var demo = load("res://scenes/main.tscn").instantiate()
	demo.demo = true
	add_child(demo)

	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_ui)

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.06, 0.14, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(center)
	_panel = VBoxContainer.new()
	_panel.custom_minimum_size = Vector2(480, 0)
	_panel.add_theme_constant_override("separation", 10)
	center.add_child(_panel)

	var brand := Label.new()
	brand.text = "Yassper Design"
	brand.add_theme_font_size_override("font_size", 13)
	brand.modulate = Color(1, 1, 1, 0.6)
	brand.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	brand.offset_left = 14.0
	brand.offset_top = -32.0
	brand.offset_right = 200.0
	brand.offset_bottom = -10.0
	_ui.add_child(brand)
	var link := LinkButton.new()
	link.text = "Jorge Coffee"
	link.uri = "https://jorge-coffee.onrender.com/"
	link.add_theme_font_size_override("font_size", 13)
	link.modulate = Color(1, 1, 1, 0.65)
	link.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	link.offset_left = -104.0
	link.offset_top = -32.0
	link.offset_right = -14.0
	link.offset_bottom = -10.0
	_ui.add_child(link)

	Net.lobby_changed.connect(_refresh)
	Net.games_changed.connect(_refresh)
	Net.net_error.connect(_on_error)
	if Net.last_error != "":
		_msg = Net.last_error
		Net.last_error = ""
	_show("main")
	_run_test_args()


# Atajos de prueba (ver Net._read_test_args). Cada uno se usa una sola vez.
func _run_test_args() -> void:
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


# ---------- Piezas ----------

func _text(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if size <= 24:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", maxi(4, int(size * 0.14)))
	_panel.add_child(l)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	_panel.add_child(b)
	return b


func _row(text: String, control: Control) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	control.custom_minimum_size = Vector2(210, 40)
	h.add_child(control)
	_panel.add_child(h)


func _gap(px: int) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, px)
	_panel.add_child(c)


func _bots_spin(min_bots: int) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = min_bots
	sb.max_value = 7
	sb.value = clampi(Net.bot_count, min_bots, 7)
	Net.bot_count = int(sb.value)
	sb.value_changed.connect(_on_bots_changed)
	return sb


func _diff_option() -> OptionButton:
	var ob := OptionButton.new()
	for d in DIFF:
		ob.add_item(d)
	ob.selected = Net.difficulty
	ob.item_selected.connect(_on_diff_changed)
	return ob


func _on_bots_changed(v: float) -> void:
	Net.bot_count = int(v)
	if Net.mode == "host":
		Net.push_lobby()


func _on_diff_changed(i: int) -> void:
	Net.difficulty = i
	if Net.mode == "host":
		Net.push_lobby()


func _on_name_changed(t: String) -> void:
	var clean: String = t.strip_edges()
	Net.my_name = clean if clean != "" else "Jugador"


# ---------- Pantallas ----------

func _show(screen: String) -> void:
	_screen = screen
	for c in _panel.get_children():
		_panel.remove_child(c)
		c.queue_free()
	_ip_edit = null
	_players_label = null
	_info_label = null
	_games_box = null
	if screen == "main":
		_build_main()
	elif screen == "solo":
		_build_solo()
	elif screen == "host":
		_build_host()
	elif screen == "join":
		_build_join()
	elif screen == "client":
		_build_client()
	_refresh()


func _build_main() -> void:
	_text("GUNBEARER", 84, Color("ffe14d"))
	_text("Solo uno tiene el arma. Y tenerla te convierte en el blanco.", 18)
	_gap(14)
	var name_edit := LineEdit.new()
	name_edit.text = Net.my_name
	name_edit.max_length = 14
	name_edit.text_changed.connect(_on_name_changed)
	_row("Tu nombre", name_edit)
	_gap(4)
	_button("Jugar contra bots", _show.bind("solo"))
	_button("Crear partida en red local", _host)
	_button("Unirse a una partida", _open_join)
	_button("Salir", _quit)
	if _msg != "":
		_gap(4)
		_text(_msg, 17, Color("ff8a8a"))
		_msg = ""


func _build_solo() -> void:
	_text("Contra bots", 46, Color("ffe14d"))
	_gap(8)
	_row("Cuántos bots", _bots_spin(1))
	_row("Dificultad", _diff_option())
	_gap(8)
	_button("¡Jugar!", _play_solo)
	_button("Volver", _show.bind("main"))


func _build_host() -> void:
	_text("Tu partida", 46, Color("ffe14d"))
	var ips: Array = Net.local_ips()
	var ip_text: String = "Los demás le dan a «Unirse a una partida» y debe salirles sola."
	if ips.size() > 0:
		ip_text += " Si no sale, que escriban tu IP: %s" % "  o  ".join(PackedStringArray(ips))
	_text(ip_text, 16)
	_gap(4)
	_players_label = _text("", 22)
	_gap(4)
	_row("Bots de relleno", _bots_spin(0))
	_row("Dificultad de los bots", _diff_option())
	_gap(8)
	_button("¡Empezar!", _start_host)
	_button("Cancelar", _cancel_net)


func _build_join() -> void:
	_text("Unirse", 46, Color("ffe14d"))
	_text("Partidas en tu red", 18)
	_games_box = VBoxContainer.new()
	_games_box.add_theme_constant_override("separation", 8)
	_panel.add_child(_games_box)
	_gap(8)
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "192.168.1.20"
	_ip_edit.text_submitted.connect(_join_typed)
	_row("O escribe la IP del host", _ip_edit)
	_button("Conectar a esa IP", _join_typed.bind(""))
	_button("Volver", _close_join)


func _build_client() -> void:
	_text("Sala", 46, Color("ffe14d"))
	_players_label = _text("Conectando...", 22)
	_info_label = _text("", 16)
	_gap(4)
	_text("Esperando a que el host empiece...", 18)
	_gap(8)
	_button("Salir", _cancel_net)


func _refresh() -> void:
	if _auto_host > 0 and Net.mode == "host" and Net.lobby_players.size() >= _auto_host:
		_auto_host = 0
		Net.start_match.call_deferred()
	if _auto_join and not Net.found_games.is_empty():
		_auto_join = false
		Net.tlog("partida encontrada: %s" % str(Net.found_games.values()[0]))
		_join.call_deferred(str(Net.found_games.values()[0]["ip"]))
	if _players_label != null:
		var t: String = ""
		for p in Net.lobby_players:
			var tag: String = "  (host)" if int(p["peer"]) == 1 else ""
			t += "%s%s\n" % [str(p["name"]), tag]
		if t == "":
			t = "Conectando..."
		_players_label.text = t.strip_edges()
	if _info_label != null and Net.lobby_players.size() > 0:
		_info_label.text = "Bots de relleno: %d   ·   Dificultad: %s" % [Net.bot_count, DIFF[clampi(Net.difficulty, 0, 2)]]
	if _games_box != null:
		for c in _games_box.get_children():
			_games_box.remove_child(c)
			c.queue_free()
		if Net.found_games.is_empty():
			var l := Label.new()
			l.text = "Buscando..."
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.modulate = Color(1, 1, 1, 0.7)
			_games_box.add_child(l)
		for key in Net.found_games:
			var g: Dictionary = Net.found_games[key]
			var b := Button.new()
			b.text = "Partida de %s   (%d dentro)" % [str(g["name"]), int(g["players"])]
			b.custom_minimum_size = Vector2(0, 44)
			b.add_theme_font_size_override("font_size", 18)
			b.pressed.connect(_join.bind(str(g["ip"])))
			_games_box.add_child(b)


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
	_show("main")


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
	_show("main")


func _on_error(text: String) -> void:
	Net.last_error = ""
	_msg = text
	_show("main")


func _quit() -> void:
	get_tree().quit()
