extends Area2D

@export_file("*.tscn") var target_scene: String = "res://scenes/pathchoose.tscn"

var is_teleporting: bool = false

func _on_body_entered(body: Node2D) -> void:
	# Cegah pemicuan ganda jika sinyal terdeteksi lebih dari sekali
	if is_teleporting:
		return
		
	# Pastikan hanya node player yang memicu teleportasi
	if body.is_in_group("player") or body.name == "mainPlayer" or body.name == "Player":
		is_teleporting = true
		
		# Panggil fungsi transisi Fade Out -> Pindah Scene -> Fade In dari Autoload global
		SceneTransition.change_scene(target_scene)
