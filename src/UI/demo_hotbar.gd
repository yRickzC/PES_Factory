extends PanelContainer

const Preferences = preload("res://addons/ldk/core/Settings/game_preferences.gd")

const Config = preload("res://src/UI/hotbar_config.gd")
const Hotbar = preload("res://addons/ldk/core/Inventory/slot_hotbar.gd")
const SlotButton = preload("res://src/UI/inventory_slot_button.gd")

signal slot_activated(slot: int)
signal slot_focused(slot: int)

var _selection: Hotbar
var _texture_lookup: Callable
var _buttons: Array[SlotButton] = []


func configure(inventory: SlotInventory, selection: Hotbar, config: Config, texture_lookup: Callable) -> void:
	_selection = selection
	_texture_lookup = texture_lookup
	visible = selection.size() > 0
	theme = config.theme
	if config.panel_style != null:
		add_theme_stylebox_override(&"panel", config.panel_style)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_top = -config.bottom_margin
	offset_bottom = -config.bottom_margin
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", config.spacing)
	add_child(row)
	for slot in selection.size():
		var button := SlotButton.new()
		button.custom_minimum_size = config.slot_size
		button.focus_mode = Control.FOCUS_NONE
		row.add_child(button)
		button.configure(inventory, slot, config.icon_size, config.font_size)
		button.pressed.connect(_select.bind(slot))
		button.focus_entered.connect(slot_focused.emit.bind(slot))
		_buttons.append(button)
	inventory.changed.connect(_refresh_items)
	selection.selection_changed.connect(_refresh_selection)
	_refresh_items()
	_refresh_selection()


func set_inventory_open(open: bool) -> void:
	for button in _buttons:
		button.focus_mode = Control.FOCUS_ALL if open else Control.FOCUS_NONE


func handle_shortcut(event: InputEvent) -> bool:
	if _selection.size() == 0:
		return false
	if Preferences.current.pressed(event, &"core:hotbar_previous"):
		_selection.cycle(-1)
		return true
	if Preferences.current.pressed(event, &"core:hotbar_next"):
		_selection.cycle(1)
		return true
	for slot in _selection.size():
		if Preferences.current.pressed(event, _slot_action(slot)):
			_selection.select(slot)
			return true
	return false


func _slot_action(slot: int) -> StringName:
	return StringName("core:hotbar_%d" % (slot + 1))


func _select(slot: int) -> void:
	_selection.select(slot)
	_buttons[slot].set_pressed_no_signal(true)
	slot_activated.emit(slot)


func _refresh_items() -> void:
	for button in _buttons:
		button.display(_texture_lookup)


func _refresh_selection() -> void:
	for slot in _buttons.size():
		_buttons[slot].set_pressed_no_signal(slot == _selection.active_slot())
