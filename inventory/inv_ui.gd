extends Control

var IMPORTANCE_INFO = {
	InvItem.Importance.ESSENTIAL: {"label": "PENTING - WAJIB DIBAWA SAAT BANJIR", "color": Color(0.4, 0.73, 0.42)},
	InvItem.Importance.HELPFUL: {"label": "BERGUNA - BAWA JIKA MASIH MUAT", "color": Color(1.0, 0.79, 0.16)},
	InvItem.Importance.OPTIONAL: {"label": "TIDAK PRIORITAS DIBAWA", "color": Color(0.94, 0.33, 0.31)},
}

@onready var inv: Inv = preload("res://inventory/playerInv.tres")
@onready var slots: Array = $NinePatchRect/GridContainer.get_children()

var is_open = false
var selected_ui_slot: InvUISlot = null

var detail_panel: PanelContainer
var icon_rect: TextureRect
var name_label: Label
var badge_label: Label
var desc_label: Label
var reason_label: Label

func _ready():
	inv.updated.connect(update_slots)
	for s in slots:
		s.slot_clicked.connect(_on_slot_clicked)
	_build_detail_panel()
	update_slots()
	close()

func update_slots():
	for i in range(min(inv.slots.size(), slots.size())):
		slots[i].update(inv.slots[i])
	if selected_ui_slot and (selected_ui_slot.current_slot == null or selected_ui_slot.current_slot.item == null):
		_clear_selection()

func _process(delta):
	if Input.is_action_just_pressed("inventory"):
		if is_open:
			close()
		else:
			open()

func open():
	update_slots()
	visible = true
	is_open = true

func close():
	_clear_selection()
	visible = false
	is_open = false

# ---------- Klik item ----------
func _on_slot_clicked(ui_slot: InvUISlot) -> void:
	var slot: InvSlot = ui_slot.current_slot
	# Klik slot kosong atau klik slot yang sama lagi = tutup detail
	if slot == null or slot.item == null or ui_slot == selected_ui_slot:
		_clear_selection()
		return
	_show_detail(ui_slot, slot.item)

func _show_detail(ui_slot: InvUISlot, item: InvItem) -> void:
	if selected_ui_slot:
		selected_ui_slot.set_selected(false)
	selected_ui_slot = ui_slot
	ui_slot.set_selected(true)

	var info: Dictionary = IMPORTANCE_INFO[item.importance]
	icon_rect.texture = item.texture
	name_label.text = item.name if item.name != "" else "(item tanpa nama)"
	badge_label.text = info["label"]
	badge_label.add_theme_color_override("font_color", info["color"])
	desc_label.text = item.description if item.description != "" else "-"
	reason_label.text = item.importance_reason if item.importance_reason != "" else "-"
	detail_panel.visible = true

func _clear_selection() -> void:
	if selected_ui_slot:
		selected_ui_slot.set_selected(false)
	selected_ui_slot = null
	if detail_panel:
		detail_panel.visible = false

# ---------- Membangun panel detail ----------
func _make_label(font_size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 440
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l

func _build_detail_panel() -> void:
	detail_panel = PanelContainer.new()
	detail_panel.visible = false
	add_child(detail_panel)

	# Tepat di kiri panel backpack (lebar backpack = 400 px di sisi kanan)
	detail_panel.anchor_left = 1.0
	detail_panel.anchor_right = 1.0
	detail_panel.anchor_top = 0.5
	detail_panel.anchor_bottom = 0.5
	detail_panel.offset_right = -420
	detail_panel.offset_left = -920
	detail_panel.offset_top = -280
	detail_panel.offset_bottom = 280
	detail_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	detail_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.14, 0.95)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color(0.85, 0.85, 0.9, 0.6)
	style.set_content_margin_all(20)
	detail_panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	detail_panel.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	box.add_child(header)

	icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(96, 96)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	header.add_child(icon_rect)

	var title_box := VBoxContainer.new()
	header.add_child(title_box)

	name_label = _make_label(34)
	name_label.custom_minimum_size.x = 320
	title_box.add_child(name_label)

	badge_label = _make_label(20)
	badge_label.custom_minimum_size.x = 320
	title_box.add_child(badge_label)

	box.add_child(HSeparator.new())

	desc_label = _make_label(22, Color(0.9, 0.9, 0.9))
	box.add_child(desc_label)

	var reason_title := _make_label(22, Color(1.0, 0.85, 0.4))
	reason_title.text = "Mengapa?"
	box.add_child(reason_title)

	reason_label = _make_label(22, Color(0.9, 0.9, 0.9))
	box.add_child(reason_label)
