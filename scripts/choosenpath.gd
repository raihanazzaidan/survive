extends Node2D

@export var walk_duration: float = 1.0               # Durasi player berjalan otomatis
@export var walk_distance: Vector2 = Vector2(0, -200)  # Jarak jalan minimum (bisa ditambah otomatis, lihat _hitung_target_jalan)
## Batas posisi player di layar (0 = atas, 1 = bawah) supaya tidak tertutup kotak dialog.
## Kotak dialog menutupi sekitar 31% bagian bawah layar, jadi 0.55 sudah aman.
@export_range(0.5, 0.65) var dialog_safe_ratio: float = 0.55

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
		anim_sprite.play("walk_up1") # Sesuaikan nama animasi jalan Anda
		
	var tween = create_tween()
	var target_pos = _hitung_target_jalan()
	# Kecepatan jalan dijaga sama walau jaraknya bertambah.
	var duration := walk_duration * maxf(1.0, player.position.distance_to(target_pos) / maxf(walk_distance.length(), 1.0))
	tween.tween_property(player, "position", target_pos, duration)
	
	await tween.finished
	
	if anim_sprite:
		anim_sprite.play("idle1") # Sesuaikan nama animasi diam Anda
		
	# Kembalikan kontrol ke player
	_set_player_control(true)

	# Dialog di awal jalur
	_show_intro_dialogue()


## Menentukan titik berhenti player. Minimal sejauh walk_distance, lalu ditambah otomatis
## bila di titik itu player masih tampil terlalu rendah di layar (tertutup kotak dialog).
## Kamera TIDAK digeser sama sekali, jadi tidak pernah keluar dari batas peta.
func _hitung_target_jalan() -> Vector2:
	var target: Vector2 = player.position + walk_distance
	var camera: Camera2D = player.get_node_or_null("Camera2D")
	if not camera:
		return target

	var zoom_y: float = maxf(camera.zoom.y, 0.01)
	var view_h: float = get_viewport_rect().size.y
	var half_view: float = view_h / (2.0 * zoom_y)            # setengah tinggi layar dalam satuan dunia
	var cam_off: float = camera.position.y + camera.offset.y
	var cam_min: float = camera.limit_top + half_view          # pusat kamera tertinggi yang diizinkan
	var cam_max: float = camera.limit_bottom - half_view       # pusat kamera terendah yang diizinkan
	if cam_min > cam_max:
		return target                                          # peta lebih pendek dari layar, abaikan

	var batas_layar_y: float = view_h * dialog_safe_ratio
	# Posisi player di layar = tengah layar + (y player - pusat kamera yang sudah di-clamp) * zoom
	var cam_center: float = clampf(target.y + cam_off, cam_min, cam_max)
	var layar_y: float = view_h * 0.5 + (target.y - cam_center) * zoom_y
	if layar_y <= batas_layar_y:
		return target

	# Kamera menempel batas bawah peta -> naikkan player sampai berada di atas batas aman.
	var y_perlu: float = cam_max + (batas_layar_y - view_h * 0.5) / zoom_y
	target.y = maxf(minf(target.y, y_perlu), camera.limit_top + half_view * 0.5)
	return target


func _set_player_control(enable: bool) -> void:
	if player:
		player.set_physics_process(enable)
		player.set_process_unhandled_input(enable)


## Dialog di awal jalur menanjak: tips keselamatan sepanjang perjalanan. Hanya tampil sekali per sesi.
func _show_intro_dialogue() -> void:
	if GameManager.has_seen("dialog_jalur_tinggi"):
		return
	# Tunggu transisi layar selesai agar kotak dialog tidak muncul di balik fade.
	while GameManager.is_transitioning:
		await get_tree().process_frame
	var lines := [
		"Jalan ini menanjak dan menjauh dari sungai. Sepertinya inilah arah yang tepat.",
		"Tanah licin karena hujan, jadi aku harus berjalan pelan, hati-hati, dan tetap di jalan setapak.",
		"Kalau petir menyambar, aku tidak boleh berteduh di bawah pohon tinggi atau dekat tiang listrik. Aku harus segera mencari tempat berlindung yang kokoh.",
		"Tetap tenang dan terus naik. Tanda atau tenda evakuasi pasti ada di ujung jalur."
	]
	if DialogueBox.show_dialogue(lines, "Jalur Menanjak", DialogueBox.get_player_portrait()):
		GameManager.mark_seen("dialog_jalur_tinggi")
		await DialogueBox.dialogue_finished
