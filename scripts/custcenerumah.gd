extends Node2D

const FONT_TITLE := "res://assets/fonts/PressStart2P-Regular.ttf"
const FONT_BODY := "res://assets/fonts/VT323-Regular.ttf"
# Di proyek ini tas ada di spritesheet emergencyBag.png (640x640); sprite tas pertama = 47x50 px.
const BAG_TEXTURE := "res://assets/items/emergencyBag.png"
const BAG_REGION := Rect2(72.0, 453.0, 47.0, 50.0)
const INTERIOR_SCENE := "res://scenes/interior.tscn"

# Palet mengikuti tombol menu utama (putih tebal + emas).
const COL_GOLD := Color(0.79, 0.64, 0.32)
const COL_GOLD_LIGHT := Color(1.0, 0.84, 0.48)
const COL_GOLD_DARK := Color(0.45, 0.33, 0.14)
const COL_ALERT := Color(0.86, 0.18, 0.14)
const COL_NIGHT := Color(0.04, 0.06, 0.11)

@export_group("Kamera")
@export var zoom_awal: float = 0.92
## Seberapa besar rumah mengisi layar saat fokus (0.82 = rumah memenuhi 82% sisi layar, ada ruang bernapas).
@export_range(0.5, 0.95) var isi_layar_rumah: float = 0.82
@export var zoom_maks_rumah: float = 1.7
@export var zoom_sungai: float = 1.2
## Jarak aman (px dunia) dari tepi peta agar tepi luar/guncangan petir tidak terlihat.
@export var margin_aman: float = 16.0

@export_group("Durasi (detik)")
@export var durasi_sorot_peta: float = 10.0
@export var durasi_fokus_rumah: float = 5.0
@export var durasi_tahan_rumah: float = 3.0
@export var durasi_ke_sungai: float = 4.5
@export var durasi_gelap: float = 9.0
@export var jeda_hujan_mulai: float = 1.5
@export var durasi_hujan_naik: float = 10.0

## Pada scene ini layer peta adalah anak langsung dari root (tidak ada node "Map"),
## sehingga root dipakai sebagai "map". Jika suatu saat dibungkus node "Map", tetap berfungsi.
var map: Node2D
@onready var camera: Camera2D = $CutsceneCamera

var weather: Node
var player: Node2D
var canvas_modulate: CanvasModulate

var overlay: CanvasLayer
var ui_root: Control
var fade_rect: ColorRect
var warning_panel: PanelContainer
var interior_button: Button
var click_player: AudioStreamPlayer

var _font_title: Font
var _font_body: Font
var _dark_color := Color(0.36, 0.40, 0.55, 1.0)
var _map_bounds := Rect2(-1792.0, -1280.0, 3328.0, 2304.0)
var _river_top_y := -447.0
var _river_left_x := 1023.0
var _river_center := Vector2(1152.0, 256.0)
var _house_rect := Rect2(-24.0, -672.0, 612.0, 767.0)
var _focus_zoom := 1.15
var _pan_end_zoom := 1.1
var _path: Array[Vector2] = []
var _cam_pos := Vector2.ZERO
var _cam_zoom := 0.92
var _busy := false
var _transition_started := false


func _ready() -> void:
	map = get_node_or_null("Map") as Node2D
	if map == null:
		map = self
	_font_title = _load_font(FONT_TITLE)
	_font_body = _load_font(FONT_BODY)

	# Karakter: diam di tempat (kontrol pemain & kamera bawaannya dimatikan).
	player = map.get_node_or_null("mainPlayer") as Node2D
	if player:
		var player_camera := player.get_node_or_null("Camera2D") as Camera2D
		if player_camera:
			player_camera.enabled = false
		if player is CharacterBody2D:
			player.set_physics_process(false)
		var anim := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if anim and anim.sprite_frames and anim.sprite_frames.has_animation("idle1"):
			anim.play("idle1")
		# Karakter disembunyikan selama cutscene (hanya pada instance peta ini;
		# scene interior & gameplay tidak terpengaruh).
		player.visible = false

	_configure_weather()
	_measure_map()
	_measure_house()
	_setup_ui()

	canvas_modulate = CanvasModulate.new()
	canvas_modulate.name = "CinematicDaylight"
	canvas_modulate.color = Color.WHITE
	map.add_child(canvas_modulate)

	# Animasi kamera lama (kamera_geser) dimatikan: kamera kini digerakkan penuh oleh Tween skrip ini.
	var old_anim := camera.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if old_anim:
		old_anim.stop()
		old_anim.autoplay = ""
	camera.offset = Vector2.ZERO
	camera.rotation = 0.0

	# Batas keras kamera (lapisan pengaman kedua selain clamp per-frame).
	camera.limit_left = int(ceil(_map_bounds.position.x))
	camera.limit_top = int(ceil(_map_bounds.position.y))
	camera.limit_right = int(floor(_map_bounds.end.x))
	camera.limit_bottom = int(floor(_map_bounds.end.y))
	camera.limit_smoothed = false
	camera.position_smoothing_enabled = false
	camera.enabled = true

	_cam_zoom = zoom_awal
	# Mulai dari sisi paling kiri peta.
	_cam_pos = _clamp_camera_center(Vector2(-99999.0, _house_rect.get_center().y - 10.0), _cam_zoom)
	_apply_camera()
	camera.make_current()

	_run_cutscene()


func _process(_delta: float) -> void:
	_apply_camera()


# ---------------------------------------------------------------------------
# Kamera & batas peta
# ---------------------------------------------------------------------------

func _apply_camera() -> void:
	camera.zoom = Vector2(_cam_zoom, _cam_zoom)
	camera.global_position = _clamp_camera_center(_cam_pos, _cam_zoom)


func _measure_map() -> void:
	# Batas peta = area tile "ground" yang benar-benar terisi (tepi tile, bukan titik tengah).
	var ground := map.get_node_or_null("ground") as TileMapLayer
	if ground and ground.tile_set:
		var used: Rect2i = ground.get_used_rect()
		if used.size != Vector2i.ZERO:
			var ts := Vector2(ground.tile_set.tile_size)
			var tl := ground.to_global(Vector2(used.position) * ts)
			var br := ground.to_global(Vector2(used.end) * ts)
			_map_bounds = Rect2(tl, br - tl).abs()

	# Sungai vertikal di kanan: sisi atasnya tidak boleh tampil di layar.
	var river := map.get_node_or_null("ground/river") as TileMapLayer
	if river and river.tile_set:
		var r_used: Rect2i = river.get_used_rect()
		if r_used.size != Vector2i.ZERO:
			var r_ts := Vector2(river.tile_set.tile_size)
			var r_tl := river.to_global(Vector2(r_used.position) * r_ts)
			var r_br := river.to_global(Vector2(r_used.end) * r_ts)
			_river_top_y = r_tl.y
			_river_left_x = r_tl.x
			_river_center = (r_tl + r_br) * 0.5


func _tile_content_rect(layer: TileMapLayer, cell: Vector2i) -> Rect2:
	# Kotak isi gambar (piksel tidak transparan) dari satu tile besar, dalam koordinat dunia.
	# Godot menggambar tile di tengah sel, digeser texture_origin.
	var src := layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
	if src == null:
		return Rect2()
	var atlas := layer.get_cell_atlas_coords(cell)
	var region: Rect2i = src.get_tile_texture_region(atlas)
	var data := layer.get_cell_tile_data(cell)
	var origin := Vector2(data.texture_origin) if data else Vector2.ZERO
	var top_left := layer.to_global(layer.map_to_local(cell)) - Vector2(region.size) * 0.5 - origin
	var content := Rect2(Vector2.ZERO, Vector2(region.size))
	if src.texture:
		var img := src.texture.get_image()
		if img:
			if img.is_compressed():
				img.decompress()
			var used: Rect2i = img.get_region(region).get_used_rect()
			if used.size != Vector2i.ZERO:
				content = Rect2(used)
	return Rect2(top_left + content.position, content.size)


func _measure_house() -> void:
	# Ukur rumah utama (badan + atap) dari data tile yang sebenarnya.
	var found := false
	var rect := Rect2()
	for layer_name in ["Rumah Base", "Roof Layer"]:
		var layer := map.get_node_or_null(layer_name) as TileMapLayer
		if layer == null or layer.tile_set == null:
			continue
		for cell in layer.get_used_cells():
			var r := _tile_content_rect(layer, cell)
			if r.size == Vector2.ZERO:
				continue
			rect = r if not found else rect.merge(r)
			found = true
	if found and rect.size.x > 100.0 and rect.size.y > 100.0:
		_house_rect = rect

	# Zoom: seluruh rumah masuk layar dengan ruang di sekelilingnya, tidak terpotong.
	var vp := get_viewport_rect().size
	var fit := minf(vp.x * isi_layar_rumah / _house_rect.size.x, vp.y * isi_layar_rumah / _house_rect.size.y)
	_focus_zoom = clampf(fit, 1.0, zoom_maks_rumah)
	_pan_end_zoom = _focus_zoom * 0.96


func _house_pose(zoom_value: float) -> Vector2:
	# Pusat kamera pada rumah. Bila sisi kanan layar akan menyentuh sungai,
	# kamera digeser sedikit ke kiri (rumah tetap utuh di layar).
	var half_w := get_viewport_rect().size.x / zoom_value * 0.5
	var c := _house_rect.get_center()
	c.x = minf(c.x, _river_left_x - 40.0 - half_w)
	return c


func _clamp_camera_center(target: Vector2, zoom_value: float) -> Vector2:
	var half := get_viewport_rect().size / maxf(zoom_value, 0.1) * 0.5
	var b := _map_bounds.grow(-margin_aman)

	var min_x := b.position.x + half.x
	var max_x := b.end.x - half.x
	var x := b.get_center().x if min_x > max_x else clampf(target.x, min_x, max_x)

	# Begitu sisi kanan layar mulai memperlihatkan sungai vertikal, batas atas
	# pandangan dinaikkan sehingga bagian atas sungai tidak pernah terlihat.
	# Dibuat halus (smoothstep) agar tidak ada lonjakan kamera.
	var view_right := x + half.x
	var guard := smoothstep(_river_left_x - 30.0, _river_left_x + 40.0, view_right)
	var top_limit := lerpf(b.position.y, _river_top_y + margin_aman, guard)

	var min_y := top_limit + half.y
	var max_y := b.end.y - half.y
	var y := (min_y + max_y) * 0.5 if min_y > max_y else clampf(target.y, min_y, max_y)
	return Vector2(x, y)


func _path_point(points: Array[Vector2], u: float) -> Vector2:
	# Catmull-Rom: lintasan melengkung halus melewati semua titik.
	var n := points.size()
	var f := clampf(u, 0.0, 1.0) * float(n - 1)
	var i := mini(int(f), n - 2)
	var t := f - float(i)
	var a := points[i]
	var b := points[i + 1]
	var pre := points[maxi(i - 1, 0)]
	var post := points[mini(i + 2, n - 1)]
	return a.cubic_interpolate(b, pre, post, t)


func _step_sorot_peta(u: float) -> void:
	_cam_pos = _path_point(_path, u)
	_cam_zoom = lerpf(zoom_awal, _pan_end_zoom, u)


# ---------------------------------------------------------------------------
# Alur cutscene
# ---------------------------------------------------------------------------

func _run_cutscene() -> void:
	if _busy:
		return
	_busy = true

	_fade_from_black(1.4)

	# FASE 1 - sorot map dari kiri ke kanan, zoom in perlahan, berakhir di rumah utama.
	var left := _cam_pos
	var end_pose := _house_pose(_pan_end_zoom)
	var span := end_pose.x - left.x
	_path = [
		left,
		Vector2(left.x + span * 0.33, 250.0),
		Vector2(left.x + span * 0.66, -80.0),
		end_pose,
	]
	var pan := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pan.tween_method(_step_sorot_peta, 0.0, 1.0, durasi_sorot_peta)
	await pan.finished

	# FASE 2 - fokus rumah utama (utuh, di tengah layar). Gelap & hujan mulai bertahap.
	_start_storm_sequence()
	_cam_pos = camera.global_position
	var focus_pose := _house_pose(_focus_zoom)
	var focus := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_parallel(true)
	focus.tween_property(self, "_cam_pos", focus_pose, durasi_fokus_rumah)
	focus.tween_property(self, "_cam_zoom", _focus_zoom, durasi_fokus_rumah)
	await focus.finished

	# Zoom in sangat pelan selagi hujan menderas (rumah tetap utuh di layar).
	var drift_zoom := minf(_focus_zoom * 1.03, zoom_maks_rumah)
	var drift := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_parallel(true)
	drift.tween_property(self, "_cam_zoom", drift_zoom, durasi_tahan_rumah)
	drift.tween_property(self, "_cam_pos", _house_pose(drift_zoom), durasi_tahan_rumah)
	await drift.finished

	# FASE 3 - berpindah ke sungai. Sumbu Y bergerak lebih dulu agar batas atas
	# sungai terjaga tanpa lonjakan kamera.
	_cam_pos = camera.global_position
	var river_target := Vector2(_river_center.x - 380.0, _river_center.y - 40.0)
	var d := durasi_ke_sungai
	var move_y := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	move_y.tween_property(self, "_cam_pos:y", river_target.y, d * 0.6)
	var move_x := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_parallel(true)
	move_x.tween_property(self, "_cam_pos:x", river_target.x, d * 0.7).set_delay(d * 0.3)
	move_x.tween_property(self, "_cam_zoom", zoom_sungai, d * 0.7).set_delay(d * 0.3)
	await move_x.finished
	await get_tree().create_timer(1.0).timeout

	# FASE 4 - petir menyambar (cahaya + guntur).
	_lightning_strike()
	await get_tree().create_timer(1.3).timeout
	_lightning_strike()
	await get_tree().create_timer(1.6).timeout
	if weather and weather.has_method("start_auto_lightning"):
		weather.call("start_auto_lightning", 6.0, 10.0)

	# FASE 5 - peringatan banjir, lalu tombol aktif.
	await _show_warning()


func _configure_weather() -> void:
	weather = map.get_node_or_null("WeatherLayer")
	if not weather:
		return
	weather.set("start_weather_on_ready", false)
	weather.set("enable_storm_darkness", false) # gelapnya dikontrol cutscene
	weather.set("rain_enabled", true)
	weather.set("lightning_enabled", false)     # petir manual dulu, otomatis menyusul
	weather.set("play_sounds", true)
	weather.set("rain_density", 0.95)
	weather.set("rain_intensity", 1.5)
	weather.set("rain_wind", 0.42)
	weather.set("rain_color", Color(0.88, 0.94, 1.0, 0.92)) # lebih terang agar tetap terlihat saat gelap
	weather.set("shake_intensity", 6.0)


func _start_storm_sequence() -> void:
	var dim := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	dim.tween_property(canvas_modulate, "color", _dark_color, durasi_gelap)
	await get_tree().create_timer(jeda_hujan_mulai).timeout
	if weather and weather.has_method("activate_weather"):
		weather.call("activate_weather")
		if weather.has_method("ramp_rain"):
			weather.call("ramp_rain", durasi_hujan_naik)


func _lightning_strike() -> void:
	if weather and weather.has_method("strike_lightning"):
		weather.call("strike_lightning") # kilatan layar + garis petir + suara guntur
	# Cahaya petir ikut menerangi peta sesaat.
	var base := _dark_color
	var lit := Color(0.92, 0.95, 1.0, 1.0)
	var tw := create_tween()
	tw.tween_property(canvas_modulate, "color", lit, 0.05)
	tw.tween_property(canvas_modulate, "color", base.lerp(lit, 0.45), 0.05)
	tw.tween_property(canvas_modulate, "color", lit, 0.04)
	tw.tween_property(canvas_modulate, "color", base, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------------------
# UI: fade, letterbox, kotak peringatan
# ---------------------------------------------------------------------------

func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		var res := load(path)
		if res is Font:
			return res
	if FileAccess.file_exists(path):
		var ff := FontFile.new()
		if ff.load_dynamic_font(path) == OK:
			return ff
	return ThemeDB.fallback_font


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res := load(path)
		if res is Texture2D:
			return res
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img:
			return ImageTexture.create_from_image(img)
	return null


func _load_bag_texture() -> Texture2D:
	# Potong sprite tas dari spritesheet (piksel tajam, tanpa area kosong di sekelilingnya).
	var sheet := _load_texture(BAG_TEXTURE)
	if sheet == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = BAG_REGION
	atlas.filter_clip = true
	return atlas


func _setup_ui() -> void:
	overlay = CanvasLayer.new()
	overlay.name = "CutsceneUI"
	overlay.layer = 30
	add_child(overlay)

	ui_root = Control.new()
	ui_root.name = "Root"
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(ui_root)

	_build_warning_panel()

	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(fade_rect)

	click_player = AudioStreamPlayer.new()
	var click := load("res://assets/sfx/uiclick.wav") as AudioStream
	if click:
		click_player.stream = click
	add_child(click_player)


func _fade_from_black(seconds: float) -> void:
	fade_rect.color.a = 1.0
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(fade_rect, "color:a", 0.0, seconds)


func _style_box(bg: Color, border: Color, border_w: int, margin: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(0) # sudut tajam = gaya pixel-art
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin
	sb.content_margin_bottom = margin
	return sb


func _make_label(text: String, font: Font, size: int, color: Color, outline_color := Color(0, 0, 0, 0), outline_size := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline_size > 0:
		l.add_theme_constant_override("outline_size", outline_size)
		l.add_theme_color_override("font_outline_color", outline_color)
	return l


func _make_hazard_bar(height: float) -> Control:
	# Strip diagonal kuning-hitam khas tanda bahaya.
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0.0, height)
	bar.clip_contents = true
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func() -> void:
		var w := bar.size.x
		var h := bar.size.y
		bar.draw_rect(Rect2(0.0, 0.0, w, h), Color(0.96, 0.74, 0.22))
		var step := 36.0
		var x := -h
		while x < w + h:
			bar.draw_colored_polygon(PackedVector2Array([
				Vector2(x, h), Vector2(x + step * 0.5, h),
				Vector2(x + step * 0.5 + h, 0.0), Vector2(x + h, 0.0)]), Color(0.09, 0.08, 0.10))
			x += step
	)
	return bar


func _make_warning_icon(size: Vector2) -> Control:
	var icon := Control.new()
	icon.custom_minimum_size = size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void:
		var w := icon.size.x
		var h := icon.size.y
		var tri := PackedVector2Array([Vector2(w * 0.5, 2.0), Vector2(w - 2.0, h - 2.0), Vector2(2.0, h - 2.0)])
		icon.draw_colored_polygon(tri, Color(0.96, 0.74, 0.22))
		var closed := PackedVector2Array([tri[0], tri[1], tri[2], tri[0]])
		icon.draw_polyline(closed, Color(0.09, 0.08, 0.10), 4.0)
		icon.draw_string(_font_title, Vector2(0.0, h - 12.0), "!", HORIZONTAL_ALIGNMENT_CENTER, w, 32, Color(0.09, 0.08, 0.10))
	)
	return icon


func _make_divider() -> Control:
	var d := ColorRect.new()
	d.color = COL_GOLD_DARK
	d.custom_minimum_size = Vector2(0.0, 4.0)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d


func _build_button_style(bg: Color, border: Color, shadow_offset: float) -> StyleBoxFlat:
	var sb := _style_box(bg, border, 4, 14)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	sb.shadow_size = 0
	sb.shadow_offset = Vector2(0.0, shadow_offset)
	return sb


func _build_warning_panel() -> void:
	# --- bingkai luar (emas, tebal) ---
	warning_panel = PanelContainer.new()
	warning_panel.name = "FloodWarningPanel"
	warning_panel.visible = false
	warning_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	warning_panel.anchor_left = 0.5
	warning_panel.anchor_right = 0.5
	warning_panel.anchor_top = 0.5
	warning_panel.anchor_bottom = 0.5
	warning_panel.offset_left = -470.0
	warning_panel.offset_right = 470.0
	warning_panel.offset_top = 0.0
	warning_panel.offset_bottom = 0.0
	warning_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	warning_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var outer := _style_box(Color(0.02, 0.03, 0.06, 0.98), COL_GOLD, 6, 10)
	outer.shadow_color = Color(0.0, 0.0, 0.0, 0.7)
	outer.shadow_size = 28
	warning_panel.add_theme_stylebox_override("panel", outer)
	ui_root.add_child(warning_panel)

	# Bingkai berdenyut emas <-> merah (peringatan).
	var pulse := create_tween().set_loops()
	pulse.tween_property(outer, "border_color", COL_ALERT, 0.75).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(outer, "border_color", COL_GOLD, 0.75).set_trans(Tween.TRANS_SINE)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	warning_panel.add_child(stack)

	stack.add_child(_make_hazard_bar(18.0))

	# --- bingkai dalam (biru malam) ---
	var inner := PanelContainer.new()
	inner.add_theme_stylebox_override("panel", _style_box(Color(0.06, 0.08, 0.14, 1.0), COL_GOLD_DARK, 3, 26))
	stack.add_child(inner)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_child(content)

	content.add_child(_make_label("— PERINGATAN DARURAT —", _font_body, 30, COL_GOLD_LIGHT))

	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 22)
	title_row.add_child(_make_warning_icon(Vector2(68.0, 60.0)))
	var title := _make_label("WASPADA BANJIR!", _font_title, 40, Color.WHITE, Color(0.55, 0.09, 0.07), 12)
	title_row.add_child(title)
	title_row.add_child(_make_warning_icon(Vector2(68.0, 60.0)))
	content.add_child(title_row)

	content.add_child(_make_divider())

	var body := _make_label("Hujan deras tak kunjung reda dan air sungai terus naik.\nSegera masuk ke rumah, ambil Tas Siaga Bencana, lalu bersiap mengungsi ke tempat tinggi!", _font_body, 34, Color(0.90, 0.95, 1.0))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(body)

	# --- baris emergency bag ---
	var bag_row := HBoxContainer.new()
	bag_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bag_row.add_theme_constant_override("separation", 20)
	content.add_child(bag_row)

	var bag_frame := PanelContainer.new()
	bag_frame.add_theme_stylebox_override("panel", _style_box(Color(0.10, 0.13, 0.21), COL_GOLD, 3, 8))
	bag_row.add_child(bag_frame)
	var bag := TextureRect.new()
	bag.custom_minimum_size = Vector2(141.0, 150.0) # sprite 47x50 diperbesar 3x (piksel tajam)
	bag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bag.texture = _load_bag_texture()
	bag_frame.add_child(bag)

	var bag_text := VBoxContainer.new()
	bag_text.add_theme_constant_override("separation", 6)
	bag_text.alignment = BoxContainer.ALIGNMENT_CENTER
	bag_row.add_child(bag_text)
	var bag_title := _make_label("SIAPKAN TAS SIAGA BENCANA", _font_title, 16, COL_GOLD_LIGHT)
	bag_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	bag_text.add_child(bag_title)
	var bag_list := _make_label("Senter • Radio • Air Mineral\nKotak P3K • Kantong Tidur • Pisau", _font_body, 28, Color(0.67, 0.82, 0.93))
	bag_list.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	bag_text.add_child(bag_list)

	# --- tombol ---
	interior_button = Button.new()
	interior_button.name = "MasukInteriorButton"
	interior_button.text = "MASUK KE RUMAH & SIAPKAN TAS SIAGA BENCANA"
	interior_button.custom_minimum_size = Vector2(0.0, 74.0)
	interior_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interior_button.focus_mode = Control.FOCUS_ALL
	interior_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	interior_button.add_theme_font_override("font", _font_title)
	interior_button.add_theme_font_size_override("font_size", 16)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		interior_button.add_theme_color_override(key, Color.WHITE)
	interior_button.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.60))
	interior_button.add_theme_constant_override("outline_size", 6)
	interior_button.add_theme_color_override("font_outline_color", COL_GOLD_DARK)
	interior_button.add_theme_stylebox_override("normal", _build_button_style(COL_GOLD, COL_GOLD_LIGHT, 6.0))
	interior_button.add_theme_stylebox_override("hover", _build_button_style(Color(0.90, 0.74, 0.38), Color.WHITE, 6.0))
	interior_button.add_theme_stylebox_override("pressed", _build_button_style(Color(0.62, 0.48, 0.22), COL_GOLD_LIGHT, 0.0))
	interior_button.add_theme_stylebox_override("focus", _build_button_style(COL_GOLD, Color.WHITE, 6.0))
	interior_button.add_theme_stylebox_override("disabled", _build_button_style(Color(0.2, 0.2, 0.24), Color(0.3, 0.3, 0.34), 0.0))
	interior_button.disabled = true # baru aktif setelah peringatan tampil
	interior_button.modulate.a = 0.0
	interior_button.pressed.connect(_on_enter_pressed)
	content.add_child(interior_button)

	stack.add_child(_make_hazard_bar(18.0))


func _show_warning() -> void:
	warning_panel.visible = true
	warning_panel.modulate.a = 0.0
	await get_tree().process_frame # biarkan layout menghitung ukuran panel
	warning_panel.pivot_offset = warning_panel.size * 0.5
	warning_panel.scale = Vector2(0.86, 0.86)

	var pop := create_tween().set_parallel(true)
	pop.tween_property(warning_panel, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pop.tween_property(warning_panel, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await pop.finished

	# Beri waktu membaca, baru tombol muncul & aktif.
	await get_tree().create_timer(1.0).timeout
	var show_btn := create_tween()
	show_btn.tween_property(interior_button, "modulate:a", 1.0, 0.5)
	await show_btn.finished
	interior_button.disabled = false
	interior_button.grab_focus()


func _on_enter_pressed() -> void:
	if _transition_started or GameManager.is_transitioning:
		return
	_transition_started = true
	interior_button.disabled = true
	if click_player.stream:
		click_player.play()
	# Masuk interior TANPA spawn point & TANPA menandai intro selesai,
	# sehingga interior.gd memutar animasi tangga ("stairs") seperti semula.
	GameManager.has_played_intro_cutscene = false
	GameManager.change_scene_with_fade(INTERIOR_SCENE, "", 0.8)
