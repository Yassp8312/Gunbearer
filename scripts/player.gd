extends CharacterBody3D
# Un jugador. El mismo script sirve para todos: lo que cambia es quién lo controla.
# is_local = lo mueve esta PC (tu teclado, o un bot si esta PC manda).
# Si no es local, solo se dibuja donde dice la red.

const CharacterScript = preload("res://scripts/character.gd")

var game = null
var match_state = null
var brain = null
var slot: int = 0
var peer_id: int = 0
var is_local: bool = true
var display_name: String = "Jugador"
var color: Color = Color.WHITE
var is_bot: bool = false
var score: int = 0
var streak: int = 0
var alive: bool = true
var is_bearer: bool = false

var yaw: float = 0.0
var pitch: float = 0.0
var stun_timer: float = 0.0
var immune_timer: float = 0.0
var shield_timer: float = 0.0
var respawn_timer: float = 0.0
var dash_cd: float = 0.0
var dash_timer: float = 0.0
var dash_dir: Vector3 = Vector3.ZERO
var ammo: int = 0
var reload_timer: float = 0.0
var fire_timer: float = 0.0

# Entrada
var in_move: Vector3 = Vector3.ZERO
var in_jump: bool = false
var in_dash: bool = false
var in_shoot: bool = false
var in_reload: bool = false
var aim_point: Vector3 = Vector3.ZERO

# Red
var net_pos: Vector3 = Vector3.ZERO
var net_vel: Vector3 = Vector3.ZERO
var net_yaw: float = 0.0
var _tick: int = 0
var _respawn_sent: bool = false

var _visual: Node3D = null
var _char = null
var _body_mat: StandardMaterial3D = null
var _launcher: Node3D = null
var _marker: MeshInstance3D = null
var _tag: Label3D = null
var _trail: CPUParticles3D = null
var _spin: Vector3 = Vector3.ZERO
var _bob: float = 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	net_pos = position
	net_yaw = yaw
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	add_child(cs)

	_visual = Node3D.new()
	_visual.position = Vector3(0, 0.9, 0)
	add_child(_visual)

	# Cuerpo: un modelo animado. Si no está el archivo, queda la cápsula de siempre.
	_char = CharacterScript.new()
	if _char.setup(CharacterScript.DEFAULT_PACK, slot, color):
		_char.position = Vector3(0, -0.9, 0)
		_visual.add_child(_char)
	else:
		_char.free()
		_char = null
		_build_capsule()
	_build_rest()


func _build_capsule() -> void:
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.4
	cm.height = 1.8
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = color
	_body_mat.roughness = 0.6
	_body_mat.emission = Color.WHITE
	cm.material = _body_mat
	body.mesh = cm
	_visual.add_child(body)

	for sx in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.11
		em.height = 0.22
		var emat := StandardMaterial3D.new()
		emat.albedo_color = Color.WHITE
		em.material = emat
		eye.mesh = em
		eye.position = Vector3(0.15 * sx, 0.45, -0.34)
		_visual.add_child(eye)
		var pupil := MeshInstance3D.new()
		var pm := SphereMesh.new()
		pm.radius = 0.055
		pm.height = 0.11
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color.BLACK
		pm.material = pmat
		pupil.mesh = pm
		pupil.position = Vector3(0.15 * sx, 0.45, -0.43)
		_visual.add_child(pupil)


func _build_rest() -> void:
	_launcher = Node3D.new()
	_launcher.position = Vector3(0.5, 0.15, -0.3)
	_visual.add_child(_launcher)
	var weapon: Node3D = _char.make_weapon() if _char != null else null
	if weapon != null:
		_launcher.add_child(weapon)
	else:
		var gun := MeshInstance3D.new()
		var gm := BoxMesh.new()
		gm.size = Vector3(0.24, 0.26, 0.8)
		var gmat := StandardMaterial3D.new()
		gmat.albedo_color = Color("2b2d42")
		gm.material = gmat
		gun.mesh = gm
		_launcher.add_child(gun)
		var tank := MeshInstance3D.new()
		var tm := SphereMesh.new()
		tm.radius = 0.2
		tm.height = 0.4
		var tmat := StandardMaterial3D.new()
		tmat.albedo_color = color
		tm.material = tmat
		tank.mesh = tm
		tank.position = Vector3(0, 0.26, 0.1)
		_launcher.add_child(tank)
	_launcher.visible = false

	# Marca y luz sobre el portador
	_marker = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.32
	cone.bottom_radius = 0.0
	cone.height = 0.5
	var mmat := StandardMaterial3D.new()
	mmat.albedo_color = Color("ffe14d")
	mmat.emission_enabled = true
	mmat.emission = Color("ffe14d")
	mmat.emission_energy_multiplier = 1.2
	cone.material = mmat
	_marker.mesh = cone
	_marker.position = Vector3(0, 2.75, 0)
	_marker.visible = false
	add_child(_marker)
	var glow := OmniLight3D.new()
	glow.light_color = Color("ffe14d")
	glow.light_energy = 1.6
	glow.omni_range = 5.0
	glow.position = Vector3(0, -1.2, 0)
	_marker.add_child(glow)

	# Estela del dash
	_trail = CPUParticles3D.new()
	_trail.emitting = false
	_trail.amount = 28
	_trail.lifetime = 0.35
	_trail.local_coords = false
	_trail.direction = Vector3.UP
	_trail.spread = 180.0
	_trail.initial_velocity_min = 0.3
	_trail.initial_velocity_max = 1.4
	_trail.gravity = Vector3.ZERO
	_trail.scale_amount_min = 0.4
	_trail.scale_amount_max = 1.0
	var trm := SphereMesh.new()
	trm.radius = 0.13
	trm.height = 0.26
	var trmat := StandardMaterial3D.new()
	trmat.albedo_color = color.lightened(0.45)
	trmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trm.material = trmat
	_trail.mesh = trm
	_trail.position = Vector3(0, 0.9, 0)
	add_child(_trail)

	if game.human != self:
		_tag = Label3D.new()
		_tag.text = display_name
		_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_tag.pixel_size = 0.008
		_tag.modulate = color
		_tag.outline_size = 10
		_tag.position = Vector3(0, 2.2, 0)
		add_child(_tag)


func forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func right() -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))


func muzzle_position() -> Vector3:
	return global_position + Vector3(0, 1.25, 0) + right() * 0.5 + forward() * 0.7


func set_bearer(b: bool) -> void:
	is_bearer = b
	if _char != null:
		_char.armed = b
	if _launcher != null:
		_launcher.visible = b
		_marker.visible = b


func set_display_name(n: String) -> void:
	display_name = n
	if _tag != null:
		_tag.text = n


func apply_net_state(pos: Vector3, vel: Vector3, y: float) -> void:
	if not alive:
		return
	net_pos = pos
	net_vel = vel
	net_yaw = y


func _physics_process(delta: float) -> void:
	stun_timer = maxf(0.0, stun_timer - delta)
	immune_timer = maxf(0.0, immune_timer - delta)
	shield_timer = maxf(0.0, shield_timer - delta)
	respawn_timer = maxf(0.0, respawn_timer - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	dash_timer = maxf(0.0, dash_timer - delta)
	fire_timer = maxf(0.0, fire_timer - delta)

	if not alive:
		_dead_process(delta)
		return

	if not is_local:
		net_pos += net_vel * delta
		global_position = global_position.lerp(net_pos, 1.0 - exp(-18.0 * delta))
		velocity = net_vel
		yaw = lerp_angle(yaw, net_yaw, 1.0 - exp(-20.0 * delta))
		_update_visual(delta)
		return

	if brain != null:
		brain.think(delta)
	else:
		_read_human()

	var can_act: bool = match_state.is_playing() and stun_timer <= 0.0
	var wish: Vector3 = in_move if can_act else Vector3.ZERO
	wish.y = 0.0
	if wish.length() > 1.0:
		wish = wish.normalized()
	var speed: float = Tuning.run_speed
	if is_bearer:
		speed *= Tuning.bearer_speed_factor
	var a: float = Tuning.accel if is_on_floor() else Tuning.air_accel
	var hv: Vector3 = Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * speed, a * delta)
	velocity.x = hv.x
	velocity.z = hv.z

	if not is_on_floor():
		velocity.y -= Tuning.gravity * delta
	elif can_act and in_jump:
		velocity.y = Tuning.jump_velocity
		if self == game.human:
			Sfx.play("jump", randf_range(0.95, 1.1), -8.0)

	if can_act and in_dash and dash_cd <= 0.0:
		var d: Vector3 = wish if wish.length() > 0.1 else forward()
		dash_dir = d.normalized()
		dash_timer = Tuning.dash_time
		dash_cd = Tuning.dash_cooldown
		if self == game.human:
			Sfx.play("dash")
	if dash_timer > 0.0:
		velocity.x = dash_dir.x * Tuning.dash_speed
		velocity.z = dash_dir.z * Tuning.dash_speed

	move_and_slide()
	_check_pads()

	if can_act and is_bearer:
		_weapon(delta)
	_update_visual(delta)

	_tick += 1
	if game.online and _tick % 2 == 0:
		Net.send_state(slot, global_position, velocity, yaw)


func _check_pads() -> void:
	if not is_on_floor():
		return
	for pad in game.pads:
		var dx: float = global_position.x - pad.x
		var dz: float = global_position.z - pad.z
		if dx * dx + dz * dz < Tuning.pad_radius * Tuning.pad_radius and absf(global_position.y - pad.y) < 0.5:
			velocity.y = Tuning.pad_power
			if self == game.human:
				Sfx.play("bounce")
			else:
				Sfx.play("bounce", 0.85, -12.0)
			return


func _read_human() -> void:
	if game.menu_open:
		in_move = Vector3.ZERO
		in_jump = false
		in_dash = false
		in_reload = false
		in_shoot = false
		return
	var f: float = 0.0
	var r: float = 0.0
	if Input.is_physical_key_pressed(KEY_W):
		f += 1.0
	if Input.is_physical_key_pressed(KEY_S):
		f -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		r += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		r -= 1.0
	in_move = forward() * f + right() * r
	in_jump = Input.is_physical_key_pressed(KEY_SPACE)
	in_dash = Input.is_physical_key_pressed(KEY_SHIFT)
	in_reload = Input.is_physical_key_pressed(KEY_R)
	in_shoot = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _weapon(delta: float) -> void:
	if reload_timer > 0.0:
		reload_timer -= delta
		if reload_timer <= 0.0:
			ammo = Tuning.magazine
		return
	if ammo <= 0 or (in_reload and ammo < Tuning.magazine):
		reload_timer = Tuning.reload_time
		if self == game.human:
			Sfx.play("reload")
		return
	if in_shoot and fire_timer <= 0.0:
		fire_timer = Tuning.fire_interval
		ammo -= 1
		var origin: Vector3 = muzzle_position()
		var dir: Vector3 = aim_point - origin
		if dir.length() < 0.5:
			dir = forward()
		game.request_shot(self, origin, dir.normalized())


func eliminate(dir: Vector3, paint: Color) -> void:
	alive = false
	streak = 0
	_respawn_sent = false
	respawn_timer = Tuning.respawn_time
	dash_timer = 0.0
	_trail.emitting = false
	var flat: Vector3 = Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.01:
		flat = Vector3.FORWARD
	velocity = flat.normalized() * Tuning.knock_speed + Vector3.UP * Tuning.knock_up
	_spin = Vector3(randf_range(-9.0, 9.0), randf_range(-6.0, 6.0), randf_range(-9.0, 9.0))
	if _char != null:
		_char.paint(paint)
		_char.glow(false, 0.0)
		_char.play("dead")
	else:
		_body_mat.albedo_color = paint
		_body_mat.emission_enabled = false
	_visual.scale = Vector3.ONE
	_visual.position.y = 0.9


func _dead_process(delta: float) -> void:
	velocity.y -= Tuning.gravity * delta
	if is_on_floor() and velocity.y <= 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
		_spin = _spin.lerp(Vector3.ZERO, minf(1.0, 6.0 * delta))
	move_and_slide()
	_visual.rotation += _spin * delta
	if respawn_timer <= 0.0 and game.authority and not _respawn_sent:
		_respawn_sent = true
		game.host_respawn(self)


func respawn_at(pos: Vector3) -> void:
	alive = true
	global_position = pos
	net_pos = pos
	net_vel = Vector3.ZERO
	velocity = Vector3.ZERO
	_visual.rotation = Vector3.ZERO
	if _char != null:
		_char.set_tint(color)
	else:
		_body_mat.albedo_color = color
	shield_timer = Tuning.respawn_shield
	stun_timer = 0.0


func _update_visual(delta: float) -> void:
	var hs: float = Vector2(velocity.x, velocity.z).length()
	var dashing: bool = hs > 14.0
	if is_local:
		dashing = dash_timer > 0.0
	_trail.emitting = dashing
	_visual.rotation = Vector3(0.0, yaw, 0.0)
	if stun_timer > 0.0:
		_visual.scale = Vector3(1.2, 0.65, 1.2)
		_visual.position.y = 0.6
		_visual.rotation.z = sin(stun_timer * 40.0) * 0.15
	elif dashing:
		_visual.scale = Vector3(0.82, 1.18, 0.82)
		_visual.position.y = 0.9
	else:
		_visual.scale = _visual.scale.lerp(Vector3.ONE, minf(1.0, 14.0 * delta))
		var bob: float = 0.0
		if _char == null and hs > 1.0 and absf(velocity.y) < 0.6:
			_bob += delta * hs * 1.7
			bob = absf(sin(_bob)) * 0.08
		_visual.position.y = 0.9 + bob
	var protected: bool = immune_timer > 0.0 or shield_timer > 0.0
	var pulse: float = 0.5 + 0.4 * sin(Time.get_ticks_msec() * 0.02)
	if _char != null:
		_char.glow(protected, pulse)
		var air: bool = (not is_on_floor()) if is_local else absf(velocity.y) > 1.0
		if stun_timer > 0.0:
			_char.play("stun")
		elif dashing:
			_char.play("dash", 1.6)
		elif air:
			_char.play("jump" if velocity.y > 0.0 else "fall")
		elif hs > 1.0:
			_char.play("run", clampf(hs / Tuning.run_speed, 0.6, 1.4))
		else:
			_char.play("armed_idle" if is_bearer else "idle")
	else:
		_body_mat.emission_enabled = protected
		_body_mat.emission_energy_multiplier = pulse
	if _marker.visible:
		_marker.rotation.y += delta * 3.0
		_marker.position.y = 2.75 + sin(Time.get_ticks_msec() * 0.006) * 0.12
