extends RefCounted
## One queue per inventory owner. Plans reserve raw materials before work begins.

const Planner = preload("res://addons/ldk/core/Crafting/crafting_planner.gd")
const Recipe = preload("res://addons/ldk/core/Crafting/crafting_recipe.gd")
const MAX_ORDERS := 24
const MAX_BATCHES := 99

signal changed

class Order:
	var plan: Planner.Plan
	var held: Dictionary[StringName, int]
	var step_index := 0
	var batch := 0
	var step_elapsed := 0.0
	var elapsed := 0.0

	func _init(craft_plan: Planner.Plan) -> void:
		plan = craft_plan
		held = plan.reserved

	func product() -> StringName:
		return plan.steps[-1].recipe.product

	func remaining_quantity() -> int:
		var completed := batch if step_index == plan.steps.size() - 1 else 0
		var final_step := plan.steps[-1]
		return (final_step.batches - completed) * final_step.recipe.product_count

	func current_product() -> StringName:
		return plan.steps[step_index].recipe.product

	func progress() -> float:
		return clampf(elapsed / plan.seconds, 0.0, 1.0)

	func seconds_left() -> float:
		return maxf(0.0, plan.seconds - elapsed)


var _inventory: SlotInventory
var _items: ContentRegistry
var _planner: Planner
var _orders: Array[Order] = []
var _pending: Dictionary[InventoryItem, int] = {}
var _recipe_signatures: Dictionary[StringName, PackedByteArray] = {}


func _init(inventory: SlotInventory, items: ContentRegistry, recipes: ContentRegistry) -> void:
	_inventory = inventory
	_items = items
	_planner = Planner.new(recipes, items)
	for recipe in _planner.recipes:
		var ingredients := recipe.ingredients.keys()
		ingredients.sort()
		var signature := [ContentRegistry.normalize_id(recipe.product), recipe.product_count, recipe.seconds]
		for id: StringName in ingredients:
			signature.append([ContentRegistry.normalize_id(id), recipe.ingredients[id]])
		var hashing := HashingContext.new()
		hashing.start(HashingContext.HASH_SHA256)
		hashing.update(var_to_bytes(signature))
		_recipe_signatures[ContentRegistry.normalize_id(recipe.id)] = hashing.finish()
	_inventory.changed.connect(_retry_delivery, CONNECT_DEFERRED)


func recipes() -> Array[Recipe]:
	return _planner.recipes


func export_state() -> Dictionary:
	var stacks: Dictionary[StringName, int] = {}
	for item in _pending:
		stacks[ContentRegistry.normalize_id(item.id)] = _pending[item]
	var orders := []
	for order in _orders:
		var steps := []
		for step in order.plan.steps:
			var id := ContentRegistry.normalize_id(step.recipe.id)
			steps.append([id, step.batches, _recipe_signatures[id]])
		orders.append([steps, order.held.duplicate(), order.step_index, order.batch, order.step_elapsed])
	return {"orders": orders, "delivery": stacks}


## Reattach reserved inputs to their original orders, without charging the inventory a second time.
func restore_state(state: Dictionary) -> bool:
	var saved_orders: Variant = state.get("orders")
	var delivery: Variant = state.get("delivery")
	if not saved_orders is Array or saved_orders.size() > MAX_ORDERS or not delivery is Dictionary:
		return false
	var orders: Array[Order] = []
	for record: Variant in saved_orders:
		var order := _restore_order(record)
		if order == null:
			return false
		orders.append(order)
	var stacks: Variant = _read_stacks(delivery)
	if stacks == null:
		return false
	_orders = orders
	_pending = stacks
	changed.emit()
	return true


func _restore_order(record: Variant) -> Order:
	if not record is Array or record.size() != 5:
		return null
	var steps: Variant = record[0]
	if not steps is Array or steps.is_empty() or steps.size() > Planner.MAX_STEPS or not record[1] is Dictionary:
		return null
	var plan := Planner.Plan.new()
	for value: Variant in steps:
		if not value is Array or value.size() != 3 or not (value[0] is String or value[0] is StringName) \
			or not value[1] is int or value[1] <= 0 or value[1] > Planner.MAX_OPERATIONS - plan.operations:
			return null
		var id := ContentRegistry.normalize_id(StringName(value[0]))
		var recipe := _planner.recipe_by_id(id)
		if recipe == null or _recipe_signatures[id] != value[2]:
			return null
		plan.steps.append(Planner.Step.new(recipe, value[1]))
		plan.operations += value[1]
		plan.seconds += recipe.seconds * value[1]
	var index: Variant = record[2]
	var batch: Variant = record[3]
	var elapsed: Variant = record[4]
	if not index is int or index < 0 or index >= plan.steps.size() or not batch is int \
		or batch < 0 or batch >= plan.steps[index].batches or not elapsed is float \
		or not is_finite(elapsed) or elapsed < 0.0 or elapsed >= plan.steps[index].recipe.seconds:
		return null
	var held: Variant = _read_stacks(record[1])
	if held == null:
		return null
	var order := Order.new(plan)
	for item: InventoryItem in held:
		order.held[ContentRegistry.normalize_id(item.id)] = held[item]
	order.step_index = index
	order.batch = batch
	order.step_elapsed = elapsed
	order.elapsed = elapsed + batch * plan.steps[index].recipe.seconds
	for previous in index:
		order.elapsed += plan.steps[previous].batches * plan.steps[previous].recipe.seconds
	return order if _has_reserved_ingredients(order) else null


func _has_reserved_ingredients(order: Order) -> bool:
	var stock := order.held.duplicate()
	for index in range(order.step_index, order.plan.steps.size()):
		var step := order.plan.steps[index]
		var batches := step.batches - (order.batch if index == order.step_index else 0)
		for id in step.recipe.ingredients:
			var key := ContentRegistry.normalize_id(id)
			var available: int = stock.get(key, 0) - step.recipe.ingredients[id] * batches
			if available < 0:
				return false
			stock[key] = available
		if index < order.plan.steps.size() - 1:
			var product := ContentRegistry.normalize_id(step.recipe.product)
			stock[product] = stock.get(product, 0) + step.recipe.product_count * batches
	return true


## Entrega os materiais de uma sessão encerrada, preservando sobras até liberar espaço.
func restore_delivery(stacks: Dictionary) -> bool:
	var restored: Variant = _read_stacks(stacks)
	if restored == null:
		return false
	_pending = restored
	_deliver()
	changed.emit()
	return true


func _read_stacks(stacks: Dictionary) -> Variant:
	var restored: Dictionary[InventoryItem, int] = {}
	for id: Variant in stacks:
		if not (id is StringName or id is String) or not stacks[id] is int or stacks[id] <= 0:
			return null
		var item := _items.find(StringName(id)) as InventoryItem
		if item == null or restored.has(item):
			return null
		restored[item] = stacks[id]
	return restored


func orders() -> Array[Order]:
	return _orders.duplicate()


func active_order() -> Order:
	return _orders.front() if not _orders.is_empty() else null


func is_waiting_for_space() -> bool:
	return not _pending.is_empty()


func pending_delivery() -> Dictionary[InventoryItem, int]:
	return _pending.duplicate()


func is_running() -> bool:
	return not _orders.is_empty() and _pending.is_empty()


func has_capacity() -> bool:
	return _orders.size() < MAX_ORDERS


## Counts batches per order using the same planner as enqueue, including intermediates.
func craftable_batches(id: StringName) -> int:
	var stock := _inventory.item_totals()
	if _planner.plan_for(id, 1, stock) == null:
		return 0
	var plan := _best_plan(id, MAX_BATCHES, stock)
	return plan.steps[-1].batches if plan != null else 1


## A request of zero queues as many as possible. Positive requests allow a smaller batch.
func enqueue(id: StringName, requested := 1) -> bool:
	if requested < 0 or not has_capacity():
		return false
	var stock := _inventory.item_totals()
	var upper := mini(requested, MAX_BATCHES) if requested > 0 else MAX_BATCHES
	var plan := _best_plan(id, upper, stock)
	if plan == null or not _inventory.take_items(plan.reserved):
		return false
	_orders.append(Order.new(plan))
	changed.emit()
	return true


func _best_plan(id: StringName, upper: int, stock: Dictionary[StringName, int]) -> Planner.Plan:
	var plan := _planner.plan_for(id, upper, stock)
	if plan != null:
		return plan
	var lower := 1
	upper -= 1
	while lower <= upper:
		var middle := (lower + upper) >> 1
		var candidate := _planner.plan_for(id, middle, stock)
		if candidate == null:
			upper = middle - 1
		else:
			plan = candidate
			lower = middle + 1
	return plan


func cancel(order: Order) -> void:
	if not _orders.has(order):
		return
	_orders.erase(order)
	_release_held(order)
	_deliver()
	changed.emit()


func advance(delta: float) -> void:
	var queue_changed := false
	while delta > 0.0 and is_running():
		var order := active_order()
		var step := order.plan.steps[order.step_index]
		var remaining := step.recipe.seconds - order.step_elapsed
		var passed := minf(delta, remaining)
		order.elapsed += passed
		order.step_elapsed += passed
		delta -= passed
		if passed < remaining:
			break
		var updated := _finish_batch(order, step)
		queue_changed = queue_changed or updated
	if queue_changed:
		changed.emit()


func _finish_batch(order: Order, step: Planner.Step) -> bool:
	var recipe := step.recipe
	for id in recipe.ingredients:
		var ingredient := ContentRegistry.normalize_id(id)
		order.held[ingredient] -= recipe.ingredients[id]
		if order.held[ingredient] == 0:
			order.held.erase(ingredient)
	var finished_product := order.step_index == order.plan.steps.size() - 1
	if finished_product:
		_buffer(recipe.product, recipe.product_count)
	else:
		var product := ContentRegistry.normalize_id(recipe.product)
		order.held[product] = order.held.get(product, 0) + recipe.product_count
	order.step_elapsed = 0.0
	order.batch += 1
	if order.batch == step.batches:
		order.batch = 0
		order.step_index += 1
		if finished_product:
			_orders.pop_front()
			_release_held(order)
	if finished_product:
		_deliver()
	return finished_product or order.batch == 0


func _release_held(order: Order) -> void:
	for id in order.held:
		_buffer(id, order.held[id])
	order.held.clear()


func _buffer(id: StringName, count: int) -> void:
	var item := _items.find(id) as InventoryItem
	_pending[item] = _pending.get(item, 0) + count


func _deliver() -> void:
	if not _pending.is_empty():
		_pending = _inventory.add_items(_pending)


func _retry_delivery() -> void:
	if not _pending.is_empty():
		var previous := _pending
		_deliver()
		if _pending != previous:
			changed.emit()
