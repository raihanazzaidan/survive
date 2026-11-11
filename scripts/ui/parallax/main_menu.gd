extends Control
@onready var lightning_flash = $LightningFlash
@onready var lightning_timer = $LightningTimer
@onready var bgm_player = $BGMPlayer
@onready var rain_player = $RainPlayer
@onready var thunder_player = $ThunderPlayer
var button_type = null

# ======================= PARALLAX =======================
# Urutan = dari paling belakang ke paling depan (sama dengan urutan node di scene).
# Nilai   = seberapa jauh layer bergeser mengikuti mouse (0 = diam, 1 = paling bergerak).
# Silakan ubah angkanya sesuai selera.
const PARALLAX_DEPTHS := {
	"background": 0.0,
	"foreground": 0.1,
	"foreground2": 0.2,
	"bush1": 0.35,
	"bush2": 0.5,
	"bush3": 0.65,
	"island": 0.8,
	"island2": 1.0,
}

## Pergeseran maksimum layer terdepan (dalam piksel ruang 1920x1080).
@export var parallax_strength := 40.0
## Makin besar = makin cepat mengejar mouse. Tidak tergantung FPS.
@export var parallax_smoothing := 6.0
## Linear = gerakan halus tanpa shimmer. Matikan kalau mau tetap Nearest (pixel tajam).
@export var parallax_linear_filter := true

@onready var layer_root: Node2D = $Node2D
var _layers: Array[Sprite2D] = []
var _parallax := Vector2.ZERO


func _ready() -> void:
	_setup_parallax()
	get_viewport().size_changed.connect(_fit_parallax_layers)

	WeatherFX.default_pixel_size = 4 
	
	var weather_layer = $Node2D/WeatherLayer # (Sesuaikan dengan nama node layer cuaca kamu)
	
	# Tambahkan parameter speed, angle, dan drop_size agar lebih dinamis
	var rain := WeatherFX.add(weather_layer, "rain", {
		density = 0.7,      # Seberapa lebat hujannya
		speed = 1.5,        # Kecepatan jatuhnya air hujan
		angle = -15.0,      # Kemiringan hujan (efek angin blowing ke kiri)
		drop_size = 1.2     # Ukuran rintik hujan
	})
	
	# (Opsional) Tambahkan sedikit kabut tipis agar mendungnya makin terasa
	var fog := WeatherFX.add(weather_layer, "fog", {
		color = Color(0.6, 0.6, 0.65, 0.5) # Warna abu-abu transparan
	})
	fog.fade_in(2.0)

	bgm_player.play()
	rain_player.play()
	
	_atur_waktu_petir()


func _setup_parallax() -> void:
	for layer_name in PARALLAX_DEPTHS:
		var s := layer_root.get_node_or_null(NodePath(layer_name)) as Sprite2D
		if s == null:
			push_warning("Parallax: layer '%s' tidak ditemukan" % layer_name)
			continue
		# Matikan _process lama di script layer (position += mouse * delta) -- itu sumber bug.
		s.set_process(false)
		s.set_meta("depth", PARALLAX_DEPTHS[layer_name])
		if parallax_linear_filter:
			s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_layers.append(s)
	_fit_parallax_layers()


# Perbesar semua layer sedikit (overscan) supaya tepinya tidak pernah terlihat
# saat digeser, juga saat jendela lebih lebar dari 16:9 (stretch aspect = expand).
func _fit_parallax_layers() -> void:
	var vp := get_viewport_rect().size
	var root_scale := layer_root.global_scale
	var need := vp + Vector2(parallax_strength, parallax_strength) * 2.0
	var k := 1.0
	for s in _layers:
		if s.texture == null:
			continue
		var tex_px := s.texture.get_size() * root_scale
		k = maxf(k, maxf(need.x / tex_px.x, need.y / tex_px.y))
	# Satu faktor untuk semua layer, supaya posisi antar layer tidak berubah.
	for s in _layers:
		s.scale = Vector2.ONE * k


func _process(delta: float) -> void:
	var vp := get_viewport_rect().size
	var target := (get_global_mouse_position() / vp - Vector2(0.5, 0.5)) * 2.0
	target = target.clamp(Vector2(-1, -1), Vector2(1, 1))
	# Smoothing yang tidak tergantung frame rate.
	_parallax = _parallax.lerp(target, 1.0 - exp(-parallax_smoothing * delta))

	var base := layer_root.to_local(vp * 0.5)   # tengah layar, di ruang lokal Node2D
	var root_scale := layer_root.global_scale
	for s in _layers:
		var depth: float = s.get_meta("depth")
		s.position = base - _parallax * parallax_strength * depth / root_scale


func _atur_waktu_petir() -> void:
	# Atur waktu acak petir berikutnya antara 3 sampai 10 detik
	lightning_timer.wait_time = randf_range(7.0, 20.0)
	lightning_timer.start()

# Fungsi ini dipanggil otomatis setiap kali Timer selesai menghitung
func _on_lightning_timer_timeout() -> void:
	# Kita pakai Tween untuk membuat animasi transisi yang mulus
	var tween = create_tween()
	
	# Animasi petir menyala ganda (seperti kilat sungguhan)
	tween.tween_property(lightning_flash, "modulate:a", 0.5, 0.05) # Kilat pertama cepat
	tween.tween_property(lightning_flash, "modulate:a", 0.0, 0.05) # Redup sebentar
	tween.tween_property(lightning_flash, "modulate:a", 0.8, 0.05) # Kilat utama (lebih terang)
	tween.tween_property(lightning_flash, "modulate:a", 0.0, 0.3)  # Redup memudar perlahan
	
	thunder_player.play()
	
	# Atur ulang waktu untuk petir berikutnya
	_atur_waktu_petir()


func _on_button_pressed() -> void:
	button_type = "start"
	GameManager.has_played_intro_cutscene = false
	GameManager.target_spawn_point = ""
	$Fade_transition.show()
	$Fade_transition/Fade_timer.start()
	$Fade_transition/AnimationPlayer.play("Fade_in")


func _on_button_2_pressed() -> void:
	get_tree().quit()


func _on_fade_timer_timeout() -> void:
	if button_type == "start":
		get_tree().change_scene_to_file("res://scenes/custcenerumah.tscn")
