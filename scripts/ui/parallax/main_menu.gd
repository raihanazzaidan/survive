extends Control
@onready var lightning_flash = $LightningFlash
@onready var lightning_timer = $LightningTimer
@onready var bgm_player = $BGMPlayer
@onready var rain_player = $RainPlayer
@onready var thunder_player = $ThunderPlayer
var button_type = null

func _ready() -> void:
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
	$Fade_transition.show()
	$Fade_transition/Fade_timer.start()
	$Fade_transition/AnimationPlayer.play("Fade_in")


func _on_button_2_pressed() -> void:
	get_tree().quit()


func _on_fade_timer_timeout() -> void:
	if button_type == "start":
		get_tree().change_scene_to_file("res://scenes/interior.tscn")
