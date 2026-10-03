extends CharacterBody2D

const WALK_SPEED = 200.0
const RUN_SPEED = 300.0

@onready var anim = $AnimatedSprite2D

var is_jumping = false

func _physics_process(delta):
	# Jika sedang transisi fade layar, hentikan pergerakan player
	if GameManager.is_transitioning:
		velocity = Vector2.ZERO
		move_and_slide()
		anim.play("idle1")
		return

	# 1. Ambil Input Arah
	var direction = Input.get_vector("walk_left", "walk_right", "walk_up", "walk_down")

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
			# Balikkan sprite secara horizontal jika bergerak ke kiri
			if velocity.x != 0:
				anim.flip_h = velocity.x < 0
			
			# Percepat animasi 1.5x jika sedang lari, kembalikan ke 1.0x jika jalan
			anim.speed_scale = 1.5 if is_running else 1.0
			
			# Tentukan animasi berdasarkan arah dominan
			if abs(velocity.x) > abs(velocity.y):
				# Pergerakan Horizontal
				if is_running:
					anim.play("run1")
				else:
					anim.play("walk_side1")
			else:
				# Pergerakan Vertikal (Selalu pakai walk, kecepatan diatur oleh speed_scale di atas)
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

	# Cek apakah ada data spawn point yang tersimpan di GameManager
	if GameManager.target_spawn_point != "":
		var target_name = GameManager.target_spawn_point
		GameManager.target_spawn_point = ""
		
		var spawned = false
		# 1. Cari semua node di group "spawn_points"
		var spawn_nodes = get_tree().get_nodes_in_group("spawn_points")
		for node in spawn_nodes:
			if node.name == target_name:
				global_position = node.global_position
				spawned = true
				break
		
		# 2. Fallback jika node belum/tidak dimasukkan ke grup "spawn_points"
		if not spawned:
			var parent = get_parent()
			if parent:
				var node = parent.find_child(target_name, true, false)
				if node and node is Node2D:
					global_position = node.global_position
					spawned = true
		
		if not spawned:
			var current = get_tree().current_scene
			if current:
				var node = current.find_child(target_name, true, false)
				if node and node is Node2D:
					global_position = node.global_position
					spawned = true
