
extends Camera2D

@onready var ground_layer: TileMapLayer = get_node_or_null("../ground")
@onready var player_camera: Camera2D = get_node_or_null("../mainPlayer/Camera2D2")

const FLOOD_SCENE = "res://scenes/maprumah_banjir.tscn"

@export var rain_duration: float = 8.0
@export var flood_duration: float = 7.0

var map_left: float
var map_right: float
var map_top: float
var map_bottom: float

var fade_layer: CanvasLayer
var fade_rect: ColorRect


func _ready() -> void:
	if ground_layer == null:
		push_error("GROUND TIDAK DITEMUKAN!")
		return

	setup_camera_limits()
	create_fade_layer()

	if player_camera != null:
		player_camera.enabled = false

	enabled = true
	make_current()

	var current_scene = get_tree().current_scene.scene_file_path

	print("================================")
	print("SCENE SEKARANG: ", current_scene)
	print("CUTSCENE CAMERA AKTIF!")
	print("================================")

	if current_scene.ends_with("maprumah.tscn"):
		print("MEMULAI CUTSCENE HUJAN")

		await play_rain_cutscene()

		print("HUJAN SELESAI, MULAI TRANSISI")

		await fade_screen(1.0)

		var result = get_tree().change_scene_to_file(FLOOD_SCENE)

		print("HASIL PERGANTIAN SCENE: ", result)

		if result != OK:
			push_error("GAGAL MEMBUKA SCENE BANJIR: " + FLOOD_SCENE)

	elif current_scene.ends_with("maprumah_banjir.tscn"):
		print("MEMASUKI CUTSCENE BANJIR")

		await fade_screen(0.0)
		await play_flood_cutscene()

		finish_cutscene()

	else:
		push_error("NAMA SCENE TIDAK COCOK: " + current_scene)



func create_fade_layer() -> void:
	fade_layer = CanvasLayer.new()
	fade_layer.layer = 100
	get_tree().root.add_child(fade_layer)

	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	fade_layer.add_child(fade_rect)


func fade_screen(target_alpha: float) -> void:
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", target_alpha, 1.0)
	await tween.finished


func setup_camera_limits() -> void:
	var used_rect = ground_layer.get_used_rect()
	var tile_size = ground_layer.tile_set.tile_size

	var top_left = ground_layer.to_global(
		Vector2(used_rect.position * tile_size)
	)
	var bottom_right = ground_layer.to_global(
		Vector2(used_rect.end * tile_size)
	)

	map_left = top_left.x
	map_top = top_left.y
	map_right = bottom_right.x
	map_bottom = bottom_right.y

	limit_left = int(map_left)
	limit_top = int(map_top)
	limit_right = int(map_right)
	limit_bottom = int(map_bottom)

	print("Batas kamera cutscene berhasil diatur!")
	print("Batas map: ", used_rect)


func get_camera_point(x_ratio: float, y_ratio: float) -> Vector2:
	var x = lerp(map_left, map_right, x_ratio)
	var y = lerp(map_top, map_bottom, y_ratio)

	return Vector2(x, y)


func play_rain_cutscene() -> void:
	var start_point = get_camera_point(0.25, 0.25)
	var middle_point = get_camera_point(0.5, 0.5)
	var end_point = get_camera_point(0.75, 0.75)

	global_position = start_point

	var tween = create_tween()
	tween.tween_property(self, "global_position", middle_point, rain_duration * 0.5)
	tween.tween_property(self, "global_position", end_point, rain_duration * 0.5)

	await tween.finished


func play_flood_cutscene() -> void:
	var start_point = get_camera_point(0.25, 0.75)
	var middle_point = get_camera_point(0.5, 0.5)
	var end_point = get_camera_point(0.75, 0.25)

	global_position = start_point

	var tween = create_tween()
	tween.tween_property(self, "global_position", middle_point, flood_duration * 0.5)
	tween.tween_property(self, "global_position", end_point, flood_duration * 0.5)

	await tween.finished


func finish_cutscene() -> void:
	if player_camera != null:
		player_camera.enabled = true
		player_camera.make_current()

	if fade_layer != null:
		fade_layer.queue_free()

	queue_free()
