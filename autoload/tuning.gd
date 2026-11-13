extends Node
# Todos los números del juego en un solo lugar. Cambia aquí para balancear.

# Partida
var match_seconds: float = 180.0
var countdown_seconds: float = 3.0
var bot_count: int = 5

# Movimiento
var run_speed: float = 7.5
var bearer_speed_factor: float = 0.82
var accel: float = 60.0
var air_accel: float = 18.0
var jump_velocity: float = 8.0
var gravity: float = 22.0
var dash_speed: float = 19.0
var dash_time: float = 0.18
var dash_cooldown: float = 3.0
var mouse_sens: float = 0.0025

# Robo del Lanzador
var steal_radius: float = 1.5
var steal_immunity: float = 2.0
var steal_stun: float = 1.0

# Lanzador y bolas
var magazine: int = 5
var fire_interval: float = 0.28
var reload_time: float = 1.5
var ball_speed: float = 30.0
var ball_gravity: float = 7.0
var ball_radius: float = 0.22
var ball_life: float = 4.0
var hit_radius: float = 0.6

# Eliminación
var respawn_time: float = 3.0
var respawn_shield: float = 1.2
var knock_speed: float = 13.0
var knock_up: float = 9.0

# Bots
var bot_aim_error: float = 0.22
var bot_fire_min: float = 0.8
var bot_fire_max: float = 1.6
var bot_dash_eagerness: float = 2.0

# Trampolines
var pad_power: float = 15.0
var pad_radius: float = 1.3

# ---------- Clases de personaje ----------
# Cada clase cambia unos pocos números de arriba: una ventaja y un costo, para que
# ninguna sea la mejor en todo. Lo que una clase no nombra, vale lo de siempre.
# "pro" y "con" son los textos que ve el jugador al elegir.
var dash_charges: int = 1
var speed_factor: float = 1.0

const CLASSES: Array = [
	{"name": "Artillero", "pro": "7 bolas en vez de 5", "con": "Recarga más lenta",
		"magazine": 7, "reload_time": 2.0},
	{"name": "Velocista", "pro": "Dos dash seguidos", "con": "Cada dash llega más corto",
		"dash_charges": 2, "dash_time": 0.13},
	{"name": "Ladrón", "pro": "Roba desde más lejos", "con": "Si le roban, queda aturdido más tiempo",
		"steal_radius": 1.9, "steal_stun": 1.5},
	{"name": "Blindado", "pro": "3 s de inmunidad al robar", "con": "Corre un poco más lento",
		"steal_immunity": 3.0, "speed_factor": 0.93},
	{"name": "Saltarín", "pro": "Salta más alto y gira mejor en el aire", "con": "El dash tarda más en recargar",
		"jump_velocity": 10.0, "air_accel": 30.0, "dash_cooldown": 4.0},
	{"name": "Tirador", "pro": "Bolas más rápidas y rectas", "con": "Solo 3 bolas",
		"ball_speed": 40.0, "ball_gravity": 4.0, "magazine": 3},
]

# Clase de cada personaje, en el orden de character.gd (Leo, Mara, Alienígena, Robot, Caballero,
# Zombi, Obrero, Saqueador, Beto, Nina, Soldado, Coco, Lola, Dani, Vera, Edu, Sol, Fito, Gala, Gus).
const CHAR_CLASS: Array = [1, 2, 4, 0, 3, 3, 0, 2, 5, 1, 5, 4, 0, 2, 5, 3, 4, 1, 0, 1]


func class_of(char_index: int) -> Dictionary:
	return CLASSES[CHAR_CLASS[posmod(char_index, CHAR_CLASS.size())]]


# Un número del juego ajustado por la clase del personaje. Ej.: stat(3, "magazine").
func stat(char_index: int, key: String):
	var c: Dictionary = class_of(char_index)
	if c.has(key):
		return c[key]
	return get(key)


# Dificultad de los bots: 0 fácil, 1 normal, 2 difícil
var difficulty: int = 1


func apply_difficulty(d: int) -> void:
	difficulty = clampi(d, 0, 2)
	if difficulty == 0:
		bot_aim_error = 0.38
		bot_fire_min = 1.2
		bot_fire_max = 2.2
		bot_dash_eagerness = 1.0
	elif difficulty == 1:
		bot_aim_error = 0.22
		bot_fire_min = 0.8
		bot_fire_max = 1.6
		bot_dash_eagerness = 2.0
	else:
		bot_aim_error = 0.12
		bot_fire_min = 0.5
		bot_fire_max = 1.1
		bot_dash_eagerness = 3.0
