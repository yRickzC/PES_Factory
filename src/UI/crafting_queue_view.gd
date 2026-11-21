extends HBoxContainer

const CraftingQueue = preload("res://addons/ldk/core/Crafting/crafting_queue.gd")
const TILE_SIZE := 30
const TILE_GAP := 3
const MAX_VISIBLE := 3

class Tile extends Button:
	var meter := ProgressBar.new()
	var item_icon := TextureRect.new()
	var overflow := Label.new()
	var order: CraftingQueue.Order


var _queue: CraftingQueue
var _items: ContentRegistry
var _texture_lookup: Callable
var _hotbar: Control
var _tiles: Array[Tile] = []
var _progress_tween: Tween
var _inventory_open := false


func configure(queue: CraftingQueue, items: ContentRegistry, texture_lookup: Callable,
		hotbar: Control) -> void:
	_queue = queue
	_items = items
	_texture_lookup = texture_lookup
	_hotbar = hotbar
	add_theme_constant_override(&"separation", TILE_GAP)
	for index in MAX_VISIBLE:
		_create_tile()
	_hotbar.item_rect_changed.connect(_place_next_to_hotbar)
	_queue.changed.connect(_refresh)
	_refresh()


func set_inventory_open(open: bool) -> void:
	_inventory_open = open
	for tile in _tiles:
		_update_focus_mode(tile)


func _update_focus_mode(tile: Tile) -> void:
	tile.focus_mode = Control.FOCUS_ALL if _inventory_open and tile.order != null else Control.FOCUS_NONE


func _create_tile() -> void:
	var tile := Tile.new()
	tile.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
	tile.focus_mode = Control.FOCUS_NONE
	tile.pressed.connect(_cancel.bind(tile))
	add_child(tile)

	tile.add_child(tile.meter)
	tile.meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.meter.show_percentage = false
	tile.meter.max_value = 1.0
	tile.meter.step = 0.0
	tile.meter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tile.meter.offset_left = 2
	tile.meter.offset_top = 2
	tile.meter.offset_right = -2
	tile.meter.offset_bottom = -2

	tile.add_child(tile.item_icon)
	tile.item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tile.item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tile.item_icon.position = Vector2(5, 5)
	tile.item_icon.size = Vector2(20, 20)

	tile.add_child(tile.overflow)
	tile.overflow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.overflow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tile.overflow.add_theme_font_size_override(&"font_size", 9)
	tile.overflow.add_theme_color_override(&"font_color", Color(1.0, 0.97, 0.87))
	tile.overflow.add_theme_color_override(&"font_outline_color", Color(0.18, 0.28, 0.31))
	tile.overflow.add_theme_constant_override(&"outline_size", 3)
	tile.overflow.position = Vector2(2, 16)
	tile.overflow.size = Vector2(25, 12)
	_tiles.append(tile)


func _refresh() -> void:
	if _progress_tween != null:
		_progress_tween.kill()
		_progress_tween = null

	var orders := _queue.orders()
	var pending := _queue.pending_delivery()
	var pending_tile_count := int(not pending.is_empty())
	var total := orders.size() + pending_tile_count
	var shown := mini(total, _tiles.size())
	for index in _tiles.size():
		var tile := _tiles[index]
		tile.visible = index < shown
		tile.order = null
		if not tile.visible:
			continue
		if index < pending_tile_count:
			_show_pending(tile, pending)
		else:
			_show_order(tile, orders[index - pending_tile_count])
		_update_focus_mode(tile)
		tile.overflow.text = "+%d" % (total - shown) if index == shown - 1 and total > shown else ""

	visible = shown > 0
	if visible:
		size = Vector2(shown * TILE_SIZE + (shown - 1) * TILE_GAP, TILE_SIZE)
		_place_next_to_hotbar()


func _show_pending(tile: Tile, pending: Dictionary[InventoryItem, int]) -> void:
	var results := PackedStringArray()
	for item in pending:
		results.append("%s ×%d" % [item.title, pending[item]])
	var first: InventoryItem = pending.keys()[0]
	tile.item_icon.texture = _texture_lookup.call(first.icon_id) as Texture2D
	tile.meter.value = 1.0
	tile.tooltip_text = "Aguardando espaço na bolsa\n" + "\n".join(results)


func _show_order(tile: Tile, order: CraftingQueue.Order) -> void:
	tile.order = order
	var item := _items.find(order.product()) as InventoryItem
	tile.item_icon.texture = _texture_lookup.call(item.icon_id) as Texture2D
	tile.tooltip_text = "%s ×%d\nEnter cancela" % [item.title, order.remaining_quantity()]
	tile.meter.value = order.progress()
	if _queue.is_running() and order == _queue.active_order():
		_progress_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		_progress_tween.tween_property(tile.meter, "value", 1.0, order.seconds_left())


func _place_next_to_hotbar() -> void:
	var left := _hotbar.position.x - size.x - 6.0
	var center_y := _hotbar.position.y + (_hotbar.size.y - size.y) * 0.5
	if left < 4.0:
		position = Vector2(maxf(4.0, _hotbar.position.x), _hotbar.position.y - size.y - 4.0).floor()
	else:
		position = Vector2(left, center_y).floor()


func _cancel(tile: Tile) -> void:
	if tile.order != null:
		_queue.cancel(tile.order)
