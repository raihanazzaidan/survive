#extends Area2D
#
#var is_player_near = false
#
#func _process(delta):
	#if is_player_near and Input.is_action_just_pressed("use"):
		## Set status tas menjadi true di GameManager
		#GameManager.has_backpack = true
		#queue_free() # Hapus tas dari map
#
#func _on_body_entered(body):
	#if body.name == "mainPlayer":
		#is_player_near = true
#
#func _on_body_exited(body):
	#if body.name == "mainPlayer":
		#is_player_near = false
