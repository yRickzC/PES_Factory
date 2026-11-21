@tool
extends PopupPanel
## Presents registered component types supplied by the caller.

signal component_chosen(id: StringName)

@onready var _search: LineEdit = %Search
@onready var _results: Tree = %Results
@onready var _empty: Label = %Empty

var _groups: Dictionary[String, TreeItem] = {}
var _row_search: Dictionary[TreeItem, String] = {}
var _first_result: TreeItem


func _ready() -> void:
	_search.text_changed.connect(_filter)
	_search.text_submitted.connect(func(_text: String) -> void: _choose(_first_result))
	_search.gui_input.connect(_search_input)
	_results.item_mouse_selected.connect(_on_item_clicked)
	_results.item_activated.connect(func() -> void: _choose(_results.get_selected()))


func set_types(types: Dictionary[StringName, ContentComponentType]) -> void:
	_groups.clear()
	_row_search.clear()
	_results.clear()
	var root := _results.create_item()
	var ids := types.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		var left := types[a]
		var right := types[b]
		var category_order := left.category.naturalnocasecmp_to(right.category)
		if category_order != 0:
			return category_order < 0
		var name_order := left.display_name.naturalnocasecmp_to(right.display_name)
		return name_order < 0 if name_order != 0 else String(a) < String(b)
	)
	for id in ids:
		var entry := types[id]
		var group := _groups.get(entry.category) as TreeItem
		if group == null:
			group = _results.create_item(root)
			group.set_text(0, entry.category)
			group.set_selectable(0, false)
			_groups[entry.category] = group
		var item := _results.create_item(group)
		item.set_text(0, entry.display_name)
		item.set_metadata(0, id)
		item.set_tooltip_text(0, "%s · %s\n%s\n%s" % [entry.display_name, id, entry.description, entry.purpose])
		if entry.icon != null:
			item.set_icon(0, entry.icon)
			item.set_icon_max_width(0, 20)
		_row_search[item] = _search_text("%s %s %s %s %s" % [
			entry.display_name, entry.category, entry.description, entry.purpose, id,
		])
	_filter(_search.text)


func open_picker() -> void:
	if not _search.text.is_empty():
		_search.clear()
		_filter("")
	_results.deselect_all()
	popup_centered(Vector2i(480, 414))
	_search.grab_focus()


func _filter(query: String) -> void:
	var terms := _search_text(query).split(" ", false)
	_first_result = null
	for group: TreeItem in _groups.values():
		var group_has_matches := false
		for item in group.get_children():
			var matches := _matches(_row_search[item], terms)
			item.visible = matches
			if matches and _first_result == null:
				_first_result = item
			group_has_matches = group_has_matches or matches
		group.visible = group_has_matches
		if group_has_matches:
			group.collapsed = false
	_empty.visible = _first_result == null


static func _search_text(value: String) -> String:
	return TextServerManager.get_primary_interface().strip_diacritics(value.to_lower())


static func _matches(haystack: String, terms: PackedStringArray) -> bool:
	for term in terms:
		if term not in haystack:
			return false
	return true


func _search_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_down") and _first_result != null:
		_results.grab_focus()
		_first_result.select(0)
		_results.scroll_to_item(_first_result)
		_search.accept_event()


func _on_item_clicked(click_position: Vector2, button: int) -> void:
	if button == MOUSE_BUTTON_LEFT:
		_choose(_results.get_item_at_position(click_position))


func _choose(item: TreeItem) -> void:
	if not visible or item == null or not item.is_selectable(0):
		return
	var id: StringName = item.get_metadata(0)
	hide()
	component_chosen.emit(id)
