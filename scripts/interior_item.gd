extends Area2D

@export var item_data: InvItem
@onready var sprite = $itemSprite 

# Kartu pengetahuan yang muncul saat barang dimasukkan ke Emergency Bag.
# Kunci = nama file resource item (res://inventory/item/<kunci>.tres).
# Isi tiap kartu (3 halaman): (1) apa barangnya, (2) mengapa penting / risikonya, (3) kesimpulan prioritas.
# Prioritas mengikuti data item: PENTING (P3K, radio, air), BERGUNA (senter, kompas), TIDAK PRIORITAS (sleeping bag, pisau).
const ITEM_INFO := {
	"senter": {
		"title": "Senter",
		"lines": [
			"Senter! Pas sekali. Listrik sedang padam dan rumah gelap gulita, jadi aku butuh alat untuk menerangi jalan.",
			"Saat mengungsi malam hari, senter membantu melihat jalan, tangga, dan genangan yang tidak terlihat. Lebih aman daripada lilin yang bisa memicu kebakaran.",
			"Barang ini sangat berguna, jadi kumasukkan ke Tas Siaga Bencana."
		]
	},
	"p3k": {
		"title": "Kotak P3K",
		"lines": [
			"Kotak P3K, singkatan dari Pertolongan Pertama pada Kecelakaan. Isinya perban, plester, antiseptik, dan obat-obatan.",
			"Saat banjir, orang mudah terluka atau jatuh sakit, sementara bantuan belum tentu cepat datang. Luka yang terkena air banjir juga gampang infeksi.",
			"Ini barang penting yang wajib dibawa. Langsung kumasukkan ke tas."
		]
	},
	"radio": {
		"title": "Radio Portable",
		"lines": [
			"Radio portabel ini bisa menyala tanpa listrik rumah. Tepat sekali, karena sekarang listrik sedang padam.",
			"Kalau sinyal ponsel terganggu, radio tetap bisa menerima peringatan dan arahan resmi dari petugas, termasuk kapan aku harus mengungsi.",
			"Radio ini penting dan wajib kubawa. Aku hanya akan percaya pada informasi resmi, bukan kabar yang belum jelas sumbernya."
		]
	},
	"sleepingbag": {
		"title": "Sleeping Bag",
		"lines": [
			"Sleeping bag. Memang hangat dan enak untuk beristirahat di pengungsian.",
			"Tapi ukurannya besar dan berat, dan kalau basah susah kering. Itu bisa memperlambatku saat harus bergerak cepat.",
			"Jadi ini bukan prioritas. Kuambil dulu, tapi kalau tas penuh, inilah yang pertama kutinggalkan."
		]
	},
	"kompas": {
		"title": "Kompas",
		"lines": [
			"Kompas. Penunjuk arah ini tidak butuh baterai atau sinyal, jadi tetap bekerja saat listrik padam.",
			"Lumayan membantu kalau aku berjalan di tempat asing atau rambu jalan tertutup air. Tapi ini bukan barang utama.",
			"Yang lebih penting adalah menghafal jalur evakuasi. Kompas hanya pelengkap."
		]
	},
	"airBotol": {
		"title": "Air Mineral",
		"lines": [
			"Air mineral. Kelihatannya sepele, tapi ini penting sekali untuk dibawa.",
			"Saat banjir, air keran dan air sumur menjadi kotor dan penuh kuman penyakit. Kalau diminum, aku bisa sakit perut.",
			"Aku wajib membawa bekal air bersih supaya tidak kehausan selama mengungsi. Masuk ke tas!"
		]
	},
	"pisau": {
		"title": "Pisau",
		"lines": [
			"Pisau kecil yang mudah dibawa. Bisa dipakai untuk memotong tali atau membuka kemasan makanan.",
			"Tapi benda ini sangat tajam. Aku harus berhati-hati dan minta tolong orang dewasa saat memakainya agar tidak terluka.",
			"Jadi ini bukan prioritas. Kubawa kalau tas masih muat, dan jangan sampai menggantikan perlengkapan yang lebih penting."
		]
	}
}

const LENGKAP_LINES := [
	"Semua perlengkapan sudah masuk ke Tas Siaga Bencana. Dengan tas yang siap, aku bisa bergerak cepat tanpa panik.",
	"Listrik memang sudah padam, tapi sebelum pergi aku tetap mematikan saklar utama dan gas, lalu mengunci pintu. Listrik bisa menyala tiba-tiba saat rumah basah, dan itu berbahaya.",
	"Saatnya pergi. Aku akan menuju pintu keluar, lalu mencari jalan ke tempat yang lebih tinggi."
]

var is_player_near = false
var _picked: bool = false

func _ready():
	add_to_group("bag_items")
	# Jika barang ini sudah pernah diambil (mis. masuk rumah lagi), jangan muncul ulang.
	if GameManager.bag_collected.has(_item_key()):
		remove_from_group("bag_items")
		queue_free()
		return
	if item_data != null:
		sprite.texture = item_data.texture

func _process(delta):
	if is_player_near and not GameManager.dialogue_active and Input.is_action_just_pressed("use"):
		pungut_item()

func pungut_item():
	if _picked or item_data == null:
		return
	_picked = true
	is_player_near = false
	visible = false
	set_deferred("monitoring", false)
	var player_inv = preload("res://inventory/playerInv.tres")
	player_inv.insert(item_data)
	GameManager.bag_collected[_item_key()] = true
	await _tampilkan_info()
	queue_free()

func _item_key() -> String:
	if item_data == null:
		return ""
	return item_data.resource_path.get_file().get_basename()

func _tampilkan_info() -> void:
	var key := _item_key()
	var info: Dictionary = ITEM_INFO.get(key, {})
	var judul: String = info.get("title", "Barang")
	var lines: Array = info.get("lines", ["Aku memasukkan barang ini ke Tas Siaga Bencana."])
	var terkumpul := GameManager.bag_collected.size()
	var total := maxi(GameManager.bag_total, terkumpul)
	var portrait: Texture2D = DialogueBox.get_player_portrait()
	if DialogueBox.show_dialogue(lines, "%s  %d/%d" % [judul, terkumpul, total], portrait):
		await DialogueBox.dialogue_finished
	if GameManager.bag_remaining() == 0:
		if DialogueBox.show_dialogue(LENGKAP_LINES, "Tas Siaga Bencana Lengkap", portrait):
			await DialogueBox.dialogue_finished

func _on_body_entered(body):
	if body.name == "mainPlayer":
		is_player_near = true

func _on_body_exited(body):
	if body.name == "mainPlayer":
		is_player_near = false
