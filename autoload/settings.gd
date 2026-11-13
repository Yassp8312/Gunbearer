extends Node
# Opciones del jugador: controles reasignables, sensibilidad, volumen y pantalla completa.
# Las acciones viven en el InputMap con el prefijo "gb_"; el resto del juego pregunta por
# la acción (Input.is_action_pressed("gb_jump")), nunca por una tecla concreta.

signal changed

const PATH: String = "user://settings.cfg"

# Orden en que salen en la pantalla de opciones. "k" = tecla física, "m" = botón del mouse.
const ACTIONS: Array = [
	{"id": "gb_forward", "label": "Avanzar", "def": {"k": KEY_W}},
	{"id": "gb_back", "label": "Retroceder", "def": {"k": KEY_S}},
	{"id": "gb_left", "label": "Izquierda", "def": {"k": KEY_A}},
	{"id": "gb_right", "label": "Derecha", "def": {"k": KEY_D}},
	{"id": "gb_jump", "label": "Saltar", "def": {"k": KEY_SPACE}},
	{"id": "gb_dash", "label": "Dash", "def": {"k": KEY_SHIFT}},
	{"id": "gb_shoot", "label": "Disparar", "def": {"m": MOUSE_BUTTON_LEFT}},
	{"id": "gb_aim", "label": "Apuntar fino", "def": {"m": MOUSE_BUTTON_RIGHT}},
	{"id": "gb_reload", "label": "Recargar", "def": {"k": KEY_R}},
]

var binds: Dictionary = {}      # id de acción -> {"k": código} o {"m": botón}
var sens: float = 1.0           # multiplica a Tuning.mouse_sens
var volume: float = 0.8         # volumen general, 0 a 1
var music: float = 0.6          # volumen de la música, 0 a 1
var fullscreen: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in ACTIONS:
		binds[a["id"]] = a["def"].duplicate()
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for a in ACTIONS:
			if not cf.has_section_key("controls", a["id"]):
				continue
			var v = cf.get_value("controls", a["id"])
			if typeof(v) == TYPE_DICTIONARY and (v.has("k") or v.has("m")):
				binds[a["id"]] = v
		sens = clampf(float(cf.get_value("options", "sens", sens)), 0.2, 3.0)
		volume = clampf(float(cf.get_value("options", "volume", volume)), 0.0, 1.0)
		music = clampf(float(cf.get_value("options", "music", music)), 0.0, 1.0)
		fullscreen = bool(cf.get_value("options", "fullscreen", fullscreen))
	apply()


# Lleva las opciones al motor: InputMap, volumen y modo de ventana.
func apply() -> void:
	for a in ACTIONS:
		var id: String = a["id"]
		if InputMap.has_action(id):
			InputMap.action_erase_events(id)
		else:
			InputMap.add_action(id)
		InputMap.action_add_event(id, _event(binds[id]))
	AudioServer.set_bus_mute(0, volume <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))
	var mb: int = AudioServer.get_bus_index(Music.BUS)
	if mb >= 0:
		AudioServer.set_bus_mute(mb, music <= 0.001)
		AudioServer.set_bus_volume_db(mb, linear_to_db(maxf(music, 0.001)))
	if DisplayServer.get_name() != "headless":
		var mode: int = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
	changed.emit()


func _event(b: Dictionary) -> InputEvent:
	if b.has("m"):
		var mb := InputEventMouseButton.new()
		mb.button_index = int(b["m"])
		return mb
	var k := InputEventKey.new()
	k.physical_keycode = int(b["k"])
	return k


# Asigna una tecla o botón a una acción. Si otra acción lo usaba, se intercambian.
func bind(id: String, b: Dictionary) -> void:
	for other in binds:
		if other != id and binds[other] == b:
			binds[other] = binds[id]
	binds[id] = b
	apply()
	save()


func reset_controls() -> void:
	for a in ACTIONS:
		binds[a["id"]] = a["def"].duplicate()
	apply()
	save()


# Convierte un evento del teclado o del mouse en una asignación, o {} si no sirve.
func from_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey and event.pressed and not event.echo:
		return {"k": int(event.physical_keycode)}
	if event is InputEventMouseButton and event.pressed:
		return {"m": int(event.button_index)}
	return {}


# Nombre corto de lo que está asignado, para mostrar en opciones, pausa y avisos.
func key_name(id: String) -> String:
	var b: Dictionary = binds.get(id, {})
	if b.has("m"):
		var m: int = int(b["m"])
		if m == MOUSE_BUTTON_LEFT:
			return "Clic izq."
		if m == MOUSE_BUTTON_RIGHT:
			return "Clic der."
		if m == MOUSE_BUTTON_MIDDLE:
			return "Clic central"
		if m == MOUSE_BUTTON_WHEEL_UP:
			return "Rueda arriba"
		if m == MOUSE_BUTTON_WHEEL_DOWN:
			return "Rueda abajo"
		return "Botón %d" % m
	if b.has("k"):
		var code: int = int(b["k"])
		if code == KEY_SPACE:
			return "Espacio"
		if code == KEY_SHIFT:
			return "Shift"
		if code == KEY_CTRL:
			return "Ctrl"
		if code == KEY_ALT:
			return "Alt"
		return OS.get_keycode_string(code)
	return "?"


func save() -> void:
	if not Net.test.is_empty():
		return  # una prueba no debe pisar tu configuración
	var cf := ConfigFile.new()
	cf.load(PATH)
	for id in binds:
		cf.set_value("controls", id, binds[id])
	cf.set_value("options", "sens", sens)
	cf.set_value("options", "volume", volume)
	cf.set_value("options", "music", music)
	cf.set_value("options", "fullscreen", fullscreen)
	cf.save(PATH)
