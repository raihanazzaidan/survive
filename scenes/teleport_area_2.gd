extends Area2D

@export_file("*.tscn") var target_scene: String = "res://scenes/pathchoose.tscn"

var is_teleporting: bool = false

func _on_body_entered(body: Node2D) -> void:
	if is_teleporting:
		return

	if body.is_in_group("player") or body.name == "mainPlayer" or body.name == "Player":
		is_teleporting = true

		# Menentukan spawn tujuan di area awal
		GameManager.target_spawn_point = "SpawnKembaliJalur"

		# Menyimpan arah hadap ke kiri
		GameManager.saved_player_flip_h = true

		# Mengaktifkan gerakan otomatis ke kiri setelah kembali
		GameManager.is_moving_left_after_return = true

		# Pindah ke scene tujuan
		SceneTransition.change_scene(target_scene)
