class_name SlotInventory
extends RefCounted

signal changed

var _items: Array[InventoryItem] = []
var _counts := PackedInt32Array()


func _init(capacity: int) -> void:
	_items.resize(maxi(capacity, 0))
	_counts.resize(_items.size())


func size() -> int:
	return _items.size()


func item_at(slot: int) -> InventoryItem:
	return _items[slot] if _has_slot(slot) else null


func count_at(slot: int) -> int:
	return _counts[slot] if _has_slot(slot) else 0


func export_slots() -> Dictionary[int, Array]:
	var slots: Dictionary[int, Array] = {}
	for index in size():
		if _items[index] != null:
			slots[index] = [ContentRegistry.normalize_id(_items[index].id), _counts[index]]
	return slots


## Valida todas as pilhas antes de substituir o inventário.
func restore_slots(slots: Dictionary, registry: ContentRegistry) -> bool:
	var items: Array[InventoryItem] = []
	var counts := PackedInt32Array()
	items.resize(size())
	counts.resize(size())
	for index: Variant in slots:
		var stack: Variant = slots[index]
		if not index is int or not _has_slot(index) or not stack is Array or stack.size() != 2:
			return false
		if not (stack[0] is StringName or stack[0] is String) or not stack[1] is int:
			return false
		var item := registry.find(StringName(stack[0])) as InventoryItem
		if item == null or stack[1] <= 0 or stack[1] > item.stack_limit:
			return false
		items[index] = item
		counts[index] = stack[1]
	_items = items
	_counts = counts
	changed.emit()
	return true


func item_totals() -> Dictionary[StringName, int]:
	var totals: Dictionary[StringName, int] = {}
	for slot in size():
		var item := _items[slot]
		if item != null:
			var id := ContentRegistry.normalize_id(item.id)
			totals[id] = totals.get(id, 0) + _counts[slot]
	return totals


## Debita todos os materiais ou mantém o inventário intacto.
func take_items(amounts: Dictionary[StringName, int]) -> bool:
	if amounts.is_empty():
		return true
	var totals := item_totals()
	var remaining: Dictionary[StringName, int] = {}
	for id in amounts:
		var key := ContentRegistry.normalize_id(id)
		var required: int = remaining.get(key, 0) + amounts[id]
		if amounts[id] <= 0 or totals.get(key, 0) < required:
			return false
		remaining[key] = required
	for slot in size():
		var item := _items[slot]
		if item == null:
			continue
		var key := ContentRegistry.normalize_id(item.id)
		if not remaining.has(key):
			continue
		var used := mini(remaining[key], _counts[slot])
		_decrease(slot, used)
		remaining[key] -= used
		if remaining[key] == 0:
			remaining.erase(key)
			if remaining.is_empty():
				break
	changed.emit()
	return true


func room_for(item: InventoryItem) -> int:
	if item == null:
		return 0
	var room := 0
	for slot in size():
		var current := _items[slot]
		if current == null:
			room += maxi(item.stack_limit, 0)
		elif current.id == item.id:
			room += maxi(current.stack_limit - _counts[slot], 0)
	return room


## Retorna a quantidade adicionada, preenchendo pilhas existentes primeiro.
func add(item: InventoryItem, amount: int) -> int:
	var added := _insert(item, amount)
	if added > 0:
		changed.emit()
	return added


## Insere o que couber e devolve os itens restantes para o chamador.
func add_items(stacks: Dictionary[InventoryItem, int]) -> Dictionary[InventoryItem, int]:
	var remaining: Dictionary[InventoryItem, int] = {}
	var inserted := false
	for item in stacks:
		var added := _insert(item, stacks[item])
		inserted = inserted or added > 0
		if added < stacks[item]:
			remaining[item] = stacks[item] - added
	if inserted:
		changed.emit()
	return remaining


func _insert(item: InventoryItem, amount: int) -> int:
	if item == null or amount <= 0 or item.stack_limit <= 0:
		return 0
	var remaining := amount
	for slot in size():
		var current := _items[slot]
		if current != null and current.id == item.id:
			var transfer := mini(remaining, maxi(current.stack_limit - _counts[slot], 0))
			_counts[slot] += transfer
			remaining -= transfer
			if remaining == 0:
				break
	if remaining > 0:
		for slot in size():
			if _items[slot] == null:
				var transfer := mini(remaining, item.stack_limit)
				_items[slot] = item
				_counts[slot] = transfer
				remaining -= transfer
				if remaining == 0:
					break
	return amount - remaining


func remove(slot: int, amount: int) -> int:
	var removed := mini(count_at(slot), maxi(amount, 0))
	if removed > 0:
		_decrease(slot, removed)
		changed.emit()
	return removed


## Move uma pilha ou parte dela. Pilhas de tipos distintos só podem ser trocadas inteiras.
func move(source: int, target: int, amount := -1) -> int:
	var item := item_at(source)
	if item == null or not _has_slot(target) or source == target:
		return 0
	var count := _counts[source]
	var moved := count if amount == -1 else clampi(amount, 0, count)
	if moved == 0:
		return 0
	var other := _items[target]
	if other != null and other.id != item.id:
		if moved != count:
			return 0
		_items[source] = other
		_counts[source] = _counts[target]
		_items[target] = item
		_counts[target] = count
	else:
		var limit := item.stack_limit if other == null else other.stack_limit
		moved = mini(moved, maxi(limit - _counts[target], 0))
		if moved == 0:
			return 0
		if other == null:
			_items[target] = item
		_counts[target] += moved
		_decrease(source, moved)
	changed.emit()
	return moved


func _decrease(slot: int, amount: int) -> void:
	_counts[slot] -= amount
	if _counts[slot] == 0:
		_items[slot] = null


func _has_slot(slot: int) -> bool:
	return slot >= 0 and slot < size()
