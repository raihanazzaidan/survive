extends Control

@onready var inv: Inv = preload("res://inventory/playerInv.tres")
@onready var slots: Array = $NinePatchRect/GridContainer.get_children()

var is_open = false

func _ready():
	inv.updated.connect(update_slots) # Mendengarkan sinyal
	update_slots()
	close()
	
func update_slots():
	for i in range(min(inv.slots.size(), slots.size())):
		slots[i].update(inv.slots[i])

func _process(delta):
	if Input.is_action_just_pressed("inventory"):
		# Cek status tas dari GameManager
		if GameManager.has_backpack == false:
			print("Cari tas terlebih dahulu!") 
			return # Gagalkan pembukaan UI
			
		if is_open:
			close()
		else:
			open()
			
func open():
	update_slots()
	visible = true
	is_open = true
	
func close():
	visible = false
	is_open = false
