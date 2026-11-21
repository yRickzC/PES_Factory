class_name WildlifePopulation
extends Node3D
## Activates seed-based groups in streamed terrain around the observer.

const REGION_SIZE := VoxelChunkData.SIZE
const COLLISION_LAYER := 8
const SPAWN_CLEARANCE := 0.035

@export_range(0.1, 5.0, 0.05) var scan_interval := 0.75
@export_flags_3d_physics var spawn_collision_mask := 15

var _world: VoxelWorld
var _generator: VoxelHeightmapGenerator
var _observer: Node3D
var _texture_lookup: Callable
var _species: Array[Species] = []
var _cooldown := 0.0
var _clearance := PhysicsShapeQueryParameters3D.new()


class Species:
	var salt: int
	var definition: ContentScene
	var shape_bounds: AABB
	var visited: Dictionary[Vector2i, Vector3i] = {}
	var actors: Array[WildlifeActor] = []


func _ready() -> void:
	set_physics_process(false)


func configure(
	world: VoxelWorld, generator: VoxelHeightmapGenerator, observer: Node3D,
	registry: ContentRegistry, texture_lookup: Callable
) -> void:
	_world = world
	_generator = generator
	_observer = observer
	_texture_lookup = texture_lookup
	_clearance.collision_mask = spawn_collision_mask
	for id in registry.ids():
		var definition := registry.find(id) as ContentScene
		if definition == null or definition.wildlife == null or definition.collision == null:
			continue
		if definition.wildlife.chance_by_biome.is_empty() or definition.collision.shape == null:
			continue
		var species := Species.new()
		species.salt = hash(id) ^ _generator.world_seed
		species.definition = definition
		species.shape_bounds = definition.collision.shape.get_debug_mesh().get_aabb()
		_species.append(species)
	set_physics_process(not _species.is_empty())


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_cooldown = scan_interval
	var observer := _world.to_local(_observer.global_position)
	var center := _region_at(observer)
	for species in _species:
		_refresh(species, observer, center)


func _refresh(species: Species, observer: Vector3, center: Vector2i) -> void:
	var profile := species.definition.wildlife
	var unload_radius := maxf(profile.spawn_distance, profile.unload_distance)
	for region in species.visited.keys():
		var anchor := species.visited[region]
		if observer.distance_squared_to(Vector3(anchor) + Vector3(0.5, 1.0, 0.5)) > unload_radius * unload_radius:
			species.visited.erase(region)
	var counts: Dictionary[Vector2i, int] = {}
	for index in range(species.actors.size() - 1, -1, -1):
		var actor := species.actors[index]
		if not is_instance_valid(actor):
			species.actors.remove_at(index)
		elif actor.health > 0 and not actor.is_queued_for_deletion():
			var region := _region_at(_world.to_local(actor.global_position))
			counts[region] = counts.get(region, 0) + 1
	var radius := ceili(profile.spawn_distance / REGION_SIZE)
	for z in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var region := Vector2i(x, z)
			if not species.visited.has(region):
				_try_region(species, region, observer, profile.region_limit - counts.get(region, 0))


func _try_region(species: Species, region: Vector2i, observer: Vector3, capacity: int) -> void:
	var profile := species.definition.wildlife
	var low := maxi(1, mini(profile.group_size.x, profile.group_size.y))
	var high := mini(capacity, maxi(profile.group_size.x, profile.group_size.y))
	if high < low:
		return
	var seed_value := hash(Vector3i(region.x, species.salt, region.y))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var margin := mini(profile.group_radius, (REGION_SIZE >> 1) - 1)
	var anchor := region * REGION_SIZE + Vector2i(
		rng.randi_range(margin, REGION_SIZE - margin - 1), rng.randi_range(margin, REGION_SIZE - margin - 1)
	)
	var planar_offset := Vector2(anchor) + Vector2.ONE * 0.5 - Vector2(observer.x, observer.z)
	if planar_offset.length_squared() > profile.spawn_distance * profile.spawn_distance:
		return
	var column := _generator.sample_column(anchor.x, anchor.y)
	var support := Vector3i(anchor.x, column.x, anchor.y)
	if (
		not _in_spawn_range(observer, _spawn_position(support), profile)
		or not WildlifeActor.cell_ready(_world, support)
	):
		return
	var biome := _generator.biomes[column.y].key
	var chance: float = profile.chance_by_biome.get(biome, 0.0)
	if rng.randf() >= chance:
		species.visited[region] = support
		return
	var requested := rng.randi_range(low, high)
	var candidates: Array[Vector3] = []
	var occupied: Array[AABB] = []
	var tested: Dictionary[Vector2i, bool] = {}
	var pending := false
	var collision := species.definition.collision
	_clearance.shape = collision.shape
	var space := _world.get_world_3d().direct_space_state
	var bounds := Rect2i(region * REGION_SIZE, Vector2i.ONE * REGION_SIZE)
	for index in profile.group_attempts:
		var offset := Vector2i.ZERO if index == 0 else Vector2i(
			rng.randi_range(-profile.group_radius, profile.group_radius),
			rng.randi_range(-profile.group_radius, profile.group_radius)
		)
		var cell := anchor + offset
		if tested.has(cell) or offset.length_squared() > profile.group_radius * profile.group_radius:
			continue
		if not bounds.has_point(cell):
			continue
		tested[cell] = true
		var sample := _generator.sample_column(cell.x, cell.y)
		var floor_cell := Vector3i(cell.x, sample.x, cell.y)
		var feet := floor_cell + Vector3i.UP
		var spawn_point := _spawn_position(floor_cell)
		if not _in_spawn_range(observer, spawn_point, profile):
			pending = true
			continue
		if (
			sample.x < profile.elevation.x or sample.x > profile.elevation.y
			or absi(sample.x - column.x) > profile.max_spawn_slope
			or not _slope_allows(cell, sample.x, profile.max_spawn_slope)
			or _generator.column_is_flooded(sample)
			or profile.chance_by_biome.get(_generator.biomes[sample.y].key, 0.0) <= 0.0
		):
			continue
		if not WildlifeActor.cell_ready(_world, floor_cell) or not WildlifeActor.cell_ready(_world, feet):
			pending = true
			continue
		if _world.get_block(feet) != 0 or not WildlifeActor.solid_ground(_world, floor_cell):
			continue
		if not profile.spawn_ground.is_empty() and _world.get_block_key(floor_cell) not in profile.spawn_ground:
			continue
		var shape_center := spawn_point + collision.offset
		var footprint := species.shape_bounds
		footprint.position += shape_center
		if _overlaps_group(footprint, occupied):
			continue
		_clearance.transform = _world.global_transform * Transform3D(Basis.IDENTITY, shape_center)
		if not space.intersect_shape(_clearance, 1).is_empty():
			continue
		candidates.append(spawn_point)
		occupied.append(footprint)
		if candidates.size() == requested:
			break
	if candidates.size() < low and pending:
		return
	species.visited[region] = support
	if candidates.size() < low:
		return
	var group: Array[WildlifeActor] = []
	for spawn_point in candidates:
		var actor := WildlifeActor.new()
		actor.configure(species.definition, _world, _observer, group, _texture_lookup, rng.randi())
		actor.position = spawn_point
		add_child(actor)
		species.actors.append(actor)


func _slope_allows(cell: Vector2i, height: int, max_slope: int) -> bool:
	for side: Vector3i in WildlifeActor.CARDINALS:
		var sample := _generator.sample_column(cell.x + side.x, cell.y + side.z)
		if absi(sample.x - height) > max_slope:
			return false
	return true


static func _region_at(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / REGION_SIZE), floori(point.z / REGION_SIZE))


static func _spawn_position(support: Vector3i) -> Vector3:
	return Vector3(support) + Vector3(0.5, 1.0 + SPAWN_CLEARANCE, 0.5)


static func _in_spawn_range(observer: Vector3, point: Vector3, profile: WildlifeProfile) -> bool:
	var distance := observer.distance_squared_to(point)
	return distance >= profile.spawn_min_distance * profile.spawn_min_distance and (
		distance <= profile.spawn_distance * profile.spawn_distance
	)


static func _overlaps_group(footprint: AABB, occupied: Array[AABB]) -> bool:
	for other in occupied:
		if footprint.intersects(other):
			return true
	return false
