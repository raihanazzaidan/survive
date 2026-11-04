extends Node2D

@export var walk_duration: float = 1.0               # Durasi player berjalan otomatis
@export var walk_distance: Vector2 = Vector2(120,0)  # Jarak pergerakan otomatis (misal: 40px ke bawah)

@onready var ground_layer: TileMapLayer = $ground
@onready var player: CharacterBody2D = $mainPlayer


func _ready() -> void:
	# 1. Kunci batas kamera berdasarkan TileMapLayer $ground
	setup_camera_limits()
	
	# 2. Jalan otomatis player saat masuk map
	play_intro_walk()


func setup_camera_limits() -> void:
	if not ground_layer or not player:
		return
		
	var camera: Camera2D = player.get_node_or_null("Camera2D")
	if not camera:
		return
		
	var used_rect = ground_layer.get_used_rect()
	var tile_size = ground_layer.tile_set.tile_size
		
	camera.limit_left = used_rect.position.x * tile_size.x
	camera.limit_top = used_rect.position.y * tile_size.y
	camera.limit_right = used_rect.end.x * tile_size.x
	camera.limit_bottom = used_rect.end.y * tile_size.y
		
	camera.position_smoothing_enabled = true


func play_intro_walk() -> void:
	if not player:
		return
		
	# Kunci kontrol player selama animasi jalan otomatis
	_set_player_control(false)
	
	var anim_sprite = player.get_node_or_null("AnimatedSprite2D")
	if anim_sprite:
		anim_sprite.play("run1") # Sesuaikan nama animasi jalan Anda
		
	var tween = create_tween()
	var target_pos = player.position + walk_distance
	tween.tween_property(player, "position", target_pos, walk_duration)
	
	await tween.finished
	
	if anim_sprite:
		anim_sprite.play("idle1") # Sesuaikan nama animasi diam Anda
		
	# Kembalikan kontrol ke player
	_set_player_control(true)


func _set_player_control(enable: bool) -> void:
	if player:
		player.set_physics_process(enable)
		player.set_process_unhandled_input(enable)
