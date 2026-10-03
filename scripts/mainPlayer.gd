extends CharacterBody2D

const WALK_SPEED = 200.0
const RUN_SPEED = 300.0

@onready var anim = $AnimatedSprite2D

var is_jumping = false

func _physics_process(delta):
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
