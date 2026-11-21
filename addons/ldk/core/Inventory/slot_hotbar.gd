extends RefCounted
## The quick slots are the first slots of the inventory itself.

signal selection_changed

var _inventory: SlotInventory
var _size: int
var _active_slot := 0


func _init(inventory: SlotInventory, slot_count: int) -> void:
	_inventory = inventory
	_size = clampi(slot_count, 0, inventory.size())


func size() -> int:
	return _size


func active_slot() -> int:
	return _active_slot if _size > 0 else -1


func active_item() -> InventoryItem:
	return _inventory.item_at(active_slot())


func select(slot: int) -> void:
	if slot >= 0 and slot < _size and slot != _active_slot:
		_active_slot = slot
		selection_changed.emit()


func cycle(direction: int) -> void:
	if _size > 0:
		select(posmod(_active_slot + direction, _size))
