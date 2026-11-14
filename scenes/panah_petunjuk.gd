extends Node2D
## Deretan panah di tanah yang menunjuk ke zona evakuasi.
## Node ini harus anak dari root evakuasi, bersebelahan dengan
## "mainPlayer" dan "ZonaEvakuasi". Panah dibuat otomatis dari posisi
## pemain sampai zona.

@export var jarak_antar_panah: float = 150.0   # jarak antar panah (px)
@export var jarak_dari_pemain: float = 220.0   # panah pertama sekian px di depan pemain
@export var jarak_dari_zona: float = 200.0     # panah terakhir berhenti sekian px sebelum zona
@export var ukuran: float = 24.0               # ukuran panah
@export var kecerahan_minimum: float = 0.65    # 0 = bisa hilang total saat berdenyut, 1 = tidak berdenyut
@export var kecepatan_denyut: float = 3.0      # makin kecil makin pelan
@export var lama_hilang: float = 1.0           # detik untuk memudar saat pemain sampai zona
@export var warna: Color = Color(0.25, 0.6, 1.0, 1.0)         # biru
@export var warna_garis: Color = Color(0.04, 0.12, 0.3, 1.0)  # biru tua (garis tepi)

var _posisi: Array[Vector2] = []
var _sudut: float = 0.0
var _bentuk: PackedVector2Array
var _garis: PackedVector2Array
var _waktu: float = 0.0


func _ready() -> void:
	# Bentuk panah (tanda ">") yang menghadap ke kanan
	var s := ukuran
	_bentuk = PackedVector2Array([
		Vector2(-s, -s), Vector2(0, -s), Vector2(s, 0),
		Vector2(0, s), Vector2(-s, s), Vector2(0, 0)
	])
	_garis = _bentuk.duplicate()
	_garis.append(_bentuk[0])

	var induk := get_parent()
	var pemain: Node2D = induk.get_node_or_null("mainPlayer")
	var zona: Node2D = induk.get_node_or_null("ZonaEvakuasi")
	if pemain == null or zona == null:
		push_warning("PanahPetunjuk: node mainPlayer / ZonaEvakuasi tidak ditemukan")
		set_process(false)
		return

	var arah := zona.global_position - pemain.global_position
	var arah_norm := arah.normalized()
	_sudut = arah_norm.angle()
	var titik_awal := pemain.global_position + arah_norm * jarak_dari_pemain
	var titik_akhir := zona.global_position - arah_norm * jarak_dari_zona
	var panjang := titik_awal.distance_to(titik_akhir)
	if (titik_akhir - titik_awal).dot(arah_norm) < 0.0:
		return   # zona terlalu dekat dengan pemain, tidak perlu panah

	var jumlah := int(panjang / jarak_antar_panah) + 1
	for i in jumlah:
		var titik := titik_awal + arah_norm * (jarak_antar_panah * i)
		_posisi.append(to_local(titik))


func _process(delta: float) -> void:
	_waktu += delta
	queue_redraw()


func _draw() -> void:
	for i in _posisi.size():
		# Denyut bergantian dari panah pertama ke terakhir (efek "mengalir")
		var denyut := 0.5 + 0.5 * sin(_waktu * kecepatan_denyut - i * 0.9)
		var isi := warna
		isi.a = kecerahan_minimum + (1.0 - kecerahan_minimum) * denyut
		var garis := warna_garis
		garis.a = isi.a
		draw_set_transform(_posisi[i], _sudut, Vector2.ONE)
		draw_colored_polygon(_bentuk, isi)
		draw_polyline(_garis, garis, 3.0)


func sembunyikan() -> void:
	set_process(false)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, lama_hilang)
	await tween.finished
	visible = false
