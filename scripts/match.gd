extends Node
# La verdad de la partida: quién tiene el Lanzador, puntos, tiempo.
# Quien manda (el host, o tú si juegas solo) decide; los demás solo aplican lo que llega.

signal feed(text: String, color: Color)

const WAITING: int = 0
const COUNTDOWN: int = 1
const PLAYING: int = 2
const ENDED: int = 3

var state: int = WAITING
var players: Array = []
var bearer = null
var time_left: float = 0.0
var countdown: float = 0.0
var game = null
var _sync_t: float = 0.0


func is_waiting() -> bool:
	return state == WAITING


func is_counting() -> bool:
	return state == COUNTDOWN


func is_playing() -> bool:
	return state == PLAYING


func is_ended() -> bool:
	return state == ENDED


func scores() -> Array:
	var s: Array = []
	for p in players:
		s.append(p.score)
	return s


func begin(first) -> void:
	time_left = Tuning.match_seconds
	countdown = Tuning.countdown_seconds
	if game.demo:
		time_left = 999999.0
		countdown = 0.6
	state = COUNTDOWN
	for p in players:
		p.score = 0
		p.stat_steals = 0
		p.stat_shots = 0
		p.stat_best_streak = 0
		p.stat_time = 0.0
	apply_give(first, null)


func apply_give(to, from) -> void:
	bearer = to
	for p in players:
		p.set_bearer(p == to)
	to.immune_timer = float(to.stat("steal_immunity"))
	to.ammo = int(to.stat("magazine"))
	to.reload_timer = 0.0
	to.fire_timer = 0.3
	to.streak = 0
	if from != null:
		to.stat_steals += 1
		from.stun_timer = float(from.stat("steal_stun"))
		from.streak = 0
		feed.emit("%s le robó el Lanzador a %s" % [to.display_name, from.display_name], to.color)
		Sfx.play("steal")
		game.on_steal(to, from)


func apply_elim(victim, shooter, dir: Vector3) -> void:
	shooter.score += 1
	shooter.streak += 1
	shooter.stat_best_streak = maxi(shooter.stat_best_streak, shooter.streak)
	feed.emit("%s pintó a %s" % [shooter.display_name, victim.display_name], shooter.color)
	victim.eliminate(dir, shooter.color)
	Sfx.play("hit", randf_range(0.9, 1.1))
	game.on_elimination(shooter, victim)


func apply_end(final_scores: Array) -> void:
	for i in mini(players.size(), final_scores.size()):
		players[i].score = int(final_scores[i])
	if state == ENDED:
		return
	state = ENDED
	time_left = 0.0
	Sfx.play("end")
	game.on_match_ended()


func apply_sync(s: int, cd: float, tl: float, bslot: int, sc: Array) -> void:
	if state == ENDED:
		return
	if state == WAITING and (s == COUNTDOWN or s == PLAYING) and bslot >= 0 and bslot < players.size():
		begin(players[bslot])
	if state == COUNTDOWN:
		if s == PLAYING:
			_go()
		else:
			countdown = cd
	time_left = tl
	for i in mini(players.size(), sc.size()):
		players[i].score = maxi(players[i].score, int(sc[i]))


func _go() -> void:
	state = PLAYING
	game.on_go()


func _physics_process(delta: float) -> void:
	if state == COUNTDOWN:
		countdown -= delta
		if countdown <= 0.0:
			_go()
	elif state == PLAYING:
		time_left = maxf(0.0, time_left - delta)
		if bearer != null:
			bearer.stat_time += delta
		if game.authority:
			if time_left <= 0.0:
				game.host_end()
				return
			_check_steal()
	if game.authority and game.online and state != WAITING:
		_sync_t -= delta
		if _sync_t <= 0.0:
			_sync_t = 0.25
			var bslot: int = -1
			if bearer != null:
				bslot = bearer.slot
			Net.send_sync(state, countdown, time_left, bslot, scores())


func _check_steal() -> void:
	if bearer == null or bearer.immune_timer > 0.0:
		return
	var best = null
	var best_d: float = 999.0
	for p in players:
		if p == bearer or not p.alive or p.stun_timer > 0.0:
			continue
		var d: float = p.global_position.distance_to(bearer.global_position)
		# Cada clase roba desde su propia distancia; gana el que esté más cerca.
		if d < float(p.stat("steal_radius")) and d < best_d:
			best_d = d
			best = p
	if best != null:
		game.host_give(best, bearer)


func ball_hit_test(ball, pos: Vector3):
	if state != PLAYING:
		return null
	for p in players:
		if p == ball.shooter or not p.alive or p.shield_timer > 0.0:
			continue
		var base: Vector3 = p.global_position
		var cy: float = clampf(pos.y, base.y + 0.4, base.y + 1.4)
		if pos.distance_to(Vector3(base.x, cy, base.z)) < Tuning.hit_radius:
			game.host_elim(p, ball)
			return p
	return null


func ranking() -> Array:
	var r: Array = players.duplicate()
	r.sort_custom(func(a, b): return a.score > b.score)
	return r
