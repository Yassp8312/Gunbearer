extends RefCounted
# Cerebro de un bot. Llena las mismas variables de entrada que el teclado.

var me = null
var _fire_cd: float = 1.0
var _strafe: float = 1.0
var _strafe_t: float = 0.0
var _stuck_t: float = 0.0
var _side_t: float = 0.0
var _side: Vector3 = Vector3.ZERO
var _react: float = 0.0
var _aim_err: Vector3 = Vector3.ZERO


func think(delta: float) -> void:
	var ms = me.match_state
	me.in_jump = false
	me.in_dash = false
	me.in_shoot = false
	me.in_reload = false
	if not ms.is_playing():
		me.in_move = Vector3.ZERO
		return
	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe_t = randf_range(0.5, 1.4)
		_strafe = -1.0 if randf() < 0.5 else 1.0

	var pos: Vector3 = me.global_position
	var move: Vector3 = Vector3.ZERO
	if me.is_bearer:
		move = _think_bearer(delta, pos)
	else:
		move = _think_chaser(delta, pos)

	# Atascado contra algo: salta y, si sigue, rodea.
	var hv: Vector3 = Vector3(me.velocity.x, 0.0, me.velocity.z)
	if move.length() > 0.3 and hv.length() < 1.0 and me.stun_timer <= 0.0:
		_stuck_t += delta
	else:
		_stuck_t = maxf(0.0, _stuck_t - delta)
	if _stuck_t > 0.25:
		me.in_jump = true
		if _stuck_t > 0.7:
			_side = Vector3(-move.z, 0.0, move.x) * _strafe
			_side_t = 0.6
			_stuck_t = 0.0
	if _side_t > 0.0:
		_side_t -= delta
		move = (move * 0.3 + _side).normalized()
	me.in_move = move


func _think_chaser(delta: float, pos: Vector3) -> Vector3:
	var b = me.match_state.bearer
	if b == null:
		return Vector3.ZERO
	var bpos: Vector3 = b.global_position
	var to: Vector3 = bpos - pos
	var dist: float = to.length()
	to.y = 0.0
	var dir: Vector3 = to.normalized()
	var perp: Vector3 = Vector3(-dir.z, 0.0, dir.x) * _strafe
	var weave: float = 0.4 if dist > 5.0 else 0.1
	var move: Vector3 = (dir + perp * weave).normalized()
	me.yaw = atan2(-dir.x, -dir.z)

	# No amontonarse con los otros perseguidores.
	for p in me.match_state.players:
		if p == me or p == b or not p.alive:
			continue
		var off: Vector3 = pos - p.global_position
		off.y = 0.0
		if off.length() < 1.3 and off.length() > 0.01:
			move += off.normalized() * 0.8
	move = move.normalized()

	if b.immune_timer > 0.0 and dist < 4.0:
		move = perp
	elif dist < 5.5 and dist > 1.5 and me.dash_left > 0 and randf() < Tuning.bot_dash_eagerness * delta:
		me.in_dash = true
		move = dir
	if bpos.y - pos.y > 0.8 and dist < 6.0 and me.is_on_floor():
		me.in_jump = true
	return move


func _think_bearer(delta: float, pos: Vector3) -> Vector3:
	var nearest = null
	var best: float = 999.0
	for p in me.match_state.players:
		if p == me or not p.alive:
			continue
		var d: float = p.global_position.distance_to(pos)
		if d < best:
			best = d
			nearest = p
	if nearest == null:
		return Vector3.ZERO

	var npos: Vector3 = nearest.global_position
	var away: Vector3 = pos - npos
	away.y = 0.0
	away = away.normalized()
	var perp: Vector3 = Vector3(-away.z, 0.0, away.x) * _strafe
	var center: Vector3 = Vector3(-pos.x, 0.0, -pos.z)
	var cb: float = clampf(center.length() / 20.0, 0.0, 1.0)
	var flee: float = 1.0 if best < 9.0 else 0.2
	var move: Vector3 = (away * flee + perp * 0.6 + center.normalized() * cb * 1.2).normalized()
	if best < 3.5 and me.dash_left > 0 and me.immune_timer <= 0.0:
		me.in_dash = true

	# Apuntar con adelanto y un poco de error.
	var tp: Vector3 = npos + Vector3(0, 0.9, 0)
	var origin: Vector3 = me.muzzle_position()
	var dist: float = origin.distance_to(tp)
	var t: float = dist / float(me.stat("ball_speed"))
	var nvel: Vector3 = nearest.velocity
	var lead: Vector3 = tp + Vector3(nvel.x, 0.0, nvel.z) * t
	lead.y += 0.5 * float(me.stat("ball_gravity")) * t * t
	_react -= delta
	if _react <= 0.0:
		_react = 0.35
		var e: float = Tuning.bot_aim_error * dist
		_aim_err = Vector3(randf_range(-e, e), randf_range(-e, e) * 0.5, randf_range(-e, e))
	me.aim_point = lead + _aim_err
	var ad: Vector3 = me.aim_point - pos
	me.yaw = atan2(-ad.x, -ad.z)

	_fire_cd -= delta
	if _fire_cd <= 0.0 and best < 30.0 and _has_los(origin, tp):
		me.in_shoot = true
		_fire_cd = randf_range(Tuning.bot_fire_min, Tuning.bot_fire_max)
	return move


func _has_los(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit: Dictionary = me.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty()
