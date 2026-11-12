extends Node
# Red local: crear o unirse a una partida, sala de espera, búsqueda de partidas
# y todos los mensajes del juego. Los mensajes pasan por aquí (y no por los nodos
# de la partida) para que nunca lleguen a un nodo que todavía no existe.

signal lobby_changed
signal games_changed
signal net_error(text: String)

const PORT: int = 24570
const DISCOVERY_PORT: int = 24571
const MAX_PLAYERS: int = 8
const BOT_NAMES: Array = ["Cuco", "Yusimí", "El Brayan", "Tata", "Machito", "La Flaca", "Pipo", "Yunior"]

var mode: String = "solo"  # solo, host, client
var my_name: String = "Jugador"
var bot_count: int = 5
var difficulty: int = 1
var roster: Array = []
var lobby_players: Array = []
var game = null
var found_games: Dictionary = {}
var last_error: String = ""

var _udp_out: PacketPeerUDP = null
var _udp_in: PacketPeerUDP = null
var _announce_t: float = 0.0
var _session_id: int = 0
var _ready_peers: Dictionary = {}

# Atajos de prueba que llegan por línea de comandos (ver _read_test_args).
var test: Dictionary = {}


# Para probar la red sin tocar el menú. Van después de "--", por ejemplo:
#   Godot.exe --path . -- --host --netlog --match=30
#   Godot.exe --path . -- --join --autopilot --netlog
#
#   --host[=N]        crea la partida y arranca sola al haber N humanos (2 si no se dice)
#   --join[=IP|auto]  se une a esa IP (127.0.0.1 si no se dice); "auto" usa la búsqueda
#   --name=X          nombre del jugador        --bots=N       bots de relleno
#   --match=SEG       duración de la partida    --autopilot    tu muñeco lo lleva un bot
#   --netlog          imprime los eventos       --rematch      el host lanza otra ronda al acabar
#   --leave-after=S   sale al menú a los S s    --quit-after=S cierra el juego a los S s
func _read_test_args() -> void:
	for a in OS.get_cmdline_user_args():
		var s: String = a
		if not s.begins_with("--"):
			continue
		var kv: PackedStringArray = s.substr(2).split("=", true, 1)
		test[kv[0]] = kv[1] if kv.size() > 1 else ""
	if test.has("name"):
		my_name = str(test["name"])
	if test.has("bots"):
		bot_count = clampi(int(test["bots"]), 0, 7)
	if test.has("match"):
		Tuning.match_seconds = maxf(5.0, float(test["match"]))
	if test.has("quit-after"):
		get_tree().create_timer(float(test["quit-after"])).timeout.connect(_quit_now)


	if test.has("leave-after"):
		get_tree().create_timer(float(test["leave-after"])).timeout.connect(_leave_now)


func _leave_now() -> void:
	if game != null:
		tlog("salgo al menú")
		game._leave()


func _quit_now() -> void:
	close()
	get_tree().quit()


func tlog(text: String) -> void:
	if test.has("netlog"):
		print("[%s %s] %s" % [mode, my_name, text])


# Al cerrar la ventana, avisa a los demás en vez de dejarlos esperando a que caduque la conexión.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		close()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") == OK:
		my_name = str(cf.get_value("player", "name", my_name))
		bot_count = clampi(int(cf.get_value("game", "bots", bot_count)), 0, 7)
		difficulty = clampi(int(cf.get_value("game", "difficulty", difficulty)), 0, 2)
	_read_test_args()


func save_cfg() -> void:
	if not test.is_empty():
		return  # una prueba no debe pisar tu configuración
	var cf := ConfigFile.new()
	cf.set_value("player", "name", my_name)
	cf.set_value("game", "bots", bot_count)
	cf.set_value("game", "difficulty", difficulty)
	cf.save("user://settings.cfg")


func is_authority() -> bool:
	return mode != "client"


func is_online() -> bool:
	return mode == "host" or mode == "client"


func my_id() -> int:
	return multiplayer.get_unique_id()


func local_ips() -> Array:
	var out: Array = []
	for a in IP.get_local_addresses():
		var s: String = a
		if s.count(".") == 3 and not s.begins_with("127.") and not s.begins_with("169.254."):
			out.append(s)
	return out


# ---------- Conexión ----------

func host_game() -> bool:
	close()
	var peer := ENetMultiplayerPeer.new()
	var err: int = peer.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		last_error = "No se pudo crear la partida. ¿Ya hay otra abierta en esta PC?"
		return false
	multiplayer.multiplayer_peer = peer
	mode = "host"
	lobby_players = [{"peer": 1, "name": my_name}]
	_session_id = randi()
	_udp_out = PacketPeerUDP.new()
	_udp_out.set_broadcast_enabled(true)
	_announce_t = 0.0
	lobby_changed.emit()
	return true


func join_game(ip: String) -> bool:
	close()
	var peer := ENetMultiplayerPeer.new()
	var err: int = peer.create_client(ip, PORT)
	if err != OK:
		last_error = "No se pudo conectar a esa dirección."
		return false
	multiplayer.multiplayer_peer = peer
	mode = "client"
	return true


func close() -> void:
	mode = "solo"
	var old = multiplayer.multiplayer_peer
	if old != null and not (old is OfflineMultiplayerPeer):
		old.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if _udp_out != null:
		_udp_out.close()
		_udp_out = null
	lobby_players = []
	_ready_peers.clear()


func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	if mode != "host":
		return
	for i in lobby_players.size():
		if int(lobby_players[i]["peer"]) == id:
			lobby_players.remove_at(i)
			break
	if game != null:
		game.on_peer_left(id)
	push_lobby()


func _on_connected() -> void:
	c_hello.rpc_id(1, my_name)


func _on_connection_failed() -> void:
	close()
	last_error = "No se pudo conectar con la partida."
	net_error.emit(last_error)


func _on_server_disconnected() -> void:
	if mode != "client":
		return
	var in_game: bool = game != null
	close()
	last_error = "Se perdió la conexión con el host."
	if in_game:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
	else:
		net_error.emit(last_error)


# ---------- Búsqueda de partidas en la red ----------

func start_listening() -> void:
	stop_listening()
	found_games.clear()
	_udp_in = PacketPeerUDP.new()
	if _udp_in.bind(DISCOVERY_PORT) != OK:
		_udp_in = null


func stop_listening() -> void:
	if _udp_in != null:
		_udp_in.close()
		_udp_in = null


func _announce() -> void:
	var text: String = JSON.stringify({"g": "gunbearer", "id": _session_id, "name": my_name, "players": lobby_players.size()})
	var msg: PackedByteArray = text.to_utf8_buffer()
	var targets: Array = ["255.255.255.255", "127.0.0.1"]
	for s in local_ips():
		var parts: PackedStringArray = s.split(".")
		targets.append("%s.%s.%s.255" % [parts[0], parts[1], parts[2]])
	for t in targets:
		_udp_out.set_dest_address(t, DISCOVERY_PORT)
		_udp_out.put_packet(msg)


func _process(delta: float) -> void:
	if mode == "host" and _udp_out != null and game == null:
		_announce_t -= delta
		if _announce_t <= 0.0:
			_announce_t = 1.0
			_announce()
	if _udp_in == null:
		return
	var changed: bool = false
	while _udp_in.get_available_packet_count() > 0:
		var pkt: PackedByteArray = _udp_in.get_packet()
		var ip: String = _udp_in.get_packet_ip()
		var txt: String = pkt.get_string_from_utf8()
		if not txt.begins_with("{"):
			continue
		var data = JSON.parse_string(txt)
		if typeof(data) != TYPE_DICTIONARY or str(data.get("g", "")) != "gunbearer":
			continue
		var key: String = str(data.get("id", ip))
		var gname: String = str(data.get("name", "?"))
		var count: int = int(data.get("players", 1))
		if found_games.has(key):
			var g: Dictionary = found_games[key]
			if g["name"] != gname or g["players"] != count:
				changed = true
			g["name"] = gname
			g["players"] = count
			g["t"] = 0.0
			if str(g["ip"]).begins_with("127.") and not ip.begins_with("127."):
				g["ip"] = ip
		else:
			found_games[key] = {"ip": ip, "name": gname, "players": count, "t": 0.0}
			changed = true
	for k in found_games.keys():
		found_games[k]["t"] += delta
		if found_games[k]["t"] > 3.5:
			found_games.erase(k)
			changed = true
	if changed:
		games_changed.emit()


# ---------- Sala de espera ----------

func push_lobby() -> void:
	if mode == "host":
		s_lobby.rpc(lobby_players, bot_count, difficulty)
	lobby_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func c_hello(pname: String) -> void:
	if mode != "host":
		return
	var id: int = multiplayer.get_remote_sender_id()
	if game != null or lobby_players.size() >= MAX_PLAYERS:
		s_reject.rpc_id(id, "Esa partida ya empezó o está llena.")
		return
	var clean: String = pname.strip_edges().substr(0, 14)
	if clean == "":
		clean = "Jugador"
	lobby_players.append({"peer": id, "name": clean})
	push_lobby()


@rpc("authority", "call_remote", "reliable")
func s_lobby(players: Array, bots: int, diff: int) -> void:
	lobby_players = players
	bot_count = bots
	difficulty = diff
	lobby_changed.emit()


@rpc("authority", "call_remote", "reliable")
func s_reject(text: String) -> void:
	close()
	last_error = text
	net_error.emit(text)


# ---------- Arranque de la partida ----------

func start_match() -> void:
	roster = []
	if mode == "host":
		for p in lobby_players:
			roster.append({"peer": int(p["peer"]), "name": str(p["name"])})
	else:
		roster.append({"peer": 1, "name": "Tú"})
	var bots: int = clampi(bot_count, 0, MAX_PLAYERS - roster.size())
	if roster.size() + bots < 2:
		bots = 2 - roster.size()
	var names: Array = BOT_NAMES.duplicate()
	names.shuffle()
	for i in bots:
		roster.append({"peer": 0, "name": names[i]})
	_ready_peers.clear()
	save_cfg()
	if mode == "host":
		s_start.rpc(roster, difficulty)
	_load_game()


@rpc("authority", "call_remote", "reliable")
func s_start(r: Array, diff: int) -> void:
	roster = r
	difficulty = diff
	_load_game()


func _load_game() -> void:
	Tuning.apply_difficulty(difficulty)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func game_ready(g) -> void:
	game = g
	if mode == "client":
		c_ready.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func c_ready() -> void:
	if mode == "host":
		_ready_peers[multiplayer.get_remote_sender_id()] = true


func all_ready() -> bool:
	var peers: PackedInt32Array = multiplayer.get_peers()
	for p in roster:
		var id: int = int(p["peer"])
		if id > 1 and peers.has(id) and not _ready_peers.has(id):
			return false
	return true


# ---------- Mensajes de la partida ----------

func send_state(slot: int, pos: Vector3, vel: Vector3, yaw: float) -> void:
	if is_online():
		x_state.rpc(slot, pos, vel, yaw)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func x_state(slot: int, pos: Vector3, vel: Vector3, yaw: float) -> void:
	if game != null:
		game.net_state(multiplayer.get_remote_sender_id(), slot, pos, vel, yaw)


func send_shoot(origin: Vector3, dir: Vector3) -> void:
	if mode == "client":
		c_shoot.rpc_id(1, origin, dir)


@rpc("any_peer", "call_remote", "reliable")
func c_shoot(origin: Vector3, dir: Vector3) -> void:
	if mode == "host" and game != null:
		game.net_shoot(multiplayer.get_remote_sender_id(), origin, dir)


func send_event(kind: int, args: Array) -> void:
	if mode == "host":
		s_event.rpc(kind, args)


@rpc("authority", "call_remote", "reliable")
func s_event(kind: int, args: Array) -> void:
	if game != null:
		game.apply_event(kind, args)


func send_sync(state: int, countdown: float, time_left: float, bearer_slot: int, scores: Array) -> void:
	if mode == "host":
		s_sync.rpc(state, countdown, time_left, bearer_slot, scores)


@rpc("authority", "call_remote", "unreliable_ordered")
func s_sync(state: int, countdown: float, time_left: float, bearer_slot: int, scores: Array) -> void:
	if game != null:
		game.match_state.apply_sync(state, countdown, time_left, bearer_slot, scores)
