extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var player: CharacterBody2D = $mainPlayer
@onready var ground_layer: TileMapLayer = $LantaiLayer # atau $ground di luar rumah

# Dialog pembuka saat pertama kali berada di dalam rumah (cerita, memakai potret player).
const INTRO_LINES := [
	"Listrik padam! Seluruh rumah mendadak gelap gulita.",
	"Mungkin hujan deras, petir, atau genangan air mengganggu jaringan listrik. Keadaan di luar sepertinya semakin berbahaya.",
	"Tanpa listrik, lampu tidak bisa menyala dan ponselku tidak bisa diisi daya. TV dan internet juga tidak bisa diandalkan untuk mendapatkan informasi.",
	"Hujan deras belum berhenti, air sungai semakin tinggi, dan listrik sudah padam. Banjir bisa segera datang! Aku harus bersiap mengungsi sebelum keadaan semakin buruk.",
    "Aku harus menyiapkan Tas Siaga Bencana! Masukkan perlengkapan penting yang kubutuhkan selama evakuasi, termasuk kebutuhan darurat jika listrik dan komunikasi terputus."
]

var _exit_warned: bool = false

func _ready() -> void:
	setup_camera_limits()
	# Hitung barang yang harus dikumpulkan (barang yang sudah diambil tidak ikut dihitung dua kali)
	GameManager.bag_total = GameManager.bag_collected.size() + get_tree().get_nodes_in_group("bag_items").size()
	if has_node("Fade_transition") and $Fade_transition.has_node("AnimationPlayer"):
		$Fade_transition/AnimationPlayer.play("Fade_out")
	# Cek apakah cutscene tangga harus diputar (hanya 1 kali ketika dari main menu)
	if not GameManager.has_played_intro_cutscene and GameManager.target_spawn_point == "":
		GameManager.has_played_intro_cutscene = true
		player.position = Vector2(515, -602)
		player.mulai_cutscene()
		animation_player.play("stairs")
		await animation_player.animation_finished
		_tampilkan_dialog_awal()
	else:
		# Jika sudah pernah cutscene (misal masuk kembali dari luar), jangan jalankan animasi stairs lagi
		animation_player.stop()
		player.mulai_main_normal()
		if has_node("CanvasModulate"):
			$CanvasModulate.color = Color(0.12, 0.12, 0.20, 1.0)
		_tampilkan_dialog_awal()

func setup_camera_limits() -> void:
	if not ground_layer or not player:
		return
		
	var camera: Camera2D = player.get_node_or_null("Camera2D")
	if not camera:
		return
		
		# Ambil area petak tile yang dipakai
	var used_rect = ground_layer.get_used_rect()
	var tile_size = ground_layer.tile_set.tile_size
		
		# Konversi koordinat tile ke pixel dunia
	camera.limit_left = used_rect.position.x * tile_size.x
	camera.limit_top = used_rect.position.y * tile_size.y
	camera.limit_right = used_rect.end.x * tile_size.x
	camera.limit_bottom = used_rect.end.y * tile_size.y
		
		# Aktifkan pergerakan halus jika belum
	camera.position_smoothing_enabled = true


## Dialog pembuka di dalam rumah: cerita singkat + petunjuk cara mengambil barang.
## Hanya tampil sekali per sesi permainan.
func _tampilkan_dialog_awal() -> void:
	if GameManager.has_seen("rumah_intro"):
		return
	GameManager.mark_seen("rumah_intro")
	# Tunggu transisi layar selesai agar kotak dialog tidak muncul di balik fade.
	while GameManager.is_transitioning:
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout

	if DialogueBox.show_dialogue(INTRO_LINES, "Listrik Padam", DialogueBox.get_player_portrait()):
		await DialogueBox.dialogue_finished

	var petunjuk := [
		"Ada %d barang yang tersebar di dalam rumah. Dekati barangnya, lalu tekan E untuk memasukkannya ke Tas Siaga Bencana." % GameManager.bag_total,
		"Tekan TAB untuk membuka Tas Siaga Bencana dan melihat isinya. Gunakan W, A, S, D atau tombol panah untuk berjalan, Shift untuk berlari.",
		"Setelah semua barang terkumpul, berjalan ke pintu keluar dan tekan E."
	]
	DialogueBox.show_hint(petunjuk, "Petunjuk: Tas Siaga Bencana")


## Dipanggil tpIntExt.gd sebelum pindah scene. Jika masih ada barang yang belum diambil,
## pemain diingatkan satu kali; tekan E lagi di pintu untuk tetap keluar.
func can_exit() -> bool:
	var sisa := GameManager.bag_remaining()
	if sisa <= 0 or _exit_warned:
		return true
	_exit_warned = true
	var lines := [
		"Masih ada %d barang penting yang belum masuk ke Tas Siaga Bencana. Saat banjir datang, aku tidak akan sempat kembali untuk mengambilnya." % sisa,
		"Sebaiknya kuambil dulu. Kalau sudah yakin, tekan E lagi di pintu untuk keluar."
	]
	DialogueBox.show_dialogue(lines, "Tas Siaga Bencana Belum Lengkap", DialogueBox.get_player_portrait())
	return false
