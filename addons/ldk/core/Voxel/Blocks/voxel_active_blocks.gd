class_name VoxelActiveBlocks
extends RefCounted
## Only cells with pending behavior are scheduled, grouped by chunk.

var _states: Dictionary[Vector3i, Dictionary] = {}
var _active: Dictionary[Vector3i, Dictionary] = {}


func interact(cell: Vector3i, behavior: VoxelBlockBehavior) -> void:
	var state: Dictionary = _states.get(cell, {})
	var active := behavior.interact(cell, state)
	_store(cell, state, active)


func clear(cell: Vector3i) -> void:
	_store(cell, {}, false)


func chunk_coords() -> Array[Vector3i]:
	return _active.keys()


func advance_chunk(
	coord: Vector3i, data: VoxelChunkData, catalog: VoxelCatalog, delta: float
) -> void:
	if not _active.has(coord):
		return
	for cell: Vector3i in _active[coord].keys():
		var id := data.id_at(VoxelChunkData.index_of(VoxelChunkData.local_of(cell)))
		var behavior := catalog.behavior_for(id)
		if behavior == null:
			clear(cell)
			continue
		var state: Dictionary = _states.get(cell, {})
		var active := behavior.advance(cell, state, delta)
		_store(cell, state, active)


func _store(cell: Vector3i, state: Dictionary, active: bool) -> void:
	if state.is_empty():
		_states.erase(cell)
	else:
		_states[cell] = state
	var coord := VoxelChunkData.chunk_of(cell)
	if active:
		if not _active.has(coord):
			_active[coord] = {}
		_active[coord][cell] = true
	elif _active.has(coord):
		_active[coord].erase(cell)
		if _active[coord].is_empty():
			_active.erase(coord)
