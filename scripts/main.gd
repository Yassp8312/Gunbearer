extends Node3D
# La partida: arma la arena, crea a los jugadores, lleva la cámara
# y reparte los eventos (los decide quien manda y se aplican igual en todas las PC).

const PlayerScript = preload("res://scripts/player.gd")
const BotScript = preload("res://scripts/bot.gd")
const BallScript = preload("res://scripts/ball.gd")
const MatchScript = preload("res://scripts/match.gd")
const HudScript = preload("res://scripts/hud.gd")

const ARENA: float = 24.0

const EV_START: int = 0
const EV_GIVE: int = 1
const EV_BALL: int = 2
const EV_ELIM: int = 3
const EV_RESPAWN: int = 4
const EV_END: int = 5
const EV_TAKEOVER: int = 6

var demo: bool = false       # fondo del menú: solo bots, sin HUD ni sonido
var authority: bool = true   # esta PC decide (host, o partida sola)
var online: bool = false     # hay red de por medio

var colors: Array = [Color("ff5a5f"), Color("3fa7ff"), Color("ffd23f"), Color("4cd964"), Color("b86bff"), Color("ff9f1c"), Color("2ee6c8"), Color("ff7ac8")]

var world: Node3D
var match_state
var hud = null
var human = null
var players: Array = []
var cam: Camera3D
var spawns: Array = []
var pads: Array = []
var balls: Dictionary = {}
var menu_open: bool = false
var _next_ball: int = 1
var _splats: Array = []
var _shake: float = 0.0
var _cam_dist: float = 4.4
var _cam_frac: float = 1.0
var _pivot: Vector3 = Vector3.ZERO
var _wait_t: float = 0.0
var _demo_ang: float = 0.0


func _ready() -> void:
	randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	authority = demo or Net.is_authority()
	online = (not demo) and Net.is_online()

	world = Node3D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	_build_world()

	cam = Camera3D.new()
	cam.fov = 78.0
	cam.far = 300.0
	add_child(cam)
	cam.current = true

	match_state = MatchScript.new()
	match_state.game = self
	world.add_child(match_state)

	var roster: Array = Net.roster
	if demo:
		roster = []
		var names: Array = Net.BOT_NAMES.duplicate()
		names.shuffle()
		for i in 6:
			roster.append({"peer": 0, "name": names[i]})
	var me: int = Net.my_id()
	for i in roster.size():
		var p = PlayerScript.new()
		p.slot = i
		p.game = self
		p.match_state = match_state
		p.color = colors[i % colors.size()]
		p.display_name = str(roster[i]["name"])
		p.peer_id = int(roster[i]["peer"])
		p.is_bot = p.peer_id == 0
		if p.is_bot:
			p.is_local = authority
			if authority:
				var brain = BotScript.new()
				brain.me = p
				p.brain = brain
		else:
			p.is_local = (not demo) and p.peer_id == me
			if p.is_local:
				human = p
		var sp: Vector3 = spawns[i % spawns.size()]
		p.position = sp
		p.yaw = atan2(sp.x, sp.z)
		world.add_child(p)
		players.append(p)
	match_state.players = players

	if demo:
		cam.look_at_from_position(Vector3(30.0, 15.0, 0.0), Vector3(0, 1, 0), Vector3.UP)
		return
	Sfx.muted = false
	hud = HudScript.new()
	hud.game = self
	add_child(hud)
	match_state.feed.connect(hud.add_feed)
	if human != null:
		_pivot = human.position + Vector3(0, 1.55, 0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Net.game_ready(self)


func _exit_tree() -> void:
	if Net.game == self:
		Net.game = null


# ---------- Arena ----------

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("3d9bff")
	sm.sky_horizon_color = Color("cfeaff")
	sm.ground_bottom_color = Color("7fb2d9")
	sm.ground_horizon_color = Color("cfeaff")
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, 35.0, 0.0)
	sun.shadow_enabled = true
	sun.light_energy = 0.95
	add_child(sun)

	var s: float = ARENA
	# Piso y muros
	_box(Vector3(0, -0.5, 0), Vector3(s * 2.0, 1.0, s * 2.0), Color("aebbd0"))
	_box(Vector3(s + 0.5, 3.0, 0), Vector3(1.0, 6.0, s * 2.0 + 2.0), Color("8ecae6"))
	_box(Vector3(-s - 0.5, 3.0, 0), Vector3(1.0, 6.0, s * 2.0 + 2.0), Color("8ecae6"))
	_box(Vector3(0, 3.0, s + 0.5), Vector3(s * 2.0 + 2.0, 6.0, 1.0), Color("a2d2ff"))
	_box(Vector3(0, 3.0, -s - 0.5), Vector3(s * 2.0 + 2.0, 6.0, 1.0), Color("a2d2ff"))
	# Tarima central de dos pisos, con rampas
	_box(Vector3(0, 0.6, 0), Vector3(8.0, 1.2, 8.0), Color("ffd6a5"))
	_box(Vector3(0, 1.8, 0), Vector3(3.0, 1.2, 3.0), Color("ffadad"))
	_box(Vector3(0, 0.45, 6.4), Vector3(3.0, 0.3, 5.0), Color("fdffb6"), Vector3(0.2425, 0, 0))
	_box(Vector3(0, 0.45, -6.4), Vector3(3.0, 0.3, 5.0), Color("fdffb6"), Vector3(-0.2425, 0, 0))
	# Coberturas altas
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(Vector3(13.0 * sx, 1.4, 13.0 * sz), Vector3(5.0, 2.8, 1.2), Color("bdb2ff"), Vector3(0, PI * 0.25 * sx * sz, 0))
	# Bloques bajos para saltar
	_box(Vector3(17.0, 0.6, 0), Vector3(3.0, 1.2, 3.0), Color("caffbf"))
	_box(Vector3(-17.0, 0.6, 0), Vector3(3.0, 1.2, 3.0), Color("caffbf"))
	_box(Vector3(0, 0.6, 17.0), Vector3(3.0, 1.2, 3.0), Color("9bf6ff"))
	_box(Vector3(0, 0.6, -17.0), Vector3(3.0, 1.2, 3.0), Color("9bf6ff"))
	# Torres en dos esquinas: se sube con el trampolín de al lado
	_box(Vector3(20.0, 2.0, -20.0), Vector3(5.0, 4.0, 5.0), Color("ffc6ff"))
	_box(Vector3(-20.0, 2.0, 20.0), Vector3(5.0, 4.0, 5.0), Color("ffc6ff"))
	# Trampolines
	_pad(Vector3(15.5, 0.0, -15.5))
	_pad(Vector3(-15.5, 0.0, 15.5))
	_pad(Vector3(9.0, 0.0, 9.0))
	_pad(Vector3(-9.0, 0.0, -9.0))

	for i in 8:
		var ang: float = TAU * float(i) / 8.0 + PI / 8.0
		spawns.append(Vector3(cos(ang) * 19.0, 0.1, sin(ang) * 19.0))


func _box(pos: Vector3, size: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	bm.material = mat
	mesh.mesh = bm
	body.add_child(mesh)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.position = pos
	body.rotation = rot
	world.add_child(body)
	return body


func _pad(pos: Vector3) -> void:
	pads.append(pos)
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = Tuning.pad_radius
	cm.bottom_radius = Tuning.pad_radius
	cm.height = 0.1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ff4fa3")
	mat.emission_enabled = true
	mat.emission = Color("ff4fa3")
	mat.emission_energy_multiplier = 0.8
	cm.material = mat
	m.mesh = cm
	m.position = pos + Vector3(0, 0.05, 0)
	world.add_child(m)
	var inner := MeshInstance3D.new()
	var im := CylinderMesh.new()
	im.top_radius = Tuning.pad_radius * 0.55
	im.bottom_radius = Tuning.pad_radius * 0.55
	im.height = 0.1
	var imat := StandardMaterial3D.new()
	imat.albedo_color = Color("fff3b0")
	imat.emission_enabled = true
	imat.emission = Color("fff3b0")
	imat.emission_energy_multiplier = 0.8
	im.material = imat
	inner.mesh = im
	inner.position = pos + Vector3(0, 0.08, 0)
	world.add_child(inner)


# ---------- Entrada ----------

func _input(event: InputEvent) -> void:
	if demo:
		return
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and human != null and not menu_open:
			var mm := event as InputEventMouseMotion
			var sens: float = Tuning.mouse_sens
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and human.is_bearer:
				sens *= 0.6
			human.yaw -= mm.relative.x * sens
			human.pitch = clampf(human.pitch - mm.relative.y * sens, -1.2, 1.0)
	elif event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		if k.physical_keycode == KEY_ESCAPE:
			_toggle_menu()
		elif k.physical_keycode == KEY_Q:
			if menu_open or match_state.is_ended():
				_leave()
		elif k.physical_keycode == KEY_ENTER or k.physical_keycode == KEY_KP_ENTER:
			if match_state.is_ended() and authority:
				Net.start_match()


func _toggle_menu() -> void:
	if match_state.is_ended():
		return
	menu_open = not menu_open
	if not online:
		get_tree().paused = menu_open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if menu_open else Input.MOUSE_MODE_CAPTURED
	hud.show_pause(menu_open)


func _leave() -> void:
	Net.close()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


# ---------- Bucle ----------

func _cam_basis() -> Basis:
	return Basis.from_euler(Vector3(human.pitch, human.yaw, 0.0))


func _physics_process(delta: float) -> void:
	if authority and match_state.is_waiting():
		_wait_t += delta
		if _wait_t > 0.4 and ((not online) or Net.all_ready() or _wait_t > 8.0):
			emit_event(EV_START, [randi() % players.size()])
	if demo or human == null or get_tree().paused:
		return
	var space := get_world_3d().direct_space_state
	# Que la cámara no atraviese paredes
	var b: Basis = _cam_basis()
	var want: Vector3 = _pivot + b * Vector3(0.65, 0.25, _cam_dist)
	var q := PhysicsRayQueryParameters3D.create(_pivot, want, 1)
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		_cam_frac = 1.0
	else:
		var hp: Vector3 = hit["position"]
		_cam_frac = clampf(_pivot.distance_to(hp) / maxf(0.01, _pivot.distance_to(want)) - 0.08, 0.15, 1.0)
	# A dónde apunta la mira
	var ct: Transform3D = cam.global_transform
	var fwd: Vector3 = -ct.basis.z
	var from: Vector3 = ct.origin + fwd * (_cam_dist * _cam_frac + 1.0)
	var to: Vector3 = ct.origin + fwd * 120.0
	var q2 := PhysicsRayQueryParameters3D.create(from, to, 3)
	q2.exclude = [human.get_rid()]
	var hit2: Dictionary = space.intersect_ray(q2)
	if hit2.is_empty():
		human.aim_point = to
	else:
		human.aim_point = hit2["position"]


func _process(delta: float) -> void:
	if demo:
		_demo_ang += delta * 0.12
		cam.look_at_from_position(Vector3(cos(_demo_ang) * 30.0, 15.0, sin(_demo_ang) * 30.0), Vector3(0, 1, 0), Vector3.UP)
		return
	if human == null:
		return
	var aiming: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and human.is_bearer and human.alive and not menu_open
	var k: float = 1.0 - exp(-12.0 * delta)
	_cam_dist = lerpf(_cam_dist, 2.6 if aiming else 4.4, k)
	cam.fov = lerpf(cam.fov, 52.0 if aiming else 78.0, k)
	var target: Vector3 = human.global_position + Vector3(0, 1.55, 0)
	_pivot = _pivot.lerp(target, 1.0 - exp(-22.0 * delta))
	var b: Basis = _cam_basis()
	var offset: Vector3 = b * Vector3(0.65, 0.25, _cam_dist)
	_shake = maxf(0.0, _shake - delta * 2.5)
	var sh: Vector3 = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _shake * 0.15
	cam.global_transform = Transform3D(b, _pivot + offset * _cam_frac + b * sh)


# ---------- Eventos: los decide quien manda, se aplican en todas las PC ----------

func emit_event(kind: int, args: Array) -> void:
	apply_event(kind, args)
	if online:
		Net.send_event(kind, args)


func apply_event(kind: int, a: Array) -> void:
	if kind == EV_START:
		match_state.begin(players[a[0]])
		if hud != null and match_state.bearer == human:
			hud.flash("¡Empiezas con el Lanzador!", Color("ffe14d"))
	elif kind == EV_GIVE:
		match_state.apply_give(players[a[0]], players[a[1]])
	elif kind == EV_BALL:
		_spawn_ball(a[0], players[a[1]], a[2], a[3])
	elif kind == EV_ELIM:
		if balls.has(a[3]):
			balls[a[3]].queue_free()
		match_state.apply_elim(players[a[0]], players[a[1]], a[2])
	elif kind == EV_RESPAWN:
		players[a[0]].respawn_at(a[1])
	elif kind == EV_END:
		match_state.apply_end(a[0])
	elif kind == EV_TAKEOVER:
		_takeover(players[a[0]])


func host_give(to, from) -> void:
	emit_event(EV_GIVE, [to.slot, from.slot])


func host_elim(victim, ball) -> void:
	var dir: Vector3 = ball.velocity.normalized()
	emit_event(EV_ELIM, [victim.slot, ball.shooter.slot, dir, ball.id])


func host_respawn(p) -> void:
	emit_event(EV_RESPAWN, [p.slot, pick_spawn(p)])


func host_end() -> void:
	emit_event(EV_END, [match_state.scores()])


func request_shot(shooter, origin: Vector3, dir: Vector3) -> void:
	if authority:
		_host_shot(shooter, origin, dir)
	else:
		Net.send_shoot(origin, dir)


func _host_shot(shooter, origin: Vector3, dir: Vector3) -> void:
	var id: int = _next_ball
	_next_ball += 1
	emit_event(EV_BALL, [id, shooter.slot, origin, dir])


func _spawn_ball(id: int, shooter, origin: Vector3, dir: Vector3) -> void:
	var ball = BallScript.new()
	ball.setup(self, id, shooter, origin, dir)
	world.add_child(ball)
	balls[id] = ball
	if shooter == human:
		Sfx.play("shoot", randf_range(0.95, 1.1))
		_shake = maxf(_shake, 0.25)
	else:
		Sfx.play("shoot", randf_range(0.8, 0.95), -9.0)


func _takeover(p) -> void:
	p.peer_id = 0
	p.is_bot = true
	if hud != null:
		hud.add_feed("%s se fue. Ahora lo lleva un bot." % p.display_name, p.color)
	p.set_display_name(p.display_name + " (bot)")
	if authority:
		p.is_local = true
		var brain = BotScript.new()
		brain.me = p
		p.brain = brain


# ---------- Lo que llega por la red ----------

func net_state(sender: int, slot: int, pos: Vector3, vel: Vector3, yaw: float) -> void:
	if slot < 0 or slot >= players.size():
		return
	var p = players[slot]
	if p.is_local:
		return
	if sender != p.peer_id and sender != 1:
		return
	p.apply_net_state(pos, vel, yaw)


func net_shoot(sender: int, origin: Vector3, dir: Vector3) -> void:
	if not match_state.is_playing() or dir.length() < 0.5:
		return
	for p in players:
		if p.peer_id == sender and p.is_bearer and p.alive:
			_host_shot(p, origin, dir.normalized())
			return


func on_peer_left(id: int) -> void:
	for p in players:
		if p.peer_id == id:
			emit_event(EV_TAKEOVER, [p.slot])


# ---------- Efectos ----------

func add_splat(pos: Vector3, normal: Vector3, color: Color) -> void:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	var r: float = randf_range(0.35, 0.75)
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.02
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.3
	cm.material = mat
	m.mesh = cm
	var up: Vector3 = normal.normalized()
	var ref: Vector3 = Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x: Vector3 = up.cross(ref).normalized()
	var z: Vector3 = x.cross(up).normalized()
	m.transform = Transform3D(Basis(x, up, z), pos + up * (0.012 + randf() * 0.01))
	world.add_child(m)
	_splats.append(m)
	if _splats.size() > 90:
		var old = _splats.pop_front()
		old.queue_free()
	burst(pos + up * 0.1, up, color, 10, 4.5)


func burst(pos: Vector3, dir: Vector3, color: Color, amount: int, speed: float) -> void:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.6
	p.direction = dir
	p.spread = 65.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -18.0, 0)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.0
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	sm.material = mat
	p.mesh = sm
	p.position = pos
	world.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.3, false).timeout.connect(p.queue_free)


func ring(pos: Vector3, color: Color) -> void:
	var m := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.8
	t.outer_radius = 1.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	t.material = mat
	m.mesh = t
	m.position = pos + Vector3(0, 0.2, 0)
	m.scale = Vector3(0.3, 0.3, 0.3)
	world.add_child(m)
	var tw := m.create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "scale", Vector3(3.4, 1.0, 3.4), 0.45)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(m.queue_free)


func pick_spawn(_who) -> Vector3:
	var b = match_state.bearer
	if b == null:
		return spawns[randi() % spawns.size()]
	var bpos: Vector3 = b.global_position
	var sorted: Array = spawns.duplicate()
	sorted.sort_custom(func(p, q): return p.distance_to(bpos) > q.distance_to(bpos))
	return sorted[randi() % 3]


func on_go() -> void:
	Sfx.play("go")
	if hud != null:
		hud.flash("¡YA!", Color("7dffb0"))


func on_steal(new_bearer, old_bearer) -> void:
	ring(new_bearer.global_position, Color("ffe14d"))
	if hud == null:
		return
	if new_bearer == human:
		hud.flash("¡EL LANZADOR ES TUYO!", Color("ffe14d"))
		_shake = maxf(_shake, 0.6)
	elif old_bearer == human:
		hud.flash("¡Te lo robaron!", Color("ff6b6b"))
		_shake = maxf(_shake, 0.8)


func on_elimination(shooter, victim) -> void:
	burst(victim.global_position + Vector3(0, 1.0, 0), Vector3.UP, shooter.color, 30, 8.0)
	if hud == null:
		return
	if victim == human:
		hud.flash("¡Te pintaron!", Color("ff6b6b"))
		_shake = maxf(_shake, 1.0)
	elif shooter == human:
		var txt: String = "+1"
		if shooter.streak == 2:
			txt = "¡DOBLE!"
		elif shooter.streak == 3:
			txt = "¡TRIPLE!"
		elif shooter.streak >= 4:
			txt = "¡IMPARABLE!"
		if shooter.streak >= 2:
			Sfx.play("streak", 1.0 + 0.12 * float(mini(shooter.streak, 6)))
		hud.flash(txt, Color("7dffb0"))
		_shake = maxf(_shake, 0.4)


func on_match_ended() -> void:
	if demo:
		return
	menu_open = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_end()
