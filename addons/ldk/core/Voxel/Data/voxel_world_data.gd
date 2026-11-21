class_name VoxelWorldData
extends RefCounted
## Main-thread authority. Worker snapshots are immutable VoxelChunkData references.

const UNLOADED := -1

var _chunks: Dictionary[Vector3i, VoxelChunkData] = {}
var _edits: Dictionary[Vector3i, Dictionary] = {}
# By support chunk. An empty ID suppresses the original procedural object.
var _prop_edits: Dictionary[Vector3i, Dictionary] = {}
var _component_states: Dictionary[Vector3i, Dictionary] = {}


func get_chunk(coord: Vector3i) -> VoxelChunkData:
	return _chunks.get(coord)


func get_block(cell: Vector3i) -> int:
	var data := get_chunk(VoxelChunkData.chunk_of(cell))
	if data == null:
		return UNLOADED
	return data.id_at(VoxelChunkData.index_of(VoxelChunkData.local_of(cell)))


func is_prop_removed(support: Vector3i) -> bool:
	var edits: Dictionary = _prop_edits.get(VoxelChunkData.chunk_of(support), {})
	return edits.has(support) and edits[support] == &""


func planted_prop_at(support: Vector3i) -> StringName:
	var edits: Dictionary = _prop_edits.get(VoxelChunkData.chunk_of(support), {})
	return edits.get(support, &"")


func prop_edits(coord: Vector3i) -> Dictionary[Vector3i, StringName]:
	var edits: Dictionary[Vector3i, StringName] = _prop_edits.get(coord, {} as Dictionary[Vector3i, StringName])
	return edits.duplicate()


func export_prop_edits() -> Dictionary[Vector3i, StringName]:
	var edits: Dictionary[Vector3i, StringName] = {}
	for chunk in _prop_edits.values():
		edits.merge(chunk)
	return edits


func restore_prop_edits(edits: Dictionary) -> bool:
	for support: Variant in edits:
		var id: Variant = edits[support]
		if not support is Vector3i or not (id is String or id is StringName):
			return false
		if not StringName(id).is_empty() and ContentRegistry.namespace_of(StringName(id)).is_empty():
			return false
	_prop_edits.clear()
	for support: Vector3i in edits:
		_set_prop_edit(support, ContentRegistry.normalize_id(StringName(edits[support])))
	return true


func plant_prop(support: Vector3i, entity_id: StringName) -> bool:
	if entity_id.is_empty() or not planted_prop_at(support).is_empty():
		return false
	_set_prop_edit(support, entity_id)
	return true


func mark_prop_removed(support: Vector3i) -> bool:
	if is_prop_removed(support):
		return false
	_set_prop_edit(support, &"")
	return true


func _set_prop_edit(support: Vector3i, entity_id: StringName) -> void:
	var coord := VoxelChunkData.chunk_of(support)
	if not _prop_edits.has(coord):
		_prop_edits[coord] = {} as Dictionary[Vector3i, StringName]
	_prop_edits[coord][support] = entity_id


func chunk_block_edits(coord: Vector3i) -> Dictionary:
	return _edits.get(coord, {})


## Install overrides before the procedural chunk is loaded.
func restore_chunk(coord: Vector3i, blocks: Dictionary[int, int], props: Dictionary, states: Dictionary) -> void:
	if not blocks.is_empty():
		_edits[coord] = blocks
	for index: int in props:
		var support := coord * VoxelChunkData.SIZE + VoxelChunkData.local_from_index(index)
		_set_prop_edit(support, ContentRegistry.normalize_id(StringName(props[index])))
	if not states.is_empty():
		_component_states[coord] = states


func persistent_coords() -> Array[Vector3i]:
	var coords := {}
	for collection in [_edits, _prop_edits, _component_states]:
		coords.merge(collection)
	var keys: Array[Vector3i] = []
	keys.assign(coords.keys())
	return keys


func chunk_component_states(coord: Vector3i) -> Dictionary:
	var states: Dictionary = _component_states.get(coord, {})
	return states.duplicate(true)


func component_states(cell: Vector3i) -> Dictionary:
	var chunk: Dictionary = _component_states.get(VoxelChunkData.chunk_of(cell), {})
	var states: Dictionary = chunk.get(VoxelChunkData.index_of(VoxelChunkData.local_of(cell)), {})
	return states.duplicate(true)


func set_component_state(cell: Vector3i, id: StringName, value: Variant) -> bool:
	var coord := VoxelChunkData.chunk_of(cell)
	var index := VoxelChunkData.index_of(VoxelChunkData.local_of(cell))
	var chunk: Dictionary = _component_states.get(coord, {})
	var states: Dictionary = chunk.get(index, {})
	if states.get(id) == value:
		return false
	if value == null:
		states.erase(id)
	else:
		states[id] = value
	if states.is_empty():
		chunk.erase(index)
	else:
		chunk[index] = states
	if chunk.is_empty():
		_component_states.erase(coord)
	else:
		_component_states[coord] = chunk
	return true


func clear_component_states(cell: Vector3i) -> bool:
	var coord := VoxelChunkData.chunk_of(cell)
	if not _component_states.has(coord):
		return false
	var chunk := _component_states[coord]
	var removed := chunk.erase(VoxelChunkData.index_of(VoxelChunkData.local_of(cell)))
	if chunk.is_empty():
		_component_states.erase(coord)
	return removed


static func is_persistent_value(value: Variant, depth := 0) -> bool:
	if depth > 24:
		return false
	match typeof(value):
		TYPE_DICTIONARY:
			for key: Variant in value:
				if not (key is int or key is String or key is StringName) or not is_persistent_value(value[key], depth + 1):
					return false
		TYPE_ARRAY:
			for entry: Variant in value:
				if not is_persistent_value(entry, depth + 1):
					return false
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_VECTOR2, TYPE_VECTOR3:
			return value.is_finite()
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME, \
		TYPE_VECTOR2I, TYPE_VECTOR3I, TYPE_PACKED_BYTE_ARRAY:
			pass
		_:
			return false
	return true


func install_chunk(coord: Vector3i, generated: VoxelChunkData) -> void:
	if _edits.has(coord):
		generated = generated.with_changes(_edits[coord])
	_chunks[coord] = generated


func unload_chunk(coord: Vector3i) -> void:
	_chunks.erase(coord)


func resident_coords() -> Array[Vector3i]:
	return _chunks.keys()


func write_blocks(edits: Dictionary[Vector3i, int], preserve_equal := false) -> Array[Vector3i]:
	var by_chunk: Dictionary[Vector3i, Dictionary] = {}
	var changed: Array[Vector3i] = []
	for cell in edits:
		var coord := VoxelChunkData.chunk_of(cell)
		var index := VoxelChunkData.index_of(VoxelChunkData.local_of(cell))
		var id := edits[cell]
		var stored: Dictionary[int, int] = _edits.get(coord, {} as Dictionary[int, int])
		var current := get_block(cell)
		if current == UNLOADED and stored.has(index):
			current = stored[index]
		if current == id:
			if preserve_equal:
				stored[index] = id
				_edits[coord] = stored
			continue
		if not by_chunk.has(coord):
			var changes: Dictionary[int, int] = {}
			by_chunk[coord] = changes
		by_chunk[coord][index] = id
		stored[index] = id
		_edits[coord] = stored
		changed.append(cell)
	for coord in by_chunk:
		if _chunks.has(coord):
			_chunks[coord] = _chunks[coord].with_changes(by_chunk[coord])
	return changed


func edited_blocks() -> Dictionary[Vector3i, int]:
	var result: Dictionary[Vector3i, int] = {}
	for coord in _edits:
		var origin := coord * VoxelChunkData.SIZE
		for index: int in _edits[coord]:
			var local := VoxelChunkData.local_from_index(index)
			result[origin + local] = _edits[coord][index]
	return result


func payload_bytes() -> int:
	var bytes := 0
	for data in _chunks.values():
		bytes += data.payload_bytes()
	return bytes
