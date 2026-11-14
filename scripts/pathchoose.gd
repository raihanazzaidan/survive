
extends Node2D

@export var walk_duration: float = 1.0
@export var walk_distance: Vector2 = Vector2(60, 0)
@export var return_run_distance: Vector2 = Vector2(-60, 0)
@export var return_run_duration: float = 1.0

@onready var ground_layer: TileMapLayer = $ground
@onready var player: CharacterBody2D = $mainPlayer


func _ready() -> void:
	setup_camera_limits()

	# Simpan target spawn yang sudah dibaca oleh mainPlayer.gd.
	var target_name = GameManager.target_spawn_point

	# Cek apakah player baru kembali dari cutscene.
	var is_returning = (
		target_name == "SpawnKembaliJalur"
		or target_name == "SpawnDariBanjir"
	)

	# Bersihkan target setelah player selesai membaca titik spawn.
	GameManager.target_spawn_point = ""

	# Bersihkan status kembali dari sistem upstream.
	GameManager.returning_from_detour = false
	GameManager.last_path_spawn = ""

	if is_returning:
		play_intro_walk(true)
	else:
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


func play_intro_walk(is_returning: bool = false) -> void:
	if not player:
		return

	_set_player_control(false)
	player.is_cutscene = true

	var camera: Camera2D = player.get_node_or_null("Camera2D")
	if is_returning and camera:
		camera.reset_smoothing()

	var anim_sprite = player.get_node_or_null("AnimatedSprite2D")

	var target_direction = walk_distance
	var movement_duration = walk_duration

	if is_returning:
		target_direction = return_run_distance
		movement_duration = return_run_duration

	if anim_sprite:
		anim_sprite.flip_h = target_direction.x < 0.0
		anim_sprite.play("run1")

	var tween = create_tween()
	var target_pos = player.position + target_direction
	tween.tween_property(player, "position", target_pos, movement_duration)

	await tween.finished

	if anim_sprite:
		anim_sprite.play("idle1")

	player.is_cutscene = false
	_set_player_control(true)

	_show_intro_dialogue()


func _set_player_control(enable: bool) -> void:
	if player:
		player.set_physics_process(enable)
		player.set_process_unhandled_input(enable)


## Dialog di persimpangan: mengajak pemain mengamati keadaan sebelum memilih jalur.
## Hanya tampil sekali per sesi.
func _show_intro_dialogue() -> void:
	if GameManager.has_seen("dialog_persimpangan"):
		return

	# Tunggu transisi layar selesai.
	while GameManager.is_transitioning:
		await get_tree().process_frame

	var lines := [
		"Aku sampai di persimpangan. Berhenti sebentar dan amati keadaan sekitar sebelum memilih jalan.",
		"Ada tiga hal yang harus kuperiksa: apakah jalannya terendam air, seberapa deras arusnya, dan apakah jembatan atau bangunan terlihat rusak.",
		"Aku harus memilih jalur yang menanjak ke tempat lebih tinggi dan menjauhi sungai.",
		"Kalau sebuah jalur ternyata berbahaya, jangan dipaksakan. Aku akan kembali ke persimpangan dan mencoba jalur lain."
	]

	if DialogueBox.show_dialogue(lines, "Persimpangan", DialogueBox.get_player_portrait()):
		GameManager.mark_seen("dialog_persimpangan")
