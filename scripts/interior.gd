extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var player: CharacterBody2D = $mainPlayer
@onready var ground_layer: TileMapLayer = $LantaiLayer # atau $ground di luar rumah

func _ready() -> void:
	setup_camera_limits()
	if has_node("Fade_transition") and $Fade_transition.has_node("AnimationPlayer"):
		$Fade_transition/AnimationPlayer.play("Fade_out")
	# Cek apakah cutscene tangga harus diputar (hanya 1 kali ketika dari main menu)
	if not GameManager.has_played_intro_cutscene and GameManager.target_spawn_point == "":
		GameManager.has_played_intro_cutscene = true
		player.position = Vector2(515, -602)
		player.mulai_cutscene()
		animation_player.play("stairs")
	else:
		# Jika sudah pernah cutscene (misal masuk kembali dari luar), jangan jalankan animasi stairs lagi
		animation_player.stop()
		player.mulai_main_normal()
		if has_node("CanvasModulate"):
			$CanvasModulate.color = Color(0.12, 0.12, 0.20, 1.0)

func setup_camera_limits() -> void:
	if not ground_layer or not player:
		return
		
	var camera: Camera2D = player.get_node_or_null("Camera2D")
	if not camera:
		return
		
		# Ambil area petak tile yang dipakai
	var used_rect = ground_layer.get_used_rect()
	var tile_size = ground_layer.tile_set.tile_size
		
		# Konversi koordinat tile ke pixel dunia
	camera.limit_left = used_rect.position.x * tile_size.x
	camera.limit_top = used_rect.position.y * tile_size.y
	camera.limit_right = used_rect.end.x * tile_size.x
	camera.limit_bottom = used_rect.end.y * tile_size.y
		
		# Aktifkan pergerakan halus jika belum
	camera.position_smoothing_enabled = true
