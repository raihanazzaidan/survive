extends Node2D
class_name StormController

## Pengontrol Cuaca Badai (Hujan Deras & Petir)
## Didesain khusus untuk menyimulasikan cuaca ekstrem pra-banjir.

@export_group("Rain Effect (WeatherFX)")
@export var rain_enabled: bool = true
## Kepadatan tetesan hujan (0.0 - 1.0, 0.9+ untuk badai lebat)
@export_range(0.0, 1.0) var rain_density: float = 0.95
## Kemiringan hujan akibat angin (-1.0 s/d 1.0)
@export_range(-1.0, 1.0) var rain_wind: float = 0.42
## Kecepatan jatuh air hujan
@export_range(0.5, 3.0) var rain_fall_speed: float = 2.0
## Panjang garis tetesan air hujan
@export_range(10.0, 80.0) var rain_drop_length: float = 48.0
## Kekuatan visual hujan
@export_range(0.0, 2.0) var rain_intensity: float = 1.4
## Warna air hujan badai
@export var rain_color: Color = Color(0.72, 0.82, 0.98, 0.82)

@export_group("Lightning & Thunder")
## Mengaktifkan petir otomatis secara berkala
@export var lightning_enabled: bool = true
## Menampilkan garis sambaran petir di layar (matikan jika di dalam ruangan)
@export var show_lightning_bolts: bool = true
## Interval waktu minimal antar petir (detik)
@export var min_strike_interval: float = 4.0
## Interval waktu maksimal antar petir (detik)
@export var max_strike_interval: float = 8.5
## Apakah kamera bergetar saat petir menyambar
@export var enable_camera_shake: bool = true
## Kekuatan getaran kamera saat sambaran petir
@export var shake_intensity: float = 7.0

@export_group("Atmosphere & Lighting")
## Mengaktifkan suasana mendung gelap
@export var enable_storm_darkness: bool = true
## Warna pencahayaan lingkungan (CanvasModulate)
@export var ambient_darkness: Color = Color(0.48, 0.50, 0.60, 1.0)

@export_group("Audio")
@export var play_sounds: bool = true
@export var rain_volume_db: float = -4.0
@export var thunder_volume_db: float = 0.0

var _rain_fx: WeatherFX
var _rain_audio: AudioStreamPlayer
var _thunder_audio: AudioStreamPlayer
var _canvas_modulate: CanvasModulate

var _flash_layer: CanvasLayer
var _flash_rect: ColorRect
var _bolt_glow: Line2D
var _bolt_core: Line2D
var _branch_glow: Line2D
var _branch_core: Line2D

var _strike_timer: Timer
var _camera: Camera2D
var _shake_remaining: float = 0.0
var _shake_power: float = 0.0


func _ready() -> void:
	z_index = 10
	
	# 1. Atur Suasana Mendung (CanvasModulate)
	if enable_storm_darkness:
		_setup_atmosphere()
	
	# 2. Atur Audio Hujan & Petir
	if play_sounds:
		_setup_audio()
		
	# 3. Atur Hujan Deras via WeatherFX
	if rain_enabled:
		_setup_rain()
		
	# 4. Atur Sistem Visual Petir (Flash & Sambaran Bolt)
	_setup_lightning()
	if lightning_enabled:
		_start_lightning_timer()


func _setup_atmosphere() -> void:
	_canvas_modulate = CanvasModulate.new()
	_canvas_modulate.name = "StormAtmosphere"
	_canvas_modulate.color = ambient_darkness
	add_child(_canvas_modulate)


func _setup_audio() -> void:
	# Audio Hujan (Looping)
	var rain_stream = load("res://assets/sfx/rain.wav")
	if rain_stream:
		_rain_audio = AudioStreamPlayer.new()
		_rain_audio.name = "RainAudioPlayer"
		_rain_audio.stream = rain_stream
		_rain_audio.volume_db = rain_volume_db
		_rain_audio.autoplay = true
		add_child(_rain_audio)
	
	# Audio Petir
	var thunder_stream = load("res://assets/sfx/thunder.wav")
	if thunder_stream:
		_thunder_audio = AudioStreamPlayer.new()
		_thunder_audio.name = "ThunderAudioPlayer"
		_thunder_audio.stream = thunder_stream
		_thunder_audio.volume_db = thunder_volume_db
		add_child(_thunder_audio)


func _setup_rain() -> void:
	_rain_fx = WeatherFX.add(self, "rain", {
		"density": rain_density,
		"wind": rain_wind,
		"fall_speed": rain_fall_speed,
		"drop_length": rain_drop_length,
		"splashes": 0.9,
		"color": rain_color,
		"intensity": rain_intensity,
		"z_index": 10
	})
	_rain_fx.name = "HeavyRainFX"


func _setup_lightning() -> void:
	_flash_layer = CanvasLayer.new()
	_flash_layer.name = "LightningCanvasLayer"
	_flash_layer.layer = 20
	add_child(_flash_layer)
	
	# Fullscreen Flash Rect
	_flash_rect = ColorRect.new()
	_flash_rect.name = "FlashRect"
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	_flash_layer.add_child(_flash_rect)
	
	# Sambaran Petir Utama (Glow + Inti Putih)
	_bolt_glow = Line2D.new()
	_bolt_glow.name = "BoltGlow"
	_bolt_glow.width = 9.0
	_bolt_glow.default_color = Color(0.5, 0.75, 1.0, 0.5)
	_bolt_glow.joint_mode = Line2D.LINE_JOINT_ROUND
	_bolt_glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_bolt_glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	_bolt_glow.visible = false
	_flash_layer.add_child(_bolt_glow)
	
	_bolt_core = Line2D.new()
	_bolt_core.name = "BoltCore"
	_bolt_core.width = 3.5
	_bolt_core.default_color = Color(1.0, 1.0, 1.0, 1.0)
	_bolt_core.joint_mode = Line2D.LINE_JOINT_ROUND
	_bolt_core.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_bolt_core.end_cap_mode = Line2D.LINE_CAP_ROUND
	_bolt_core.visible = false
	_flash_layer.add_child(_bolt_core)
	
	# Cabang Petir Tambahan (Forks)
	_branch_glow = Line2D.new()
	_branch_glow.name = "BranchGlow"
	_branch_glow.width = 5.0
	_branch_glow.default_color = Color(0.5, 0.75, 1.0, 0.4)
	_branch_glow.visible = false
	_flash_layer.add_child(_branch_glow)
	
	_branch_core = Line2D.new()
	_branch_core.name = "BranchCore"
	_branch_core.width = 2.0
	_branch_core.default_color = Color(1.0, 1.0, 1.0, 0.9)
	_branch_core.visible = false
	_flash_layer.add_child(_branch_core)


func _start_lightning_timer() -> void:
	_strike_timer = Timer.new()
	_strike_timer.name = "StrikeTimer"
	_strike_timer.one_shot = true
	_strike_timer.timeout.connect(_on_strike_timer_timeout)
	add_child(_strike_timer)
	_queue_next_strike()


func _queue_next_strike() -> void:
	if not lightning_enabled or not is_inside_tree():
		return
	var next_time = randf_range(min_strike_interval, max_strike_interval)
	_strike_timer.start(next_time)


func _on_strike_timer_timeout() -> void:
	strike_lightning()
	_queue_next_strike()


## Memanggil sambaran petir secara manual atau otomatis
func strike_lightning() -> void:
	if not _flash_layer:
		return
		
	var viewport_size = get_viewport_rect().size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		viewport_size = Vector2(1280, 720)
		
	# 1. Bentuk Sambaran Petir Bergerigi (Zig-Zag Lightning Bolt)
	if show_lightning_bolts:
		var start_x = randf_range(viewport_size.x * 0.2, viewport_size.x * 0.8)
		var current_pos = Vector2(start_x, -10.0)
		var main_points = PackedVector2Array([current_pos])
		
		var strike_ground_y = viewport_size.y * randf_range(0.65, 0.95)
		var segments = randi_range(7, 11)
		var step_y = strike_ground_y / float(segments)
		
		var branch_start_idx = randi_range(3, segments - 2)
		var branch_points = PackedVector2Array()
		
		for i in range(segments):
			var jitter_x = randf_range(-38.0, 38.0)
			current_pos.x += jitter_x
			current_pos.y += step_y
			main_points.append(current_pos)
			
			# Cabang tambahan jika di titik tengah
			if i == branch_start_idx:
				var b_pos = current_pos
				branch_points.append(b_pos)
				var branch_dir = 1.0 if jitter_x >= 0 else -1.0
				for b in range(randi_range(3, 5)):
					b_pos += Vector2(branch_dir * randf_range(20, 45), randf_range(15, 35))
					branch_points.append(b_pos)
		
		_bolt_glow.points = main_points
		_bolt_core.points = main_points
		_bolt_glow.visible = true
		_bolt_core.visible = true
		
		if branch_points.size() > 0:
			_branch_glow.points = branch_points
			_branch_core.points = branch_points
			_branch_glow.visible = true
			_branch_core.visible = true
		else:
			_branch_glow.visible = false
			_branch_core.visible = false
	else:
		_bolt_glow.visible = false
		_bolt_core.visible = false
		_branch_glow.visible = false
		_branch_core.visible = false

	# 2. Animasi Kilatan Cahaya Layar (Double Pulse Flash)
	var flash_tween = create_tween()
	_flash_rect.color.a = 0.85
	# Penurunan kilatan pertama
	flash_tween.tween_property(_flash_rect, "color:a", 0.35, 0.04)
	# Denyut kedua yang lebih terang
	flash_tween.tween_property(_flash_rect, "color:a", 0.95, 0.03)
	# Meredup perlahan
	flash_tween.tween_property(_flash_rect, "color:a", 0.0, 0.38).set_ease(Tween.EASE_OUT)
	
	# Sembunyikan garis sambaran petir setelah 0.12 detik
	get_tree().create_timer(0.12).timeout.connect(func():
		if is_instance_valid(_bolt_glow):
			_bolt_glow.visible = false
			_bolt_core.visible = false
			_branch_glow.visible = false
			_branch_core.visible = false
	)
	
	# 3. Bunyi Gemuruh Guntur (Thunder SFX) dengan Delay Realistis
	var audio_delay = randf_range(0.04, 0.14)
	get_tree().create_timer(audio_delay).timeout.connect(func():
		if _thunder_audio:
			_thunder_audio.pitch_scale = randf_range(0.88, 1.12)
			_thunder_audio.play()
	)
	
	# 4. Getaran Kamera (Camera Shake)
	if enable_camera_shake:
		_trigger_camera_shake(shake_intensity)


func _trigger_camera_shake(intensity: float) -> void:
	if not _camera:
		_camera = get_viewport().get_camera_2d()
	if not _camera:
		return
		
	_shake_power = intensity
	_shake_remaining = 0.32


func _process(delta: float) -> void:
	if _shake_remaining > 0.0:
		_shake_remaining -= delta
		if _camera:
			var offset = Vector2(
				randf_range(-_shake_power, _shake_power),
				randf_range(-_shake_power, _shake_power)
			)
			_camera.offset = offset
		if _shake_remaining <= 0.0:
			if _camera:
				_camera.offset = Vector2.ZERO
