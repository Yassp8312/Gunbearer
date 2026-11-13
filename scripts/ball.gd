extends Node3D
# Bola de pintura. Todos la ven volar, pero solo quien manda decide si le dio a alguien.

var id: int = 0
var velocity: Vector3 = Vector3.ZERO
var shooter = null
var color: Color = Color.WHITE
var game = null
var _life: float = 0.0
var _gravity: float = 7.0


func setup(p_game, p_id: int, p_shooter, p_pos: Vector3, p_dir: Vector3) -> void:
	game = p_game
	id = p_id
	shooter = p_shooter
	color = p_shooter.color
	position = p_pos
	velocity = p_dir * float(p_shooter.stat("ball_speed"))
	_gravity = float(p_shooter.stat("ball_gravity"))


func _ready() -> void:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = Tuning.ball_radius
	s.height = Tuning.ball_radius * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.6
	s.material = mat
	m.mesh = s
	add_child(m)


func _exit_tree() -> void:
	if game != null:
		game.balls.erase(id)


func _physics_process(delta: float) -> void:
	_life += delta
	if _life > Tuning.ball_life:
		queue_free()
		return
	var steps: int = 2
	var dt: float = delta / float(steps)
	var space := get_world_3d().direct_space_state
	for i in steps:
		velocity.y -= _gravity * dt
		var from: Vector3 = global_position
		var to: Vector3 = from + velocity * dt
		var q := PhysicsRayQueryParameters3D.create(from, to, 1)
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty():
			game.add_splat(hit["position"], hit["normal"], color)
			Sfx.play("splat", randf_range(0.9, 1.2), -8.0)
			queue_free()
			return
		global_position = to
		if game.authority:
			var victim = game.match_state.ball_hit_test(self, to)
			if victim != null:
				queue_free()
				return
