class_name VoxelWorld
extends Node3D
## Coordinates streaming, worker lifetimes, edits and main-thread presentation.

signal blocks_changed(cells: Array[Vector3i])
signal chunk_ready(coord: Vector3i)
signal chunk_unloaded(coord: Vector3i)
signal prop_planted(support: Vector3i, entity_id: StringName)
signal prop_destroyed(support: Vector3i)
signal persistence_changed(coord: Vector3i)

@export_group("Chunks ao redor do alvo")
## Nó que define o centro do carregamento de chunks. A cena de jogo configura o jogador como alvo.
@export var follow_target: Node3D
## Raio horizontal em chunks ao redor do alvo. Aumente para manter mais terreno disponível à distância.
@export_range(0, 8) var horizontal_radius := 2
## Raio em chunks acima e abaixo do alvo. Aumente para manter mais andares carregados.
@export_range(0, 6) var vertical_radius := 1

@export_group("Processamento de chunks")
## Quantidade máxima de tarefas de chunks em paralelo. Valores maiores permitem mais trabalho simultâneo e usam mais CPU.
@export_range(1, 8) var worker_limit := 3
## Número máximo de malhas de chunks aplicadas por quadro. Valores maiores exibem o terreno mais rápido e podem pesar em cada quadro.
@export_range(1, 8) var mesh_commits_per_frame := 2

var _generator: VoxelGenerator
var _catalog: VoxelCatalog
var _materials: Array[Material]
var _missing_edits: Dictionary[Vector3i, Dictionary] = {}
var _data := VoxelWorldData.new()
var _active := VoxelActiveBlocks.new()
var _focus: Vector3i
var _has_focus := false
var _wanted: Dictionary[Vector3i, int] = {}
var _halo: Dictionary[Vector3i, bool] = {}
var _priority: Array[Vector3i] = []
var _built: Dictionary[Vector3i, int] = {}
var _views: Dictionary[Vector3i, VoxelChunkView] = {}
var _pool: Array[VoxelChunkView] = []
var _generating: Dictionary[Vector3i, VoxelChunkJob] = {}
var _meshing: Dictionary[Vector3i, VoxelChunkJob] = {}
var _generation_count := 0
var _generation_usec := 0
var _mesh_count := 0
var _mesh_usec := 0
var _commit_max_usec := 0
var _total_commit_usec := 0


func configure(
	generator: VoxelGenerator, catalog: VoxelCatalog, materials: Array[Material]
) -> void:
	assert(_generator == null and materials.size() == 2)
	_generator = generator
	_generator.prepare()
	_catalog = catalog
	_catalog.freeze()
	_materials = materials


func get_block(cell: Vector3i) -> int:
	return _data.get_block(cell)


func block_at(cell: Vector3i) -> VoxelCatalog.BakedBlock:
	var id := get_block(cell)
	return _catalog.block(id) if _catalog != null and id > 0 else null


func block_definition_at(cell: Vector3i) -> VoxelBlock:
	return _catalog.definition(get_block(cell)) if _catalog != null else null


func is_prop_removed(support: Vector3i) -> bool:
	return _data.is_prop_removed(support)


func planted_prop_at(support: Vector3i) -> StringName:
	return _data.planted_prop_at(support)


func prop_edits(coord: Vector3i) -> Dictionary[Vector3i, StringName]:
	return _data.prop_edits(coord)


func export_prop_edits() -> Dictionary[Vector3i, StringName]:
	return _data.export_prop_edits()


## Restaura edições antes do streaming da sessão.
func restore_prop_edits(edits: Dictionary) -> bool:
	return _data.restore_prop_edits(edits)


func can_plant_prop(support: Vector3i) -> bool:
	var cell := support + Vector3i.UP
	var ground := block_at(support)
	return ground != null and ground.solid_cube and can_edit(cell) and get_block(cell) == 0 \
		and is_chunk_ready(VoxelChunkData.chunk_of(support)) and is_chunk_ready(VoxelChunkData.chunk_of(cell)) \
		and planted_prop_at(support).is_empty()


func plant_prop(support: Vector3i, entity_id: StringName) -> bool:
	var key := ContentRegistry.normalize_id(entity_id)
	if ContentRegistry.namespace_of(key).is_empty() or not can_plant_prop(support):
		return false
	if not _data.plant_prop(support, key):
		return false
	persistence_changed.emit(VoxelChunkData.chunk_of(support))
	prop_planted.emit(support, key)
	return true


func mark_prop_removed(support: Vector3i) -> bool:
	if not _data.mark_prop_removed(support):
		return false
	var support_chunk := VoxelChunkData.chunk_of(support)
	if _data.clear_component_states(support + Vector3i.UP):
		var anchor_chunk := VoxelChunkData.chunk_of(support + Vector3i.UP)
		if anchor_chunk != support_chunk:
			persistence_changed.emit(anchor_chunk)
	persistence_changed.emit(support_chunk)
	prop_destroyed.emit(support)
	return true


func connections_at(cell: Vector3i, block: VoxelCatalog.BakedBlock) -> int:
	if block.connection_group.is_empty():
		return 0
	var mask := 0
	for side: int in VoxelCatalog.CONNECTION_SIDES:
		if block.connects_to(block_at(cell + VoxelChunkData.DIRECTIONS[side])):
			mask |= 1 << side
	return mask


func get_block_key(cell: Vector3i) -> StringName:
	return _catalog.key_for(get_block(cell)) if _catalog != null else &""


func set_block_key(cell: Vector3i, key: StringName) -> bool:
	return _catalog != null and set_block(cell, _catalog.id_for(key))


func export_block_edits() -> Dictionary[Vector3i, StringName]:
	var result: Dictionary[Vector3i, StringName] = {}
	if _catalog == null:
		return result
	for coord in persistent_chunk_coords():
		var edits := _export_chunk_blocks(coord)
		for index: int in edits:
			result[coord * VoxelChunkData.SIZE + VoxelChunkData.local_from_index(index)] = edits[index]
	return result


func persistent_chunk_coords() -> Array[Vector3i]:
	return _data.persistent_coords()


func export_persistent_chunk(coord: Vector3i) -> Dictionary:
	var props := {}
	var overrides := _data.prop_edits(coord)
	for support in overrides:
		props[VoxelChunkData.index_of(VoxelChunkData.local_of(support))] = overrides[support]
	return {"blocks": _export_chunk_blocks(coord), "props": props, "components": _data.chunk_component_states(coord)}


func _export_chunk_blocks(coord: Vector3i) -> Dictionary:
	var keys := {}
	var edits := _data.chunk_block_edits(coord)
	for index: int in edits:
		keys[index] = _catalog.key_for(edits[index])
	keys.merge(_missing_edits.get(coord, {}), true)
	return keys


## Called before streaming. IDs of unavailable block definitions survive the fallback mesh.
func restore_persistent_chunk(coord: Vector3i, record: Dictionary) -> void:
	var runtime: Dictionary[int, int] = {}
	var missing := {}
	for index: int in record.blocks:
		var key: StringName = record.blocks[index]
		runtime[index] = _catalog.resolve(key)
		if _catalog.id_for(key) < 0:
			missing[index] = key
	if not missing.is_empty():
		_missing_edits[coord] = missing
	_data.restore_chunk(coord, runtime, record.props, record.components)


func persistent_component_states(cell: Vector3i) -> Dictionary:
	return _data.component_states(cell)


## Persist plain data for a block or a prop's occupied cell, above its support. Null removes the state.
func set_persistent_component_state(cell: Vector3i, id: StringName, value: Variant) -> bool:
	id = ContentRegistry.normalize_id(id)
	if ContentRegistry.namespace_of(id).is_empty() or not can_edit(cell) or not VoxelWorldData.is_persistent_value(value):
		return false
	var owned: Variant = value.duplicate(true) if value is Dictionary or value is Array else value
	if _data.set_component_state(cell, id, owned):
		persistence_changed.emit(VoxelChunkData.chunk_of(cell))
	return true


func restore_block_edits(edits: Dictionary, legacy_keys: Array[StringName] = []) -> bool:
	if _catalog == null:
		return false
	var runtime: Dictionary[Vector3i, int] = {}
	var missing: Dictionary[Vector3i, Dictionary] = {}
	for cell: Variant in edits:
		var value: Variant = edits[cell]
		if not cell is Vector3i:
			return false
		var key: StringName
		if value is int and value >= 0 and value < legacy_keys.size():
			key = legacy_keys[value]
		elif value is String or value is StringName:
			key = ContentRegistry.normalize_id(StringName(value))
		if ContentRegistry.namespace_of(key).is_empty():
			return false
		if not can_edit(cell):
			continue
		runtime[cell] = _catalog.resolve(key)
		if _catalog.id_for(key) < 0:
			var coord := VoxelChunkData.chunk_of(cell)
			if not missing.has(coord):
				missing[coord] = {}
			missing[coord][VoxelChunkData.index_of(VoxelChunkData.local_of(cell))] = key
	if not _apply_blocks(runtime, true):
		return false
	_missing_edits.merge(missing, true)
	return true


func is_chunk_ready(coord: Vector3i) -> bool:
	return _built.has(coord)


func can_edit(cell: Vector3i) -> bool:
	return _generator != null and _generator.allows_edit(cell)


func set_block(cell: Vector3i, id: int) -> bool:
	var edits: Dictionary[Vector3i, int] = {}
	edits[cell] = id
	return set_blocks(edits)


func set_blocks(edits: Dictionary[Vector3i, int]) -> bool:
	return _apply_blocks(edits, false)


func _apply_blocks(edits: Dictionary[Vector3i, int], preserve_equal: bool) -> bool:
	if _catalog == null:
		return false
	for cell in edits:
		if not can_edit(cell) or not _catalog.has_id(edits[cell]):
			return false
	var persistence_dirty: Dictionary[Vector3i, bool] = {}
	for cell in edits:
		var coord := VoxelChunkData.chunk_of(cell)
		if _missing_edits.has(coord):
			var missing := _missing_edits[coord]
			if missing.erase(VoxelChunkData.index_of(VoxelChunkData.local_of(cell))):
				persistence_dirty[coord] = true
			if missing.is_empty():
				_missing_edits.erase(coord)
	var changed := _data.write_blocks(edits, preserve_equal)
	var dirty: Dictionary[Vector3i, bool] = {}
	for cell in changed:
		_active.clear(cell)
		var coord := VoxelChunkData.chunk_of(cell)
		var local := VoxelChunkData.local_of(cell)
		if not preserve_equal:
			_data.clear_component_states(cell)
		persistence_dirty[coord] = true
		dirty[coord] = true
		for side in 6:
			var direction := VoxelChunkData.DIRECTIONS[side]
			var offset := local + direction
			if offset != VoxelChunkData.local_of(offset):
				dirty[coord + direction] = true
	for coord in dirty:
		if _wanted.has(coord):
			_wanted[coord] += 1
			if _meshing.has(coord):
				_meshing[coord].cancel.cancel()
	if not changed.is_empty():
		blocks_changed.emit(changed)
	if not preserve_equal:
		for coord in persistence_dirty:
			persistence_changed.emit(coord)
	return true


func interact(cell: Vector3i) -> bool:
	if _catalog == null:
		return false
	var behavior := _catalog.behavior_for(get_block(cell))
	if behavior == null:
		return false
	_active.interact(cell, behavior)
	return true


func stats() -> Dictionary:
	var vertices := 0
	var triangles := 0
	var surfaces := 0
	for view in _views.values():
		vertices += view.vertex_count
		triangles += view.triangle_count
		surfaces += view.surface_count
	return {
		"resident": _data.resident_coords().size(),
		"payload_bytes": _data.payload_bytes(),
		"ready": _built.size(),
		"wanted": _wanted.size(),
		"pending": _meshing.size() + _generating.size(),
		"vertices": vertices,
		"triangles": triangles,
		"surfaces": surfaces,
		"generated": _generation_count,
		"meshed": _mesh_count,
		"generation_avg_ms": _generation_usec / (1000.0 * maxi(_generation_count, 1)),
		"meshing_avg_ms": _mesh_usec / (1000.0 * maxi(_mesh_count, 1)),
		"commit_avg_ms": _total_commit_usec / (1000.0 * maxi(_mesh_count, 1)),
		"commit_max_ms": _commit_max_usec / 1000.0,
	}


func _process(delta: float) -> void:
	if _generator == null or not is_instance_valid(follow_target):
		return
	var point := to_local(follow_target.global_position).floor()
	var center := VoxelChunkData.chunk_of(Vector3i(point))
	if not _has_focus or center != _focus:
		_refresh_interest(center)
	_collect_jobs()
	_dispatch_jobs()
	for coord in _active.chunk_coords():
		if not _wanted.has(coord):
			continue
		var data := _data.get_chunk(coord)
		if data != null:
			_active.advance_chunk(coord, data, _catalog, delta)


func _exit_tree() -> void:
	var jobs: Array[VoxelChunkJob] = []
	jobs.append_array(_generating.values())
	jobs.append_array(_meshing.values())
	for job in jobs:
		job.cancel.cancel()
	for job in jobs:
		WorkerThreadPool.wait_for_task_completion(job.task_id)
	_generating.clear()
	_meshing.clear()


func _refresh_interest(center: Vector3i) -> void:
	_focus = center
	_has_focus = true
	var next_wanted: Dictionary[Vector3i, int] = {}
	_halo.clear()
	for y in range(-vertical_radius, vertical_radius + 1):
		for z in range(-horizontal_radius, horizontal_radius + 1):
			for x in range(-horizontal_radius, horizontal_radius + 1):
				var coord := center + Vector3i(x, y, z)
				next_wanted[coord] = _wanted.get(coord, 0)
				_halo[coord] = true
				for direction in VoxelChunkData.DIRECTIONS:
					_halo[coord + direction] = true
	_wanted = next_wanted
	_priority = _wanted.keys()
	_priority.sort_custom(_nearer)
	for coord in _built.keys():
		if not _wanted.has(coord):
			_built.erase(coord)
			_release_view(coord)
			chunk_unloaded.emit(coord)
	for coord in _data.resident_coords():
		if not _halo.has(coord):
			_data.unload_chunk(coord)
	for coord in _generating:
		if not _halo.has(coord):
			_generating[coord].cancel.cancel()
	for coord in _meshing:
		if not _wanted.has(coord):
			_meshing[coord].cancel.cancel()


func _nearer(a: Vector3i, b: Vector3i) -> bool:
	var da := a - _focus
	var db := b - _focus
	var distance_a := da.length_squared()
	var distance_b := db.length_squared()
	if distance_a != distance_b:
		return distance_a < distance_b
	return absi(da.y) < absi(db.y)


func _collect_jobs() -> void:
	for coord in _generating.keys():
		var job := _generating[coord]
		if not WorkerThreadPool.is_task_completed(job.task_id):
			continue
		WorkerThreadPool.wait_for_task_completion(job.task_id)
		_generating.erase(coord)
		if job.generated != null and not job.cancel.is_cancelled() and _halo.has(coord):
			_data.install_chunk(coord, job.generated)
			_generation_count += 1
			_generation_usec += job.elapsed_usec

	var commits := 0
	for coord in _meshing.keys():
		var job := _meshing[coord]
		if not WorkerThreadPool.is_task_completed(job.task_id):
			continue
		var current: bool = not job.cancel.is_cancelled() and _wanted.get(coord, -1) == job.revision
		if current and commits >= mesh_commits_per_frame:
			continue
		WorkerThreadPool.wait_for_task_completion(job.task_id)
		_meshing.erase(coord)
		if not current or job.geometry == null:
			continue
		_commit(job)
		commits += 1


func _dispatch_jobs() -> void:
	var capacity := worker_limit - _generating.size() - _meshing.size()
	if capacity <= 0:
		return
	for coord in _priority:
		if _built.get(coord, -1) == _wanted[coord] or _meshing.has(coord):
			continue
		var center := _data.get_chunk(coord)
		if center == null:
			capacity -= int(_request_data(coord))
			if capacity <= 0:
				return
			continue
		# Empty chunks have no geometry and need no six-neighbor snapshot.
		if center.uniform_id() == 0:
			_release_view(coord)
			_mark_ready(coord, _wanted[coord])
			continue
		var neighbors: Array[VoxelChunkData] = []
		for side in VoxelChunkData.DIRECTIONS:
			var adjacent := coord + side
			var neighbor := _data.get_chunk(adjacent)
			if neighbor == null:
				capacity -= int(_request_data(adjacent))
				if capacity <= 0:
					return
			else:
				neighbors.append(neighbor)
		if neighbors.size() == 6:
			var job := VoxelChunkJob.new()
			job.coord = coord
			job.revision = _wanted[coord]
			job.task_id = WorkerThreadPool.add_task(job.mesh.bind(center, neighbors, _catalog))
			_meshing[coord] = job
			capacity -= 1
			if capacity <= 0:
				return


func _request_data(coord: Vector3i) -> bool:
	if _generating.has(coord):
		return false
	var job := VoxelChunkJob.new()
	job.coord = coord
	job.task_id = WorkerThreadPool.add_task(job.generate.bind(_generator))
	_generating[coord] = job
	return true


func _commit(job: VoxelChunkJob) -> void:
	var started := Time.get_ticks_usec()
	if job.geometry.is_empty():
		_release_view(job.coord)
	else:
		var view := _views.get(job.coord) as VoxelChunkView
		if view == null:
			if _pool.is_empty():
				view = VoxelChunkView.new()
				add_child(view)
			else:
				view = _pool.pop_back()
			_views[job.coord] = view
		view.apply(job.coord, job.geometry, _materials)
	var elapsed := Time.get_ticks_usec() - started
	_mesh_count += 1
	_mesh_usec += job.elapsed_usec
	_total_commit_usec += elapsed
	_commit_max_usec = maxi(_commit_max_usec, elapsed)
	_mark_ready(job.coord, job.revision)


func _mark_ready(coord: Vector3i, revision: int) -> void:
	var first := not _built.has(coord)
	_built[coord] = revision
	if first:
		chunk_ready.emit(coord)


func _release_view(coord: Vector3i) -> void:
	if not _views.has(coord):
		return
	var view := _views[coord]
	_views.erase(coord)
	view.release()
	_pool.append(view)
