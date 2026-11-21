extends VBoxContainer
## Lista as ações registradas e encaminha mudanças à camada de preferências.

const Preferences = preload("res://addons/ldk/core/Settings/game_preferences.gd")

signal back_requested

var _search := LineEdit.new()
var _tabs := TabContainer.new()
var _status := Label.new()
var _groups: Dictionary[StringName, Array] = {}
var _rows: Dictionary[StringName, HBoxContainer] = {}
var _buttons: Dictionary[StringName, Button] = {}
var _empty: Array[Label] = []
var _capture: StringName
var _modifier: InputEventKey


func _ready() -> void:
	custom_minimum_size = Vector2(472, 284)
	add_theme_constant_override(&"separation", 5)
	var title := Label.new()
	title.text = "Controles"
	title.add_theme_font_size_override(&"font_size", 17)
	add_child(title)
	_search.placeholder_text = "Pesquisar ação"
	_search.clear_button_enabled = true
	_search.text_changed.connect(_filter)
	add_child(_search)
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.clip_tabs = true
	add_child(_tabs)
	_tabs.get_tab_bar().focus_mode = Control.FOCUS_ALL
	_status.custom_minimum_size.y = 20
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_status)
	var back := Button.new()
	back.text = "Voltar"
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	back.pressed.connect(back_requested.emit)
	add_child(back)
	Preferences.current.bindings_changed.connect(_sync)
	_sync()


func open() -> void:
	show()
	_status.text = ""
	_search.grab_focus()


func is_capturing() -> bool:
	return not _capture.is_empty()


func capture_input(event: InputEvent) -> void:
	if Preferences.current.fallback_pressed(event):
		_finish_capture("Captura cancelada.")
		return
	if event is InputEventMouseButton and event.pressed:
		_change_binding(event)
		return
	if not event is InputEventKey or event.is_echo():
		return
	if event.physical_keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
		if event.pressed:
			_modifier = Preferences.normalize(event) as InputEventKey
			return
		if _modifier != null and _modifier.physical_keycode == event.physical_keycode:
			_change_binding(_modifier)
	elif event.is_pressed():
		_change_binding(event)


func _change_binding(event: InputEvent) -> void:
	var result: String = Preferences.current.set_binding(_capture, event)
	_finish_capture("Atalho atualizado." if result.is_empty() else result)


func _start_capture(id: StringName) -> void:
	_capture = id
	_modifier = null
	_status.text = "Pressione uma tecla ou botão do mouse. Esc cancela."
	_refresh_bindings()


func _finish_capture(message: String) -> void:
	_capture = &""
	_modifier = null
	_status.text = message
	_refresh_bindings()


func _reset(ids: Array) -> void:
	var result: String = Preferences.current.restore_defaults(ids)
	_status.text = "Padrões restaurados." if result.is_empty() else result


func _sync() -> void:
	if _rows.size() != Preferences.current.actions.size():
		_rebuild()
	_refresh_bindings()


func _rebuild() -> void:
	for child in _tabs.get_children():
		_tabs.remove_child(child)
		child.queue_free()
	_groups.clear()
	_rows.clear()
	_buttons.clear()
	_empty.clear()
	for id in Preferences.current.actions:
		var action = Preferences.current.actions[id]
		var category := ContentRegistry.normalize_id(action.category)
		if not _groups.has(category):
			_groups[category] = []
		_groups[category].append(id)
	for category in _groups:
		_add_category(_groups[category])
	_filter(_search.text)


func _add_category(ids: Array) -> void:
	var page := VBoxContainer.new()
	page.add_theme_constant_override(&"separation", 4)
	_tabs.add_child(page)
	var definition = Preferences.current.actions[ids[0]]
	_tabs.set_tab_title(_tabs.get_tab_count() - 1,
		definition.category_title if not definition.category_title.is_empty() else definition.category)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	page.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for id: StringName in ids:
		_add_action(list, id)
	var empty := Label.new()
	empty.text = "Nenhuma ação nesta categoria."
	list.add_child(empty)
	_empty.append(empty)
	var restore := Button.new()
	restore.text = "Restaurar categoria"
	restore.size_flags_horizontal = Control.SIZE_SHRINK_END
	restore.pressed.connect(_reset.bind(ids))
	page.add_child(restore)


func _add_action(list: VBoxContainer, id: StringName) -> void:
	var row := HBoxContainer.new()
	list.add_child(row)
	var title := Label.new()
	title.text = Preferences.current.actions[id].title
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(title)
	var binding := Button.new()
	binding.custom_minimum_size = Vector2(136, 20)
	binding.clip_text = true
	binding.pressed.connect(_start_capture.bind(id))
	row.add_child(binding)
	var restore := Button.new()
	restore.text = "Restaurar"
	restore.pressed.connect(_reset.bind([id]))
	row.add_child(restore)
	_rows[id] = row
	_buttons[id] = binding


func _refresh_bindings() -> void:
	for id in _buttons:
		var label: String = Preferences.current.binding_label(id)
		_buttons[id].text = "Aguardando…" if id == _capture else label
		_buttons[id].tooltip_text = label


func _filter(query: String) -> void:
	var needle := query.strip_edges().to_lower()
	var selected_has_matches := false
	var first_match := -1
	var index := 0
	for ids: Array in _groups.values():
		var has_matches := false
		for id: StringName in ids:
			var definition = Preferences.current.actions[id]
			var matches := needle.is_empty() or needle in ("%s %s %s" % [
				definition.title, id, definition.category_title,
			]).to_lower()
			_rows[id].visible = matches
			has_matches = has_matches or matches
		_empty[index].visible = not has_matches
		if has_matches:
			if first_match == -1:
				first_match = index
			if index == _tabs.current_tab:
				selected_has_matches = true
		index += 1
	if not selected_has_matches and first_match != -1:
		_tabs.current_tab = first_match
