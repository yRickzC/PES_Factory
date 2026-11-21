@tool
extends VBoxContainer
## Adapts VoxelBlock properties and dependencies to the reusable graph surface.

const Document := preload("res://addons/ldk/core/UI/editor/block_graph_document.gd")
const Canvas := preload("res://addons/ldk/core/UI/editor/resource_graph_canvas.gd")
const EditorContext := preload("res://addons/ldk/core/UI/editor/content_editor_context.gd")
const ComponentPicker := preload("res://addons/ldk/core/UI/editor/component_picker.gd")
const COLORS: Array[Color] = [
	Color("#71cdb6"), Color("#88aef5"), Color("#f5bb75"),
	Color("#c5a6f7"), Color("#9baabb"), Color("#eb99ab"),
]
const STARTS := {
	&"geometry": Vector2(32, 32), &"collision": Vector2(330, 32),
	&"drops": Vector2(32, 380), &"breakable": Vector2(330, 380),
	&"occlusion": Vector2(32, 600), &"behavior": Vector2(330, 600),
	Document.ROOT: Vector2(630, 100),
}
const FIELD_TITLES := {
	&"cube": "Cubo inteiro", &"face_tiles": "Faces (+X, −X, +Y, −Y, +Z, −Z)",
	&"model": "Modelo", &"connection_arm": "Modelo da extensão",
	&"material_slot": "Camada (0 opaca, 1 transparente)",
	&"full_sides": "Faces completas", &"merge_group": "Grupo de mesclagem",
	&"seconds": "Tempo de quebra (s)", &"items": "Drops (ID=quantidade)",
}
const SIDES: Array[String] = ["+X", "−X", "+Y", "−Y", "+Z", "−Z"]

@onready var _canvas: Canvas = %Canvas
@onready var _block_id: Label = %BlockID
@onready var _add: Button = %Add
@onready var _component_picker: ComponentPicker = %ComponentPicker
@onready var _undo: Button = %Undo
@onready var _redo: Button = %Redo
@onready var _duplicate: Button = %Duplicate
@onready var _delete: Button = %Delete
@onready var _status: Label = %Status

var _documents: Dictionary[String, Document] = {}
var _document: Document
var _context: EditorContext
var _revision := -1
var _loaded_database: ContentDB
var _rendered: Dictionary[StringName, Variant] = {}
var _views: Dictionary[String, Vector3] = {}
var _types: Dictionary[StringName, ContentComponentType] = {}
var _types_by_script: Dictionary[Script, ContentComponentType] = {}
var _texture_ids: Array[StringName] = []


func _ready() -> void:
	_add.pressed.connect(_component_picker.open_picker)
	_component_picker.component_chosen.connect(_add_component)
	_canvas.resource_dropped.connect(func(value: Resource, position: Vector2) -> void:
		_finish(_document.add_component(value, position))
	)
	_canvas.connection_request.connect(_wire.bind(true))
	_canvas.disconnection_request.connect(_wire.bind(false))
	_canvas.delete_nodes_request.connect(_delete_nodes)
	_canvas.duplicate_nodes_request.connect(_duplicate_nodes)
	_canvas.end_node_move.connect(_move_nodes)
	_canvas.node_selected.connect(_update_selection_actions.unbind(1))
	_canvas.node_deselected.connect(_update_selection_actions.unbind(1))
	_canvas.undo_requested.connect(_run_undo)
	_canvas.redo_requested.connect(_run_redo)
	_undo.pressed.connect(_run_undo)
	_redo.pressed.connect(_run_redo)
	_duplicate.pressed.connect(_duplicate_nodes)
	_delete.pressed.connect(func() -> void: _delete_nodes(_canvas.selected_ids()))
	theme_changed.connect(_update_icons)
	_update_icons()


func set_context(context: EditorContext) -> void:
	if context == _context and context.revision == _revision:
		return
	clear()
	_context = context
	_revision = context.revision
	_documents.clear()
	_views.clear()
	if _loaded_database != context.database:
		_load_component_types(context.database)


func _load_component_types(database: ContentDB) -> void:
	_loaded_database = database
	_types.clear()
	_types_by_script.clear()
	_texture_ids.clear()
	if database != null:
		var registered := database.component_types(&"block")
		for id in registered:
			var entry := registered[id]
			var script := entry.prototype.get_script() as Script
			if Document.kind_of(entry.prototype).is_empty() or (script != null and not script.is_tool()):
				continue
			_types[id] = entry
			if script != null and not _types_by_script.has(script):
				_types_by_script[script] = entry
		_texture_ids = database.textures.ids()
		_texture_ids.sort()
	_component_picker.set_types(_types)


func show_block(block: VoxelBlock, path: String) -> void:
	if _document != null and _document.path == path and _document.block == block:
		return
	clear()
	if not _documents.has(path) or _documents[path].block != block:
		_documents[path] = Document.new(block, path, _context.id)
	_document = _documents[path]
	var id := ContentRegistry.normalize_id(block.key)
	_block_id.text = String(id) if not id.is_empty() else path.get_file().get_basename()
	_block_id.tooltip_text = path
	_finish("")
	var view: Vector3 = _views.get(path, Vector3(0, 0, 0.75))
	_canvas.zoom = view.z
	_canvas.set_deferred("scroll_offset", Vector2(view.x, view.y))


func clear() -> void:
	_component_picker.hide()
	if _document == null:
		return
	_views[_document.path] = Vector3(_canvas.scroll_offset.x, _canvas.scroll_offset.y, _canvas.zoom)
	_canvas.clear_connections()
	for id in _canvas.nodes.keys():
		_canvas.remove_graph_node(id)
	_rendered.clear()
	_document = null


func _move_nodes() -> void:
	var positions: Dictionary[StringName, Vector2] = {}
	for id in _canvas.nodes:
		positions[id] = _canvas.nodes[id].position_offset
	var before := _document.state
	_complete_layout_edit(_document.move_nodes(positions), before)


func _duplicate_nodes() -> void:
	_finish(_document.duplicate_components(_canvas.selected_ids()))


func _delete_nodes(ids: Array[StringName]) -> void:
	var before := _document.state
	_complete_layout_edit(_document.remove_components(ids), before)


func _add_component(type_id: StringName) -> void:
	var entry := _types.get(type_id) as ContentComponentType
	if _document == null or entry == null:
		return
	var resource := entry.new_component()
	if resource == null:
		_finish("Não foi possível criar %s com os valores padrão." % entry.display_name)
		return
	var offset := Vector2.ONE * (_document.state.nodes.size() % 7) * 24.0
	var position := _canvas.graph_position(_canvas.size * Vector2(0.25, 0.25)) + offset
	_finish(_document.add_component(resource, position, type_id))


func _wire(from: StringName, out_port: int, target: StringName, in_port: int, attach: bool) -> void:
	var before := _document.state
	_complete_layout_edit(_document.wire(from, out_port, target, in_port, attach), before)


func _run_undo() -> void:
	if _document != null:
		var before := _document.state
		_complete_layout_edit(_document.undo(), before)


func _run_redo() -> void:
	if _document != null:
		var before := _document.state
		_complete_layout_edit(_document.redo(), before)


func _complete_layout_edit(issue: String, before: Document.State) -> void:
	if issue.is_empty() and (before.positions != _document.state.positions or before.bindings != _document.state.bindings):
		issue = _document.save_layout()
	_finish(issue)


func _finish(issue: String) -> void:
	_render()
	if issue.is_empty():
		issue = _document.warning(_context.database)
	_status.text = issue
	_status.visible = not issue.is_empty()
	_undo.disabled = not _document.can_undo()
	_redo.disabled = not _document.can_redo()
	_update_selection_actions()


func _update_selection_actions() -> void:
	var ids := _canvas.selected_ids()
	ids.erase(Document.ROOT)
	_duplicate.disabled = ids.is_empty()
	_delete.disabled = ids.is_empty()


func _render() -> void:
	var snapshot := _document.state
	var root_stamp := [snapshot.turns, snapshot.group]
	if _rendered.get(Document.ROOT) != root_stamp:
		_render_root()
		_rendered[Document.ROOT] = root_stamp
	for id in _rendered.keys():
		if id != Document.ROOT and not snapshot.nodes.has(id):
			_canvas.remove_graph_node(id)
			_rendered.erase(id)
	for id in snapshot.nodes:
		var resource := snapshot.nodes[id]
		if _rendered.get(id) != resource:
			_render_component(id, resource)
			_rendered[id] = resource
	for id in snapshot.positions:
		var node := _canvas.nodes[id]
		if node.position_offset != snapshot.positions[id]:
			node.position_offset = snapshot.positions[id]
	var links: Array[Dictionary] = []
	var breakable: StringName = snapshot.bindings.get(&"breakable", &"")
	for kind in snapshot.bindings:
		if kind == &"drops" and breakable.is_empty():
			continue
		links.append({
			"from_node": snapshot.bindings[kind], "from_port": 0,
			"to_node": breakable if kind == &"drops" else Document.ROOT,
			"to_port": 0 if kind == &"drops" else Document.ROOT_SLOTS.find(kind),
		})
	_canvas.project_links(links)


func _render_root() -> void:
	var fields: Array[Control] = []
	var slots: Dictionary[int, Dictionary] = {}
	for kind in Document.ROOT_SLOTS:
		slots[fields.size()] = _left_slot(kind)
		fields.append(_caption(Document.TITLES[kind]))
	fields.append(_field(Document.ROOT, &"quarter_turns", "Giros de 90°", _document.state.turns,
			{"hint": PROPERTY_HINT_RANGE, "hint_string": "0,3,1"}))
	fields.append(_field(Document.ROOT, &"connection_group", "Grupo de conexão", _document.state.group, {}))
	_place_node(Document.ROOT, Document.ROOT, "BlockDefinition", fields, slots)


func _render_component(id: StringName, value: Resource) -> void:
	var kind := Document.kind_of(value)
	var fields: Array[Control] = []
	var slots: Dictionary[int, Dictionary] = {}
	var direction := _caption("Saída")
	direction.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slots[0] = {"right": _port_type(kind), "right_color": _port_color(kind)}
	fields.append(direction)
	if kind == &"breakable":
		slots[fields.size()] = _left_slot(&"drops")
		fields.append(_caption("Drops"))
	if kind == &"behavior":
		fields.append(_picker("Resource de interação", "VoxelBlockBehavior", value,
				_queue_replacement.bind(_document, id)))
	for info in value.get_property_list():
		var usage: int = info["usage"]
		if not (usage & PROPERTY_USAGE_EDITOR) or not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var property: StringName = info["name"]
		var field_title: String = FIELD_TITLES.get(property, String(property).capitalize())
		var field: Control
		if value is SimpleTexture and property == &"texture":
			field = _texture_field(value.texture, _queue_edit.bind(_document, id, property))
		else:
			field = _field(id, property, field_title, value.get(property), info)
		if field != null:
			fields.append(field)
	var type_id: StringName = _document.state.component_types.get(id, &"")
	var entry := _types.get(type_id) as ContentComponentType
	var script := value.get_script() as Script
	if entry == null and script != null:
		entry = _types_by_script.get(script)
	var title: String = entry.display_name if entry != null else Document.TITLES[kind]
	_place_node(id, kind, title, fields, slots)


func _place_node(id: StringName, kind: StringName, title: String, fields: Array[Control], slots: Dictionary[int, Dictionary]) -> void:
	var position: Vector2 = _document.state.positions.get(id, STARTS[kind])
	_document.state.positions[id] = position
	_canvas.set_graph_node(id, title, position, fields, slots)


func _left_slot(kind: StringName) -> Dictionary:
	return {"left": _port_type(kind), "left_color": _port_color(kind)}


func _port_type(kind: StringName) -> int:
	return Document.KINDS.find(kind) + 1


func _port_color(kind: StringName) -> Color:
	return COLORS[Document.KINDS.find(kind)]


func _caption(title: String) -> Label:
	var label := Label.new()
	label.text = title
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


func _field(id: StringName, property: StringName, title: String, value: Variant, info: Dictionary) -> Control:
	var commit := _queue_edit.bind(_document, id, property)
	var component := _document.state.nodes.get(id) as Resource
	if typeof(value) == TYPE_BOOL:
		var check := CheckBox.new()
		check.text = title
		check.button_pressed = value
		check.toggled.connect(commit)
		return check
	var hint: int = info.get("hint", PROPERTY_HINT_NONE)
	var hint_string: String = info.get("hint_string", "")
	if hint == PROPERTY_HINT_RESOURCE_TYPE:
		return _picker(title, hint_string, value, commit)
	if property == &"full_sides" and (component is VoxelOcclusion or component is VoxelCollision):
		return _flags_field(title, value, commit)
	if hint == PROPERTY_HINT_ENUM and typeof(value) == TYPE_INT:
		return _enum_field(title, value, hint_string, commit)
	if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		return _numeric_field(title, value, hint, hint_string, commit)
	if property == &"face_tiles" and component is VoxelGeometry:
		return _text_field(title, ", ".join(PackedStringArray(value)), "ID por face, em ordem", commit)
	if property == &"items" and component is ContentDrops:
		var pairs := PackedStringArray()
		for key in value:
			pairs.append("%s=%d" % [key, value[key]])
		return _text_field(title, ", ".join(pairs), "core:stone=1", commit)
	if typeof(value) in [TYPE_STRING, TYPE_STRING_NAME]:
		return _text_field(title, String(value), "", func(text: String) -> void: commit.call(StringName(text) if typeof(value) == TYPE_STRING_NAME else text))
	return null


func _picker(title: String, base: String, value: Resource, commit: Callable) -> Control:
	var field := EditorResourcePicker.new()
	field.base_type = base
	field.edited_resource = value
	field.resource_changed.connect(commit)
	return _labeled_field(title, field)


func _texture_field(value: StringName, commit: Callable) -> Control:
	var field := OptionButton.new()
	field.fit_to_longest_item = false
	field.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	field.search_bar_enabled = true
	field.search_bar_min_item_count = 12
	var current := ContentRegistry.normalize_id(value)
	if current.is_empty() or current not in _texture_ids:
		field.add_item("Selecione uma textura" if current.is_empty() else String(value))
		field.set_item_disabled(0, true)
		field.select(0)
	for id in _texture_ids:
		field.add_item(String(id))
		var index := field.item_count - 1
		field.set_item_metadata(index, id)
		if id == current:
			field.select(index)
	field.item_selected.connect(func(index: int) -> void: commit.call(field.get_item_metadata(index)))
	return _labeled_field("Textura", field)


func _numeric_field(title: String, value: Variant, hint: int, hint_string: String, commit: Callable) -> Control:
	var integer := typeof(value) == TYPE_INT
	var field := SpinBox.new()
	field.step = 1.0 if integer else 0.01
	field.allow_lesser = true
	field.allow_greater = true
	if hint == PROPERTY_HINT_RANGE:
		var limits := hint_string.split(",")
		if limits.size() >= 2:
			field.min_value = limits[0].to_float()
			field.max_value = limits[1].to_float()
			field.allow_lesser = limits.has("or_less")
			field.allow_greater = limits.has("or_greater")
		# Keep authored values even when they have more precision than the range hint.
		if limits.size() >= 3 and integer:
			field.step = maxf(1.0, limits[2].to_float())
	field.set_value_no_signal(value)
	field.value_changed.connect(func(number: float) -> void: commit.call(int(number) if integer else number))
	return _labeled_field(title, field)


func _enum_field(title: String, value: int, hint_string: String, commit: Callable) -> Control:
	var field := OptionButton.new()
	var next := 0
	for item in hint_string.split(","):
		var parts := item.split(":")
		if parts.size() == 2:
			next = parts[1].to_int()
		field.add_item(parts[0])
		field.set_item_metadata(field.item_count - 1, next)
		if value == next:
			field.select(field.item_count - 1)
		next += 1
	field.item_selected.connect(func(index: int) -> void: commit.call(field.get_item_metadata(index)))
	return _labeled_field(title, field)


func _flags_field(title: String, value: int, commit: Callable) -> Control:
	var row := HBoxContainer.new()
	for i in SIDES.size():
		var bit := 1 << i
		var check := Button.new()
		check.text = SIDES[i]
		check.toggle_mode = true
		check.button_pressed = (value & bit) != 0
		check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		check.toggled.connect(func(active: bool) -> void: commit.call((value | bit) if active else (value & ~bit)))
		row.add_child(check)
	return _labeled_field(title, row)


func _text_field(title: String, value: String, placeholder: String, commit: Callable) -> Control:
	var field := LineEdit.new()
	field.text = value
	field.placeholder_text = placeholder
	field.text_submitted.connect(func(_text: String) -> void: field.release_focus())
	field.focus_exited.connect(func() -> void:
		if field.text.strip_edges() != value:
			commit.call(field.text.strip_edges())
	)
	return _labeled_field(title, field)


func _labeled_field(title: String, field: Control) -> Control:
	var row := VBoxContainer.new()
	row.add_child(_caption(title))
	row.add_child(field)
	return row


func _queue_edit(value: Variant, document: Document, id: StringName, property: StringName) -> void:
	_apply_field.call_deferred(value, document, id, property)


func _queue_replacement(value: Resource, document: Document, id: StringName) -> void:
	_replace_behavior.call_deferred(value, document, id)


func _replace_behavior(value: Resource, document: Document, id: StringName) -> void:
	if _documents.get(document.path) != document or not document.state.nodes.has(id):
		return
	var issue := document.replace_component(id, value)
	if document == _document:
		if not issue.is_empty():
			_rendered.erase(id)
		_finish(issue)
	elif not issue.is_empty():
		push_warning("LDK · %s · %s" % [document.path, issue])


func _apply_field(value: Variant, document: Document, id: StringName, property: StringName) -> void:
	if _documents.get(document.path) != document or (id != Document.ROOT and not document.state.nodes.has(id)):
		return
	var component := document.state.nodes.get(id) as Resource
	var issue := ""
	if property == &"face_tiles" and component is VoxelGeometry:
		var faces: Array[StringName] = []
		for part in String(value).split(","):
			faces.append(ContentRegistry.normalize_id(StringName(part.strip_edges())))
		if faces.size() == 6:
			value = faces
		else:
			issue = "Informe seis faces separadas por vírgula."
	elif property == &"items" and component is ContentDrops:
		var entries: Dictionary[StringName, int] = {}
		if not String(value).is_empty():
			for pair in String(value).split(","):
				var parts := pair.split("=")
				var key := ContentRegistry.normalize_id(StringName(parts[0].strip_edges()))
				if parts.size() != 2 or not parts[1].strip_edges().is_valid_int() or entries.has(key):
					issue = "Use ID=quantidade para cada drop, com IDs únicos separados por vírgula."
					break
				entries[key] = parts[1].strip_edges().to_int()
		value = entries
	var previous := document.state
	if issue.is_empty():
		issue = document.edit(id, property, value)
	if document == _document:
		if not issue.is_empty() or previous == document.state:
			_rendered.erase(id)
		_finish(issue)
	elif not issue.is_empty():
		push_warning("LDK · %s · %s" % [document.path, issue])


func _update_icons() -> void:
	for data in [[_undo, &"Undo", "Desfazer"], [_redo, &"Redo", "Refazer"],
			[_duplicate, &"Duplicate", "Duplicar"], [_delete, &"Remove", "Remover"]]:
		var button: Button = data[0]
		var icon: Texture2D
		if has_theme_icon(data[1], &"EditorIcons"):
			icon = get_theme_icon(data[1], &"EditorIcons")
		button.icon = icon
		button.text = data[2] if icon == null else ""
