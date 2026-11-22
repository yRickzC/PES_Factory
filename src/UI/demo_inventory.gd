class_name DemoInventoryView
extends CanvasLayer

const Preferences = preload("res://addons/ldk/core/Settings/game_preferences.gd")

const Hotbar = preload("res://addons/ldk/core/Inventory/slot_hotbar.gd")
const HotbarConfig = preload("res://src/UI/hotbar_config.gd")
const HotbarView = preload("res://src/UI/demo_hotbar.gd")
const SlotButton = preload("res://src/UI/inventory_slot_button.gd")
const CraftingQueue = preload("res://addons/ldk/core/Crafting/crafting_queue.gd")
const CraftingView = preload("res://src/UI/demo_crafting.gd")
const CraftingQueueView = preload("res://src/UI/crafting_queue_view.gd")

signal open_changed(open: bool)

var _texture: Callable
var _inventory: SlotInventory
var _active_slot: int
var _focused_slot := -1
var _source_slot := -1
var _buttons: Array[SlotButton] = []
var _hotbar: Hotbar
var _hotbar_view: HotbarView

@onready var _dialog: ColorRect = %Dialog
@onready var _slots: GridContainer = %Slots
@onready var _slot_hint: Label = %SlotHint
@onready var _close_button: Button = %Close
@onready var _crafting: CraftingView = %Crafting
@onready var _crafting_queue: CraftingQueueView = %CraftingQueue


func _ready() -> void:
	_close_button.pressed.connect(_toggle)


func configure(inventory: SlotInventory, texture_lookup: Callable, hotbar: Hotbar, config: HotbarConfig) -> void:
	_inventory = inventory
	_texture = texture_lookup
	_hotbar = hotbar
	_active_slot = hotbar.size()
	for slot in range(hotbar.size(), _inventory.size()):
		_create_slot(slot)
	_hotbar_view = HotbarView.new()
	_hotbar_view.name = "Hotbar"
	$Screen.add_child(_hotbar_view)
	_hotbar_view.configure(inventory, hotbar, config, texture_lookup)
	_hotbar_view.slot_activated.connect(_activate_slot)
	_hotbar_view.slot_focused.connect(_focus_slot)
	_inventory.changed.connect(_refresh)
	_refresh()


func configure_crafting(queue: CraftingQueue, items: ContentRegistry, tags: ContentRegistry) -> void:
	_crafting.configure(queue, _inventory, items, tags, _texture)
	_crafting_queue.configure(queue, items, _texture, _hotbar_view)


func is_open() -> bool:
	return _dialog.visible


func active_slot() -> int:
	return _active_slot


func handle_hotbar_shortcut(event: InputEvent) -> bool:
	return _hotbar_view != null and _hotbar_view.handle_shortcut(event)


func _input(event: InputEvent) -> void:
	if _inventory != null and Preferences.current.pressed(event, &"core:inventory"):
		_toggle()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN and _source_slot >= 0:
		_source_slot = -1
		_refresh_hint()


func _toggle() -> void:
	_dialog.visible = not _dialog.visible
	var open := is_open()
	_source_slot = -1
	_focused_slot = -1
	_hotbar_view.set_inventory_open(open)
	_crafting_queue.set_inventory_open(open)
	if open:
		if _buttons.is_empty():
			_close_button.grab_focus()
		else:
			var index := clampi(_active_slot - _hotbar.size(), 0, _buttons.size() - 1)
			_buttons[index].grab_focus()
	_refresh()
	open_changed.emit(open)


func _create_slot(slot: int) -> void:
	var button := SlotButton.new()
	button.custom_minimum_size = Vector2(38, 38)
	_slots.add_child(button)
	button.configure(_inventory, slot, Vector2(24, 24), 10)
	button.pressed.connect(_activate_slot.bind(slot))
	button.focus_entered.connect(_focus_slot.bind(slot))
	_buttons.append(button)


func _activate_slot(slot: int) -> void:
	if _source_slot >= 0 and _source_slot != slot:
		var source := _source_slot
		_source_slot = -1
		if _inventory.move(source, slot) > 0:
			_active_slot = slot
	else:
		_active_slot = slot
		_source_slot = slot if _inventory.item_at(slot) != null and _source_slot == -1 else -1
	_refresh()


func _focus_slot(slot: int) -> void:
	_focused_slot = slot
	_refresh_hint()


func _refresh() -> void:
	if _inventory == null:
		return
	for index in _buttons.size():
		_buttons[index].set_pressed_no_signal(index + _hotbar.size() == _active_slot)
		_buttons[index].display(_texture)
	_refresh_hint()


func _refresh_hint() -> void:
	var source := _inventory.item_at(_source_slot)
	if source != null:
		_slot_hint.text = "Mover %s · Enter no destino" % source.title
		return
	var item := _inventory.item_at(_focused_slot)
	_slot_hint.text = "%s · Enter seleciona" % item.title if item != null else "Tab ou setas para escolher um slot"
