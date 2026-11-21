class_name VoxelChunkMesher
extends RefCounted
## Conservative culling for authored triangles, greedy rectangles for cube faces.

const SIZE := VoxelChunkData.SIZE
const AREA := VoxelChunkData.AREA
const VOLUME := VoxelChunkData.VOLUME
const U_AXIS := [1, 2, 0]
const V_AXIS := [2, 0, 1]
const TILE_MASK := 511
const BLEND_BIT := 512
const COLLISION_BIT := 1024
const LEDGE_SHIFT := 11
const STYLE_SHIFT := LEDGE_SHIFT + 6
const FACE_MASK := (1 << LEDGE_SHIFT) - 1
const TOP_SIDE := 2
const HORIZONTAL_SIDES := 0b110011

var _masks := PackedInt32Array()
var _slices := PackedByteArray()
var _styled_collision_slices := 0
var _result := VoxelMeshPayload.new()


static func preview_surface(block: VoxelCatalog.BakedBlock, connections := 0) -> VoxelMeshPayload.Surface:
	var mesher := VoxelChunkMesher.new()
	if block.cube:
		for side in 6:
			var key := int(block.tiles[side]) + 1
			if block.slot == 1:
				key |= BLEND_BIT
			mesher._add_quad(side, 0, Rect2i(0, 0, 1, 1), key)
	else:
		var model := block.visual_for(connections)
		if model != null:
			mesher._add_model(model, Vector3.ZERO, 0, block.slot)
	return mesher._result.surfaces[block.slot]


func build(
	center: VoxelChunkData,
	neighbors: Array[VoxelChunkData],
	catalog: VoxelCatalog,
	cancel: VoxelCancellation,
	greedy := true
) -> VoxelMeshPayload:
	var uniform := center.uniform_id()
	if uniform == 0:
		return _result
	var boundary_only := false
	if uniform > 0:
		var block := catalog.block(uniform)
		boundary_only = (
			(not block.cube or block.opaque_sides == 63 or block.merge_group != 0)
			and block.visual == null and block.collision == null
		)
		if boundary_only and _uniform_hidden(block, neighbors, catalog):
			return _result
	_masks.resize(6 * VOLUME)
	_slices.resize(6 * SIZE)
	for y in SIZE:
		if cancel.is_cancelled():
			return null
		for z in SIZE:
			for x in SIZE:
				var cell := Vector3i(x, y, z)
				if boundary_only and x > 0 and x < 15 and y > 0 and y < 15 and z > 0 and z < 15:
					continue
				var id := center.id_at(VoxelChunkData.index_of(cell))
				if id != 0:
					_add_cell(cell, catalog.block(id), center, neighbors, catalog, boundary_only)
	for side in 6:
		if cancel.is_cancelled():
			return null
		for depth in SIZE:
			if _slices[side * SIZE + depth] != 0:
				_merge_slice(side, depth, greedy)
	return _result


func _uniform_hidden(
	block: VoxelCatalog.BakedBlock, neighbors: Array[VoxelChunkData], catalog: VoxelCatalog
) -> bool:
	for side in 6:
		var id := neighbors[side].uniform_id()
		if id < 0:
			return false
		var neighbor := catalog.block(id)
		var opposite := 1 << (side ^ 1)
		if block.cube and not _occludes(block, neighbor, opposite):
			return false
		if block.solid_cube and (neighbor.solid_sides & opposite) == 0:
			return false
	return true


func _add_cell(
	cell: Vector3i,
	block: VoxelCatalog.BakedBlock,
	center: VoxelChunkData,
	neighbors: Array[VoxelChunkData],
	catalog: VoxelCatalog,
	boundary_only: bool
) -> void:
	var hidden_visual := 0
	var hidden_collision := 0
	var exposed_cube_sides := 0
	var connections := 0
	var connects := not block.connection_group.is_empty()
	for side in 6:
		@warning_ignore("integer_division")
		var axis := side / 2
		var outside := cell[axis] == (15 if side % 2 == 0 else 0)
		if boundary_only and not outside:
			continue
		var adjacent := cell + VoxelChunkData.DIRECTIONS[side]
		var data := center
		if outside:
			adjacent[axis] &= 15
			data = neighbors[side]
		var neighbor := catalog.block(data.id_at(VoxelChunkData.index_of(adjacent)))
		if connects and axis != Vector3i.AXIS_Y and block.connects_to(neighbor):
			connections |= 1 << side
		var opposite := 1 << (side ^ 1)
		var key := 0
		if _occludes(block, neighbor, opposite):
			hidden_visual |= 1 << side
		elif block.cube:
			key = (int(block.tiles[side]) + 1) | (0 if block.slot == 0 else BLEND_BIT)
			if side == TOP_SIDE:
				key |= block.top_style << STYLE_SHIFT
			exposed_cube_sides |= 1 << side
		if neighbor.solid_sides & opposite:
			hidden_collision |= 1 << side
		elif block.solid_cube:
			key |= COLLISION_BIT
			if side == TOP_SIDE and block.top_style != 0 and key & TILE_MASK:
				_styled_collision_slices |= 1 << cell.y
		if key != 0:
			var slice := side * SIZE + cell[axis]
			var index := slice * AREA + cell[V_AXIS[axis]] * SIZE + cell[U_AXIS[axis]]
			_masks[index] = key
			_slices[slice] = 1
	var ledges := exposed_cube_sides & HORIZONTAL_SIDES
	if ledges != 0 and block.slot == 0 and (exposed_cube_sides & (1 << TOP_SIDE)) != 0:
		# Match the top slice's axes (U = Z, V = X). Its key keeps unlike ledges apart.
		var top_index := (TOP_SIDE * SIZE + cell.y) * AREA + cell.x * SIZE + cell.z
		_masks[top_index] |= ledges << LEDGE_SHIFT
		if _masks[top_index] & COLLISION_BIT:
			_styled_collision_slices |= 1 << cell.y
	if block.visual != null:
		_add_model(block.visual_for(connections), Vector3(cell), hidden_visual, block.slot)
	if block.collision != null:
		_add_model(block.collision_for(connections), Vector3(cell), hidden_collision, -1)


static func _occludes(
	block: VoxelCatalog.BakedBlock, neighbor: VoxelCatalog.BakedBlock, opposite: int
) -> bool:
	return (
		(neighbor.opaque_sides & opposite) != 0
		or (block.merge_group != 0 and block.merge_group == neighbor.merge_group)
	)


func _merge_slice(side: int, depth: int, greedy: bool) -> void:
	var offset := (side * SIZE + depth) * AREA
	if greedy and side == TOP_SIDE and (_styled_collision_slices & (1 << depth)) != 0:
		# Keep collision rectangles independent of edge markings and texture styles.
		var collision_keys := _masks.slice(offset, offset + AREA)
		for index in AREA:
			var key := collision_keys[index]
			collision_keys[index] = key & FACE_MASK if (key & COLLISION_BIT) != 0 else 0
			_masks[offset + index] = key & ~COLLISION_BIT
		_merge_faces(collision_keys, 0, side, depth, greedy, true)
	_merge_faces(_masks, offset, side, depth, greedy)


func _merge_faces(
	keys: PackedInt32Array, offset: int, side: int, depth: int, greedy: bool,
	collision_only := false
) -> void:
	for v in SIZE:
		var u := 0
		while u < SIZE:
			var index := offset + v * SIZE + u
			var key := keys[index]
			if key == 0:
				u += 1
				continue
			var width := 1
			while greedy and u + width < SIZE and keys[index + width] == key:
				width += 1
			var height := 1
			while greedy and v + height < SIZE and _matches(keys, index + height * SIZE, width, key):
				height += 1
			for row in range(1, height):
				for column in width:
					keys[index + row * SIZE + column] = 0
			_add_quad(side, depth, Rect2i(u, v, width, height), key, collision_only)
			u += width


func _matches(keys: PackedInt32Array, start: int, width: int, key: int) -> bool:
	for column in width:
		if keys[start + column] != key:
			return false
	return true


func _add_quad(side: int, depth: int, rect: Rect2i, key: int, collision_only := false) -> void:
	@warning_ignore("integer_division")
	var axis := side / 2
	var positive := side % 2 == 0
	var a := Vector3.ZERO
	var along_u := Vector3.ZERO
	var along_v := Vector3.ZERO
	a[axis] = depth + int(positive)
	a[U_AXIS[axis]] = rect.position.x
	a[V_AXIS[axis]] = rect.position.y
	along_u[U_AXIS[axis]] = rect.size.x
	along_v[V_AXIS[axis]] = rect.size.y
	var b := a + along_u
	var c := b + along_v
	var d := a + along_v
	# Godot uses clockwise front faces.
	if key & COLLISION_BIT:
		_result.collision.append(a)
		_result.collision.append(c if positive else b)
		_result.collision.append(b if positive else c)
		_result.collision.append(a)
		_result.collision.append(d if positive else c)
		_result.collision.append(c if positive else d)
	var layer := (key & TILE_MASK) - 1
	if collision_only or layer < 0:
		return
	var surface := _result.surfaces[int((key & BLEND_BIT) != 0)]
	var start := surface.vertices.size()
	var normal := Vector3(VoxelChunkData.DIRECTIONS[side])
	# The upper bits of UV2.y carry the style table offset. The low six carry ledges.
	var tile := Vector2(layer, (key >> LEDGE_SHIFT) & ((1 << 21) - 1))
	surface.add_vertex(a, normal, project_uv(a, axis), tile)
	surface.add_vertex(b, normal, project_uv(b, axis), tile)
	surface.add_vertex(c, normal, project_uv(c, axis), tile)
	surface.add_vertex(d, normal, project_uv(d, axis), tile)
	surface.indices.append(start)
	surface.indices.append(start + (2 if positive else 1))
	surface.indices.append(start + (1 if positive else 2))
	surface.indices.append(start)
	surface.indices.append(start + (3 if positive else 2))
	surface.indices.append(start + (2 if positive else 3))


static func project_uv(point: Vector3, axis: int) -> Vector2:
	match axis:
		0: return Vector2(point.z, -point.y)
		1: return Vector2(point.x, point.z)
		_: return Vector2(point.x, -point.y)


func _add_model(model: VoxelModel, offset: Vector3, hidden: int, slot: int) -> void:
	for triangle in model.boundaries.size():
		var side := model.boundaries[triangle]
		if side >= 0 and (hidden & (1 << side)) != 0:
			continue
		var start := triangle * 3
		var a := offset + model.vertices[start]
		var b := offset + model.vertices[start + 1]
		var c := offset + model.vertices[start + 2]
		if slot < 0:
			_result.collision.append(a)
			_result.collision.append(b)
			_result.collision.append(c)
		else:
			var surface := _result.surfaces[slot]
			var normal := (c - a).cross(b - a).normalized()
			var tile := Vector2(model.runtime_tiles[triangle], 0)
			var first := surface.vertices.size()
			surface.add_vertex(a, normal, model.uv[start], tile)
			surface.add_vertex(b, normal, model.uv[start + 1], tile)
			surface.add_vertex(c, normal, model.uv[start + 2], tile)
			surface.indices.append(first)
			surface.indices.append(first + 1)
			surface.indices.append(first + 2)
