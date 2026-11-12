extends CanvasLayer
# Toda la interfaz de la partida, armada por código.

var game = null
var _root: Control
var _timer: Label
var _scores: RichTextLabel
var _feed: RichTextLabel
var _status: Label
var _ammo: Label
var _dash: Label
var _flash: Label
var _flash_t: float = 0.0
var _count: Label
var _marker: ColorRect
var _cross: ColorRect
var _overlay: ColorRect
var _overlay_text: RichTextLabel
var _link: LinkButton
var _feed_lines: Array = []
var _last_count: int = -1
var _last_t: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_cross = ColorRect.new()
	_cross.color = Color(1, 1, 1, 0.9)
	_cross.size = Vector2(6, 6)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_cross)

	_marker = ColorRect.new()
	_marker.size = Vector2(18, 18)
	_marker.pivot_offset = Vector2(9, 9)
	_marker.rotation = PI / 4.0
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_marker)

	_timer = _label(40)
	_status = _label(24)
	_ammo = _label(28)
	_ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dash = _label(22)
	_dash.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_flash = _label(52)
	_count = _label(120)
	_scores = _rich(20)
	_feed = _rich(17)

	_overlay = ColorRect.new()
	_overlay.color = Color(0.05, 0.06, 0.12, 0.78)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	_root.add_child(_overlay)
	_overlay_text = _rich(26)
	_overlay_text.visible = false
	_link = LinkButton.new()
	_link.text = "Jorge Coffee"
	_link.uri = "https://jorge-coffee.onrender.com/"
	_link.add_theme_font_size_override("font_size", 13)
	_link.modulate = Color(1, 1, 1, 0.65)
	_link.visible = false
	_root.add_child(_link)


func _label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", maxi(5, int(font_size * 0.2)))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(l)
	return l


func _rich(font_size: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.scroll_active = false
	r.fit_content = true
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", font_size)
	r.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	r.add_theme_constant_override("outline_size", 6)
	_root.add_child(r)
	return r


func flash(text: String, color: Color = Color.WHITE) -> void:
	_flash.text = text
	_flash.modulate = color
	_flash_t = 1.4


func add_feed(text: String, color: Color) -> void:
	_feed_lines.append({"t": 5.0, "bb": "[color=#%s]%s[/color]" % [color.to_html(false), text]})
	if _feed_lines.size() > 5:
		_feed_lines.pop_front()


func show_pause(on: bool) -> void:
	_overlay.visible = on
	_overlay_text.visible = on
	_link.visible = on
	if on:
		var title: String = "PAUSA"
		var note: String = ""
		if game.online:
			title = "MENÚ"
			note = "\n[font_size=18]La partida sigue mientras tanto[/font_size]"
		_overlay_text.text = "[center][font_size=54]%s[/font_size]%s\n\nWASD moverse   ·   Mouse apuntar\nClic izquierdo disparar   ·   Clic derecho apuntar fino\nEspacio saltar   ·   Shift dash   ·   R recargar\n\nEsc para seguir   ·   Q para salir al menú[/center]" % [title, note]


func show_end() -> void:
	var ms = game.match_state
	var rank: Array = ms.ranking()
	var top = rank[0]
	var title: String = "¡GANASTE!" if top == game.human else "Ganó %s" % top.display_name
	if rank.size() > 1 and rank[1].score == top.score:
		title = "¡Empate arriba!"
	var bb: String = "[center][font_size=58][color=#%s]%s[/color][/font_size]\n\n" % [top.color.to_html(false), title]
	var i: int = 1
	for p in rank:
		bb += "[color=#%s]%d.  %s   %d[/color]\n" % [p.color.to_html(false), i, p.display_name, p.score]
		i += 1
	if game.authority:
		bb += "\nEnter: otra ronda   ·   Q: salir al menú[/center]"
	else:
		bb += "\nEsperando a que el host lance otra ronda   ·   Q: salir[/center]"
	_overlay_text.text = bb
	_overlay.visible = true
	_overlay_text.visible = true
	_link.visible = true


func _process(delta: float) -> void:
	if game == null or game.match_state == null or game.human == null:
		return
	var ms = game.match_state
	var h = game.human
	var vs: Vector2 = get_viewport().get_visible_rect().size

	_cross.position = vs * 0.5 - Vector2(3, 3)
	_cross.visible = h.is_bearer and h.alive

	var t: int = int(ceil(ms.time_left))
	_timer.text = "%d:%02d" % [int(t / 60.0), t % 60]
	_timer.position = Vector2(vs.x * 0.5 - 150.0, 10.0)
	_timer.size = Vector2(300.0, 50.0)
	_timer.modulate = Color("ff6b6b") if t <= 10 else Color.WHITE
	_timer.visible = not ms.is_waiting()
	if ms.is_playing() and t != _last_t:
		_last_t = t
		if t <= 10 and t > 0:
			Sfx.play("tick", 1.2)

	var bb: String = ""
	for p in ms.ranking():
		var mark: String = ">> " if p.is_bearer else ""
		var me: String = " (tú)" if (game.online and p == h) else ""
		bb += "[right][color=#%s]%s%s%s   %d[/color][/right]\n" % [p.color.to_html(false), mark, p.display_name, me, p.score]
	_scores.text = bb
	_scores.position = Vector2(vs.x - 340.0, 14.0)
	_scores.size = Vector2(324.0, 10.0)

	var fb: String = ""
	for line in _feed_lines:
		line["t"] -= delta
		fb += line["bb"] + "\n"
	while _feed_lines.size() > 0 and _feed_lines[0]["t"] <= 0.0:
		_feed_lines.pop_front()
	_feed.text = fb
	_feed.position = Vector2(16.0, 14.0)
	_feed.size = Vector2(460.0, 10.0)

	if ms.is_waiting():
		_status.text = "Esperando a los demás jugadores..."
		_status.modulate = Color.WHITE
	elif not h.alive:
		_status.text = "Te pintaron. Vuelves en %d" % int(ceil(h.respawn_timer))
		_status.modulate = Color("ff6b6b")
	elif h.is_bearer:
		_status.text = "TIENES EL LANZADOR: dispara y que no te toquen"
		_status.modulate = Color("ffe14d")
	elif h.stun_timer > 0.0:
		_status.text = "Aturdido..."
		_status.modulate = Color("ff6b6b")
	elif ms.bearer != null:
		_status.text = "Toca a %s para robarle el Lanzador" % ms.bearer.display_name
		_status.modulate = Color.WHITE
	_status.position = Vector2(vs.x * 0.5 - 450.0, vs.y - 62.0)
	_status.size = Vector2(900.0, 40.0)

	_ammo.visible = h.is_bearer
	if h.reload_timer > 0.0:
		_ammo.text = "Recargando..."
	else:
		_ammo.text = "Bolas %d/%d" % [h.ammo, Tuning.magazine]
	_ammo.position = Vector2(vs.x - 320.0, vs.y - 64.0)
	_ammo.size = Vector2(300.0, 40.0)

	if h.dash_cd > 0.0:
		_dash.text = "Dash %.1f" % h.dash_cd
		_dash.modulate = Color(1, 1, 1, 0.55)
	else:
		_dash.text = "Dash listo [Shift]"
		_dash.modulate = Color("7dffb0")
	_dash.position = Vector2(20.0, vs.y - 60.0)
	_dash.size = Vector2(300.0, 40.0)

	_flash_t = maxf(0.0, _flash_t - delta)
	_flash.visible = _flash_t > 0.0
	_flash.modulate.a = clampf(_flash_t * 2.0, 0.0, 1.0)
	_flash.position = Vector2(vs.x * 0.5 - 500.0, vs.y * 0.24)
	_flash.size = Vector2(1000.0, 70.0)

	var counting: bool = ms.is_counting()
	_count.visible = counting
	if counting:
		var c: int = int(ceil(ms.countdown))
		_count.text = str(c)
		if c != _last_count:
			_last_count = c
			Sfx.play("tick")
	_count.position = Vector2(vs.x * 0.5 - 200.0, vs.y * 0.5 - 120.0)
	_count.size = Vector2(400.0, 160.0)

	var b = ms.bearer
	var show_marker: bool = b != null and b != h and b.alive and not ms.is_ended()
	if show_marker:
		var wp: Vector3 = b.global_position + Vector3(0, 3.3, 0)
		var cam: Camera3D = game.cam
		if cam.is_position_behind(wp):
			show_marker = false
		else:
			var sp: Vector2 = cam.unproject_position(wp)
			sp.x = clampf(sp.x, 20.0, vs.x - 20.0)
			sp.y = clampf(sp.y, 70.0, vs.y - 90.0)
			_marker.position = sp - Vector2(9, 9)
			_marker.color = Color("ffe14d")
	_marker.visible = show_marker

	_overlay.position = Vector2.ZERO
	_overlay.size = vs
	_overlay_text.position = Vector2(vs.x * 0.5 - 450.0, vs.y * 0.16)
	_overlay_text.size = Vector2(900.0, 10.0)
	_link.position = Vector2(vs.x - 110.0, vs.y - 28.0)
