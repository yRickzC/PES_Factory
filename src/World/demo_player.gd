class_name DemoVoxelPlayer
extends CharacterBody3D

const Preferences = preload("res://addons/ldk/core/Settings/game_preferences.gd")

const PhysicsSettings = preload("res://addons/ldk/core/World/world_physics_config.gd")

signal attack_impact(action: EquipmentAction)
signal attack_window(action: EquipmentAction, from_time: float, to_time: float)

## Vida máxima do jogador. A vida atual é preservada pelo save.
@export_range(1, 10000) var max_hp := 100

var hp: int
var world: VoxelWorld
var input_enabled := true
var spawn_point: Vector3
var facing := Vector3.BACK
var _machine_state := ActorStateMachine.new()
var _effects := MeleeEffectView.new()
var _hit_feedback_view: HitFeedbackView
var _equipment: HandEquipment
var _movement: PhysicsSettings
var _jump_was_held := false
@onready var _avatar: PlayerSpriteView = $Avatar
@onready var _shadow: ProjectedGroundShadow = $Shadow


func _ready() -> void:
	_shadow.exclude_body(self)
	add_child(_effects)
	_machine_state.impacted.connect(_emit_attack_impact)
	_machine_state.impact_window.connect(_emit_attack_window)


func configure_avatar(atlas: Texture2D, camera_offset: Vector3) -> float:
	_avatar.configure(atlas, camera_offset)
	_avatar.present(facing, _machine_state)
	return _avatar.position.y + _avatar.profile.frame_size.y * _avatar.pixel_size * _avatar.scale.y * 0.5


func set_equipment(equipment: HandEquipment) -> void:
	if _equipment == equipment:
		return
	cancel_attack()
	_equipment = equipment
	_avatar.set_equipment(_equipment.visual if _equipment != null else null)
	_avatar.present(facing, _machine_state)


func try_attack(direction := Vector3.ZERO) -> bool:
	return not is_attacking() and input_enabled and _equipment != null and world != null \
		and _ready_at(global_position) and _machine_state.start_attack(_equipment.action, direction)


func is_attacking() -> bool:
	return _machine_state.state == ActorStateMachine.State.ATTACK


func in_hitstop() -> bool:
	return _machine_state.in_hitstop()


func cancel_attack() -> void:
	if is_attacking():
		_machine_state.cancel_attack()
		_present(0.0)


func show_melee_hit(point: Vector3) -> void:
	if _equipment != null and _equipment.visual != null:
		_effects.show_hit(_equipment.visual.melee_effects, point)


func confirm_melee_hit(weapon: MeleeWeapon, direction: Vector3) -> void:
	var profile := weapon.hit_feedback
	if profile == null:
		return
	HitFeedback.confirm(profile, _machine_state)
	if _hit_feedback_view == null:
		_hit_feedback_view = HitFeedbackView.new(_avatar)
	_hit_feedback_view.confirm(profile, direction)


func camera_shake_pixels() -> Vector2:
	var impact := _hit_feedback_view.camera_shake_pixels() if _hit_feedback_view != null else Vector2.ZERO
	return (impact + _avatar.run_shake_pixels).round()


func _emit_attack_impact(action: EquipmentAction) -> void:
	attack_impact.emit(action)


func _emit_attack_window(action: EquipmentAction, from_time: float, to_time: float) -> void:
	attack_window.emit(action, from_time, to_time)


func configure_movement(settings: PhysicsSettings) -> void:
	_movement = settings
	floor_snap_length = settings.floor_snap_length
	floor_max_angle = deg_to_rad(settings.floor_max_angle)


func _physics_process(delta: float) -> void:
	if _hit_feedback_view != null:
		_hit_feedback_view.advance(delta)
	var stopped := _machine_state.consume_hitstop(delta)
	if world == null or _movement == null or not _ready_at(global_position):
		velocity.x = 0.0
		velocity.z = 0.0
		_machine_state.cancel_attack()
		_machine_state.advance(0.0, false)
		_present(delta)
		_shadow.hide()
		return
	if stopped:
		_effects.advance_hits(delta)
		return
	var input := Vector2.ZERO
	if input_enabled:
		input = Vector2(
			int(Preferences.current.held(&"core:move_right")) - int(Preferences.current.held(&"core:move_left")),
			int(Preferences.current.held(&"core:move_back")) - int(Preferences.current.held(&"core:move_forward"))
		).limit_length()
	var wants_move := not input.is_zero_approx()
	var sprinting: bool = wants_move and Preferences.current.held(&"core:sprint")
	var direction := Vector3(input.x, 0.0, input.y) * _movement.movement_speed
	var movement := _planar_movement(direction, sprinting, delta)
	velocity.x = 0
	velocity.z = 0
	if not movement.is_zero_approx() and _ready_at(global_position + movement * delta):
		velocity.x = movement.x
		velocity.z = movement.z
	var jump_held: bool = input_enabled and Preferences.current.held(&"core:jump")
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif jump_held and (_movement.repeat_jump_while_held or not _jump_was_held):
		jump()
	_jump_was_held = jump_held
	move_and_slide()
	var horizontal := get_real_velocity()
	horizontal.y = 0.0
	var moving := wants_move and horizontal.length_squared() > 0.000001
	if moving:
		_update_facing(horizontal)
	elif wants_move:
		_update_facing(direction)
	# While an attack locks movement, keep sampling the intended locomotion for its exit.
	var resume_locomotion := wants_move and is_attacking() and _machine_state.movement_scale() == 0.0 \
		and _ready_at(global_position + direction * delta)
	_machine_state.advance(delta, moving or resume_locomotion, sprinting)
	_present(delta)
	_shadow.project_from(global_position)


func _planar_movement(direction: Vector3, sprinting: bool, delta: float) -> Vector3:
	if not input_enabled or is_attacking():
		return direction * _machine_state.movement_scale()
	var target := direction * (_movement.sprint_speed_multiplier if sprinting else 1.0)
	var previous := Vector3(velocity.x, 0.0, velocity.z)
	var rate := _movement.move_acceleration
	if previous.length_squared() > target.length_squared() or previous.dot(target) < 0.0:
		rate = _movement.move_deceleration
	return previous.move_toward(target, rate * delta)


func _present(delta: float) -> void:
	_avatar.present(facing, _machine_state, delta, is_on_floor())
	var visual := _equipment.visual if _equipment != null else null
	_effects.present(_machine_state, visual.melee_effects if visual != null else null, delta)


func _update_facing(horizontal: Vector3) -> void:
	var x := absf(horizontal.x)
	var z := absf(horizontal.z)
	var use_x := facing.x != 0.0 if is_equal_approx(x, z) else x > z
	if use_x:
		facing = Vector3(signf(horizontal.x), 0.0, 0.0)
	else:
		facing = Vector3(0.0, 0.0, signf(horizontal.z))


func jump() -> bool:
	if not input_enabled or not is_on_floor() or _movement == null or _movement.jump_speed <= 0.0:
		return false
	velocity.y = _movement.jump_speed
	return true


func respawn() -> void:
	hp = max_hp
	_machine_state.cancel_attack()
	_machine_state.clear_hitstop()
	if _hit_feedback_view != null:
		_hit_feedback_view.reset()
	_avatar.run_shake_pixels = Vector2.ZERO
	_machine_state.advance(0.0, false)
	_present(0.0)
	global_position = spawn_point
	velocity = Vector3.ZERO
	_shadow.hide()


func _ready_at(point: Vector3) -> bool:
	var feet := Vector3i(world.to_local(point - Vector3.UP * 0.2).floor())
	var coord := VoxelChunkData.chunk_of(feet)
	if not world.is_chunk_ready(coord):
		return false
	# A floor immediately below the lower edge is owned by the next vertical chunk.
	return (feet.y & 15) > 1 or world.is_chunk_ready(coord + Vector3i.DOWN)
