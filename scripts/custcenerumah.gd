extends Node2D

@export_file("*.tscn") var target_scene: String = "res://scenes/interior.tscn"

@onready var anim_player = $CutsceneCamera/AnimationPlayer

func _ready():

	anim_player.play("kamera_geser")
	
	await anim_player.animation_finished
	
	SceneTransition.change_scene(target_scene)
