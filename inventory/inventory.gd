extends Resource
class_name Inv

signal updated

@export var slots: Array[InvSlot] 

func insert(item_data: InvItem):
	var item_slots = slots.filter(func(slot): return slot.item == item_data)
	if not item_slots.is_empty():
		item_slots[0].amount += 1
	else:
		var empty_slots = slots.filter(func(slot): return slot.item == null)
		if not empty_slots.is_empty():
			empty_slots[0].item = item_data
			empty_slots[0].amount = 1
			
	updated.emit()

# Buang item dari slot. Defaultnya membuang 1 buah; slot otomatis kosong jika jumlahnya habis.
func remove_item(slot: InvSlot, amount: int = 1) -> void:
	if slot == null or slot.item == null or amount <= 0:
		return
	slot.amount -= amount
	if slot.amount <= 0:
		slot.item = null
		slot.amount = 0
	updated.emit()
