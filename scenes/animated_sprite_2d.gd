extends AnimatedSprite2D

@export var parallax_strength: float = 0.05
var initial_position: Vector2

func _ready() -> void:
	# Menyimpan posisi awal karakter saat game pertama kali dijalankan
	initial_position = position

func _process(delta: float) -> void:
	var mouse_pos = get_global_mouse_position()
	# Menghitung target posisi berdasarkan offset mouse ditambah posisi awal
	var target_pos = initial_position + (mouse_pos * parallax_strength)
	position = position.lerp(target_pos, delta * 5.0)
