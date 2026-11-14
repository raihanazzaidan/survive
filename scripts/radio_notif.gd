extends CanvasLayer
## Notifikasi radio: panel di atas layar + suara kresek-kresek.
## Suara dibuat lewat kode (tanpa file audio). Dipanggil dari evakuasi.gd.

signal selesai

const FONT_TITLE_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const FONT_TEXT_PATH := "res://assets/fonts/VT323-Regular.ttf"

const C_BG := Color(0.07, 0.20, 0.38)
const C_BORDER := Color(0.55, 0.80, 0.95)
const C_TEXT := Color(0.94, 0.98, 1.0)
const C_GOLD := Color(1.0, 0.82, 0.38)
const C_OUTLINE := Color(0.03, 0.08, 0.18)

const MIX_RATE := 22050.0

var _panel: PanelContainer
var _lampu: ColorRect
var _label: Label
var _audio: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback

var _kresek_aktif: bool = false
var _amp: float = 0.3
var _amp_target: float = 0.3
var _ganti_amp: float = 0.0
var _beep_frames: int = 0
var _fase: float = 0.0
var _waktu: float = 0.0


func _ready() -> void:
	layer = 95   # di atas dialog (90), di bawah fade transisi (128)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_build_audio()


# ------------------------------------------------------------------ tampilan

func _build_ui() -> void:
	var font_title := load(FONT_TITLE_PATH) as Font
	var font_text := load(FONT_TEXT_PATH) as Font

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left = -520
	_panel.offset_right = 520
	_panel.offset_top = 50
	_panel.offset_bottom = 50
	_panel.grow_vertical = Control.GROW_DIRECTION_END
	_panel.modulate.a = 0.0   # tersembunyi sampai tampil() dipanggil

	var style := StyleBoxFlat.new()
	style.bg_color = C_BG
	style.border_color = C_BORDER
	style.set_border_width_all(6)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 20
	style.content_margin_left = 36
	style.content_margin_right = 36
	style.content_margin_top = 24
	style.content_margin_bottom = 28
	_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_panel)

	var kolom := VBoxContainer.new()
	kolom.add_theme_constant_override("separation", 14)
	_panel.add_child(kolom)

	# Baris judul: lampu berkedip + tulisan RADIO
	var baris := HBoxContainer.new()
	baris.add_theme_constant_override("separation", 14)
	baris.alignment = BoxContainer.ALIGNMENT_CENTER
	kolom.add_child(baris)

	_lampu = ColorRect.new()
	_lampu.custom_minimum_size = Vector2(22, 22)
	_lampu.color = Color(1.0, 0.25, 0.25)
	baris.add_child(_lampu)

	var judul := Label.new()
	judul.text = "RADIO DARURAT"
	judul.add_theme_font_size_override("font_size", 22)
	judul.add_theme_color_override("font_color", C_GOLD)
	judul.add_theme_color_override("font_outline_color", C_OUTLINE)
	judul.add_theme_constant_override("outline_size", 8)
	if font_title != null:
		judul.add_theme_font_override("font", font_title)
	baris.add_child(judul)

	var garis := ColorRect.new()
	garis.color = C_BORDER
	garis.custom_minimum_size = Vector2(0, 3)
	kolom.add_child(garis)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(900, 0)
	_label.add_theme_font_size_override("font_size", 42)
	_label.add_theme_color_override("font_color", C_TEXT)
	_label.add_theme_color_override("font_outline_color", C_OUTLINE)
	_label.add_theme_constant_override("outline_size", 6)
	if font_text != null:
		_label.add_theme_font_override("font", font_text)
	_label.visible_ratio = 0.0
	kolom.add_child(_label)


# --------------------------------------------------------------------- suara

func _build_audio() -> void:
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = MIX_RATE
	generator.buffer_length = 0.25

	_audio = AudioStreamPlayer.new()
	_audio.stream = generator
	_audio.volume_db = -10.0
	add_child(_audio)
	_audio.play()
	_playback = _audio.get_stream_playback() as AudioStreamGeneratorPlayback


func _process(delta: float) -> void:
	_waktu += delta
	# Lampu berkedip merah
	var terang: float = 0.55 + 0.45 * sin(_waktu * 9.0)
	_lampu.color = Color(1.0, 0.25, 0.25, terang)

	if not _kresek_aktif or _playback == null:
		return

	# Kresek: noise putih yang volumenya naik turun acak (putus-putus)
	_ganti_amp -= delta
	if _ganti_amp <= 0.0:
		_ganti_amp = randf_range(0.04, 0.16)
		if randf() > 0.25:
			_amp_target = randf_range(0.05, 0.6)
		else:
			_amp_target = 0.0
	_amp = lerpf(_amp, _amp_target, 0.5)

	var jumlah: int = _playback.get_frames_available()
	for i in jumlah:
		var v: float = randf_range(-1.0, 1.0) * _amp
		# "Bip" pendek di awal, khas radio saat tersambung
		if _beep_frames > 0:
			_fase += TAU * 1200.0 / MIX_RATE
			v += sin(_fase) * 0.25
			_beep_frames -= 1
		_playback.push_frame(Vector2(v, v))


func _mulai_kresek(dengan_bip: bool) -> void:
	_kresek_aktif = true
	if dengan_bip:
		_beep_frames = int(MIX_RATE * 0.12)


func _henti_kresek() -> void:
	_kresek_aktif = false


# --------------------------------------------------------------------- tampil

## Menampilkan notifikasi radio. Hanya teks "teks" yang ditampilkan,
## "lama" = berapa detik teks bertahan setelah selesai diketik.
func tampil(teks: String, lama: float = 5.0) -> void:
	_label.text = teks
	_label.visible_ratio = 0.0
	await get_tree().process_frame

	# Panel meluncur turun dari atas + memudar masuk
	var y_akhir: float = _panel.position.y
	_panel.position.y = y_akhir - 160.0
	var masuk := create_tween()
	masuk.set_parallel(true)
	masuk.tween_property(_panel, "position:y", y_akhir, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	masuk.tween_property(_panel, "modulate:a", 1.0, 0.3)

	# Suara kresek menyala sambil teks diketik
	_mulai_kresek(true)
	var ketik := create_tween()
	ketik.tween_property(_label, "visible_ratio", 1.0, 2.5)
	await ketik.finished
	_henti_kresek()

	# Teks bertahan agar sempat dibaca
	await get_tree().create_timer(lama).timeout

	# Kresek pendek penutup, lalu panel hilang
	_mulai_kresek(false)
	var keluar := create_tween()
	keluar.set_parallel(true)
	keluar.tween_property(_panel, "position:y", y_akhir - 160.0, 0.5)
	keluar.tween_property(_panel, "modulate:a", 0.0, 0.5)
	await keluar.finished
	_henti_kresek()

	selesai.emit()
