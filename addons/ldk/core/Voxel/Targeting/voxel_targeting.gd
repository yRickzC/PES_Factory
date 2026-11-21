class_name VoxelTargeting
extends RefCounted
## Resolves voxel selection and directional melee queries against the shared world.

const OFFSET := 0.001
const ConstructionConfig = preload("res://addons/ldk/core/Voxel/Targeting/voxel_construction_config.gd")

var valid := false
var can_place := false
var out_of_range := false
var cell: Vector3i
var adjacent: Vector3i
var face: Vector3i
var placement_face: Vector3i
var normal: Vector3
var local_point: Vector3
var distance: float
var whole_block := false
var prop_valid := false
var prop_support: Vector3i

var _ray := PhysicsRayQueryParameters3D.new()
var _placement_query := PhysicsShapeQueryParameters3D.new()
var _melee_query := PhysicsShapeQueryParameters3D.new()
var _melee_ray := PhysicsRayQueryParameters3D.new()
var _melee_box := BoxShape3D.new()
var _interaction_mask: int
var _prop_mask: int


func configure(terrain_mask: int, prop_mask: int, excluded: Array[RID], extra_placement_mask := 0) -> void:
	_interaction_mask = terrain_mask | prop_mask
	_prop_mask = prop_mask
	_ray.exclude = excluded
	_melee_ray.exclude = excluded
	_melee_query.exclude = excluded
	_melee_query.shape = _melee_box
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * (1.0 - 2.0 * OFFSET)
	_placement_query.shape = shape
	_placement_query.collision_mask = prop_mask | extra_placement_mask
	_placement_query.exclude = excluded


func clear() -> void:
	valid = false
	can_place = false
	out_of_range = false
	prop_valid = false
	placement_face = Vector3i.ZERO


func aim_melee(
	space: PhysicsDirectSpaceState3D, camera_origin: Vector3, camera_direction: Vector3,
	feet: Vector3, fallback: Vector3, weapon: MeleeWeapon
) -> Vector3:
	var origin := feet + Vector3.UP * weapon.origin_height
	var projection: Variant = Plane(Vector3.UP, origin.y).intersects_ray(camera_origin, camera_direction)
	if projection == null:
		return fallback
	var point: Vector3 = projection
	# Prefer the shape under the mouse when it is visible from the camera.
	if camera_direction.y < -OFFSET:
		_melee_ray.collision_mask = _interaction_mask | weapon.target_mask
		_melee_ray.from = camera_origin
		_melee_ray.to = point + camera_direction * (weapon.origin_height / -camera_direction.y)
		var hit := space.intersect_ray(_melee_ray)
		var body := hit.get("collider") as CollisionObject3D
		if body != null and body.has_method(&"take_damage"):
			point = _shape_center(body, int(hit.shape))
	var direction := point - origin
	direction.y = 0.0
	return fallback if direction.length_squared() < OFFSET else direction.normalized()


func melee_hits(
	space: PhysicsDirectSpaceState3D, feet: Vector3, heading: Vector3,
	weapon: MeleeWeapon, window: Vector2, previous_hits: Dictionary[int, bool]
) -> Array[Dictionary]:
	var contacts: Array[Dictionary] = []
	if heading.is_zero_approx():
		return contacts
	var origin := feet + Vector3.UP * weapon.origin_height
	var first := weapon.sweep_direction(heading, window.x)
	var last := weapon.sweep_direction(heading, window.y)
	var spacing := atan2(weapon.sweep_width * 0.5, weapon.reach)
	var steps := maxi(1, ceili(first.angle_to(last) / spacing))
	var size := Vector3(weapon.sweep_width, weapon.hit_height, weapon.reach)
	if _melee_box.size != size:
		_melee_box.size = size
	_melee_query.collision_mask = weapon.target_mask
	_melee_ray.collision_mask = _interaction_mask
	var found: Dictionary[int, bool] = {}
	for step in steps + 1:
		var elapsed := lerpf(window.x, window.y, float(step) / steps)
		var direction := weapon.sweep_direction(heading, elapsed)
		var center := origin + direction * weapon.reach * 0.5
		_melee_query.transform = Transform3D(Basis.looking_at(direction), center)
		for hit in space.intersect_shape(_melee_query, 32):
			var body := hit.collider as CollisionObject3D
			if body == null or body.is_queued_for_deletion() or not body.has_method(&"take_damage"):
				continue
			var id := body.get_instance_id()
			if previous_hits.has(id) or found.has(id):
				continue
			var point := _shape_center(body, int(hit.shape))
			_melee_ray.from = origin
			_melee_ray.to = point
			var obstruction := space.intersect_ray(_melee_ray)
			if not obstruction.is_empty() and obstruction.collider != body:
				continue
			found[id] = true
			contacts.append({"body": body, "position": point})
	return contacts


static func _shape_center(body: CollisionObject3D, index: int) -> Vector3:
	var owner := body.shape_find_owner(index)
	return body.to_global(body.shape_owner_get_transform(owner).origin)


func pick_layer(
	world: VoxelWorld, origin: Vector3, direction: Vector3, feet: Vector3,
	layer: int, config: ConstructionConfig
) -> void:
	clear()
	var height := float(layer) + config.cursor_plane_height
	var local_direction := world.global_basis.inverse() * direction
	var hit: Variant = Plane(Vector3.UP, height).intersects_ray(world.to_local(origin), local_direction)
	if hit == null:
		return
	local_point = hit
	adjacent = Vector3i(floori(local_point.x), layer, floori(local_point.z))
	var center := world.to_global(Vector3(adjacent) + Vector3.ONE * 0.5)
	distance = feet.distance_to(center)
	can_place = distance <= config.reach + OFFSET
	if not can_place and world.is_chunk_ready(VoxelChunkData.chunk_of(adjacent)):
		cell = adjacent
		face = Vector3i.UP
		local_point.y = float(layer)
		out_of_range = true


func placement_clear(space: PhysicsDirectSpaceState3D, world: VoxelWorld, destination: Vector3i) -> bool:
	if _placement_query.collision_mask == 0:
		return true
	# Test the destination itself so intervening geometry cannot block layer placement.
	var center := Vector3(destination) + Vector3.ONE * 0.5
	_placement_query.transform = world.global_transform * Transform3D(Basis.IDENTITY, center)
	return space.intersect_shape(_placement_query, 1).is_empty()


func pick(
	space: PhysicsDirectSpaceState3D, world: VoxelWorld, origin: Vector3, direction: Vector3,
	actor: Vector3, config: VoxelTargetingConfig, hidden: Callable,
	props: VoxelPropView = null, ray_length := 0.0
) -> void:
	var previous_placement := placement_face if valid else Vector3i.ZERO
	clear()
	# Pick what the camera sees first, then evaluate interaction reach from the actor.
	var limit := ray_length if ray_length > 0.0 else origin.distance_to(actor) + config.reach
	var prop := {}
	if props != null and _prop_mask != 0:
		prop = props.pick_sprite(origin, direction, limit)
		if not prop.is_empty():
			limit = prop.depth
		_ray.collision_mask = _prop_mask
		_ray.from = origin
		_ray.to = origin + direction * limit
		var body := space.intersect_ray(_ray)
		if not body.is_empty():
			var depth := origin.distance_to(body.position)
			var hit := props.body_hit(body.collider as Node, depth)
			if not hit.is_empty():
				prop = hit
				limit = depth
	var start := world.to_local(origin)
	var end := world.to_local(origin + direction * limit)
	var length := start.distance_to(end)
	if is_zero_approx(length):
		return
	var along := (end - start) / length
	var struck := Vector3i(start.floor())
	var step := Vector3i(along.sign())
	var next_crossing := Vector3(INF, INF, INF)
	var crossing_interval := Vector3.ZERO
	for axis in 3:
		if is_zero_approx(along[axis]):
			continue
		var boundary := struck[axis] + int(step[axis] > 0)
		next_crossing[axis] = (boundary - start[axis]) / along[axis]
		crossing_interval[axis] = absf(1.0 / along[axis])
	var travel := 0.0
	var entered_face := Vector3.ZERO
	while travel <= length:
		var block := world.block_at(struck)
		if block != null and world.is_chunk_ready(VoxelChunkData.chunk_of(struck)):
			if not hidden.is_valid() or not hidden.call(struck):
				if block.cube and (block.solid_cube or config.select_non_solid) and entered_face != Vector3.ZERO:
					normal = entered_face
					local_point = start + along * travel
					whole_block = false
					_select(space, world, origin, actor, config, struck, previous_placement)
					return
				if block.visual != null and (block.collision != null or config.select_non_solid):
					var model := block.visual_for(world.connections_at(struck, block))
					if _model_hit(model, struck, start, end, along):
						whole_block = true
						_select(space, world, origin, actor, config, struck, previous_placement)
						return
		var move_axis := next_crossing.min_axis_index()
		travel = next_crossing[move_axis]
		if travel > length:
			break
		# Step all tied axes at edges and corners so zero-width cells are never picked.
		for axis in 3:
			if absf(next_crossing[axis] - travel) <= 0.000001:
				struck[axis] += step[axis]
				next_crossing[axis] += crossing_interval[axis]
		entered_face = Vector3.ZERO
		entered_face[move_axis] = -step[move_axis]
	if not prop.is_empty():
		_select_prop(space, props, prop, actor, origin + direction * limit, config.reach)


func _select_prop(
	space: PhysicsDirectSpaceState3D, props: VoxelPropView, hit: Dictionary,
	actor: Vector3, point: Vector3, reach: float
) -> void:
	var definition := props.definition_at(hit.support)
	if definition == null or definition.breakable == null:
		return
	distance = actor.distance_to(point)
	if distance > reach + OFFSET:
		cell = hit.support
		face = Vector3i.UP
		local_point = Vector3(cell) + Vector3(0.5, 1.0, 0.5)
		out_of_range = true
		return
	_ray.collision_mask = _interaction_mask
	_ray.from = actor
	_ray.to = point
	var obstruction := space.intersect_ray(_ray)
	var root: Node3D = hit.root
	if not obstruction.is_empty():
		var body := obstruction.collider as Node
		if root == null or body == null or (body != root and not root.is_ancestor_of(body)):
			return
	prop_support = hit.support
	prop_valid = true


func _model_hit(model: VoxelModel, struck: Vector3i, start: Vector3, end: Vector3, along: Vector3) -> bool:
	var offset := Vector3(struck)
	var local_start := start - offset
	var local_end := end - offset
	var nearest := INF
	for i in range(0, model.vertices.size(), 3):
		var a := model.vertices[i]
		var b := model.vertices[i + 1]
		var c := model.vertices[i + 2]
		var outward := (c - a).cross(b - a).normalized()
		if outward.dot(along) >= 0.0:
			continue
		var point: Variant = Geometry3D.segment_intersects_triangle(local_start, local_end, a, b, c)
		if point == null:
			continue
		var depth := start.distance_squared_to(offset + Vector3(point))
		if depth < nearest:
			nearest = depth
			local_point = offset + Vector3(point)
			normal = outward
	return nearest < INF


func _select(
	space: PhysicsDirectSpaceState3D, world: VoxelWorld, origin: Vector3, actor: Vector3,
	config: VoxelTargetingConfig, struck: Vector3i, previous_placement: Vector3i
) -> void:
	var point := world.to_global(local_point)
	distance = actor.distance_to(point)
	var axis := normal.abs().max_axis_index()
	if is_equal_approx(absf(normal.y), absf(normal[axis])):
		axis = Vector3.AXIS_Y
	var hit_face := Vector3i.ZERO
	hit_face[axis] = int(signf(normal[axis]))
	if distance > config.reach + OFFSET:
		cell = struck
		face = hit_face
		out_of_range = true
		return
	if _prop_mask != 0:
		_ray.collision_mask = _prop_mask
		_ray.from = origin
		_ray.to = point
		if not space.intersect_ray(_ray).is_empty():
			return
	# The camera can see through the cutaway. Interaction still respects physical obstacles.
	_ray.collision_mask = _interaction_mask
	_ray.from = actor
	_ray.to = point
	var obstruction := space.intersect_ray(_ray)
	if not obstruction.is_empty():
		var inward: Vector3 = obstruction.position - obstruction.normal * 0.01
		var blocked_cell := Vector3i(world.to_local(inward).floor())
		if blocked_cell != struck and Vector3(obstruction.position).distance_squared_to(point) >= 0.0004:
			return
	var previous := previous_placement if cell == struck and face == hit_face else Vector3i.ZERO
	cell = struck
	face = hit_face
	placement_face = placement_face_at(face, local_point - Vector3(cell), previous, config)
	adjacent = cell + placement_face
	if config.place_over_side_neighbor and face == Vector3i.UP and placement_face.y == 0:
		var neighbor := world.block_at(adjacent)
		if neighbor != null and (neighbor.solid_cube or neighbor.collision != null):
			adjacent += Vector3i.UP
	var destination := world.to_global(Vector3(adjacent) + Vector3.ONE * 0.5)
	can_place = actor.distance_to(destination) <= config.placement_distance + OFFSET
	valid = true


static func placement_face_at(
	surface: Vector3i, point: Vector3, previous: Vector3i, config: VoxelTargetingConfig
) -> Vector3i:
	if config.aim_mode != VoxelTargetingConfig.AimMode.CURSOR or surface == Vector3i.DOWN:
		return surface
	var p := point.clamp(Vector3.ZERO, Vector3.ONE)
	if surface != Vector3i.UP:
		var bottom := _edge_score(
			p.y, config.bottom_edge_width, Vector3i.DOWN, surface, previous, config.face_hysteresis
		)
		return Vector3i.DOWN if bottom <= 0.0 else surface
	var x_face := Vector3i.LEFT if p.x < 0.5 else Vector3i.RIGHT
	var z_face := Vector3i.FORWARD if p.z < 0.5 else Vector3i.BACK
	var x_gap := minf(p.x, 1.0 - p.x)
	var z_gap := minf(p.z, 1.0 - p.z)
	var x_score := _edge_score(
		x_gap, config.side_edge_width, x_face, surface, previous, config.face_hysteresis
	)
	var z_score := _edge_score(
		z_gap, config.side_edge_width, z_face, surface, previous, config.face_hysteresis
	)
	if minf(x_score, z_score) > 0.0:
		return surface
	if x_score <= 0.0 and z_score <= 0.0 and (
		absf(x_score - z_score) <= config.face_hysteresis
	):
		if previous == x_face or previous == z_face:
			return previous
		match config.corner_priority:
			VoxelTargetingConfig.CornerPriority.X_AXIS:
				return x_face
			VoxelTargetingConfig.CornerPriority.Z_AXIS:
				return z_face
	return x_face if x_score <= z_score else z_face


static func _edge_score(
	gap: float, width: float, edge: Vector3i, surface: Vector3i, previous: Vector3i, hysteresis: float
) -> float:
	if width <= 0.0:
		return INF
	# Require a deeper crossing to enter a band and allow a small retreat before leaving it.
	var margin := minf(hysteresis, width * 0.5)
	if previous == edge:
		return gap - width - margin
	if previous == surface:
		return gap - width + margin
	return gap - width
