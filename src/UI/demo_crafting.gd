extends VBoxContainer

const CraftingQueue = preload("res://addons/ldk/core/Crafting/crafting_queue.gd")
const Recipe = preload("res://addons/ldk/core/Crafting/crafting_recipe.gd")
const CraftingTag = preload("res://addons/ldk/core/Crafting/crafting_tag.gd")
const FALLBACK_TAB := "Outras"
const SLOT_SIZE := Vector2(38, 38)

var _queue: CraftingQueue
var _inventory: SlotInventory
var _items: ContentRegistry
var _selected: Recipe
var _clicked_recipe: Recipe
var _feedback := ""
var _refresh_pending := false

@onready var _tabs: TabContainer = %RecipeTabs
@onready var _title: Label = %RecipeName
@onready var _status: Label = %RecipeStatus
@onready var _details: Label = %RecipeDetails
@onready var _detail_scroll: ScrollContainer = %DetailScroll


func _ready() -> void:
	_tabs.get_tab_bar().focus_mode = Control.FOCUS_ALL
	visibility_changed.connect(_schedule_stock_refresh)


func configure(queue: CraftingQueue, inventory: SlotInventory, items: ContentRegistry,
		tags: ContentRegistry, texture_lookup: Callable) -> void:
	_queue = queue
	_inventory = inventory
	_items = items
	_build_tabs(tags, texture_lookup)
	_inventory.changed.connect(_schedule_stock_refresh)


func _build_tabs(tags: ContentRegistry, texture_lookup: Callable) -> void:
	var groups: Dictionary[StringName, Array] = {}
	for recipe in _queue.recipes():
		var tag := ContentRegistry.normalize_id(recipe.tag) if tags.find(recipe.tag) != null else &""
		if not groups.has(tag):
			groups[tag] = []
		groups[tag].append(recipe)

	var ordered_tags: Array[CraftingTag] = []
	for key in groups:
		if not key.is_empty():
			ordered_tags.append(tags.find(key) as CraftingTag)
	ordered_tags.sort_custom(func(a: CraftingTag, b: CraftingTag) -> bool:
		return a.order < b.order if a.order != b.order else String(a.id) < String(b.id)
	)
	var group := ButtonGroup.new()
	for tag in ordered_tags:
		_add_tab(tag.title if not tag.title.is_empty() else String(tag.id), groups[ContentRegistry.normalize_id(tag.id)], group, texture_lookup)
	if groups.has(&""):
		_add_tab(FALLBACK_TAB, groups[&""], group, texture_lookup)
	if groups.is_empty():
		_title.text = "Sem receitas disponíveis"


func _add_tab(label: String, recipes: Array, group: ButtonGroup, texture_lookup: Callable) -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_tabs.add_child(scroll)
	_tabs.set_tab_title(_tabs.get_tab_count() - 1, label)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 4)
	margin.add_theme_constant_override(&"margin_top", 4)
	scroll.add_child(margin)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override(&"h_separation", 4)
	grid.add_theme_constant_override(&"v_separation", 4)
	margin.add_child(grid)
	for recipe: Recipe in recipes:
		var button := Button.new()
		button.custom_minimum_size = SLOT_SIZE
		button.icon = texture_lookup.call(_item(recipe.product).icon_id) as Texture2D
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_constant_override(&"icon_max_width", 22)
		button.toggle_mode = true
		button.button_group = group
		button.focus_entered.connect(_select_recipe.bind(recipe))
		button.mouse_exited.connect(func() -> void: _clicked_recipe = null)
		button.gui_input.connect(_on_recipe_input.bind(recipe))
		grid.add_child(button)


func _on_recipe_input(event: InputEvent, recipe: Recipe) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if event.double_click and _clicked_recipe == recipe:
			_clicked_recipe = null
			_enqueue_recipe(recipe)
		else:
			_clicked_recipe = recipe
	elif event.is_action_pressed(&"ui_accept"):
		_clicked_recipe = null
		_enqueue_recipe(recipe)


func _enqueue_recipe(recipe: Recipe) -> void:
	_feedback = ""
	if not _queue.enqueue(recipe.id):
		_feedback = "Fila cheia" if not _queue.has_capacity() else "Recursos insuficientes"
	_refresh_status()


func _select_recipe(recipe: Recipe) -> void:
	if _selected != recipe:
		_detail_scroll.scroll_vertical = 0
	_feedback = ""
	_selected = recipe
	_refresh_details()
	_refresh_status()


func _schedule_stock_refresh() -> void:
	if _queue == null or not is_visible_in_tree() or _refresh_pending:
		return
	_refresh_pending = true
	_refresh_stock.call_deferred()


func _refresh_stock() -> void:
	_refresh_pending = false
	if is_visible_in_tree():
		_refresh_details()
		_refresh_status()


func _refresh_status() -> void:
	if _selected != null:
		var batches := _queue.craftable_batches(_selected.id)
		_status.text = "%d lote(s) · Clique duplo ou Enter" % batches if _feedback.is_empty() else _feedback


func _refresh_details() -> void:
	if _selected == null:
		return
	var result := _item(_selected.product)
	var result_name := result.title
	if not _selected.title.is_empty() and _selected.title != result.title:
		result_name = "%s → %s" % [_selected.title, result.title]
	_title.text = "%s ×%d · %.2f s" % [result_name, _selected.product_count, _selected.seconds]
	_title.tooltip_text = _title.text
	var lines := PackedStringArray()
	if not _selected.description.is_empty():
		lines.append(_selected.description)
	var stock := _inventory.item_totals()
	var ingredients := PackedStringArray()
	if _selected.ingredients.is_empty():
		ingredients.append("Nenhum")
	for id in _selected.ingredients:
		ingredients.append("%s ×%d (%d na bolsa)" % [_item(id).title, _selected.ingredients[id], stock.get(ContentRegistry.normalize_id(id), 0)])
	lines.append("Ingredientes · %s" % ", ".join(ingredients))
	_details.text = "\n".join(lines)


func _item(id: StringName) -> InventoryItem:
	return _items.find(id) as InventoryItem
