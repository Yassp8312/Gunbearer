extends Node
# Música hecha por código, sin archivos de audio. Funciona como un secuenciador:
# se generan unas pocas notas cortas al arrancar (bajo, melodía, colchón, bombo, caja, platillo)
# y un reloj las va disparando según un patrón, cambiando el tono con pitch_scale.
#
# Uso: Music.play("menu"), Music.play("match"), Music.play("") para callar.
# Music.urgent = true acelera el tema (últimos segundos de la partida).
# Suena por el bus "Music", que tiene su propio volumen en Opciones.

const BUS: String = "Music"

# Cuatro compases; cada uno es un acorde. Semitonos respecto a La.
#               La menor     Fa mayor      Do mayor     Sol mayor
const CHORDS: Array = [[0, 3, 7], [-4, 0, 3], [3, 7, 10], [-2, 2, 5]]

# Patrones de 16 pasos por compás. En melodía y colchón: qué nota del acorde (0, 1, 2), 3 = la primera una octava arriba, -1 = silencio.
const SONGS: Dictionary = {
	"menu": {
		"bpm": 84.0,
		"lead": [],
		"pad": [0, -1, -1, -1, 1, -1, -1, -1, 2, -1, -1, -1, 1, -1, 3, -1],
		"bass": [1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0],
		"kick": [], "snare": [], "hat": [],
	},
	"match": {
		"bpm": 126.0,
		"lead": [0, -1, 1, -1, 2, -1, 1, -1, 3, -1, 2, 1, -1, 2, -1, -1],
		"pad": [],
		"bass": [1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0],
		"kick": [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1],
		"snare": [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
		"hat": [0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1],
	},
}

var urgent: bool = false

var _song: String = ""
var _t: float = 0.0
var _step: int = 0
var _streams: Dictionary = {}
var _players: Array = []
var _next: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index(BUS) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS)
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = BUS
		add_child(p)
		_players.append(p)
	# Notas base: la melodía y el colchón en La4 (440 Hz), el bajo en La2 (110 Hz).
	_streams["lead"] = _tone(0.28, 440.0, 0.35, 2.2, 0.30)
	_streams["pad"] = _tone(1.10, 440.0, 0.05, 1.3, 0.26)
	_streams["bass"] = _tone(0.34, 110.0, 0.55, 1.8, 0.42)
	_streams["kick"] = _drum(0.22, 150.0, 42.0, 0.0, 0.60)
	_streams["snare"] = _drum(0.16, 220.0, 160.0, 0.85, 0.34)
	_streams["hat"] = _drum(0.05, 0.0, 0.0, 1.0, 0.14)


# Al cerrar el juego se sueltan las notas que estén sonando, para no dejar nada sin liberar.
func _exit_tree() -> void:
	for p in _players:
		p.stop()
		p.stream = null


func play(song: String) -> void:
	if song == _song:
		return
	_song = song if SONGS.has(song) else ""
	_t = 0.0
	_step = 0
	urgent = false


func _process(delta: float) -> void:
	if _song == "":
		return
	var bpm: float = float(SONGS[_song]["bpm"]) * (1.22 if urgent else 1.0)
	var step_len: float = 60.0 / bpm / 4.0
	_t += minf(delta, 0.1)
	while _t >= step_len:
		_t -= step_len
		_tick()
		_step = (_step + 1) % 64


func _tick() -> void:
	var s: Dictionary = SONGS[_song]
	var chord: Array = CHORDS[int(_step / 16.0) % CHORDS.size()]
	var i: int = _step % 16
	_voice(s["lead"], i, chord, "lead", 0)
	_voice(s["pad"], i, chord, "pad", 0)
	var bass: Array = s["bass"]
	if bass.size() > i and int(bass[i]) == 1:
		_hit("bass", int(chord[0]))
	for d in ["kick", "snare", "hat"]:
		var pat: Array = s[d]
		if pat.size() > i and int(pat[i]) == 1:
			_hit(d, 0)


func _voice(pattern: Array, i: int, chord: Array, sample: String, shift: int) -> void:
	if pattern.size() <= i or int(pattern[i]) < 0:
		return
	var n: int = int(pattern[i])
	var semi: int = int(chord[0]) + 12 if n >= 3 else int(chord[n])
	_hit(sample, semi + shift)


func _hit(sample: String, semitones: int) -> void:
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sample]
	p.pitch_scale = pow(2.0, float(semitones) / 12.0)
	p.play()


# Nota con armónicos suaves. "bright" mezcla onda cuadrada (0 = seno puro), "fall" es lo rápido que se apaga.
func _tone(dur: float, freq: float, bright: float, fall: float, vol: float) -> AudioStreamWAV:
	var rate: int = 22050
	var n: int = int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t: float = float(i) / float(n)
		var ph: float = TAU * freq * float(i) / float(rate)
		var s: float = sin(ph) * (1.0 - bright) + (sin(ph) + sin(ph * 3.0) / 3.0 + sin(ph * 5.0) / 5.0) * bright
		var env: float = pow(1.0 - t, fall) * minf(1.0, float(i) / 120.0)
		data.encode_s16(i * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32000.0))
	return _wav(data, rate)


# Percusión: un tono que cae de f0 a f1, mezclado con ruido.
func _drum(dur: float, f0: float, f1: float, noise: float, vol: float) -> AudioStreamWAV:
	var rate: int = 22050
	var n: int = int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase: float = 0.0
	for i in n:
		var t: float = float(i) / float(n)
		phase += TAU * lerpf(f0, f1, t) / float(rate)
		var s: float = sin(phase) * (1.0 - noise) + randf_range(-1.0, 1.0) * noise
		var env: float = (1.0 - t) * (1.0 - t)
		data.encode_s16(i * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32000.0))
	return _wav(data, rate)


func _wav(data: PackedByteArray, rate: int) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w
