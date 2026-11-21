extends RefCounted

const Recipe = preload("res://addons/ldk/core/Crafting/crafting_recipe.gd")
const MAX_DEPTH := 32
const MAX_STEPS := 128
const MAX_OPERATIONS := 4096

class Step:
	var recipe: Recipe
	var batches: int

	func _init(definition: Recipe, count: int) -> void:
		recipe = definition
		batches = count


class Plan:
	var steps: Array[Step] = []
	var reserved: Dictionary[StringName, int] = {}
	var stock: Dictionary[StringName, int]
	var surplus: Dictionary[StringName, int] = {}
	var visiting: Dictionary[StringName, bool] = {}
	var seconds := 0.0
	var operations := 0


var recipes: Array[Recipe] = []
var _by_id: Dictionary[StringName, Recipe] = {}
var _by_product: Dictionary[StringName, Recipe] = {}


func _init(registry: ContentRegistry, items: ContentRegistry) -> void:
	for id in registry.ids():
		var recipe := registry.find(id) as Recipe
		if not _valid(recipe, items):
			push_warning("Invalid crafting recipe: %s" % id)
			continue
		recipes.append(recipe)
		_by_id[id] = recipe
		# Keep the first valid recipe per item for automatic prerequisites.
		var product := ContentRegistry.normalize_id(recipe.product)
		if not _by_product.has(product):
			_by_product[product] = recipe


func plan_for(id: StringName, batches: int, stock: Dictionary[StringName, int]) -> Plan:
	var recipe := recipe_by_id(id)
	if recipe == null or batches <= 0:
		return null
	var plan := Plan.new()
	plan.stock = stock.duplicate()
	if not _append(plan, recipe, batches):
		return null
	plan.stock.clear()
	plan.surplus.clear()
	return plan


func recipe_by_id(id: StringName) -> Recipe:
	return _by_id.get(ContentRegistry.normalize_id(id))


func _append(plan: Plan, recipe: Recipe, batches: int) -> bool:
	if plan.visiting.has(recipe.id) or plan.visiting.size() >= MAX_DEPTH:
		return false
	if plan.operations + batches > MAX_OPERATIONS:
		return false
	plan.operations += batches
	plan.visiting[recipe.id] = true
	for id in recipe.ingredients:
		if not _supply(plan, ContentRegistry.normalize_id(id), recipe.ingredients[id] * batches):
			return false
	plan.visiting.erase(recipe.id)
	if plan.steps.size() >= MAX_STEPS:
		return false
	plan.steps.append(Step.new(recipe, batches))
	plan.seconds += recipe.seconds * batches
	return true


func _supply(plan: Plan, item: StringName, required: int) -> bool:
	var extra := mini(required, plan.surplus.get(item, 0))
	if extra > 0:
		plan.surplus[item] -= extra
		required -= extra
	var available := mini(required, plan.stock.get(item, 0))
	if available > 0:
		plan.stock[item] -= available
		plan.reserved[item] = plan.reserved.get(item, 0) + available
		required -= available
	if required == 0:
		return true
	var producer := _by_product.get(item) as Recipe
	if producer == null:
		return false
	var batches := ceili(float(required) / producer.product_count)
	if not _append(plan, producer, batches):
		return false
	plan.surplus[item] = plan.surplus.get(item, 0) + batches * producer.product_count - required
	return true


func _valid(recipe: Recipe, items: ContentRegistry) -> bool:
	if recipe == null or not is_finite(recipe.seconds) or recipe.seconds < 0.05 or recipe.seconds > 3600.0:
		return false
	if recipe.product_count <= 0 or recipe.product_count > 9999 or not _valid_item(recipe.product, items):
		return false
	for item in recipe.ingredients:
		if recipe.ingredients[item] <= 0 or recipe.ingredients[item] > 9999 or not _valid_item(item, items):
			return false
	return true


func _valid_item(id: StringName, items: ContentRegistry) -> bool:
	var item := items.find(id) as InventoryItem
	return item != null and item.stack_limit > 0
