extends CharacterBody2D

const WALK_SPEED = 150.0
const RUN_SPEED = 250.0 # Kecepatan saat lari

@onready var anim = $AnimatedSprite2D

var is_jumping = false

func _physics_process(delta):
	# 1. Ambil Input Arah
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var current_speed = WALK_SPEED
	
	# 2. Cek Tombol Lari (Misal menahan tombol Shift)
	var is_running = Input.is_key_pressed(KEY_SHIFT)
	if is_running:
		current_speed = RUN_SPEED
		
	# Terapkan pergerakan
	velocity = direction * current_speed
	move_and_slide()
	
	# 3. Logika Lompat (Tekan Spasi / ui_accept)
	if Input.is_action_just_pressed("ui_accept") and not is_jumping:
		is_jumping = true
		anim.play("jump")
		
		# Simulasi durasi lompat sederhana (misal 0.5 detik)
		# Kamu bisa mengganti ini menggunakan sinyal animation_finished nantinya
		await get_tree().create_timer(0.5).timeout 
		is_jumping = false

	# 4. Logika Animasi Berjalan & Diam (Hanya berjalan jika tidak sedang lompat)
	if not is_jumping:
		if velocity.length() > 0:
			# Balikkan sprite secara horizontal jika bergerak ke kiri
			if velocity.x != 0:
				anim.flip_h = velocity.x < 0
				
			if is_running:
				anim.play("running")
			else:
				# Tentukan animasi jalan berdasarkan arah dominan
				if abs(velocity.x) > abs(velocity.y):
					anim.play("walk") # Pakai "walk" untuk kiri/kanan
				else:
					if velocity.y > 0:
						anim.play("walk_down")
					else:
						anim.play("walk_up")
		else:
			anim.play("idle")
