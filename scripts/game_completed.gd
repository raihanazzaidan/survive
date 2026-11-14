extends CanvasLayer
## Layar akhir "GAME COMPLETED!".
## Seluruh tampilan dibuat lewat kode, jadi scene-nya cukup satu node CanvasLayer.
## Gaya visual disamakan dengan panel "PERINGATAN JALUR": biru malam + emas.

const MENU_SCENE := "res://scenes/main_menu.tscn"

const FONT_TITLE_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const FONT_TEXT_PATH := "res://assets/fonts/VT323-Regular.ttf"
const CLICK_SFX_PATH := "res://assets/sfx/uiclick.wav"

# Musik kemenangan. Simpan file musik kamu di assets/sfx/ dengan salah satu nama ini.
# Jika tidak ada, sementara dipakai soundtrack.mp3 yang sudah ada di proyek.
const MUSIC_CANDIDATES := [
	"res://assets/sfx/musik_kemenangan.ogg",
	"res://assets/sfx/musik_kemenangan.mp3",
	"res://assets/sfx/musik_kemenangan.wav",
	"res://assets/sfx/soundtrack.mp3",
]

# Palet sama dengan panel peringatan (cutscene banjir)
const C_NAVY_OUTER := Color(0.02, 0.03, 0.06, 0.98)   # bingkai luar
const C_NAVY_INNER := Color(0.06, 0.08, 0.14, 1.0)    # isi panel
const C_GOLD := Color(0.79, 0.64, 0.32)
const C_GOLD_LIGHT := Color(1.0, 0.84, 0.48)
const C_GOLD_DARK := Color(0.45, 0.33, 0.14)
const C_TEXT := Color(0.90, 0.95, 1.0)                # putih kebiruan
const C_OUTLINE := Color(0.02, 0.03, 0.06)

var _font_title: Font = null
var _font_text: Font = null
var _panel: PanelContainer
var _button: Button
var _music: AudioStreamPlayer
var _sfx: AudioStreamPlayer
var _pindah: bool = false


func _ready() -> void:
	layer = 100   # di atas dialog (90), di bawah fade transisi (128)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font_title = load(FONT_TITLE_PATH) as Font
	_font_text = load(FONT_TEXT_PATH) as Font

	_build_ui()
	_build_confetti()
	_play_music()
	_animate_in()


# ------------------------------------------------------------------ tampilan

func _build_ui() -> void:
	var root := Control.new()
	root.name = "Root"
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP   # klik tidak tembus ke game

	# Latar gelap transparan
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.65)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Bingkai luar (biru malam + border emas)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -560
	_panel.offset_right = 560
	_panel.offset_top = -330
	_panel.offset_bottom = 330
	var outer := _style_box(C_NAVY_OUTER, C_GOLD, 6, 10)
	outer.shadow_color = Color(0, 0, 0, 0.7)
	outer.shadow_size = 28
	_panel.add_theme_stylebox_override("panel", outer)
	root.add_child(_panel)

	# Border berdenyut pelan: emas <-> emas terang
	var pulse := create_tween()
	pulse.set_loops()
	pulse.tween_property(outer, "border_color", C_GOLD_LIGHT, 0.9).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(outer, "border_color", C_GOLD, 0.9).set_trans(Tween.TRANS_SINE)

	# Panel bagian dalam
	var inner := PanelContainer.new()
	inner.add_theme_stylebox_override("panel", _style_box(C_NAVY_INNER, C_GOLD_DARK, 3, 32))
	_panel.add_child(inner)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	inner.add_child(box)

	box.add_child(_make_label("SELAMAT! KAMU BERHASIL BERTAHAN!", _font_title, 30, Color.WHITE, C_GOLD_DARK, 8))

	var garis := ColorRect.new()
	garis.color = C_GOLD_DARK
	garis.custom_minimum_size = Vector2(0, 4)
	garis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(garis)

	box.add_child(_make_label(
		"Kamu telah berhasil menyelesaikan seluruh rangkaian misi dan mencapai tempat evakuasi dengan selamat. Kamu juga telah mengikuti arahan selama proses evakuasi. Tetap waspada dan selalu utamakan keselamatan!",
		_font_text, 38, C_TEXT))

	box.add_child(_make_label("GAME COMPLETED!", _font_title, 52, C_GOLD_LIGHT, C_GOLD_DARK, 10))

	_button = Button.new()
	_button.name = "TombolMenu"
	_button.text = "KEMBALI KE MENU UTAMA"
	_button.custom_minimum_size = Vector2(0, 76)
	_button.focus_mode = Control.FOCUS_NONE
	_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_button.disabled = true   # dinyalakan sebentar lagi agar tidak terpencet tidak sengaja
	_button.add_theme_font_size_override("font_size", 18)
	for key in ["font_color", "font_hover_color", "font_pressed_color"]:
		_button.add_theme_color_override(key, Color.WHITE)
	_button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.45))
	_button.add_theme_color_override("font_outline_color", C_GOLD_DARK)
	_button.add_theme_constant_override("outline_size", 6)
	if _font_title != null:
		_button.add_theme_font_override("font", _font_title)
	_button.add_theme_stylebox_override("normal", _button_style(C_GOLD, C_GOLD_LIGHT, 6))
	_button.add_theme_stylebox_override("hover", _button_style(Color(0.90, 0.74, 0.38), Color.WHITE, 6))
	_button.add_theme_stylebox_override("pressed", _button_style(Color(0.62, 0.48, 0.22), C_GOLD_LIGHT, 0))
	_button.add_theme_stylebox_override("disabled", _button_style(C_GOLD_DARK, C_GOLD_DARK, 0))
	_button.pressed.connect(_on_menu_pressed)
	box.add_child(_button)

	_sfx = AudioStreamPlayer.new()
	var click := load(CLICK_SFX_PATH) as AudioStream
	if click != null:
		_sfx.stream = click
	add_child(_sfx)


func _make_label(teks: String, font: Font, ukuran: int, warna: Color,
		warna_garis: Color = Color(0, 0, 0, 0), tebal_garis: int = 0) -> Label:
	var label := Label.new()
	label.text = teks
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", ukuran)
	label.add_theme_color_override("font_color", warna)
	if font != null:
		label.add_theme_font_override("font", font)
	if tebal_garis > 0:
		label.add_theme_color_override("font_outline_color", warna_garis)
		label.add_theme_constant_override("outline_size", tebal_garis)
	return label


func _style_box(bg: Color, border: Color, border_w: int, margin: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(0)   # sudut kotak, sama seperti panel peringatan
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin
	sb.content_margin_bottom = margin
	return sb


func _button_style(bg: Color, border: Color, shadow_offset: float) -> StyleBoxFlat:
	var sb := _style_box(bg, border, 4, 14)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, shadow_offset)
	return sb


# ------------------------------------------------------------------- confetti

func _build_confetti() -> void:
	var lebar: float = get_viewport().get_visible_rect().size.x

	# Warna acak: tiap kertas memilih satu warna dari gradient ini
	# (emas, putih, biru, hijau supaya serasi dengan panel)
	var gradient := Gradient.new()
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	gradient.offsets = PackedFloat32Array([0.0, 0.17, 0.34, 0.51, 0.68, 0.84])
	gradient.colors = PackedColorArray([
		Color(1.0, 0.84, 0.48), Color(0.79, 0.64, 0.32), Color(0.90, 0.95, 1.0),
		Color(0.30, 0.60, 1.0), Color(0.30, 0.80, 0.40), Color(1.0, 0.55, 0.15)
	])

	var confetti := CPUParticles2D.new()
	confetti.name = "Confetti"
	confetti.position = Vector2(lebar * 0.5, -30)
	confetti.amount = 160
	confetti.lifetime = 6.0
	confetti.preprocess = 3.0               # langsung terlihat penuh saat muncul
	confetti.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	confetti.emission_rect_extents = Vector2(lebar * 0.5, 10)
	confetti.direction = Vector2(0, 1)
	confetti.spread = 25.0
	confetti.gravity = Vector2(0, 260)
	confetti.initial_velocity_min = 120.0
	confetti.initial_velocity_max = 320.0
	confetti.angular_velocity_min = -360.0
	confetti.angular_velocity_max = 360.0
	confetti.scale_amount_min = 9.0
	confetti.scale_amount_max = 18.0
	confetti.color_initial_ramp = gradient
	confetti.emitting = true
	add_child(confetti)


# ----------------------------------------------------------------- musik & anim

func _play_music() -> void:
	for path in MUSIC_CANDIDATES:
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream != null:
				_music = AudioStreamPlayer.new()
				_music.stream = stream
				_music.volume_db = -4.0
				add_child(_music)
				_music.play()
				return
	push_warning("Musik kemenangan tidak ditemukan di assets/sfx/")


func _animate_in() -> void:
	await get_tree().process_frame
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.7, 0.7)
	_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.5)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	await get_tree().create_timer(0.8).timeout
	_button.disabled = false


# --------------------------------------------------------------------- tombol

func _on_menu_pressed() -> void:
	if _pindah:
		return
	_pindah = true
	_button.disabled = true
	if _sfx != null and _sfx.stream != null:
		_sfx.play()

	# Kembalikan status permainan seperti awal
	GameManager.dialogue_active = false
	GameManager.target_spawn_point = ""
	GameManager.has_played_intro_cutscene = false
	GameManager.is_moving_left_after_return = false

	# Pakai fade yang sudah ada; scene ini ikut hilang saat pindah
	# (musik dan confetti otomatis berhenti)
	GameManager.change_scene_with_fade(MENU_SCENE)
