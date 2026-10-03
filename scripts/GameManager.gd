extends Node

# Menyimpan nama/ID checkpoint atau spawn point tujuan
var target_spawn_point: String = ""
var is_transitioning: bool = false

var _canvas_layer: CanvasLayer
var _fade_rect: ColorRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 128
	add_child(_canvas_layer)
	
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas_layer.add_child(_fade_rect)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func change_scene_with_fade(target_scene: String, spawn_point: String = "", duration: float = 0.35) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	
	target_spawn_point = spawn_point
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 1. Fade Out (Layar menjadi hitam)
	var tween = create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, duration)
	await tween.finished
	
	# 2. Ganti scene
	get_tree().change_scene_to_file(target_scene)
	
	# Tunggu jeda frame agar scene baru selesai di-load dan posisi player terpasang
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 3. Fade In (Layar kembali terang)
	var tween_in = create_tween()
	tween_in.tween_property(_fade_rect, "color:a", 0.0, duration)
	await tween_in.finished
	
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_transitioning = false
