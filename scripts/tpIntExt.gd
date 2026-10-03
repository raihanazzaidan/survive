extends Area2D

@export_file("*.tscn") var target_scene: String = "res://maprumah.tscn"
@export var spawn_point_name: String = "SpawnPintuA"

var player_in_range: bool = false
var is_teleporting: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Cek apakah player sudah berada di dalam area sejak awal
	for body in get_overlapping_bodies():
		if _is_player(body):
			player_in_range = true
			break

func _is_player(body: Node2D) -> bool:
	return body.is_in_group("player") or body.name == "player" or body.name == "mainPlayer"

func _on_body_entered(body: Node2D) -> void:
	if _is_player(body):
		player_in_range = true
		print("Player masuk area teleport. Tekan E untuk teleport ke: ", target_scene)

func _on_body_exited(body: Node2D) -> void:
	if _is_player(body):
		player_in_range = false

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and not GameManager.is_transitioning and event.is_action_pressed("use") and not event.is_echo():
		teleport()

func _process(_delta: float) -> void:
	if player_in_range and not GameManager.is_transitioning and Input.is_action_just_pressed("use"):
		teleport()

func teleport() -> void:
	if is_teleporting or GameManager.is_transitioning:
		return
	if target_scene != "":
		is_teleporting = true
		if GameManager.has_method("change_scene_with_fade"):
			GameManager.change_scene_with_fade(target_scene, spawn_point_name)
		else:
			GameManager.target_spawn_point = spawn_point_name
			get_tree().change_scene_to_file(target_scene)
	else:
		print("Target scene belum ditentukan!")
