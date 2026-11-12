extends RefCounted
# Los campos de juego. Cada uno es una función que coloca cajas (con su pieza de props.gd)
# y trampolines llamando a main._box y main._pad. Para añadir un campo: una entrada en
# NAMES y su función en build().
#
# Reglas para que un campo sea justo (el juego es competitivo):
# - Simétrico: lo que hay en un lado está también en el opuesto.
# - Los ocho puntos de salida están en un círculo de radio 19 m, a 22,5° + k·45°.
#   No se pone nada a menos de 3 m de ellos.
# - Los bots no saben rodear obstáculos largos: ninguna pieza de más de 6 m de largo.
# - Se sube a 1,2 m saltando; a más altura, con rampa o trampolín.

const NAMES: Array = ["El Parque", "El Muelle", "La Torre"]
const SIZE: float = 24.0   # media anchura del campo

const RED: Color = Color("ff5a5f")
const BLUE: Color = Color("3fa7ff")
const YELLOW: Color = Color("ffd23f")
const GREEN: Color = Color("4cd964")
const PURPLE: Color = Color("b86bff")
const ORANGE: Color = Color("e4572e")


static func count() -> int:
	return NAMES.size()


static func name_of(i: int) -> String:
	if i < 0:
		return "Aleatorio"
	return str(NAMES[i % NAMES.size()])


static func build(i: int, g) -> void:
	var idx: int = posmod(i, NAMES.size())
	var floors: Array = [Color("86c97a"), Color("b7c0cf"), Color("e3cd9c")]
	_shell(g, floors[idx])
	if idx == 0:
		_parque(g)
	elif idx == 1:
		_muelle(g)
	else:
		_torre(g)


# Piso y muros, iguales en todos los campos.
static func _shell(g, floor_color: Color) -> void:
	var s: float = SIZE
	g._box(Vector3(0, -0.5, 0), Vector3(s * 2.0, 1.0, s * 2.0), floor_color)
	g._box(Vector3(s + 0.5, 3.0, 0), Vector3(1.0, 6.0, s * 2.0 + 2.0), Color("f0e2c4"), Vector3.ZERO, "wall")
	g._box(Vector3(-s - 0.5, 3.0, 0), Vector3(1.0, 6.0, s * 2.0 + 2.0), Color("f0e2c4"), Vector3.ZERO, "wall")
	g._box(Vector3(0, 3.0, s + 0.5), Vector3(s * 2.0 + 2.0, 6.0, 1.0), Color("ead9b6"), Vector3.ZERO, "wall")
	g._box(Vector3(0, 3.0, -s - 0.5), Vector3(s * 2.0 + 2.0, 6.0, 1.0), Color("ead9b6"), Vector3.ZERO, "wall")


# Rampa de 1,2 m de alto que sube hasta `edge` (un punto del borde de una plataforma, a ras de suelo)
# viniendo desde la dirección `out` (unitaria, hacia fuera de la plataforma).
static func _ramp(g, edge: Vector3, out: Vector3) -> void:
	var c: Vector3 = edge + out * 2.4
	g._box(Vector3(c.x, 0.45, c.z), Vector3(3.0, 0.3, 5.0), Color("fdffb6"), Vector3(0.2425, atan2(out.x, out.z), 0), "ramp")


# El Parque: tarima central con rampas, vallas en diagonal, neumáticos y dos torres.
static func _parque(g) -> void:
	g._box(Vector3(0, 0.6, 0), Vector3(8.0, 1.2, 8.0), YELLOW, Vector3.ZERO, "stage")
	g._box(Vector3(0, 1.8, 0), Vector3(3.0, 1.2, 3.0), RED, Vector3.ZERO, "crate")
	_ramp(g, Vector3(0, 0, 4.0), Vector3(0, 0, 1))
	_ramp(g, Vector3(0, 0, -4.0), Vector3(0, 0, -1))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			g._box(Vector3(13.0 * sx, 1.4, 13.0 * sz), Vector3(5.0, 2.8, 1.2), PURPLE, Vector3(0, PI * 0.25 * sx * sz, 0), "fence")
	g._box(Vector3(17.0, 0.6, 0), Vector3(3.0, 1.2, 3.0), GREEN, Vector3.ZERO, "tires")
	g._box(Vector3(-17.0, 0.6, 0), Vector3(3.0, 1.2, 3.0), GREEN, Vector3.ZERO, "tires")
	g._box(Vector3(0, 0.6, 17.0), Vector3(3.0, 1.2, 3.0), BLUE, Vector3.ZERO, "tires")
	g._box(Vector3(0, 0.6, -17.0), Vector3(3.0, 1.2, 3.0), BLUE, Vector3.ZERO, "tires")
	g._box(Vector3(20.0, 2.0, -20.0), Vector3(5.0, 4.0, 5.0), ORANGE, Vector3.ZERO, "container")
	g._box(Vector3(-20.0, 2.0, 20.0), Vector3(5.0, 4.0, 5.0), ORANGE, Vector3.ZERO, "container")
	g._pad(Vector3(15.5, 0.0, -15.5))
	g._pad(Vector3(-15.5, 0.0, 15.5))
	g._pad(Vector3(9.0, 0.0, 9.0))
	g._pad(Vector3(-9.0, 0.0, -9.0))


# El Muelle: cuatro contenedores en cruz alrededor de un trampolín central, con vallas al fondo.
static func _muelle(g) -> void:
	g._pad(Vector3(0, 0.0, 0))
	for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var along_z: bool = absf(d.x) > 0.5
		var cont: Vector3 = Vector3(2.6, 2.4, 6.0) if along_z else Vector3(6.0, 2.4, 2.6)
		g._box(d * 10.0 + Vector3(0, 1.2, 0), cont, ORANGE if along_z else BLUE, Vector3.ZERO, "container")
		# Trampolín por dentro para subirse al contenedor
		g._pad(d * 6.8)
		var fence: Vector3 = Vector3(1.2, 2.8, 5.0) if along_z else Vector3(5.0, 2.8, 1.2)
		g._box(d * 20.0 + Vector3(0, 1.4, 0), fence, PURPLE, Vector3.ZERO, "fence")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			g._box(Vector3(4.2 * sx, 0.6, 4.2 * sz), Vector3(2.4, 1.2, 2.4), GREEN, Vector3.ZERO, "tires")
			g._box(Vector3(14.5 * sx, 0.6, 14.5 * sz), Vector3(3.0, 1.2, 3.0), YELLOW, Vector3.ZERO, "crate")


# La Torre: torre central alta, cuatro tarimas con rampa mirando al centro y neumáticos en las diagonales.
static func _torre(g) -> void:
	g._box(Vector3(0, 2.0, 0), Vector3(4.0, 4.0, 4.0), RED, Vector3.ZERO, "container")
	for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		g._box(d * 13.0 + Vector3(0, 0.6, 0), Vector3(5.0, 1.2, 5.0), YELLOW if absf(d.x) > 0.5 else BLUE, Vector3.ZERO, "stage")
		_ramp(g, d * 10.5, -d)
		# Trampolín al pie de la torre
		g._pad(d * 3.6)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			g._box(Vector3(9.0 * sx, 0.6, 9.0 * sz), Vector3(3.0, 1.2, 3.0), GREEN, Vector3.ZERO, "tires")
			g._box(Vector3(18.0 * sx, 1.4, 18.0 * sz), Vector3(5.0, 2.8, 1.2), PURPLE, Vector3(0, PI * 0.25 * sx * sz, 0), "fence")
