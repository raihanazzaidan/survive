extends Panel
class_name InvUISlot

signal slot_clicked(ui_slot)

@onready var item_visual: Sprite2D = $CenterContainer/Panel/item_display
@onready var amount_text: Label = $CenterContainer/Panel/Label
@onready var background: Sprite2D = $Sprite2D

var current_slot: InvSlot

func _ready() -> void:
	# Pastikan anak node tidak menelan klik, hanya Panel ini yang menerimanya
	for child in find_children("*", "Control", true, false):
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE

func update(slot: InvSlot) -> void:
	current_slot = slot
	if !slot or !slot.item:
		item_visual.visible = false
		amount_text.visible = false
	else:
		item_visual.visible = true
		item_visual.texture = slot.item.texture
		if slot.amount > 1:
			amount_text.visible = true
			amount_text.text = str(slot.amount)
		else:
			amount_text.visible = false

func set_selected(selected: bool) -> void:
	background.modulate = Color(1.0, 0.85, 0.35) if selected else Color.WHITE

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		slot_clicked.emit(self)
