@tool
extends RefCounted
## Editor-only transactions on the existing fields of a VoxelBlock.

const ROOT := &"BlockDefinition"
const ROOT_SLOTS: Array[StringName] = [&"geometry", &"collision", &"breakable", &"behavior", &"occlusion"]
const KINDS: Array[StringName] = [&"geometry", &"collision", &"breakable", &"behavior", &"occlusion", &"drops"]
const TITLES := {
	&"geometry": "Visual", &"collision": "Collision", &"breakable": "Breakable",
	&"behavior": "Interactable", &"occlusion": "Occlusion", &"drops": "Drops",
}
const HISTORY_LIMIT := 64
const LAYOUT_DIR := "user://ldk/content_editor/graphs"


class State:
	var nodes: Dictionary[StringName, Resource] = {}
	var component_types: Dictionary[StringName, StringName] = {}
	var bindings: Dictionary[StringName, StringName] = {}
	var positions: Dictionary[StringName, Vector2] = {}
	var turns: int
	var group: StringName

	func copy() -> State:
		var result := State.new()
		result.nodes = nodes.duplicate()
		result.component_types = component_types.duplicate()
		result.bindings = bindings.duplicate()
		result.positions = positions.duplicate()
		result.turns = turns
		result.group = group
		return result

	func component(kind: StringName) -> Resource:
		return nodes.get(bindings.get(kind, &""))


var block: VoxelBlock
var path: String
var state := State.new()

var _fingerprint: String
var _serial := 0
var _past: Array[State] = []
var _future: Array[State] = []
var _layout_path: String
var _layout := ConfigFile.new()


func _init(definition: VoxelBlock, source_path: String, context_id: StringName) -> void:
	block = definition
	path = source_path
	_fingerprint = FileAccess.get_sha256(path)
	state.turns = block.quarter_turns
	state.group = block.connection_group
	_layout_path = LAYOUT_DIR.path_join(("%s\n%s" % [context_id, path]).sha256_text() + ".cfg")
	if FileAccess.file_exists(_layout_path):
		_layout.load(_layout_path)
	_load_position(ROOT, ROOT)
	for kind in KINDS:
		var resource: Resource = block.get(kind)
		if resource == null:
			continue
		state.nodes[kind] = resource
		state.bindings[kind] = kind
		_load_position(kind, kind)


func _load_position(id: StringName, slot: StringName) -> void:
	var position: Variant = _layout.get_value("nodes", String(slot), null)
	if position is Vector2 and position.is_finite():
		state.positions[id] = position


func save_layout() -> String:
	for kind in KINDS:
		var id: StringName = state.bindings.get(kind, &"")
		if state.positions.has(id):
			_layout.set_value("nodes", String(kind), state.positions[id])
	if state.positions.has(ROOT):
		_layout.set_value("nodes", String(ROOT), state.positions[ROOT])
	var error := DirAccess.make_dir_recursive_absolute(LAYOUT_DIR)
	if error == OK:
		error = _layout.save(_layout_path)
	return "" if error == OK else "Falha ao salvar a disposição dos nós (%s)." % error_string(error)


func warning(database: ContentDB) -> String:
	if state.bindings.has(&"drops") and not state.bindings.has(&"breakable"):
		return "Drops sem Breakable. Conecte um Breakable para usar as recompensas."
	var invalid := VoxelBlock.geometry_issue(block)
	if not invalid.is_empty():
		return invalid
	if database == null:
		return ""
	var absent := PackedStringArray()
	for id in ContentDB._block_tiles(block):
		if database.textures.find(id) == null:
			absent.append(id)
	if block.drops != null:
		for id in block.drops.items:
			if database.items.find(id) == null and not absent.has(id):
				absent.append(id)
	return "" if absent.is_empty() else "IDs ausentes no catálogo: " + ", ".join(absent)


static func kind_of(resource: Resource) -> StringName:
	if resource is VoxelVisual:
		return &"geometry"
	if resource is VoxelCollision:
		return &"collision"
	if resource is ContentBreakable:
		return &"breakable"
	if resource is VoxelBlockBehavior:
		return &"behavior"
	if resource is VoxelOcclusion:
		return &"occlusion"
	if resource is ContentDrops:
		return &"drops"
	return &""


func add_component(resource: Resource, position: Vector2, type_id: StringName = &"") -> String:
	if kind_of(resource).is_empty():
		return "Este Resource não é um componente de bloco."
	var next := state.copy()
	_add_node(next, resource, position, type_id)
	return _commit(next)


func duplicate_components(ids: Array[StringName]) -> String:
	var next := state.copy()
	for id in ids:
		if state.nodes.has(id):
			_add_node(next, state.nodes[id], state.positions[id] + Vector2(34, 48), state.component_types.get(id, &""))
	return _commit(next)


func _add_node(next: State, resource: Resource, position: Vector2, type_id: StringName) -> void:
	_serial += 1
	var id := StringName("component_%d" % _serial)
	next.nodes[id] = resource
	next.positions[id] = position
	if not type_id.is_empty():
		next.component_types[id] = type_id


func remove_components(ids: Array[StringName]) -> String:
	var next := state.copy()
	for id in ids:
		if not next.nodes.has(id):
			continue
		var kind := kind_of(next.nodes[id])
		if next.bindings.get(kind) == id:
			next.bindings.erase(kind)
		next.nodes.erase(id)
		next.component_types.erase(id)
		next.positions.erase(id)
	return _commit(next)


func move_nodes(positions: Dictionary[StringName, Vector2]) -> String:
	var next := state.copy()
	next.positions = positions
	return _commit(next)


func wire(from: StringName, out_port: int, target: StringName, in_port: int, attach: bool) -> String:
	var kind := kind_of(state.nodes.get(from))
	if kind.is_empty() or out_port != 0:
		return "Use a saída de um componente."
	if kind == &"drops":
		if not state.bindings.has(&"breakable") or target != state.bindings[&"breakable"] or in_port != 0:
			return "Conecte Drops ao Breakable ligado ao bloco."
	elif target != ROOT or ROOT_SLOTS.find(kind) != in_port:
		return "Conecte %s à porta correspondente em BlockDefinition." % TITLES[kind]
	var next := state.copy()
	var bound: StringName = next.bindings.get(kind, &"")
	if attach:
		if bound == from:
			return ""
		if not bound.is_empty():
			return "Desconecte o %s já ativo antes de substituir o componente." % TITLES[kind]
		next.bindings[kind] = from
	elif bound == from:
		next.bindings.erase(kind)
	return _commit(next)


func edit(id: StringName, property: StringName, value: Variant) -> String:
	var next := state.copy()
	if id == ROOT:
		match property:
			&"quarter_turns": next.turns = clampi(int(value), 0, 3)
			&"connection_group": next.group = ContentRegistry.normalize_id(StringName(value))
			_: return "Propriedade desconhecida."
	elif next.nodes.has(id):
		var component := next.nodes[id]
		if component.get(property) == value:
			return ""
		# Keep shared components intact. Only the edited block gets the modified copy.
		var updated := component.duplicate_deep(Resource.DEEP_DUPLICATE_NONE)
		if updated == null:
			return "Não foi possível copiar o componente."
		updated.set(property, value)
		var issue := _component_issue(updated)
		if not issue.is_empty() and issue != _component_issue(component):
			return issue
		next.nodes[id] = updated
	else:
		return "O componente foi removido."
	return _commit(next)


func replace_component(id: StringName, resource: Resource) -> String:
	if not state.nodes.has(id) or resource == null or kind_of(resource) != kind_of(state.nodes[id]):
		return "Escolha um Resource compatível ou desconecte o componente."
	var next := state.copy()
	if resource.get_script() != next.nodes[id].get_script():
		next.component_types.erase(id)
	next.nodes[id] = resource
	return _commit(next)


func can_undo() -> bool:
	return not _past.is_empty()


func can_redo() -> bool:
	return not _future.is_empty()


func undo() -> String:
	if not can_undo():
		return ""
	var previous := _past.back() as State
	var issue := _apply(previous, false)
	if issue.is_empty():
		_future.append(state)
		state = previous
		_past.pop_back()
	return issue


func redo() -> String:
	if not can_redo():
		return ""
	var following := _future.back() as State
	var issue := _apply(following, false)
	if issue.is_empty():
		_past.append(state)
		state = following
		_future.pop_back()
	return issue


func _commit(next: State) -> String:
	if next.nodes == state.nodes and next.bindings == state.bindings and next.positions == state.positions and (
			next.turns == state.turns and next.group == state.group):
		return ""
	var issue := _apply(next, true)
	if not issue.is_empty():
		return issue
	_past.append(state)
	if _past.size() > HISTORY_LIMIT:
		_past.pop_front()
	_future.clear()
	state = next
	return ""


func _apply(next: State, validate: bool) -> String:
	var changed := state.turns != next.turns or state.group != next.group
	for kind in KINDS:
		if state.component(kind) != next.component(kind):
			changed = true
	if not changed:
		return ""
	# Reject edits against a stale selection or a file changed elsewhere in the editor.
	if _fingerprint.is_empty() or FileAccess.get_sha256(path) != _fingerprint:
		return "O arquivo mudou ou não pode ser lido. Atualize o catálogo antes de editar."
	for kind in KINDS:
		if block.get(kind) != state.component(kind):
			return "O bloco mudou no Inspetor. Atualize o catálogo antes de editar."
	if block.quarter_turns != state.turns or block.connection_group != state.group:
		return "O bloco mudou no Inspetor. Atualize o catálogo antes de editar."

	var candidate := VoxelBlock.new()
	_write(candidate, next)
	if validate:
		if next.bindings.has(&"drops") and not next.bindings.has(&"breakable") and (
				not state.bindings.has(&"drops") or state.bindings.has(&"breakable")):
			return "Desconecte Drops antes de remover ou desconectar Breakable."
		if candidate.connection_group != block.connection_group and not candidate.connection_group.is_empty() and (
				ContentRegistry.namespace_of(candidate.connection_group).is_empty()):
			return "Use namespace:nome no grupo de conexão."
		var geometry_issue := VoxelBlock.geometry_issue(candidate)
		if not geometry_issue.is_empty() and geometry_issue != VoxelBlock.geometry_issue(block):
			return geometry_issue
		for kind in KINDS:
			var component := next.component(kind)
			var issue := _component_issue(component)
			if not issue.is_empty() and component != state.component(kind):
				return issue
	_write(block, next)
	var error := ResourceSaver.save(block, path)
	if error != OK:
		_write(block, state)
		return "Falha ao salvar o bloco (%s)." % error_string(error)
	_fingerprint = FileAccess.get_sha256(path)
	block.emit_changed()
	return ""


static func _write(target: VoxelBlock, snapshot: State) -> void:
	for kind in KINDS:
		target.set(kind, snapshot.component(kind))
	target.quarter_turns = snapshot.turns
	target.connection_group = snapshot.group


static func _component_issue(resource: Resource) -> String:
	if resource is SimpleTexture:
		if not resource.texture.is_empty() and ContentRegistry.namespace_of(resource.texture).is_empty():
			return "Use um ID namespace:nome para a textura."
	if resource is ContentBreakable and (not is_finite(resource.seconds) or resource.seconds < ContentBreakable.MIN_SECONDS):
		return "O tempo de quebra deve ser de pelo menos 0,05 segundo."
	if resource is ContentDrops:
		for id in resource.items:
			if ContentRegistry.namespace_of(id).is_empty() or resource.items[id] <= 0:
				return "Cada drop deve ter um ID namespace:nome e quantidade positiva."
	if resource is VoxelGeometry:
		for id in resource.face_tiles:
			if not id.is_empty() and ContentRegistry.namespace_of(id).is_empty():
				return "Use IDs namespace:nome nas texturas."
	return ""
