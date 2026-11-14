extends Node2D
## Mengatur gerak animasi tim penyelamat (Basarnas) mendekati pemain.
## Dipanggil dari evakuasi.gd lewat mulai_datang(pemain).

signal sudah_bertemu

@export var kecepatan: float = 220.0        # px per detik
@export var jarak_mulai: float = 1200.0     # petugas mulai sekian px di KIRI pemain (di luar layar)
@export var skala: float = 2.5              # ukuran petugas (2 = kecil, 3 = besar)

@onready var video: VideoStreamPlayer = $Basarnas
@onready var area_pertemuan: Area2D = $AreaPertemuan

var _target: Node2D = null
var _berjalan: bool = false


func _ready() -> void:
	# Ukuran dan posisi video diatur lewat script
	video.scale = Vector2(skala, skala)
	# Videonya 96x96 px; posisi dihitung otomatis supaya petugas tetap di tengah
	# dan kakinya tetap pas di titik node BasarnasTim, berapa pun skalanya.
	video.position = Vector2(-48.0 * skala, -80.0 * skala)

	# Disembunyikan dulu; baru muncul saat mulai_datang() dipanggil
	visible = false
	video.paused = true
	area_pertemuan.body_entered.connect(_on_area_pertemuan_body_entered)


func mulai_datang(target: Node2D) -> void:
	_target = target
	# Mulai dari kiri pemain (di luar layar), sejajar tanah pemain
	global_position = Vector2(target.global_position.x - jarak_mulai, target.global_position.y)
	visible = true
	if not video.is_playing():
		video.play()
	video.paused = false
	_berjalan = true


func _process(delta: float) -> void:
	if not _berjalan:
		return
	global_position.x += kecepatan * delta
	# Pengaman: kalau Area2D entah kenapa tidak terdeteksi, berhenti di posisi pemain
	if global_position.x >= _target.global_position.x:
		_berhenti()


func _on_area_pertemuan_body_entered(body: Node2D) -> void:
	# Dinding peta (StaticBody2D) juga bisa terdeteksi, jadi hanya pemain yang dihitung
	if not body.is_in_group("player"):
		return
	_berhenti()


func _berhenti() -> void:
	if not _berjalan:
		return
	_berjalan = false
	video.paused = true     # animasi jalan berhenti
	sudah_bertemu.emit()
