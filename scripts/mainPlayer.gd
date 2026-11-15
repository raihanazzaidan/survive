extends CharacterBody2D

const WALK_SPEED = 200.0
const RUN_SPEED = 300.0

const SFX_RUNNING_INT = preload("res://assets/sfx/runningint.wav")
const SFX_FOOTSTEP_GRAVEL = preload("res://assets/sfx/footstepgravel.wav")

@onready var anim = $AnimatedSprite2D
@export var inv: Inv

var is_jumping = false
var is_cutscene: bool = false

# Durasi gerakan otomatis setelah kembali dari jembatan
var return_move_timer: float = 0.5

var footstep_player: AudioStreamPlayer
var footstep_timer: float = 0.0


func _physics_process(delta):
	if is_cutscene:
		_stop_footstep()
		move_and_slide()
		return

	if GameManager.is_transitioning or GameManager.dialogue_active:
		_stop_footstep()
		velocity = Vector2.ZERO
		move_and_slide()
		anim.play("idle1")
		return

	# Gerakan otomatis ke kiri setelah kembali dari jembatan
	if GameManager.is_moving_left_after_return:
		velocity = Vector2.LEFT * WALK_SPEED

		anim.flip_h = true
		anim.speed_scale = 1.0
		anim.play("walk_side1")

		move_and_slide()
		_update_footstep(delta, false)

		return_move_timer -= delta

		if return_move_timer <= 0:
			GameManager.is_moving_left_after_return = false
			return_move_timer = 0.5

			velocity = Vector2.ZERO
			anim.play("idle1")
			_stop_footstep()

		return

	# 1. Ambil Input Arah
	var direction = Input.get_vector(
		"walk_left",
		"walk_right",
		"walk_up",
		"walk_down"
	)

	var current_speed = WALK_SPEED

	# 2. Cek Tombol Lari
	var is_running = Input.is_key_pressed(KEY_SHIFT)

	if is_running:
		current_speed = RUN_SPEED

	# Terapkan pergerakan
	velocity = direction * current_speed
	move_and_slide()

	# 3. Logika Lompat
	if Input.is_action_just_pressed("ui_accept") and not is_jumping:
		is_jumping = true
		_stop_footstep()
		anim.play("jump1")

		await get_tree().create_timer(0.5).timeout

		is_jumping = false

	# 4. Logika Animasi & SFX Footstep
	if not is_jumping:
		if velocity.length() > 0:

			# Balikkan sprite jika bergerak ke kiri
			if velocity.x != 0:
				anim.flip_h = velocity.x < 0

			# Percepat animasi jika sedang lari
			anim.speed_scale = 1.5 if is_running else 1.0

			# Tentukan animasi berdasarkan arah dominan
			if abs(velocity.x) > abs(velocity.y):
				if is_running:
					anim.play("run1")
				else:
					anim.play("walk_side1")
			else:
				if velocity.y > 0:
					anim.play("walk_down1")
				else:
					anim.play("walk_up1")

			_update_footstep(delta, is_running)

		else:
			anim.speed_scale = 1.0
			anim.play("idle1")
			_stop_footstep()
	else:
		_stop_footstep()


func _ready() -> void:
	if not is_in_group("player"):
		add_to_group("player")

	_setup_footstep_audio()

	# Cek data spawn point dari GameManager
	if GameManager.target_spawn_point != "":
		var target_name = GameManager.target_spawn_point

		var spawned = false

		# 1. Cari spawn point dalam grup spawn_points
		var spawn_nodes = get_tree().get_nodes_in_group("spawn_points")

		for node in spawn_nodes:
			if node.name == target_name:
				global_position = node.global_position
				spawned = true
				break

		# 2. Fallback pencarian di parent
		if not spawned:
			var parent = get_parent()

			if parent:
				var node = parent.find_child(target_name, true, false)

				if node and node is Node2D:
					global_position = node.global_position
					spawned = true

		# 3. Fallback pencarian di current scene
		if not spawned:
			var current = get_tree().current_scene

			if current:
				var node = current.find_child(target_name, true, false)

				if node and node is Node2D:
					global_position = node.global_position
					spawned = true

		# 4. Atur arah hadap setelah teleport
		if target_name == "SpawnJembatan":
			anim.flip_h = true

		elif target_name in ["SpawnKembaliJalur", "SpawnDariBanjir", "SpawnDariJembatan"]:
			anim.flip_h = true


func _setup_footstep_audio() -> void:
	if not footstep_player:
		footstep_player = AudioStreamPlayer.new()
		footstep_player.name = "FootstepAudio"
		footstep_player.bus = &"Master"
		add_child(footstep_player)


func _is_in_interior() -> bool:
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return false
	var scene_path = tree.current_scene.scene_file_path
	if scene_path != "" and scene_path.get_file() == "interior.tscn":
		return true
	return tree.current_scene.name.to_lower() == "interior"


func _update_footstep(delta: float, is_running: bool) -> void:
	if not footstep_player:
		return

	var in_interior = _is_in_interior()
	var target_stream = SFX_RUNNING_INT if in_interior else SFX_FOOTSTEP_GRAVEL
	var target_volume = -6.0 if in_interior else -3.0
	var speed_multiplier = 1.35 if is_running else 1.0
	var step_interval = (0.58 if in_interior else 1.0) / speed_multiplier

	footstep_timer -= delta

	if footstep_timer <= 0.0 or not footstep_player.playing or footstep_player.stream != target_stream:
		footstep_timer = step_interval
		if footstep_player.stream != target_stream:
			footstep_player.stream = target_stream
			footstep_player.volume_db = target_volume
		footstep_player.pitch_scale = speed_multiplier
		footstep_player.play()


func _stop_footstep() -> void:
	footstep_timer = 0.0
	if footstep_player and footstep_player.playing:
		footstep_player.stop()


func start_footstep(is_running: bool = false) -> void:
	_update_footstep(0.0, is_running)


func stop_footstep() -> void:
	_stop_footstep()


func mulai_cutscene():
	is_cutscene = true
	_stop_footstep()

	if anim:
		anim.speed_scale = 1.0
		anim.play("walk_down1")


func mulai_main_normal():
	is_cutscene = false
	_stop_footstep()

	if anim:
		anim.speed_scale = 1.0
		anim.play("idle1")


func collect(item):
	inv.insert(item)
