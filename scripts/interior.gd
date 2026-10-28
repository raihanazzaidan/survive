extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var player: CharacterBody2D = $mainPlayer

func _ready() -> void:
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
