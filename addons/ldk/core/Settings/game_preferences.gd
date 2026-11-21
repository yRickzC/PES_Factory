class_name GamePreferencesService
extends Node
## Owns player preferences and applies authored input defaults to InputMap.

const Settings = preload("res://addons/ldk/core/Settings/game_settings.gd")
const Action = preload("res://addons/ldk/core/Settings/game_action_definition.gd")
const STORAGE := "user://game_settings.cfg"
const OPTION_KEYS := [&"master_volume", &"fullscreen", &"vsync", &"placement_preview"]

signal bindings_changed
signal options_changed

static var current: GamePreferencesService

## Resource com os padrões usados quando o jogador não configurou preferências.
@export var defaults: Settings

var actions: Dictionary[StringName, Action] = {}
var _bindings: Dictionary[StringName, InputEvent] = {}
var _saved_bindings := {}
var _options := {}
var _fallback: InputEvent


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


func _ready() -> void:
	var config := ConfigFile.new()
	var error := config.load(STORAGE)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		push_warning("Não foi possível ler as preferências: %s" % error_string(error))
	for key in OPTION_KEYS:
		var authored: Variant = defaults.get(key)
		var value: Variant = config.get_value("options", key, authored)
		_options[key] = value if typeof(value) == typeof(authored) else authored
	_options[&"master_volume"] = clampf(_options[&"master_volume"], 0.0, 1.0)
	_fallback = normalize(defaults.protected_binding)
	if config.has_section("controls"):
		for key in config.get_section_keys("controls"):
			_saved_bindings[StringName(key)] = config.get_value("controls", key)
	register_actions(defaults.actions)
	_apply_options()


func register_actions(definitions: Array) -> void:
	var added: Array[StringName] = []
	for definition: Action in definitions:
		if definition == null or definition.category.is_empty():
			continue
		var id := ContentRegistry.normalize_id(definition.id)
		if ContentRegistry.namespace_of(id).is_empty() or actions.has(id):
			continue
		actions[id] = definition
		added.append(id)
	if not added.is_empty():
		# Re-evaluate saved overrides together so swapped keys can round-trip.
		_load_bindings()
		bindings_changed.emit()


func register_content(registry: ContentRegistry) -> void:
	var definitions: Array[Action] = []
	for id in registry.ids():
		definitions.append(registry.find(id) as Action)
	register_actions(definitions)


func binding_label(id: StringName) -> String:
	var binding := binding_for(id)
	if binding == null:
		return _fallback.as_text().replace(" (Physical)", "") if id == defaults.protected_action and _fallback != null else "Sem atalho"
	var label := binding.as_text().replace(" (Physical)", "")
	if id == defaults.protected_action and _fallback != null and _token(binding) != _token(_fallback):
		label += " / " + _fallback.as_text().replace(" (Physical)", "")
	return label


func binding_for(id: StringName) -> InputEvent:
	return _bindings.get(id)


func pressed(event: InputEvent, action: StringName) -> bool:
	return event.is_pressed() and not event.is_echo() and InputMap.has_action(action) and (
		event.is_action_pressed(action, false, true) or
		(_code(event) in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META] and
			binding_for(action) != null and _token(event) == _token(binding_for(action))
		)
	)


func pressed_with_held_modifiers(event: InputEvent, action: StringName, held_actions: Array[StringName]) -> bool:
	if pressed(event, action):
		return true
	if not event.is_pressed() or event.is_echo():
		return false
	var actual := _token(event)
	var binding := _token(binding_for(action))
	var matches_binding := actual.x == binding.x and (actual.y & binding.y) == binding.y
	if not matches_binding and action == defaults.protected_action:
		binding = _token(_fallback)
	if actual.x == 0 or actual.x != binding.x or (actual.y & binding.y) != binding.y:
		return false
	var extra := actual.y & ~binding.y
	if extra == 0:
		return false
	var allowed := 0
	for held_action in held_actions:
		if not held(held_action):
			continue
		var held_binding := _token(binding_for(held_action))
		allowed |= held_binding.y
		match held_binding.x:
			KEY_SHIFT: allowed |= 1
			KEY_CTRL: allowed |= 2
			KEY_ALT: allowed |= 4
			KEY_META: allowed |= 8
	if (extra & ~allowed) != 0:
		return false
	# An explicitly assigned chord takes precedence over a shortcut with extra modifiers.
	for other in _bindings:
		if other != action and _token(_bindings[other]) == actual:
			return false
	return true


func fallback_pressed(event: InputEvent) -> bool:
	return _fallback != null and event.is_pressed() and not event.is_echo() and _token(event) == _token(_fallback)


func released(event: InputEvent, action: StringName) -> bool:
	if event.is_pressed() or not (event is InputEventKey or event is InputEventMouseButton):
		return false
	# A held click/keypress may be released after the modifiers are lifted.
	var binding := binding_for(action)
	return binding != null and _code(event) == _code(binding)


func held(action: StringName) -> bool:
	var event := binding_for(action)
	if event == null:
		return false
	if event is InputEventWithModifiers:
		if (event.shift_pressed and not Input.is_key_pressed(KEY_SHIFT)) or \
				(event.ctrl_pressed and not Input.is_key_pressed(KEY_CTRL)) or \
				(event.alt_pressed and not Input.is_key_pressed(KEY_ALT)) or \
				(event.meta_pressed and not Input.is_key_pressed(KEY_META)):
			return false
	if event is InputEventKey:
		return Input.is_physical_key_pressed(event.physical_keycode)
	return event is InputEventMouseButton and Input.is_mouse_button_pressed(event.button_index)


func set_binding(id: StringName, event: InputEvent) -> String:
	var binding := normalize(event)
	if not _usable(id, binding):
		return "Escolha uma tecla ou botão válido para esta ação."
	var proposed := _bindings.duplicate()
	proposed[id] = binding
	var conflict := _conflict(id, proposed)
	if not conflict.is_empty():
		return "Atalho em uso por %s." % actions[conflict].title
	return _commit_bindings(proposed, [id])


func restore_defaults(ids: Array) -> String:
	var proposed := _bindings.duplicate()
	for id: StringName in ids:
		var binding := normalize(actions[id].binding)
		proposed[id] = binding if _usable(id, binding) else null
	for id: StringName in ids:
		var conflict := _conflict(id, proposed)
		if not conflict.is_empty():
			return "O padrão de %s está em uso por %s." % [actions[id].title, actions[conflict].title]
	return _commit_bindings(proposed, ids)


func option(key: StringName) -> Variant:
	return _options[key]


func set_option(key: StringName, value: Variant) -> Error:
	if key not in OPTION_KEYS or typeof(value) != typeof(defaults.get(key)):
		return ERR_INVALID_PARAMETER
	var previous: Variant = _options[key]
	_options[key] = value
	var result := _save()
	if result != OK:
		_options[key] = previous
		return result
	_apply_options()
	options_changed.emit()
	return OK


func _load_bindings() -> void:
	_bindings.clear()
	for id in actions:
		var binding := normalize(actions[id].binding)
		_bindings[id] = binding if _usable(id, binding) else null
		if not _conflict(id, _bindings).is_empty():
			_bindings[id] = null
	var baseline := _bindings.duplicate()
	for id in actions:
		var override := _from_token(_saved_bindings.get(id, Vector2i.ZERO))
		if _usable(id, override):
			_bindings[id] = override
	# Discard overrides that have become ambiguous after content changes.
	var repeat := true
	while repeat:
		repeat = false
		for id in actions:
			if _token(_bindings[id]) != _token(baseline[id]) and not _conflict(id, _bindings).is_empty():
				_bindings[id] = baseline[id]
				repeat = true
	for id in actions:
		_apply_binding(id)


func _usable(id: StringName, binding: InputEvent) -> bool:
	if not actions.has(id) or binding == null:
		return false
	return not (actions[id].continuous and binding is InputEventMouseButton and binding.button_index in [4, 5, 6, 7])


func _conflict(id: StringName, bindings: Dictionary) -> StringName:
	var binding: InputEvent = bindings[id]
	if binding == null:
		return &""
	if _is_reserved(id, binding):
		return defaults.protected_action
	var token := _token(binding)
	for other: StringName in bindings:
		if id == other:
			continue
		var candidate := _token(bindings[other])
		if token.x != candidate.x:
			continue
		var shared := token.y & candidate.y
		if token.y == candidate.y or (actions[id].continuous and shared == token.y) or (
			actions[other].continuous and shared == candidate.y
		):
			return other
	return &""


func _is_reserved(id: StringName, binding: InputEvent) -> bool:
	if id == defaults.protected_action or _fallback == null:
		return false
	var token := _token(binding)
	var reserved := _token(_fallback)
	return token.x == reserved.x and (token.y == reserved.y or (
		actions[id].continuous and token.y == (token.y & reserved.y)
	))


func _commit_bindings(proposed: Dictionary, ids: Array) -> String:
	var previous := _saved_bindings.duplicate()
	for id: StringName in ids:
		var token := _token(proposed[id])
		if token == _token(normalize(actions[id].binding)):
			_saved_bindings.erase(id)
		else:
			_saved_bindings[id] = token
	var error := _save()
	if error != OK:
		_saved_bindings = previous
		return "Não foi possível salvar os controles."
	_bindings.assign(proposed)
	for id: StringName in ids:
		_apply_binding(id)
	bindings_changed.emit()
	return ""


func _apply_binding(id: StringName) -> void:
	if not InputMap.has_action(id):
		InputMap.add_action(id)
	Input.action_release(id)
	InputMap.action_erase_events(id)
	var binding := binding_for(id)
	if binding != null:
		InputMap.action_add_event(id, binding)
	if id == defaults.protected_action and _fallback != null and _token(binding) != _token(_fallback):
		InputMap.action_add_event(id, _fallback)


func _apply_options() -> void:
	var volume := float(_options[&"master_volume"])
	AudioServer.set_bus_mute(0, volume <= 0.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, volume)))
	if DisplayServer.get_name() != "headless":
		var is_fullscreen := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
		if is_fullscreen != _options[&"fullscreen"]:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if _options[&"fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED)
		var vsync := DisplayServer.VSYNC_ENABLED if _options[&"vsync"] else DisplayServer.VSYNC_DISABLED
		if DisplayServer.window_get_vsync_mode() != vsync:
			DisplayServer.window_set_vsync_mode(vsync)


func _save() -> Error:
	var config := ConfigFile.new()
	for key: StringName in _options:
		config.set_value("options", key, _options[key])
	for id: StringName in _saved_bindings:
		config.set_value("controls", id, _saved_bindings[id])
	var temporary := STORAGE + ".tmp"
	var error := config.save(temporary)
	return DirAccess.rename_absolute(temporary, STORAGE) if error == OK else error


static func normalize(original: InputEvent) -> InputEvent:
	return _from_token(_token(original))


static func _code(event: InputEvent) -> int:
	if event is InputEventKey:
		return event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	return -event.button_index if event is InputEventMouseButton else 0


static func _token(event: InputEvent) -> Vector2i:
	if not event is InputEventWithModifiers:
		return Vector2i.ZERO
	var code := _code(event)
	var bits := int(event.shift_pressed and code != KEY_SHIFT)
	bits |= int(event.ctrl_pressed and code != KEY_CTRL) << 1
	bits |= int(event.alt_pressed and code != KEY_ALT) << 2
	bits |= int(event.meta_pressed and code != KEY_META) << 3
	return Vector2i(code, bits)


static func _from_token(value: Variant) -> InputEvent:
	if not value is Vector2i or value.x == 0 or value.x < -MOUSE_BUTTON_XBUTTON2 or value.y < 0 or value.y > 15:
		return null
	var event: InputEventWithModifiers
	if value.x < 0:
		var button := InputEventMouseButton.new()
		button.button_index = -value.x as MouseButton
		event = button
	else:
		var key := InputEventKey.new()
		key.physical_keycode = value.x as Key
		event = key
	event.shift_pressed = (value.y & 1) != 0
	event.ctrl_pressed = (value.y & 2) != 0
	event.alt_pressed = (value.y & 4) != 0
	event.meta_pressed = (value.y & 8) != 0
	return event
