
extends Node2D

@onready var ground_layer: TileMapLayer = get_node_or_null("../ground")
@onready var player_camera: Camera2D = get_node_or_null("../mainPlayer/Camera2D2")
@onready var cutscene_camera: Camera2D = get_node_or_null("../CutsceneCamera")

const FLOOD_SCENE = "res://scenes/maprumah_banjir.tscn"

@export var rain_duration: float = 8.0

var map_left: float
var map_right: float
var map_top: float
var map_bottom: float



func _ready() -> void:
	print("FLOOD CONTROLLER AKTIF")
	print("Ground ditemukan: ", ground_layer != null)
	print("Player camera ditemukan: ", player_camera != null)
	print("Cutscene camera ditemukan: ", cutscene_camera != null)

	if ground_layer == null:
		push_error("Ground tidak ditemukan!")
		return

	if cutscene_camera == null:
		push_error("CutsceneCamera tidak ditemukan!")
		return

	print("MEMULAI SETUP KAMERA")
	setup_camera_limits()
	print("SETUP KAMERA SELESAI")

	if player_camera != null:
		player_camera.enabled = false

	cutscene_camera.enabled = true
	cutscene_camera.make_current()

	print("CUTSCENE HUJAN DIMULAI")

	await play_rain_cutscene()

	print("CUTSCENE HUJAN SELESAI")
	await fade_to_black()

	print("PINDAH KE MAP BANJIR")
	var result = get_tree().change_scene_to_file(FLOOD_SCENE)

	if result != OK:
		push_error("Gagal membuka map banjir!")


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

	cutscene_camera.limit_left = int(map_left)
	cutscene_camera.limit_top = int(map_top)
	cutscene_camera.limit_right = int(map_right)
	cutscene_camera.limit_bottom = int(map_bottom)


func get_camera_point(x_ratio: float, y_ratio: float) -> Vector2:
	return Vector2(
		lerp(map_left, map_right, x_ratio),
		lerp(map_top, map_bottom, y_ratio)
	)


func play_rain_cutscene() -> void:
	var start_point = get_camera_point(0.25, 0.25)
	var middle_point = get_camera_point(0.5, 0.5)
	var end_point = get_camera_point(0.75, 0.75)

	cutscene_camera.global_position = start_point

	var tween = create_tween()
	tween.tween_property(
		cutscene_camera,
		"global_position",
		middle_point,
		rain_duration * 0.5
	)
	tween.tween_property(
		cutscene_camera,
		"global_position",
		end_point,
		rain_duration * 0.5
	)

	await tween.finished


func fade_to_black() -> void:
	var fade_layer = CanvasLayer.new()
	fade_layer.layer = 100
	get_tree().root.add_child(fade_layer)

	var fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade_rect)

	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 1.0)

	await tween.finished
