extends Node2D

@export var walk_duration: float = 1.0               # Durasi player berjalan otomatis saat masuk map
@export var walk_distance: Vector2 = Vector2(120, 0) # Jarak jalan otomatis saat masuk map
@export var jeda_sebelum_radio: float = 2.0          # Detik setelah dialog 1, sebelum notifikasi radio
@export var jeda_setelah_radio: float = 3.0          # Detik setelah notifikasi radio hilang, sebelum Basarnas datang
@export var lama_radio_bertahan: float = 5.0         # Detik teks radio tetap terlihat

const SKRIP_RADIO := "res://scripts/radio_notif.gd"
const SKRIP_LAYAR_SELESAI := "res://scripts/game_completed.gd"

@onready var ground_layer: TileMapLayer = $ground
@onready var player: CharacterBody2D = $mainPlayer
@onready var zona_evakuasi: Area2D = $ZonaEvakuasi
@onready var panah_petunjuk = $PanahPetunjuk
@onready var tim_basarnas = $BasarnasTim
@onready var titik_tengah: Marker2D = get_node_or_null("TitikTengah")

var _ending_dimulai: bool = false


func _ready() -> void:
	# Bersihkan sisa target spawn dari scene sebelumnya
	GameManager.target_spawn_point = ""

	# Kunci batas kamera berdasarkan TileMapLayer $ground
	setup_camera_limits()

	# Deteksi saat pemain masuk zona evakuasi
	zona_evakuasi.body_entered.connect(_on_zona_evakuasi_body_entered)

	# Jalan otomatis player saat masuk map
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
		anim_sprite.play("run1")

	var tween = create_tween()
	var target_pos = player.position + walk_distance
	tween.tween_property(player, "position", target_pos, walk_duration)

	await tween.finished

	if anim_sprite:
		anim_sprite.play("idle1")

	# Kembalikan kontrol ke player
	_set_player_control(true)


# Dipanggil saat ada benda masuk ke ZonaEvakuasi
func _on_zona_evakuasi_body_entered(body: Node2D) -> void:
	if _ending_dimulai or not body.is_in_group("player"):
		return
	_ending_dimulai = true
	_mulai_ending()


# Urutan ending:
# berhenti -> jalan ke titik tengah -> dialog 1 -> jeda -> notifikasi radio
# -> jeda -> Basarnas datang -> bertemu pemain -> dialog 2 -> layar GAME COMPLETED
func _mulai_ending() -> void:
	# Pemain berhenti di tempat
	_set_player_control(false)
	player.velocity = Vector2.ZERO

	var anim_sprite = player.get_node_or_null("AnimatedSprite2D")
	if anim_sprite:
		anim_sprite.speed_scale = 1.0
		anim_sprite.play("idle1")

	panah_petunjuk.sembunyikan()

	# 1. Jalan otomatis ke titik tengah
	await _jalan_ke_titik_tengah(anim_sprite)

	# 2. Dialog 1 (pakai DialogueBox yang sudah ada)
	await _tampilkan_dialog(
		[
			"Selamat! Kamu telah berhasil mencapai tempat evakuasi yang aman. Sekarang, tetaplah berada di sini dan tunggu bantuan tiba.",
			"Sambil menunggu, dengarkan informasi dan arahan yang disampaikan melalui radio."
		],
		"Tempat Evakuasi"
	)

	# 3. Tunggu sebentar, lalu notifikasi radio + suara kresek
	await get_tree().create_timer(jeda_sebelum_radio).timeout
	await _tampilkan_radio(
		"Perhatian! Tim bantuan akan segera tiba di lokasi. Tetaplah di tempat dan tetap tenang.",
		lama_radio_bertahan
	)

	# Notifikasi sudah hilang, tunggu sebentar (Basarnas BELUM muncul)
	await get_tree().create_timer(jeda_setelah_radio).timeout

	# 4. Tim Basarnas datang dari kiri sampai menyentuh collision pemain
	tim_basarnas.mulai_datang(player)
	await tim_basarnas.sudah_bertemu

	# Pemain menoleh ke arah tim penyelamat (kiri)
	if anim_sprite:
		anim_sprite.flip_h = true
	await get_tree().create_timer(0.6).timeout

	# 5. Dialog 2 (hanya muncul setelah collision terdeteksi)
	await _tampilkan_dialog(
		[
			"Syukurlah, kamu berhasil ditemukan oleh tim penyelamat. Sekarang, ikuti arahan petugas, tetap tenang, dan jangan meninggalkan area tanpa izin.",
			"Petugas akan membantumu melanjutkan proses evakuasi ke tempat yang lebih aman."
		],
		"Tim Basarnas"
	)

	# 6. Pop up GAME COMPLETED
	await get_tree().create_timer(0.4).timeout
	_tampilkan_layar_selesai()


# Pemain berjalan ke Marker2D "TitikTengah" lalu berhenti
func _jalan_ke_titik_tengah(anim_sprite) -> void:
	if titik_tengah == null:
		push_warning("Node TitikTengah (Marker2D) tidak ditemukan di scene evakuasi")
		return

	var tujuan: Vector2 = titik_tengah.global_position
	var jarak: float = player.global_position.distance_to(tujuan)
	if jarak < 4.0:
		return

	if anim_sprite:
		anim_sprite.flip_h = tujuan.x < player.global_position.x
		anim_sprite.play("walk_side1")

	var durasi: float = jarak / 150.0   # kecepatan jalan sekitar 150 px per detik
	var tween = create_tween()
	tween.tween_property(player, "global_position", tujuan, durasi)
	await tween.finished

	if anim_sprite:
		anim_sprite.play("idle1")


# Menampilkan DialogueBox lalu menunggu pemain menekan tombol SELESAI
func _tampilkan_dialog(halaman: Array, judul: String) -> void:
	var terbuka: bool = DialogueBox.show_dialogue(halaman, judul, DialogueBox.get_player_portrait())
	if terbuka:
		await DialogueBox.dialogue_finished


# Menampilkan notifikasi radio lalu menunggu sampai hilang
func _tampilkan_radio(teks: String, lama: float) -> void:
	var skrip = load(SKRIP_RADIO)
	if skrip == null:
		push_error("Script radio tidak ditemukan: " + SKRIP_RADIO)
		return
	var radio = CanvasLayer.new()
	radio.set_script(skrip)
	add_child(radio)
	radio.tampil(teks, lama)
	await radio.selesai
	radio.queue_free()


# Menampilkan pop up GAME COMPLETED langsung dari script (tanpa scene)
func _tampilkan_layar_selesai() -> void:
	var skrip = load(SKRIP_LAYAR_SELESAI)
	if skrip == null:
		push_error("Script layar selesai tidak ditemukan: " + SKRIP_LAYAR_SELESAI)
		return
	var layar = CanvasLayer.new()
	layar.set_script(skrip)
	add_child(layar)


func _set_player_control(enable: bool) -> void:
	if player:
		player.set_physics_process(enable)
		player.set_process_unhandled_input(enable)
