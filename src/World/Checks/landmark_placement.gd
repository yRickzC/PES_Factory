extends VoxelBiomePlacement

const GARDEN := [Vector2i(-5, -1), Vector2i(7, -3), Vector2i(-6, 6), Vector2i(10, 7)]


func for_chunk(coord: Vector3i) -> Dictionary[Vector3i, ContentScene]:
	var placements := super.for_chunk(coord)
	var bounds := Rect2i(Vector2i(coord.x, coord.z) * VoxelChunkData.SIZE, Vector2i.ONE * VoxelChunkData.SIZE)
	for anchor: Vector2i in GARDEN:
		if bounds.has_point(anchor):
			place(placements, anchor, coord, 0, 0)
	return placements


func allows_procedural(anchor: Vector2i) -> bool:
	return anchor.distance_squared_to(Vector2i(5, 2)) >= 19 * 19



func spawn_sample(roll: int) -> float:
	# Preserve which grid cells spawned trees in the original seed at 80%.
	return (float(posmod(roll - 1, 5)) + super.spawn_sample(roll)) / 5.0
