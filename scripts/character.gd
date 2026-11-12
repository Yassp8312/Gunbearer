extends Node3D
# Cuerpo visible de un jugador: un modelo con esqueleto y sus animaciones.
# player.gd dice en qué estado está el jugador; aquí solo se elige qué animación suena.
# No sabe nada de reglas ni de red.

const DEFAULT_PACK: String = "kenney"

# Cada pack dice dónde están sus modelos y cómo se llaman sus animaciones.
# Los estados que entiende play(): idle, armed_idle, run, jump, fall, dash, stun, dead.
const PACKS: Dictionary = {
	"kenney": {
		"path": "res://assets/kenney_mini/%s.glb",
		"models": [
			"character-male-a", "character-female-a", "character-alien", "character-robot",
			"character-knight", "character-zombie", "character-worker", "character-raider",
			"character-male-b", "character-female-b", "character-soldier", "character-male-c",
			"character-female-c", "character-male-d", "character-female-d", "character-male-e",
			"character-female-e", "character-male-f", "character-female-f", "character-male-g",
		],
		"height": 1.75,
		"tint": 0.5,
		"anims": {
			"idle": "idle", "armed_idle": "holding-right", "run": "sprint", "jump": "jump",
			"fall": "fall", "dash": "sprint", "stun": "emote-no", "dead": "fall",
		},
		"loops": ["idle", "armed_idle", "run", "jump", "fall", "dash", "stun", "dead"],
		# Con el Lanzador, estos huesos copian la pose de esta animación mientras el resto sigue corriendo o saltando.
		"hold_anim": "holding-right",
		"hold_bones": ["arm-right"],
		"weapon": "res://assets/kenney_mini/weapon-shooter.glb",
		"weapon_length": 0.9,
	},
}

var armed: bool = false     # lleva el Lanzador: el brazo apunta

var _pack: Dictionary = {}
var _anim: AnimationPlayer = null
var _skel: Skeleton3D = null
var _hold_pose: Dictionary = {}   # índice de hueso -> rotación
var _mats: Array = []       # [{"mat": StandardMaterial3D, "base": Color, "tex": bool}]
var _state: String = ""


# Carga el modelo. Devuelve false si el pack o el archivo no existen (y entonces se usa la cápsula).
func setup(pack_name: String, index: int, color: Color) -> bool:
	if not PACKS.has(pack_name):
		return false
	_pack = PACKS[pack_name]
	var models: Array = _pack["models"]
	var path: String = str(_pack["path"]) % str(models[index % models.size()])
	if not ResourceLoader.exists(path):
		return false
	var scene = load(path)
	if scene == null:
		return false
	var model: Node3D = scene.instantiate()
	add_child(model)

	# Los modelos glTF miran hacia +Z y el juego hacia -Z.
	model.rotation.y = PI
	# Escalar a la altura del jugador y apoyar los pies en el suelo.
	var box: AABB = _bounds(model)
	if box.size.y > 0.001:
		var s: float = float(_pack["height"]) / box.size.y
		model.scale = Vector3(s, s, s)
		model.position.y = -box.position.y * s

	for mi in model.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var src = mi.get_active_material(i)
			if not (src is StandardMaterial3D):
				continue
			var mat: StandardMaterial3D = src.duplicate()
			mat.emission = Color.WHITE
			mi.set_surface_override_material(i, mat)
			_mats.append({"mat": mat, "base": mat.albedo_color, "tex": mat.albedo_texture != null})

	var players: Array = model.find_children("*", "AnimationPlayer", true, false)
	if players.size() > 0:
		_anim = players[0]
		var anims: Dictionary = _pack["anims"]
		for st in _pack["loops"]:
			var a: Animation = _anim.get_animation(str(anims[st])) if _anim.has_animation(str(anims[st])) else null
			if a != null:
				a.loop_mode = Animation.LOOP_LINEAR
		_read_hold_pose(model)
	set_tint(color)
	play("idle")
	return true


# Guarda la pose del brazo armado y la impone después de cada paso de animación.
func _read_hold_pose(model: Node3D) -> void:
	var skels: Array = model.find_children("*", "Skeleton3D", true, false)
	var hold: String = str(_pack.get("hold_anim", ""))
	if skels.is_empty() or hold == "" or not _anim.has_animation(hold):
		return
	_skel = skels[0]
	var a: Animation = _anim.get_animation(hold)
	var bones: Array = _pack["hold_bones"]
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_ROTATION_3D or a.track_get_key_count(t) == 0:
			continue
		var path: NodePath = a.track_get_path(t)
		if path.get_subname_count() == 0:
			continue
		var bone: String = path.get_subname(0)
		if bones.has(bone) and _skel.find_bone(bone) >= 0:
			_hold_pose[_skel.find_bone(bone)] = a.track_get_key_value(t, 0)
	if not _hold_pose.is_empty():
		_anim.mixer_applied.connect(_apply_hold)


func _apply_hold() -> void:
	if not armed or _state == "dead" or _state == "stun":
		return
	for b in _hold_pose:
		_skel.set_bone_pose_rotation(b, _hold_pose[b])


# Modelo del Lanzador de este pack, ya a escala y mirando al frente. null si no hay.
func make_weapon() -> Node3D:
	var path: String = str(_pack.get("weapon", ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var w: Node3D = load(path).instantiate()
	var box: AABB = _bounds(w)
	var longest: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
	if longest > 0.001:
		var s: float = float(_pack["weapon_length"]) / longest
		w.scale = Vector3(s, s, s)
	w.rotation.y = PI
	return w


# Caja que envuelve todas las mallas, en el espacio del modelo.
func _bounds(model: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var xf: Transform3D = Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != model and n is Node3D:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var b: AABB = xf * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


# Color del jugador. Los modelos con textura se tiñen sin perder el dibujo.
func set_tint(color: Color) -> void:
	var t: float = float(_pack.get("tint", 1.0))
	var n: int = 0
	for m in _mats:
		if m["tex"]:
			m["mat"].albedo_color = Color.WHITE.lerp(color, t)
		else:
			m["mat"].albedo_color = color if n == 0 else color.darkened(0.45)
		n += 1


# Pintado entero de un color (al ser eliminado).
func paint(color: Color) -> void:
	for m in _mats:
		m["mat"].albedo_color = color


# Brillo de protección (inmunidad al robo, escudo al reaparecer).
func glow(on: bool, energy: float) -> void:
	for m in _mats:
		m["mat"].emission_enabled = on
		m["mat"].emission_energy_multiplier = energy


func play(state: String, speed: float = 1.0) -> void:
	if _anim == null:
		return
	_anim.speed_scale = speed
	if state == _state:
		return
	_state = state
	var anims: Dictionary = _pack["anims"]
	var anim_name: String = str(anims.get(state, anims["idle"]))
	if _anim.has_animation(anim_name):
		_anim.play(anim_name, 0.12)
