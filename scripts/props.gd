extends RefCounted
# Piezas de la arena hechas con formas simples (tema: parque de paintball).
# Solo es lo que se ve: el choque y la sombra siguen siendo la caja que arma main.gd,
# así que ninguna pieza cambia por dónde se pasa ni dónde pega una bola.

const WOOD: Array = [Color("c98b4e"), Color("b87a42"), Color("d49a5c")]
const WOOD_DARK: Color = Color("7a4e28")
const RUBBER: Array = [Color("30303c"), Color("3d3d4b")]
const PAINT: Array = [Color("ff5a5f"), Color("3fa7ff"), Color("ffd23f"), Color("4cd964"), Color("b86bff"), Color("ff9f1c")]

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}


# Devuelve el adorno para una caja de ese tamaño, o null si no hay pieza con ese nombre.
# Las coordenadas son las de la caja: el centro es (0,0,0).
static func make(skin: String, size: Vector3, color: Color, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(skin) + int(pos.x * 31.0) + int(pos.z * 17.0)
	if skin == "fence":
		_fence(root, size, color, rng)
	elif skin == "tires":
		_tires(root, size, color)
	elif skin == "container":
		_container(root, size, color)
	elif skin == "stage":
		_stage(root, size, color)
	elif skin == "crate":
		_crate(root, size, color)
	elif skin == "ramp":
		_ramp(root, size)
	elif skin == "wall":
		_wall(root, size, color, pos)
	else:
		root.free()
		return null
	return root


# ---------- Piezas ----------

# Valla de tablones por las dos caras, con tapa del color de la zona y manchas de pintura.
static func _fence(root: Node3D, s: Vector3, color: Color, rng: RandomNumberGenerator) -> void:
	var n: int = maxi(2, roundi(s.x / 0.62))
	var pw: float = s.x / float(n)
	for face in [-1.0, 1.0]:
		var shift: int = 1 if face > 0.0 else 0
		for i in n:
			_box(root, Vector3(pw - 0.05, s.y - 0.12, 0.12), Vector3(-s.x * 0.5 + pw * (float(i) + 0.5), -0.06, face * (s.z * 0.5 - 0.06)), WOOD[(i + shift) % 3])
		for y in [-0.27, 0.2]:
			_box(root, Vector3(s.x, 0.18, 0.08), Vector3(0, s.y * y, face * (s.z * 0.5 + 0.02)), WOOD_DARK)
		for k in 3:
			var r: float = rng.randf_range(0.18, 0.36)
			var p := Vector3(rng.randf_range(-s.x * 0.4, s.x * 0.4), rng.randf_range(-s.y * 0.3, s.y * 0.35), face * (s.z * 0.5 + 0.012))
			_cyl(root, r, r, 0.02, p, PAINT[rng.randi() % PAINT.size()], Vector3(PI * 0.5, 0, 0))
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(0.14, s.y - 0.12, s.z - 0.24), Vector3(sx * (s.x * 0.5 - 0.07), -0.06, 0), WOOD_DARK)
	_box(root, Vector3(s.x, 0.12, s.z), Vector3(0, s.y * 0.5 - 0.06, 0), color)


# Cuatro pilas de neumáticos con un tablero encima para pisar. La capa de arriba lleva el color de la zona.
static func _tires(root: Node3D, s: Vector3, color: Color) -> void:
	var r: float = minf(s.x, s.z) * 0.25
	var layers: int = maxi(1, roundi(s.y / 0.4))
	var th: float = (s.y - 0.08) / float(layers)
	var inner: float = maxf(0.05, r - th)
	for ix in [-1.0, 1.0]:
		for iz in [-1.0, 1.0]:
			for k in layers:
				var c: Color = color if k == layers - 1 else RUBBER[k % 2]
				_torus(root, inner, r, Vector3(ix * r, -s.y * 0.5 + th * (float(k) + 0.5), iz * r), c)
	_box(root, Vector3(s.x * 0.55, s.y - 0.1, s.z * 0.55), Vector3(0, -0.05, 0), RUBBER[0])
	_box(root, Vector3(s.x - 0.1, 0.08, s.z - 0.1), Vector3(0, s.y * 0.5 - 0.04, 0), WOOD[0])


# Contenedores apilados, con costillas y marco.
static func _container(root: Node3D, s: Vector3, color: Color) -> void:
	var levels: int = 2 if s.y >= 3.0 else 1
	var lh: float = s.y / float(levels)
	var cols: Array = [color, Color("2e86de")]
	for l in levels:
		var c: Color = cols[l % 2]
		var dark: Color = c.darkened(0.2)
		var frame: Color = c.darkened(0.45)
		var y0: float = -s.y * 0.5 + lh * (float(l) + 0.5)
		_box(root, Vector3(s.x - 0.16, lh - 0.1, s.z - 0.16), Vector3(0, y0, 0), c)
		var nr: int = 6
		for i in nr:
			var t: float = (float(i) + 0.5) / float(nr) - 0.5
			for face in [-1.0, 1.0]:
				_box(root, Vector3(0.16, lh - 0.4, 0.08), Vector3(t * (s.x - 0.6), y0, face * (s.z * 0.5 - 0.04)), dark)
				_box(root, Vector3(0.08, lh - 0.4, 0.16), Vector3(face * (s.x * 0.5 - 0.04), y0, t * (s.z - 0.6)), dark)
		for e in [-1.0, 1.0]:
			for face in [-1.0, 1.0]:
				_box(root, Vector3(s.x, 0.14, 0.14), Vector3(0, y0 + e * (lh * 0.5 - 0.07), face * (s.z * 0.5 - 0.07)), frame)
				_box(root, Vector3(0.14, 0.14, s.z), Vector3(face * (s.x * 0.5 - 0.07), y0 + e * (lh * 0.5 - 0.07), 0), frame)
				_box(root, Vector3(0.16, lh, 0.16), Vector3(e * (s.x * 0.5 - 0.08), y0, face * (s.z * 0.5 - 0.08)), frame)


# Tarima de madera con tablones arriba y un borde del color de la zona.
static func _stage(root: Node3D, s: Vector3, color: Color) -> void:
	_box(root, Vector3(s.x, s.y - 0.1, s.z), Vector3(0, -0.05, 0), WOOD_DARK.lightened(0.15))
	var n: int = maxi(2, roundi(s.z / 0.8))
	var pw: float = s.z / float(n)
	for i in n:
		_box(root, Vector3(s.x, 0.1, pw - 0.04), Vector3(0, s.y * 0.5 - 0.05, -s.z * 0.5 + pw * (float(i) + 0.5)), WOOD[i % 3])
	for face in [-1.0, 1.0]:
		_box(root, Vector3(s.x + 0.06, 0.2, 0.08), Vector3(0, s.y * 0.5 - 0.22, face * (s.z * 0.5 + 0.01)), color)
		_box(root, Vector3(0.08, 0.2, s.z + 0.06), Vector3(face * (s.x * 0.5 + 0.01), s.y * 0.5 - 0.22, 0), color)


# Cajón de madera con marco, aspas y tapa de color.
static func _crate(root: Node3D, s: Vector3, color: Color) -> void:
	_box(root, Vector3(s.x - 0.1, s.y - 0.02, s.z - 0.1), Vector3(0, -0.01, 0), WOOD[2])
	for face in [-1.0, 1.0]:
		for e in [-1.0, 1.0]:
			_box(root, Vector3(s.x, 0.2, 0.2), Vector3(0, e * (s.y * 0.5 - 0.1), face * (s.z * 0.5 - 0.1)), WOOD_DARK)
			_box(root, Vector3(0.2, 0.2, s.z), Vector3(face * (s.x * 0.5 - 0.1), e * (s.y * 0.5 - 0.1), 0), WOOD_DARK)
			_box(root, Vector3(0.2, s.y, 0.2), Vector3(e * (s.x * 0.5 - 0.1), 0, face * (s.z * 0.5 - 0.1)), WOOD_DARK)
		var lx: float = Vector2(s.x - 0.4, s.y - 0.4).length()
		_box(root, Vector3(lx, 0.16, 0.06), Vector3(0, 0, face * (s.z * 0.5 - 0.03)), WOOD[1], Vector3(0, 0, atan2(s.y - 0.4, s.x - 0.4)))
		var lz: float = Vector2(s.z - 0.4, s.y - 0.4).length()
		_box(root, Vector3(0.06, 0.16, lz), Vector3(face * (s.x * 0.5 - 0.03), 0, 0), WOOD[1], Vector3(atan2(s.y - 0.4, s.z - 0.4), 0, 0))
	_box(root, Vector3(s.x - 0.4, 0.04, s.z - 0.4), Vector3(0, s.y * 0.5 - 0.01, 0), color)


# Rampa de tablones con largueros a los lados.
static func _ramp(root: Node3D, s: Vector3) -> void:
	var n: int = maxi(2, roundi(s.z / 0.6))
	var pw: float = s.z / float(n)
	for i in n:
		_box(root, Vector3(s.x - 0.3, s.y, pw - 0.04), Vector3(0, 0, -s.z * 0.5 + pw * (float(i) + 0.5)), WOOD[i % 3])
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(0.15, s.y + 0.06, s.z), Vector3(sx * (s.x * 0.5 - 0.075), 0, 0), WOOD_DARK)


# Muro exterior: panel liso, zócalo de tablones por dentro, postes y remate.
static func _wall(root: Node3D, s: Vector3, color: Color, pos: Vector3) -> void:
	var g := Node3D.new()
	root.add_child(g)
	var along_x: bool = s.x > s.z
	var length: float = s.x if along_x else s.z
	var thick: float = s.z if along_x else s.x
	# Cara que da a la arena, en el eje local Z del grupo.
	var inward: float = -signf(pos.z) if along_x else -signf(pos.x)
	if not along_x:
		g.rotation.y = PI * 0.5
	_box(g, Vector3(length, s.y, thick * 0.7), Vector3.ZERO, color)
	var n: int = maxi(2, roundi(length / 2.0))
	var pw: float = length / float(n)
	for i in n:
		_box(g, Vector3(pw - 0.06, 1.8, 0.1), Vector3(-length * 0.5 + pw * (float(i) + 0.5), -s.y * 0.5 + 0.9, inward * (thick * 0.5 - 0.05)), WOOD[i % 3])
	var posts: int = maxi(2, roundi(length / 4.0))
	for i in posts + 1:
		_box(g, Vector3(0.35, s.y, thick + 0.1), Vector3(-length * 0.5 + length * float(i) / float(posts), 0, 0), WOOD_DARK)
	_box(g, Vector3(length, 0.16, 0.08), Vector3(0, -s.y * 0.5 + 1.9, inward * (thick * 0.5)), Color("fff3b0"))
	_box(g, Vector3(length, 0.25, thick + 0.1), Vector3(0, s.y * 0.5 - 0.12, 0), WOOD_DARK)


# Lo que rodea la arena y las marcas del suelo. No tiene choque.
static func scenery(arena: float) -> Node3D:
	var root := Node3D.new()
	var line: Color = Color("f4faef")
	# Marcas del suelo
	var ring: MeshInstance3D = _torus(root, 8.6, 8.9, Vector3(0, 0.0, 0), line)
	ring.scale = Vector3(1.0, 0.04, 1.0)
	var m: float = arena - 2.5
	for face in [-1.0, 1.0]:
		_box(root, Vector3(m * 2.0, 0.02, 0.25), Vector3(0, 0.006, face * m), line)
		_box(root, Vector3(0.25, 0.02, m * 2.0), Vector3(face * m, 0.006, 0), line)
	# Torres de focos en las esquinas, por fuera
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var base := Vector3(sx * (arena + 3.5), 0, sz * (arena + 3.5))
			_cyl(root, 0.22, 0.3, 11.0, base + Vector3(0, 5.5, 0), Color("5c6470"))
			var head: MeshInstance3D = _box(root, Vector3(2.6, 1.3, 0.5), base + Vector3(0, 11.2, 0), Color("3a3f4a"))
			head.rotation.y = atan2(sx, sz)
			var lamp: MeshInstance3D = _box(root, Vector3(2.2, 0.9, 0.1), base + Vector3(-sx * 0.2, 11.2, -sz * 0.2), Color("fff6c9"), Vector3.ZERO, true)
			lamp.rotation.y = atan2(sx, sz)
	# Árboles alrededor, asomando por encima del muro
	var greens: Array = [Color("4fb05a"), Color("63c468"), Color("3f9a50")]
	for i in 14:
		var ang: float = TAU * (float(i) + 0.5) / 14.0
		var d: float = arena + 8.0 + 2.5 * float(i % 3)
		var p := Vector3(cos(ang) * d * 1.25, 0, sin(ang) * d * 1.25)
		var h: float = 5.0 + float(i % 2)
		_cyl(root, 0.45, 0.65, h, p + Vector3(0, h * 0.5, 0), Color("8a5a2b"))
		_ball(root, 3.4, p + Vector3(0, h + 2.0, 0), greens[i % 3])
		_ball(root, 2.4, p + Vector3(0.8, h + 4.4, -0.5), greens[(i + 1) % 3])
	return root


# ---------- Formas básicas (mallas y materiales compartidos) ----------

static func _mat(color: Color, glow: bool = false) -> StandardMaterial3D:
	var key: String = color.to_html() + ("g" if glow else "")
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.85
		if glow:
			m.emission_enabled = true
			m.emission = color
			m.emission_energy_multiplier = 1.5
		_mats[key] = m
	return _mats[key]


static func _add(root: Node3D, mesh: Mesh, pos: Vector3, color: Color, rot: Vector3, glow: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color, glow)
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


static func _box(root: Node3D, size: Vector3, pos: Vector3, color: Color, rot: Vector3 = Vector3.ZERO, glow: bool = false) -> MeshInstance3D:
	var key: String = "b%.2f_%.2f_%.2f" % [size.x, size.y, size.z]
	if not _meshes.has(key):
		var bm := BoxMesh.new()
		bm.size = size
		_meshes[key] = bm
	return _add(root, _meshes[key], pos, color, rot, glow)


static func _cyl(root: Node3D, top: float, bottom: float, height: float, pos: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var key: String = "c%.2f_%.2f_%.2f" % [top, bottom, height]
	if not _meshes.has(key):
		var cm := CylinderMesh.new()
		cm.top_radius = top
		cm.bottom_radius = bottom
		cm.height = height
		cm.radial_segments = 14
		cm.rings = 1
		_meshes[key] = cm
	return _add(root, _meshes[key], pos, color, rot)


static func _torus(root: Node3D, inner: float, outer: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var key: String = "t%.2f_%.2f" % [inner, outer]
	if not _meshes.has(key):
		var tm := TorusMesh.new()
		tm.inner_radius = inner
		tm.outer_radius = outer
		tm.rings = 20
		tm.ring_segments = 8
		_meshes[key] = tm
	return _add(root, _meshes[key], pos, color, Vector3.ZERO)


static func _ball(root: Node3D, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var key: String = "s%.2f" % radius
	if not _meshes.has(key):
		var sm := SphereMesh.new()
		sm.radius = radius
		sm.height = radius * 2.0
		sm.radial_segments = 10
		sm.rings = 5
		_meshes[key] = sm
	return _add(root, _meshes[key], pos, color, Vector3.ZERO)
