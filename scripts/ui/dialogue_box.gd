extends CanvasLayer
## Sistem dialog reusable (Autoload bernama "DialogueBox").
##
## Cerita (dengan portrait):
##     DialogueBox.show_dialogue(["Halaman 1.", "Halaman 2."], "Judul", DialogueBox.get_player_portrait())
## Hint (tanpa portrait):
##     DialogueBox.show_hint(["Petunjuk 1.", "Petunjuk 2."], "Petunjuk Perjalanan")
## Menunggu dialog selesai:
##     await DialogueBox.dialogue_finished
##
## Kedua fungsi mengembalikan true jika dialog benar-benar dibuka, dan false
## jika sedang ada dialog lain / daftar halaman kosong (tidak pernah terbuka ganda).
## Selama dialog terbuka GameManager.dialogue_active = true, sehingga player
## dan interaksi (E, inventory) dikunci lalu kembali normal setelah ditutup.

signal dialogue_started
signal dialogue_finished
signal page_changed(page_index: int, page_count: int)

const FONT_TEXT_PATH := "res://assets/fonts/VT323-Regular.ttf"
const FONT_TITLE_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const CLICK_SFX_PATH := "res://assets/sfx/uiclick.wav"
# Portrait diambil dari frame idle1 sprite player yang sudah ada (kepala + bahu).
const PLAYER_SHEET_PATH := "res://assets/char/char_day1m.png"
const PLAYER_PORTRAIT_REGION := Rect2(4, 26, 64, 64)

const BOX_HEIGHT := 320.0
const BOX_BOTTOM_MARGIN := 44.0
const BOX_SIDE_MARGIN := 80.0
const BOX_MAX_WIDTH := 1640.0
const PORTRAIT_SIZE := 192.0          # 64px x 3 = skala piksel bulat
const TEXT_SIZE := 40
const TITLE_SIZE := 20
const SMALL_SIZE := 16
const CHARS_PER_SECOND := 45.0
const UNLOCK_DELAY := 0.25            # jeda sebelum kontrol player aktif lagi

const C_SHADOW := Color(0.0, 0.0, 0.0, 0.45)
const C_OUTLINE := Color(0.13, 0.07, 0.03)     # border luar: cokelat sangat gelap
const C_BG := Color(0.29, 0.17, 0.09)          # latar kotak: cokelat hangat
const C_BG_DARK := Color(0.20, 0.11, 0.05)
const C_TRIM := Color(0.85, 0.71, 0.50)        # border dalam: krem / cokelat muda
const C_TEXT := Color(1.0, 0.94, 0.82)
const C_GOLD := Color(1.0, 0.82, 0.38)
const C_ACCENT := Color(0.88, 0.62, 0.22)      # aksen tombol

var is_open: bool = false

var _pages: Array[String] = []
var _page_index: int = 0
var _typing: bool = false
var _typed: float = 0.0
var _unlock_token: int = 0
var _player_portrait: Texture2D = null

var _font_text: Font = null
var _font_title: Font = null

var _root: Control
var _box: Control
var _title_panel: PanelContainer
var _title_label: Label
var _portrait_frame: PanelContainer
var _portrait_rect: TextureRect
var _text_label: Label
var _page_label: Label
var _button: Button
var _sfx: AudioStreamPlayer


func _ready() -> void:
	layer = 90   # di atas UI player, di bawah fade transisi (128)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font_text = load(FONT_TEXT_PATH) as Font
	_font_title = load(FONT_TITLE_PATH) as Font
	_build_ui()
	_root.visible = false
	set_process(false)
	get_tree().root.size_changed.connect(_update_layout)
	_update_layout()


# ---------------------------------------------------------------- API publik

func show_dialogue(pages, speaker: String = "", portrait: Texture2D = null) -> bool:
	return _open_dialogue(pages, speaker, portrait, false)


func show_hint(pages, title: String = "Petunjuk") -> bool:
	return _open_dialogue(pages, title, null, true)


## Portrait player dari sprite game yang sudah ada (null jika file tidak ada).
func get_player_portrait() -> Texture2D:
	if _player_portrait != null:
		return _player_portrait
	var sheet := load(PLAYER_SHEET_PATH) as Texture2D
	if sheet == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = PLAYER_PORTRAIT_REGION
	_player_portrait = atlas
	return _player_portrait


func close() -> void:
	if not is_open:
		return
	is_open = false
	_typing = false
	_root.visible = false
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	dialogue_finished.emit()
	# Kontrol dikembalikan sedikit terlambat supaya tombol yang menutup dialog
	# (E / Enter / Space) tidak ikut memicu interaksi pada frame yang sama.
	var token := _unlock_token
	await get_tree().create_timer(UNLOCK_DELAY).timeout
	if token == _unlock_token and not is_open:
		GameManager.dialogue_active = false


# ------------------------------------------------------------ logika dialog

func _open_dialogue(pages, title: String, portrait: Texture2D, is_hint: bool) -> bool:
	if is_open:
		return false
	var clean: Array[String] = []
	for page in pages:
		var text := str(page).strip_edges()
		if text != "":
			clean.append(text)
	if clean.is_empty():
		return false

	_pages = clean
	_page_index = 0
	is_open = true
	_unlock_token += 1
	GameManager.dialogue_active = true

	_title_label.text = title
	_title_panel.visible = title != ""
	_title_panel.add_theme_stylebox_override("panel", _title_style(is_hint))
	_title_label.add_theme_color_override("font_color", C_GOLD if is_hint else C_TEXT)

	_portrait_rect.texture = portrait
	_portrait_frame.visible = portrait != null

	_root.visible = true
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_show_page(0)
	set_process(true)
	dialogue_started.emit()
	return true


func _show_page(index: int) -> void:
	_page_index = index
	_text_label.text = _pages[index]
	_text_label.visible_characters = 0
	_typed = 0.0
	_typing = true
	_page_label.text = "%d/%d" % [index + 1, _pages.size()]
	_button.text = "SELESAI" if index >= _pages.size() - 1 else "LANJUT"
	page_changed.emit(index, _pages.size())


func _process(delta: float) -> void:
	if not _typing:
		return
	_typed += CHARS_PER_SECOND * delta
	if _typed >= float(_text_label.text.length()):
		_finish_typing()
	else:
		_text_label.visible_characters = int(_typed)


func _finish_typing() -> void:
	_typing = false
	_text_label.visible_characters = -1


## force_next = true (tombol): langsung ke halaman berikut / selesai.
## force_next = false (keyboard / klik kotak): jika teks masih diketik,
## tampilkan penuh dulu.
func _advance(force_next: bool) -> void:
	if not is_open:
		return
	if _typing and not force_next:
		_finish_typing()
		return
	_play_click()
	if _page_index >= _pages.size() - 1:
		close()
	else:
		_show_page(_page_index + 1)


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("use"):
		get_viewport().set_input_as_handled()
		_advance(false)


func _on_box_gui_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_advance(false)


func _play_click() -> void:
	if _sfx != null and _sfx.stream != null:
		_sfx.play()


# ------------------------------------------------------------------ UI build

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_box = Control.new()
	_box.name = "Box"
	_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_box.gui_input.connect(_on_box_gui_input)
	_root.add_child(_box)
	_box.anchor_left = 0.0
	_box.anchor_right = 1.0
	_box.anchor_top = 1.0
	_box.anchor_bottom = 1.0
	_box.offset_top = -(BOX_HEIGHT + BOX_BOTTOM_MARGIN)
	_box.offset_bottom = -BOX_BOTTOM_MARGIN

	# Kotak cokelat polos: border luar gelap + bayangan halus
	var frame := Panel.new()
	frame.name = "Frame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := _flat(C_BG, C_OUTLINE, 6, true)
	frame_style.set_corner_radius_all(10)
	frame_style.shadow_color = C_SHADOW
	frame_style.shadow_size = 16
	frame_style.shadow_offset = Vector2(0, 6)
	frame.add_theme_stylebox_override("panel", frame_style)
	_box.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Border dalam krem (lapis kedua)
	var inner := Panel.new()
	inner.name = "InnerBorder"
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner_style := _flat(Color(0, 0, 0, 0), C_TRIM, 3, false)
	inner_style.set_corner_radius_all(6)
	inner.add_theme_stylebox_override("panel", inner_style)
	_box.add_child(inner)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)

	# Highlight tipis di bagian atas
	var highlight := ColorRect.new()
	highlight.name = "Highlight"
	highlight.color = Color(1, 1, 1, 0.10)
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(highlight)
	highlight.anchor_left = 0.0
	highlight.anchor_right = 1.0
	highlight.offset_left = 24
	highlight.offset_right = -24
	highlight.offset_top = 17
	highlight.offset_bottom = 19

	# Isi: portrait + teks + tombol
	var margin := MarginContainer.new()
	margin.name = "Content"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 32)
	_box.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 28)
	margin.add_child(row)

	_portrait_frame = PanelContainer.new()
	_portrait_frame.name = "PortraitFrame"
	_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_portrait_frame.add_theme_stylebox_override("panel", _portrait_style())
	row.add_child(_portrait_frame)
	_portrait_rect = TextureRect.new()
	_portrait_rect.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_frame.add_child(_portrait_rect)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	row.add_child(column)

	_text_label = Label.new()
	_text_label.name = "Text"
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text_label.custom_minimum_size = Vector2(200, 130)
	_text_label.add_theme_font_size_override("font_size", TEXT_SIZE)
	_text_label.add_theme_color_override("font_color", C_TEXT)
	_text_label.add_theme_color_override("font_shadow_color", C_OUTLINE)
	_text_label.add_theme_constant_override("shadow_offset_x", 2)
	_text_label.add_theme_constant_override("shadow_offset_y", 2)
	if _font_text != null:
		_text_label.add_theme_font_override("font", _font_text)
	column.add_child(_text_label)

	var bottom := HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(bottom)

	_page_label = Label.new()
	_page_label.name = "PageNumber"
	_page_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_page_label.add_theme_font_size_override("font_size", SMALL_SIZE)
	_page_label.add_theme_color_override("font_color", C_TRIM)
	if _font_title != null:
		_page_label.add_theme_font_override("font", _font_title)
	bottom.add_child(_page_label)

	_button = Button.new()
	_button.name = "ContinueButton"
	_button.text = "LANJUT"
	_button.focus_mode = Control.FOCUS_NONE
	_button.custom_minimum_size = Vector2(230, 54)
	_button.add_theme_font_size_override("font_size", SMALL_SIZE + 2)
	_button.add_theme_color_override("font_color", C_OUTLINE)
	_button.add_theme_color_override("font_hover_color", C_OUTLINE)
	_button.add_theme_color_override("font_pressed_color", C_OUTLINE)
	if _font_title != null:
		_button.add_theme_font_override("font", _font_title)
	_button.add_theme_stylebox_override("normal", _button_style(C_ACCENT))
	_button.add_theme_stylebox_override("hover", _button_style(C_ACCENT.lightened(0.22)))
	_button.add_theme_stylebox_override("pressed", _button_style(C_ACCENT.darkened(0.2)))
	_button.pressed.connect(_advance.bind(true))
	bottom.add_child(_button)

	# Tab judul (menempel di tepi atas kotak, ditambahkan terakhir agar di atas)
	_title_panel = PanelContainer.new()
	_title_panel.name = "TitleTab"
	_title_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_panel.add_theme_stylebox_override("panel", _title_style(false))
	_box.add_child(_title_panel)
	_title_panel.position = Vector2(56, -30)
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", TITLE_SIZE)
	_title_label.add_theme_color_override("font_color", C_TEXT)
	_title_label.add_theme_color_override("font_shadow_color", C_OUTLINE)
	_title_label.add_theme_constant_override("shadow_offset_x", 2)
	_title_label.add_theme_constant_override("shadow_offset_y", 2)
	if _font_title != null:
		_title_label.add_theme_font_override("font", _font_title)
	_title_panel.add_child(_title_label)

	_sfx = AudioStreamPlayer.new()
	_sfx.name = "ClickSfx"
	_sfx.volume_db = -6.0
	var click := load(CLICK_SFX_PATH) as AudioStream
	if click != null:
		_sfx.stream = click
	add_child(_sfx)


func _update_layout() -> void:
	if _box == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var side := maxf(BOX_SIDE_MARGIN, (viewport_size.x - BOX_MAX_WIDTH) * 0.5)
	_box.offset_left = side
	_box.offset_right = -side


func _flat(bg: Color, border: Color, border_width: int, draw_center: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.draw_center = draw_center
	return style


func _button_style(bg: Color) -> StyleBoxFlat:
	var style := _flat(bg, C_OUTLINE, 4, true)
	style.set_corner_radius_all(6)
	return style


func _title_style(is_hint: bool) -> StyleBoxFlat:
	var style := _flat(C_BG_DARK, C_GOLD if is_hint else C_TRIM, 3, true)
	style.set_corner_radius_all(6)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _portrait_style() -> StyleBoxFlat:
	var style := _flat(Color(0.20, 0.27, 0.31), C_TRIM, 4, true)
	style.set_corner_radius_all(6)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style
