class_name WildlifeActor
extends CharacterBody3D
## Simulation for passive wildlife. No world edits or save records are produced.

const State = ActorStateMachine.State
const CARDINALS := [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]
const SHORE_REACHED_SQUARED := 0.09

var health: int
var _profile: WildlifeProfile
var _world: VoxelWorld
var _observer: Node3D
var _group: Array[WildlifeActor]
var _appearance: Node3D
var _view: WildlifeView
var _machine := ActorStateMachine.new()
var _hit_feedback: HitFeedback
var _hit_feedback_view: HitFeedbackView
var _rng := RandomNumberGenerator.new()
var _duration := 0.0
var _heading := Vector3.ZERO
var _facing := Vector3.BACK
var _shore_cell := Vector3i.ZERO
var _shore_point := Vector3.ZERO
var _seeking_shore := false
var _unload_distance_squared: float


func configure(
	definition: ContentScene, world: VoxelWorld, observer: Node3D,
	group: Array[WildlifeActor], texture_lookup: Callable, seed_value: int
) -> void:
	_profile = definition.wildlife
	_world = world
	_observer = observer
	_group = group
	_group.append(self)
	_rng.seed = seed_value
	health = _profile.max_health
	_unload_distance_squared = pow(maxf(_profile.spawn_distance, _profile.unload_distance), 2)
	var collision := definition.collision
	collision_layer = collision.layers
	collision_mask = collision.mask
	var collider := CollisionShape3D.new()
	collider.shape = collision.shape
	collider.position = collision.offset
	add_child(collider)
	if definition.visual != null:
		_appearance = definition.visual.instantiate(texture_lookup)
		if _appearance != null:
			add_child(_appearance)
			_view = _appearance as WildlifeView
	floor_snap_length = 0.2
	_facing = _random_heading()
	_enter(State.IDLE, _seconds(_profile.idle_seconds))


func take_damage(amount: int, source_position: Vector3) -> bool:
	if amount <= 0 or health == 0 or is_queued_for_deletion():
		return false
	health = maxi(0, health - amount)
	var away := _horizontal(global_position - source_position).normalized()
	_apply_hit_feedback(away)
	if health == 0:
		# The corpse still uses its mask to collide with the terrain during knockback.
		set_deferred("collision_layer", 0)
		velocity = Vector3.ZERO
		_enter(State.DEAD, _profile.death_seconds)
	else:
		_heading = _random_heading() if away.is_zero_approx() else away
		_enter(State.FLEE, _seconds(_profile.flee_seconds))
	return true


func _apply_hit_feedback(away: Vector3) -> void:
	var profile := _profile.hit_feedback
	if profile == null:
		return
	if _hit_feedback == null:
		_hit_feedback = HitFeedback.new()
	_hit_feedback.receive(profile, _machine, away)
	if _appearance != null:
		if _hit_feedback_view == null:
			_hit_feedback_view = HitFeedbackView.new(_appearance)
		_hit_feedback_view.receive(profile)


func _exit_tree() -> void:
	_group.erase(self)


func _physics_process(delta: float) -> void:
	var feet := _feet_cell()
	if (
		not is_instance_valid(_observer)
		or global_position.distance_squared_to(_observer.global_position) > _unload_distance_squared
		or not cell_ready(_world, feet)
		or not cell_ready(_world, feet + Vector3i.DOWN)
	):
		queue_free()
		return
	if _hit_feedback_view != null:
		_hit_feedback_view.advance(delta)
	var knockback := _hit_feedback.step_knockback(delta) if _hit_feedback != null else Vector3.ZERO
	if _machine.state == State.DEAD and knockback.is_zero_approx() and collision_mask != 0:
		collision_mask = 0
	if _machine.consume_hitstop(delta):
		# The impact still moves the body while the voluntary motion and pose are held.
		if not knockback.is_zero_approx():
			_slide(knockback, delta)
		return
	_machine.elapse(delta)
	if _machine.elapsed >= _duration:
		match _machine.state:
			State.DEAD:
				queue_free()
				return
			State.IDLE:
				_choose_activity()
			_:
				_rest()
	if _machine.state != State.DEAD or not knockback.is_zero_approx():
		_move(delta, knockback)
	if _view != null:
		var moving := _horizontal(get_real_velocity()).length_squared() > 0.01
		_view.present(_facing, _machine.state, _machine.elapsed, _duration, moving)


func _move(delta: float, knockback: Vector3) -> void:
	var desired := Vector3.ZERO
	var horizontal := knockback
	if horizontal.is_zero_approx():
		if _machine.state == State.WANDER or _machine.state == State.FLEE:
			desired = _steer()
		horizontal = _horizontal(velocity).move_toward(desired, _profile.acceleration * delta)
		if not horizontal.is_zero_approx() and not _can_move(horizontal.normalized()):
			horizontal = Vector3.ZERO
	_slide(horizontal, delta)
	var actual := _horizontal(get_real_velocity())
	if actual.length_squared() > 0.01 and (_machine.state == State.WANDER or _machine.state == State.FLEE):
		_facing = actual.normalized()
	elif not desired.is_zero_approx() and is_on_wall():
		_seeking_shore = false
		_heading = _heading.rotated(Vector3.UP, PI * 0.5 * (-1.0 if _rng.randf() < 0.5 else 1.0))


func _slide(horizontal: Vector3, delta: float) -> void:
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	var grounded := is_on_floor()
	if not grounded:
		velocity += get_gravity() * delta
	var landing_speed := -velocity.y
	move_and_slide()
	if health > 0 and not grounded and is_on_floor() and landing_speed > _profile.safe_landing_speed:
		var damage := (landing_speed - _profile.safe_landing_speed) * _profile.fall_damage_per_speed
		take_damage(ceili(damage), global_position)


func _choose_activity() -> void:
	var feet := _feet_cell()
	if _rng.randf() < _profile.cooling_chance and _find_shore(feet):
		_seeking_shore = true
	elif _rng.randf() < _profile.forage_chance and _surface_has(feet, _profile.forage_ground):
		_enter(State.FORAGE, _seconds(_profile.forage_seconds))
		return
	_heading = _random_heading()
	var toward_group := _toward_group()
	if toward_group.length_squared() > pow(_profile.cohesion_distance, 2):
		var blended := _heading.lerp(toward_group.normalized(), _profile.cohesion_strength)
		if not blended.is_zero_approx():
			_heading = blended.normalized()
	var duration := _seconds(_profile.wander_seconds)
	if _seeking_shore:
		duration = maxf(duration, _horizontal(_shore_point - global_position).length() / _profile.walk_speed + 0.5)
	_enter(State.WANDER, duration)


func _steer() -> Vector3:
	var fleeing := _machine.state == State.FLEE
	if _seeking_shore:
		var toward := _horizontal(_shore_point - global_position)
		if toward.length_squared() <= SHORE_REACHED_SQUARED:
			var water := _world.to_global(Vector3(_shore_cell) + Vector3.ONE * 0.5)
			_facing = _horizontal(water - global_position).normalized()
			_enter(State.FORAGE, _seconds(_profile.cooling_seconds))
			return Vector3.ZERO
		_heading = toward.normalized()
	var speed := _profile.flee_speed if fleeing else _profile.walk_speed
	if _can_move(_heading):
		return _heading * speed
	_seeking_shore = false
	var turn := PI / 3.0
	for angle: float in [turn, -turn, 2.0 * turn, -2.0 * turn]:
		var alternative := _heading.rotated(Vector3.UP, angle)
		if _can_move(alternative):
			_heading = alternative
			return _heading * speed
	if not fleeing:
		_rest()
	return Vector3.ZERO


func _find_shore(feet: Vector3i) -> bool:
	if _profile.cooling_blocks.is_empty():
		return false
	# Look down traversable strips at the current elevation to reach dry banks.
	var best_distance := _profile.cooling_search_cells + 1
	var found := false
	for side: Vector3i in CARDINALS:
		var bank := feet
		for distance in range(1, best_distance):
			var next := feet + side * distance
			if not cell_ready(_world, next) or not cell_ready(_world, next + Vector3i.DOWN):
				break
			if _world.get_block_key(next) in _profile.cooling_blocks or (
				_world.get_block(next) == 0 and _surface_has(next, _profile.cooling_blocks)
			):
				best_distance = distance
				_shore_cell = next
				_shore_point = _world.to_global(Vector3(bank) + Vector3(0.5, 0.0, 0.5))
				found = true
				break
			if _world.get_block(next) != 0 or not solid_ground(_world, next + Vector3i.DOWN):
				break
			bank = next
	return found


func _can_move(direction: Vector3) -> bool:
	var ahead := _feet_cell(global_position + direction * _profile.ground_probe_distance)
	var current := _feet_cell()
	if ahead == current:
		return true
	if not cell_ready(_world, ahead) or _world.get_block(ahead) != 0:
		return false
	for depth in _profile.max_step_down + 1:
		var support := ahead + Vector3i.DOWN * (depth + 1)
		if not cell_ready(_world, support):
			return false
		if _world.get_block(support) != 0:
			return solid_ground(_world, support)
	return false


func _toward_group() -> Vector3:
	var center := Vector3.ZERO
	var count := 0
	for member in _group:
		if member != self and member.health > 0 and not member.is_queued_for_deletion():
			center += member.global_position
			count += 1
	return _horizontal(center / count - global_position) if count > 0 else Vector3.ZERO


func _rest() -> void:
	_enter(State.IDLE, _seconds(_profile.idle_seconds))


func _enter(state: ActorStateMachine.State, duration: float) -> void:
	_machine.transition_to(state, true)
	_duration = duration
	if state != State.WANDER:
		_seeking_shore = false


func _seconds(interval: Vector2) -> float:
	return maxf(0.05, _rng.randf_range(minf(interval.x, interval.y), maxf(interval.x, interval.y)))


func _surface_has(feet: Vector3i, keys: Array[StringName]) -> bool:
	return _world.get_block_key(feet + Vector3i.DOWN) in keys


func _feet_cell(point: Vector3 = Vector3.INF) -> Vector3i:
	var local := _world.to_local(global_position if point == Vector3.INF else point)
	return Vector3i((local + Vector3.UP * 0.05).floor())


func _random_heading() -> Vector3:
	return Vector3.FORWARD.rotated(Vector3.UP, _rng.randf() * TAU)


static func _horizontal(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)


static func cell_ready(world: VoxelWorld, cell: Vector3i) -> bool:
	return world.is_chunk_ready(VoxelChunkData.chunk_of(cell))


static func solid_ground(world: VoxelWorld, cell: Vector3i) -> bool:
	var block := world.block_at(cell)
	return block != null and block.solid_cube
