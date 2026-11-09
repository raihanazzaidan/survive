extends Resource
class_name Inv

signal updated # Sinyal penting untuk UI

# Sekarang menyimpan InvSlot, bukan InvItem
@export var slots: Array[InvSlot] 

func insert(item_data: InvItem):
	# 1. Cek apakah item sudah ada di dalam inventory untuk ditumpuk
	var item_slots = slots.filter(func(slot): return slot.item == item_data)
	if not item_slots.is_empty():
		item_slots[0].amount += 1
	else:
		# 2. Jika belum ada, cari kotak yang masih kosong
		var empty_slots = slots.filter(func(slot): return slot.item == null)
		if not empty_slots.is_empty():
			empty_slots[0].item = item_data
			empty_slots[0].amount = 1
			
	updated.emit() # Beritahu UI untuk me-refresh gambar
