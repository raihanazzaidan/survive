
extends Control

# =====================================
# NODE
# =====================================

@onready var background_a: TextureRect = $BackgroundA
@onready var background_b: TextureRect = $BackgroundB
@onready var water: TextureRect = $Water
@onready var fade_black: ColorRect = $FadeBlack
@onready var rain_audio: AudioStreamPlayer = $RainAudio

var flood_audio: AudioStreamPlayer

# =====================================
# PENGATURAN KEMBALI KE AREA SEBELUMNYA
# =====================================

@export_file("*.tscn") var previous_scene_path: String = ""
@export var previous_spawn_name: String = ""

# =====================================
# FONT DAN WARNA WARNING
# =====================================

const FONT_TITLE := "res://assets/fonts/PressStart2P-Regular.ttf"
const FONT_BODY := "res://assets/fonts/VT323-Regular.ttf"

const COL_GOLD := Color(0.79, 0.64, 0.32)
const COL_GOLD_LIGHT := Color(1.0, 0.84, 0.48)
const COL_GOLD_DARK := Color(0.45, 0.33, 0.14)
const COL_ALERT := Color(0.86, 0.18, 0.14)

const WeatherFXScript = preload("res://addons/weather_fx/weather_fx.gd")

var _font_title: Font
var _font_body: Font

# =====================================
# BACKGROUND
# =====================================

var backgrounds = [
	preload("res://assets/maps/cutscene/screen1.png"),
	preload("res://assets/maps/cutscene/screen2.png"),
	preload("res://assets/maps/cutscene/screen3.png"),
	preload("res://assets/maps/cutscene/screen4.png"),
	preload("res://assets/maps/cutscene/screen5.png")
]

var current_background: TextureRect
var next_background: TextureRect

# =====================================
# PENGATURAN DURASI
# =====================================

var screen_duration = 2.5
var fade_duration = 0.8
var black_hold_duration = 0.25

# =====================================
# ANIMASI AIR
# =====================================

var water_start_x = 0.0
var water_tween: Tween

# =====================================
# HUJAN
# =====================================

var rain_fx: Node2D = null
var rain_audio_tween: Tween

# =====================================
# WARNING UI
# =====================================

var overlay: CanvasLayer
var ui_root: Control
var warning_dim: ColorRect
var warning_panel: PanelContainer
var return_button: Button
var click_player: AudioStreamPlayer

var _transition_started := false


# =====================================
# READY
# =====================================

func _ready() -> void:

	_font_title = _load_font(FONT_TITLE)
	_font_body = _load_font(FONT_BODY)

	current_background = background_a
	next_background = background_b

	# BACKGROUND PERTAMA
	current_background.texture = backgrounds[0]
	current_background.modulate.a = 1.0

	next_background.texture = null
	next_background.modulate.a = 0.0

	# WATER
	water_start_x = water.position.x
	water.texture = null
	water.z_index = 2

	# =================================
	# FADE BLACK
	# =================================

	fade_black.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	fade_black.color = Color.BLACK
	fade_black.modulate = Color.WHITE
	fade_black.modulate.a = 1.0

	fade_black.z_as_relative = false
	fade_black.z_index = 1000
	fade_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_black.visible = true

	# =================================
	# AUDIO HUJAN
	# =================================

	rain_audio.stream = preload("res://assets/sfx/rain.wav")
	rain_audio.volume_db = -30.0
	rain_audio.play()

	rain_audio_tween = create_tween()
	rain_audio_tween.tween_property(
		rain_audio,
		"volume_db",
		-9.0,
		1.0
	)

	# =================================
	# AUDIO BANJIR
	# =================================

	flood_audio = get_node_or_null("FloodAudio") as AudioStreamPlayer

	if flood_audio == null:
		flood_audio = AudioStreamPlayer.new()
		flood_audio.name = "FloodAudio"
		add_child(flood_audio)

	flood_audio.stream = preload(
		"res://assets/sfx/floodwaterrush.mp3"
	)

	flood_audio.volume_db = -30.0

	# LOOP AUDIO BANJIR
	flood_audio.finished.connect(_on_flood_audio_finished)

	# =================================
	# WARNING UI
	# =================================

	_setup_warning_ui()

	# =================================
	# VISUAL HUJAN
	# =================================

	start_rain_visual()

	# =================================
	# MULAI CUTSCENE
	# =================================

	await get_tree().process_frame

	await fade_screen(0.0, fade_duration)

	await play_cutscene()


# =====================================
# CUTSCENE
# =====================================

func play_cutscene() -> void:

	for i in range(1, backgrounds.size()):

		# TUNGGU SCENE SEBELUMNYA
		await get_tree().create_timer(
			screen_duration
		).timeout

		# FADE TO BLACK
		await fade_screen(1.0, fade_duration)

		# TAHAN LAYAR HITAM
		await get_tree().create_timer(
			black_hold_duration
		).timeout

		# GANTI BACKGROUND
		next_background.texture = backgrounds[i]
		next_background.modulate.a = 1.0

		current_background.texture = null
		current_background.modulate.a = 0.0

		var temp = current_background
		current_background = next_background
		next_background = temp

		# AUDIO BANJIR MULAI SCENE 2
		if i == 1:
			start_flood_audio()

		# ANIMASI AIR SCENE 2-4
		if i >= 1 and i <= 3:
			start_water()
		else:
			stop_water()

		await get_tree().process_frame

		# FADE IN SCENE BARU
		await fade_screen(0.0, fade_duration)

	# =================================
	# SCENE TERAKHIR
	# =================================

	# SCENE 5 TETAP DITAMPILKAN 2.5 DETIK
	await get_tree().create_timer(
		screen_duration
	).timeout

	stop_water()

	# TAMPILKAN WARNING
	await _show_warning()

	print("CUTSCENE SELESAI!")


# =====================================
# TRANSISI HITAM
# =====================================

func fade_screen(target_alpha: float, duration: float) -> void:

	var tween = create_tween()

	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		fade_black,
		"modulate:a",
		target_alpha,
		duration
	)

	await tween.finished


# =====================================
# AUDIO BANJIR
# =====================================

func start_flood_audio() -> void:

	if flood_audio == null:
		return

	if flood_audio.playing:
		return

	flood_audio.volume_db = -30.0
	flood_audio.play()

	var tween = create_tween()

	tween.tween_property(
		flood_audio,
		"volume_db",
		-8.0,
		1.0
	)


func _on_flood_audio_finished() -> void:

	if is_inside_tree() and flood_audio != null:
		flood_audio.play()


# =====================================
# ANIMASI AIR KANAN - KIRI
# =====================================

func start_water() -> void:

	if water_tween != null:
		water_tween.kill()

	water.position.x = water_start_x

	water_tween = create_tween()
	water_tween.set_loops()

	water_tween.tween_property(
		water,
		"position:x",
		water_start_x + 12,
		0.35
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	water_tween.tween_property(
		water,
		"position:x",
		water_start_x - 12,
		0.55
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	water_tween.tween_property(
		water,
		"position:x",
		water_start_x + 12,
		0.55
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func stop_water() -> void:

	if water_tween != null:
		water_tween.kill()

	water.position.x = water_start_x


# =====================================
# VISUAL HUJAN
# =====================================

func start_rain_visual() -> void:

	if rain_fx != null:
		return

	rain_fx = WeatherFXScript.add(self, "rain", {
		"density": 0.78,
		"wind": 0.32,
		"fall_speed": 1.8,
		"drop_length": 36.0,
		"splashes": 0.75,
		"intensity": 1.0,
		"pixel_size": 2
	})

	rain_fx.z_index = 5
	rain_fx.call("fade_in", 0.5)


func stop_rain_visual() -> void:

	if rain_fx != null:
		rain_fx.call("stop", 0.3)
		rain_fx = null


# =====================================
# LOAD FONT
# =====================================

func _load_font(path: String) -> Font:

	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Font:
			return res

	return ThemeDB.fallback_font


# =====================================
# WARNING UI SETUP
# =====================================

func _setup_warning_ui() -> void:

	overlay = CanvasLayer.new()
	overlay.name = "WarningOverlay"
	overlay.layer = 30
	add_child(overlay)

	ui_root = Control.new()
	ui_root.name = "WarningRoot"
	ui_root.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	overlay.add_child(ui_root)

	# GELAPKAN BACKGROUND
	warning_dim = ColorRect.new()
	warning_dim.color = Color(0.0, 0.0, 0.0, 0.0)
	warning_dim.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	warning_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	warning_dim.visible = false
	ui_root.add_child(warning_dim)

	# PANEL WARNING
	_build_warning_panel()

	# AUDIO KLIK
	click_player = AudioStreamPlayer.new()
	click_player.stream = load(
		"res://assets/sfx/uiclick.wav"
	)
	add_child(click_player)


# =====================================
# STYLE PANEL
# =====================================

func _style_box(
	bg: Color,
	border: Color,
	border_w: int,
	margin: int
) -> StyleBoxFlat:

	var sb = StyleBoxFlat.new()

	sb.bg_color = bg
	sb.border_color = border

	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(0)

	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin
	sb.content_margin_bottom = margin

	return sb


# =====================================
# LABEL
# =====================================

func _make_label(
	label_text: String,
	font: Font,
	size: int,
	color: Color,
	outline_color := Color(0, 0, 0, 0),
	outline_size := 0
) -> Label:

	var label = Label.new()

	label.text = label_text

	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)

	if outline_size > 0:
		label.add_theme_constant_override(
			"outline_size",
			outline_size
		)
		label.add_theme_color_override(
			"font_outline_color",
			outline_color
		)

	return label


# =====================================
# GARIS PEMBATAS
# =====================================

func _make_divider() -> Control:

	var divider = ColorRect.new()

	divider.color = COL_GOLD_DARK
	divider.custom_minimum_size = Vector2(0, 4)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE

	return divider


# =====================================
# HAZARD STRIPE
# =====================================

func _make_hazard_bar(height: float) -> Control:

	var bar = Control.new()

	bar.custom_minimum_size = Vector2(0, height)
	bar.clip_contents = true
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	bar.draw.connect(func() -> void:

		var w = bar.size.x
		var h = bar.size.y

		bar.draw_rect(
			Rect2(0, 0, w, h),
			Color(0.96, 0.74, 0.22)
		)

		var step = 36.0
		var x = -h

		while x < w + h:

			bar.draw_colored_polygon(
				PackedVector2Array([
					Vector2(x, h),
					Vector2(x + step * 0.5, h),
					Vector2(x + step * 0.5 + h, 0),
					Vector2(x + h, 0)
				]),
				Color(0.09, 0.08, 0.10)
			)

			x += step
	)

	return bar


# =====================================
# ICON WARNING
# =====================================

func _make_warning_icon(size: Vector2) -> Control:

	var icon = Control.new()

	icon.custom_minimum_size = size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

	icon.draw.connect(func() -> void:

		var w = icon.size.x
		var h = icon.size.y

		var triangle = PackedVector2Array([
			Vector2(w * 0.5, 2),
			Vector2(w - 2, h - 2),
			Vector2(2, h - 2)
		])

		icon.draw_colored_polygon(
			triangle,
			Color(0.96, 0.74, 0.22)
		)

		var closed = PackedVector2Array([
			triangle[0],
			triangle[1],
			triangle[2],
			triangle[0]
		])

		icon.draw_polyline(
			closed,
			Color(0.09, 0.08, 0.10),
			4.0
		)

		icon.draw_string(
			_font_title,
			Vector2(0, h - 12),
			"!",
			HORIZONTAL_ALIGNMENT_CENTER,
			w,
			30,
			Color(0.09, 0.08, 0.10)
		)
	)

	return icon


# =====================================
# BUTTON STYLE
# =====================================

func _build_button_style(
	bg: Color,
	border: Color,
	shadow_offset: float
) -> StyleBoxFlat:

	var sb = _style_box(bg, border, 4, 14)

	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, shadow_offset)

	return sb


# =====================================
# MEMBUAT WARNING PANEL
# =====================================

func _build_warning_panel() -> void:

	# BINGKAI LUAR
	warning_panel = PanelContainer.new()

	warning_panel.name = "BridgeWarningPanel"
	warning_panel.visible = false
	warning_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	warning_panel.anchor_left = 0.5
	warning_panel.anchor_right = 0.5
	warning_panel.anchor_top = 0.5
	warning_panel.anchor_bottom = 0.5

	warning_panel.offset_left = -470
	warning_panel.offset_right = 470
	warning_panel.offset_top = -245
	warning_panel.offset_bottom = 245

	var outer = _style_box(
		Color(0.02, 0.03, 0.06, 0.98),
		COL_GOLD,
		6,
		10
	)

	outer.shadow_color = Color(0, 0, 0, 0.7)
	outer.shadow_size = 28

	warning_panel.add_theme_stylebox_override(
		"panel",
		outer
	)

	ui_root.add_child(warning_panel)

	# ANIMASI BORDER EMAS DAN MERAH
	var pulse = create_tween()
	pulse.set_loops()

	pulse.tween_property(
		outer,
		"border_color",
		COL_ALERT,
		0.75
	).set_trans(Tween.TRANS_SINE)

	pulse.tween_property(
		outer,
		"border_color",
		COL_GOLD,
		0.75
	).set_trans(Tween.TRANS_SINE)

	# ISI PANEL
	var stack = VBoxContainer.new()
	stack.add_theme_constant_override(
		"separation",
		8
	)

	warning_panel.add_child(stack)

	stack.add_child(_make_hazard_bar(18))

	# PANEL BAGIAN DALAM
	var inner = PanelContainer.new()

	inner.add_theme_stylebox_override(
		"panel",
		_style_box(
			Color(0.06, 0.08, 0.14, 1.0),
			COL_GOLD_DARK,
			3,
			24
		)
	)

	stack.add_child(inner)

	var content = VBoxContainer.new()

	content.add_theme_constant_override(
		"separation",
		14
	)

	content.alignment = BoxContainer.ALIGNMENT_CENTER

	inner.add_child(content)

	# SUBJUDUL
	content.add_child(
		_make_label(
			"— PERINGATAN JALUR —",
			_font_body,
			30,
			COL_GOLD_LIGHT
		)
	)

	# JUDUL + ICON
	var title_row = HBoxContainer.new()

	title_row.alignment = BoxContainer.ALIGNMENT_CENTER

	title_row.add_theme_constant_override(
		"separation",
		22
	)

	title_row.add_child(
		_make_warning_icon(Vector2(68, 60))
	)

	var title = _make_label(
		"JEMBATAN RUSAK!",
		_font_title,
		28,
		Color.WHITE,
		Color(0.55, 0.09, 0.07),
		8
	)

	title_row.add_child(title)

	title_row.add_child(
		_make_warning_icon(Vector2(68, 60))
	)

	content.add_child(title_row)

	# DIVIDER
	content.add_child(_make_divider())

	# PESAN WARNING
	var body = _make_label(
		"Arus banjir terlalu deras dan jembatan tidak dapat dilewati.\nKondisi ini berbahaya untuk dilalui.\nSilakan kembali ke area sebelumnya!",
		_font_body,
		34,
		Color(0.90, 0.95, 1.0)
	)

	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(0, 105)

	content.add_child(body)

	# INSTRUKSI
	content.add_child(
		_make_label(
			"JANGAN MEMAKSAKAN DIRI UNTUK MENYEBERANG!",
			_font_body,
			27,
			COL_GOLD_LIGHT
		)
	)

	# =================================
	# TOMBOL KEMBALI
	# =================================

	return_button = Button.new()

	return_button.name = "ReturnButton"
	return_button.text = "KEMBALI KE AREA SEBELUMNYA"

	return_button.custom_minimum_size = Vector2(0, 74)
	return_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	return_button.focus_mode = Control.FOCUS_ALL
	return_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	return_button.add_theme_font_override(
		"font",
		_font_title
	)

	return_button.add_theme_font_size_override(
		"font_size",
		14
	)

	for key in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_focus_color"
	]:
		return_button.add_theme_color_override(
			key,
			Color.WHITE
		)

	return_button.add_theme_color_override(
		"font_outline_color",
		COL_GOLD_DARK
	)

	return_button.add_theme_constant_override(
		"outline_size",
		6
	)

	return_button.add_theme_stylebox_override(
		"normal",
		_build_button_style(
			COL_GOLD,
			COL_GOLD_LIGHT,
			6
		)
	)

	return_button.add_theme_stylebox_override(
		"hover",
		_build_button_style(
			Color(0.90, 0.74, 0.38),
			Color.WHITE,
			6
		)
	)

	return_button.add_theme_stylebox_override(
		"pressed",
		_build_button_style(
			Color(0.62, 0.48, 0.22),
			COL_GOLD_LIGHT,
			0
		)
	)

	return_button.add_theme_stylebox_override(
		"focus",
		_build_button_style(
			COL_GOLD,
			Color.WHITE,
			6
		)
	)

	return_button.disabled = true
	return_button.modulate.a = 0.0

	return_button.pressed.connect(_on_return_pressed)

	content.add_child(return_button)

	stack.add_child(_make_hazard_bar(18))


# =====================================
# MENAMPILKAN WARNING
# =====================================

func _show_warning() -> void:

	warning_dim.visible = true
	warning_panel.visible = true

	warning_dim.color.a = 0.0
	warning_panel.modulate.a = 0.0

	await get_tree().process_frame

	warning_panel.pivot_offset = (
		warning_panel.size * 0.5
	)

	warning_panel.scale = Vector2(0.86, 0.86)

	# FADE BACKGROUND + POPUP PANEL
	var pop = create_tween()
	pop.set_parallel(true)

	pop.tween_property(
		warning_dim,
		"color:a",
		0.65,
		0.45
	).set_trans(Tween.TRANS_SINE)

	pop.tween_property(
		warning_panel,
		"modulate:a",
		1.0,
		0.45
	).set_trans(Tween.TRANS_SINE)

	pop.tween_property(
		warning_panel,
		"scale",
		Vector2.ONE,
		0.6
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await pop.finished

	# TUNGGU AGAR PEMAIN MEMBACA PESAN
	await get_tree().create_timer(1.0).timeout

	# TAMPILKAN TOMBOL
	var show_button = create_tween()

	show_button.tween_property(
		return_button,
		"modulate:a",
		1.0,
		0.5
	)

	await show_button.finished

	return_button.disabled = false
	return_button.grab_focus()


# =====================================
# KEMBALI KE AREA SEBELUMNYA
# =====================================

func _on_return_pressed() -> void:

	if _transition_started:
		return

	if GameManager.is_transitioning:
		return

	# CEK PATH SCENE
	if previous_scene_path.is_empty():
		push_error(
			"Isi Previous Scene Path di Inspector terlebih dahulu!"
		)
		return

	_transition_started = true

	return_button.disabled = true

	# AUDIO KLIK
	if click_player.stream:
		click_player.play()

	print("PREVIOUS SCENE: ", previous_scene_path)
	print("PREVIOUS SPAWN: ", previous_spawn_name)

	# PINDAH SCENE
	GameManager.change_scene_with_fade(
		previous_scene_path,
		previous_spawn_name,
		0.8
	)
