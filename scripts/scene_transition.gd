extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect

func _ready() -> void:
	# Layar awal transparan dan tidak menghalangi klik
	color_rect.color.a = 0.0
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func change_scene(target_path: String, duration: float = 0.5) -> void:
	# Blokir input selama proses perpindahan map berlangsung
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 1. FADE OUT (Layar berubah jadi hitam)
	var tween_out = create_tween()
	tween_out.tween_property(color_rect, "color:a", 1.0, duration)
	await tween_out.finished
	
	# 2. PINDAH SCENE
	get_tree().change_scene_to_file(target_path)
	
	# 3. FADE IN (Layar kembali terang)
	var tween_in = create_tween()
	tween_in.tween_property(color_rect, "color:a", 0.0, duration)
	await tween_in.finished
	
	# Kembalikan filter mouse agar player bisa berinteraksi kembali
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
