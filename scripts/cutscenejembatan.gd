extends Node2D

@onready var ground_layer: TileMapLayer = $ground
@onready var player: CharacterBody2D = $mainPlayer
@onready var spawn_jembatan: Marker2D = get_node_or_null("SpawnJembatan")


func _ready() -> void:
	if GameManager.target_spawn_point == "SpawnJembatan":
		if spawn_jembatan:
			player.global_position = spawn_jembatan.global_position

		# Membalik arah hadap player setelah keluar dari cutscene
		var anim = player.get_node_or_null("AnimatedSprite2D")
		if anim:
			anim.flip_h = true

		GameManager.target_spawn_point = ""

	setup_camera_limits()


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


func _on_body_entered(body: Node2D) -> void:
	if body == player:
		GameManager.target_spawn_point = "SpawnKembaliJalur"
		SceneTransition.change_scene("res://scenes/pathchoose.tscn")
