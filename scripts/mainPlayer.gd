
extends CharacterBody2D

const WALK_SPEED = 200.0
const RUN_SPEED = 300.0

@onready var anim = $AnimatedSprite2D
@export var inv: Inv

var is_jumping = false
var is_cutscene: bool = false

# Durasi gerakan otomatis setelah kembali dari jembatan
var return_move_timer: float = 0.5


func _physics_process(delta):
	if is_cutscene:
		move_and_slide()
		return

	if GameManager.is_transitioning or GameManager.dialogue_active:
		velocity = Vector2.ZERO
		move_and_slide()
		anim.play("idle1")
		return

		# Saat kotak dialog terbuka, pemain diam di tempat
	if GameManager.dialogue_active:
		velocity = Vector2.ZERO
		move_and_slide()
		anim.speed_scale = 1.0
		anim.play("idle1")
		return

	# Gerakan otomatis ke kiri setelah kembali dari jembatan
	if GameManager.is_moving_left_after_return:
		velocity = Vector2.LEFT * WALK_SPEED

		anim.flip_h = false
		anim.speed_scale = 1.0
		anim.play("walk_side1")

		move_and_slide()

		return_move_timer -= delta

		if return_move_timer <= 0:
			GameManager.is_moving_left_after_return = false
			return_move_timer = 0.5

			velocity = Vector2.ZERO
			anim.play("idle1")

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
		anim.play("jump1")

		await get_tree().create_timer(0.5).timeout

		is_jumping = false

	# 4. Logika Animasi
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

		else:
			anim.speed_scale = 1.0
			anim.play("idle1")


func _ready() -> void:
	if not is_in_group("player"):
		add_to_group("player")

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

		elif target_name == "SpawnKembaliJalur":
			anim.flip_h = true


func mulai_cutscene():
	is_cutscene = true

	if anim:
		anim.speed_scale = 1.0
		anim.play("walk_down1")


func mulai_main_normal():
	is_cutscene = false

	if anim:
		anim.speed_scale = 1.0
		anim.play("idle1")


func collect(item):
	inv.insert(item)
