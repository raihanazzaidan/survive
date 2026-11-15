extends Area2D

@export_file("*.tscn") var target_scene: String = "res://scenes/SpawnJembatan.tscn"

var is_teleporting: bool = false

func _ready() -> void:
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	# Cegah pemicuan ganda jika sinyal terdeteksi lebih dari sekali
	if is_teleporting:
		return

	# Pastikan hanya node player yang memicu teleportasi
	if body.is_in_group("player") or body.name == "mainPlayer" or body.name == "Player":
		# Cegah teleportasi jika player sedang dalam animasi cutscene kembali atau scene sedang transisi
		if body.get("is_cutscene") == true or GameManager.is_transitioning or GameManager.returning_from_detour:
			return

		is_teleporting = true
		GameManager.target_spawn_point = "SpawnJembatan"

		# Panggil fungsi transisi Fade Out -> Pindah Scene -> Fade In dari Autoload global
		SceneTransition.change_scene(target_scene)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "mainPlayer" or body.name == "Player":
		is_teleporting = false
