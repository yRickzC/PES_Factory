class_name VoxelCutawayRegion
extends RefCounted
## Resolves column cut heights from the loaded world and the camera's viewing direction.

const UNCUT := 2147483647
const ROOM_RADIUS := 7
const ROOF_SEARCH := 8
const WALL_REACH := 6
const VIEW_REACH := 20
const DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var _world: VoxelWorld


func _init(world: VoxelWorld) -> void:
	_world = world


func columns(
	feet: Vector3, to_camera: Vector3, head_height: float, sprite_height: float
) -> Dictionary[Vector2i, int]:
	var result: Dictionary[Vector2i, int] = {}
	var center := Vector2i(floori(feet.x), floori(feet.z))
	var head := ceili(feet.y + head_height - 0.025)
	var floor_level := floori(feet.y + 0.025)
	var front_step := _front_step(to_camera)
	var ceiling := _ceiling(center, head)
	var covered := _has_roof_span(center, ceiling, head)
	if covered:
		_cover(result, center, ceiling, floor_level, head)
		_extend_roof(result, center, head)
	_walls(result, feet, center, front_step, to_camera, floor_level, head_height, covered)
	_clear_view(result, feet, center, front_step, to_camera, floor_level, head, sprite_height, covered)
	return result


func _cover(
	result: Dictionary[Vector2i, int], center: Vector2i, ceiling: int,
	floor_level: int, head: int
) -> void:
	var queue: Array[Vector2i] = [center]
	var visited: Dictionary[Vector2i, bool] = {center: true}
	result[center] = ceiling
	var index := 0
	while index < queue.size():
		var column := queue[index]
		index += 1
		for direction: Vector2i in DIRECTIONS:
			var next := column + direction
			if visited.has(next) or (next - center).length_squared() > ROOM_RADIUS * ROOM_RADIUS:
				continue
			visited[next] = true
			var height := _ceiling(next, head)
			if height == UNCUT:
				continue
			# Discover the interior before following the roof across wall tops and eaves.
			var boundary := false
			for y in range(floor_level, height):
				if _solid(next, y):
					boundary = true
					break
			if not boundary:
				queue.append(next)
				result[next] = height


func _extend_roof(result: Dictionary[Vector2i, int], center: Vector2i, head: int) -> void:
	var queue := result.keys()
	var index := 0
	while index < queue.size():
		var column: Vector2i = queue[index]
		index += 1
		var height := result[column]
		for direction: Vector2i in DIRECTIONS:
			var next := column + direction
			if result.has(next) or (next - center).length_squared() > ROOM_RADIUS * ROOM_RADIUS:
				continue
			var edge_height := height
			if not _solid(next, height):
				if height > head and _solid(next, height - 1) and not _solid(next, height - 2):
					edge_height -= 1
				elif height < head + ROOF_SEARCH and _solid(next, height + 1):
					edge_height += 1
				else:
					continue
			queue.append(next)
			result[next] = edge_height


func _walls(
	result: Dictionary[Vector2i, int], feet: Vector3, center: Vector2i, front_step: Vector2i, to_camera: Vector3,
	floor_level: int, head_height: float, covered: bool
) -> void:
	var horizontal := Vector2(to_camera.x, to_camera.z)
	var length := horizontal.length()
	if length < 0.001:
		return
	var forward := horizontal / length
	var slope := to_camera.y / length
	var feet_xz := Vector2(feet.x, feet.z)
	var half_width := absf(forward.x) + absf(forward.y)
	for dz in range(-WALL_REACH, WALL_REACH + 1):
		for dx in range(-WALL_REACH, WALL_REACH + 1):
			var offset := Vector2i(dx, dz)
			if Vector2(offset).dot(forward) <= 0.001 or not _allows_wall_cut(offset, front_step):
				continue
			var column := center + offset
			# Clear the foreground wall at the player's level before checking taller stacks.
			if (offset == front_step and _solid(column, floor_level)
				and (covered or _solid(column, floor_level + 1))):
				result[column] = mini(result.get(column, UNCUT), floor_level)
				continue
			var delta := Vector2(column) + Vector2(0.5, 0.5) - feet_xz
			var depth := delta.dot(forward)
			var sideways := absf(forward.cross(delta))
			if depth < 0.4 or depth > WALL_REACH:
				continue
			if sideways > 0.60 + half_width * 0.5:
				continue
			var lowest := floori(feet.y + maxf(0.0, depth - half_width * 0.5) * slope + 0.25)
			var highest := floori(feet.y + (depth + half_width * 0.5) * slope + head_height)
			# An isolated platform aloft is handled by the roof rule. Cut stacks rising from this floor.
			if not _solid(column, floor_level) or not _solid(column, floor_level + 1):
				continue
			for y in range(floor_level + 1, mini(highest, floor_level + ROOF_SEARCH) + 1):
				if not _solid(column, y):
					break
				if y >= lowest:
					result[column] = mini(result.get(column, UNCUT), floor_level + 1)
					break


func _clear_view(
	result: Dictionary[Vector2i, int], feet: Vector3, center: Vector2i, front_step: Vector2i, to_camera: Vector3,
	floor_level: int, head: int, sprite_height: float, covered: bool
) -> void:
	var horizontal := Vector2(to_camera.x, to_camera.z)
	var distance := horizontal.length()
	if distance < 0.001 or to_camera.y <= 0.0:
		return
	var forward := horizontal / distance
	var reach := minf(distance, VIEW_REACH)
	var slope := to_camera.y / distance
	var start := Vector2(feet.x, feet.z)
	var end := start + forward * reach
	var lower := Vector2i((start.min(end) - Vector2.ONE).floor())
	var upper := Vector2i((start.max(end) + Vector2.ONE).floor())
	var half_tile := (absf(forward.x) + absf(forward.y)) * 0.5
	for z in range(lower.y, upper.y + 1):
		for x in range(lower.x, upper.x + 1):
			var column := Vector2i(x, z)
			var offset := column - center
			if offset != Vector2i.ZERO and not _allows_wall_cut(offset, front_step):
				continue
			var delta := Vector2(column) + Vector2(0.5, 0.5) - start
			var depth := delta.dot(forward)
			var near_edge := maxf(0.0, depth - half_tile)
			var far_edge := minf(reach, depth + half_tile)
			if near_edge >= far_edge or absf(forward.cross(delta)) > 0.30 + half_tile:
				continue
			# Follow the projected silhouette all the way out of an excavation.
			var low := floori(feet.y + 0.15 + near_edge * slope)
			var high := floori(feet.y + sprite_height + far_edge * slope)
			if offset != front_step:
				low = maxi(low, floor_level + 1)
			if column == center:
				low = maxi(low, head)
			for y in range(low, mini(high + 1, result.get(column, UNCUT))):
				if not _solid(column, y):
					continue
				# Below the player's level the terrain supports a step but adds no wall height.
				if covered or _solid(column, y + 1) or (y > floor_level and _solid(column, y - 1)):
					result[column] = y
					break


func _front_step(view: Vector3) -> Vector2i:
	if absf(view.x) > absf(view.z):
		return Vector2i(int(signf(view.x)), 0)
	return Vector2i(0, int(signf(view.z)))


func _allows_wall_cut(offset: Vector2i, front_step: Vector2i) -> bool:
	# In the immediate 3×3 neighborhood, restrict wall cuts to the central foreground tile.
	return offset == front_step or maxi(absi(offset.x), absi(offset.y)) > 1


func _has_roof_span(center: Vector2i, ceiling: int, head: int) -> bool:
	if ceiling == UNCUT:
		return false
	var covered_neighbors := 0
	for direction: Vector2i in DIRECTIONS:
		for y in range(maxi(head, ceiling - 1), ceiling + 2):
			if _solid(center + direction, y):
				covered_neighbors += 1
				if covered_neighbors == 2:
					return true
				break
	return false


func _ceiling(column: Vector2i, head: int) -> int:
	for height in range(head, head + ROOF_SEARCH + 1):
		if _solid(column, height):
			return height
	return UNCUT


func _solid(column: Vector2i, height: int) -> bool:
	var block := _world.block_at(Vector3i(column.x, height, column.y))
	return block != null and (block.solid_cube or block.collision != null)
