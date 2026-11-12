extends Node
# Sonidos generados por código, para no depender de archivos de audio todavía.

var _streams: Dictionary = {}
var _players: Array = []
var _next: int = 0
var muted: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_streams["shoot"] = _make(0.10, 700.0, 220.0, 0.2, 0.5)
	_streams["splat"] = _make(0.12, 180.0, 90.0, 0.8, 0.45)
	_streams["hit"] = _make(0.30, 300.0, 60.0, 0.5, 0.7)
	_streams["steal"] = _make(0.25, 400.0, 1000.0, 0.05, 0.5)
	_streams["dash"] = _make(0.20, 200.0, 500.0, 0.85, 0.35)
	_streams["jump"] = _make(0.12, 300.0, 520.0, 0.0, 0.3)
	_streams["reload"] = _make(0.15, 900.0, 700.0, 0.1, 0.35)
	_streams["go"] = _make(0.40, 660.0, 880.0, 0.0, 0.5)
	_streams["tick"] = _make(0.10, 500.0, 500.0, 0.0, 0.4)
	_streams["end"] = _make(0.60, 800.0, 300.0, 0.0, 0.5)
	_streams["bounce"] = _make(0.22, 180.0, 620.0, 0.0, 0.45)
	_streams["streak"] = _make(0.30, 520.0, 1040.0, 0.0, 0.5)


func _make(dur: float, f0: float, f1: float, noise: float, vol: float) -> AudioStreamWAV:
	var rate: int = 22050
	var n: int = int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase: float = 0.0
	for i in n:
		var t: float = float(i) / float(n)
		var f: float = lerpf(f0, f1, t)
		phase += TAU * f / float(rate)
		var env: float = (1.0 - t) * (1.0 - t)
		var s: float = sin(phase) * (1.0 - noise) + randf_range(-1.0, 1.0) * noise
		data.encode_s16(i * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


func play(id: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if muted or not _streams.has(id):
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[id]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()
