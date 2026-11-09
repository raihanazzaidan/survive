extends Area2D

@export var item_data: InvItem
@onready var sprite = $itemSprite 

var is_player_near = false

func _ready():
	if item_data != null:
		sprite.texture = item_data.texture

func _process(delta):
	if is_player_near and Input.is_action_just_pressed("use"):
		pungut_item()

func pungut_item():
	var player_inv = preload("res://inventory/playerInv.tres")
	player_inv.insert(item_data)
	queue_free()

func _on_body_entered(body):
	if body.name == "mainPlayer":
		is_player_near = true

func _on_body_exited(body):
	if body.name == "mainPlayer":
		is_player_near = false
