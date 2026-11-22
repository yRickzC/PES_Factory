extends Button

var _inventory: SlotInventory
var _slot: int
var _icon := TextureRect.new()
var _count := Label.new()


func configure(inventory: SlotInventory, slot: int, icon_size: Vector2, count_font_size: int) -> void:
	_inventory = inventory
	_slot = slot
	toggle_mode = true
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_icon)
	_icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_icon.offset_left = -icon_size.x * 0.5
	_icon.offset_right = icon_size.x * 0.5
	_icon.offset_top = -icon_size.y * 0.5 - 2.0
	_icon.offset_bottom = icon_size.y * 0.5 - 2.0
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_count.add_theme_font_size_override(&"font_size", count_font_size)
	add_child(_count)
	_count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_count.offset_right = -4
	_count.offset_bottom = -2


func display(texture_lookup: Callable) -> void:
	var item := _inventory.item_at(_slot)
	tooltip_text = item.title if item != null else ""
	_icon.texture = texture_lookup.call(item.icon_id) if item != null else null
	_count.text = str(_inventory.count_at(_slot)) if item != null and item.stack_limit > 1 else ""


func _get_drag_data(_at: Vector2) -> Variant:
	var item := _inventory.item_at(_slot)
	if item == null:
		return null
	if _icon.texture != null:
		var preview := TextureRect.new()
		preview.texture = _icon.texture
		preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		preview.expand_mode = _icon.expand_mode
		preview.stretch_mode = _icon.stretch_mode
		preview.size = _icon.size
		set_drag_preview(preview)
	else:
		var preview := Label.new()
		preview.text = item.title
		set_drag_preview(preview)
	return {"inventory": _inventory, "slot": _slot, "item": item}


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	if not data is Dictionary or data.get("inventory") != _inventory or not data.get("slot") is int:
		return false
	var source: int = data["slot"]
	var item := _inventory.item_at(source)
	if source == _slot or item == null or item != data.get("item"):
		return false
	var destination := _inventory.item_at(_slot)
	return destination == null or (destination.id == item.id and _inventory.count_at(_slot) < destination.stack_limit)


func _drop_data(at: Vector2, data: Variant) -> void:
	if _can_drop_data(at, data):
		_inventory.move(data["slot"], _slot)
