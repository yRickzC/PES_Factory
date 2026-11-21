class_name PlayerSpriteView
extends Sprite3D
## Presents the state machine's pose with pixel-aligned atlas slices.

@export var profile: PlayerSpriteProfile

var run_shake_pixels := Vector2.ZERO
var _visual: HandEquipmentVisual
var _frame := -1
var _bob := -1
var _stride := 0
var _grip_dirty := true
var _was_swinging := false
var _vertical_per_depth: float
var _screen_depth: float
@onready var _head: Sprite3D = $Head
@onready var _grip: Node3D = $Grip
@onready var _hand: Sprite3D = $Grip/Hand
@onready var _off_hand: Sprite3D = $OffHand
@onready var _tool: Sprite3D = $Grip/Tool


func configure(atlas: Texture2D, camera_offset: Vector3) -> void:
	_vertical_per_depth = camera_offset.y / (camera_offset.z * scale.y)
	_screen_depth = camera_offset.normalized().y
	texture = atlas
	_head.texture = atlas
	_hand.texture = atlas
	_off_hand.texture = atlas
	_hand.region_rect = profile.hand_region
	_off_hand.region_rect = profile.hand_region
	_head.pixel_size = pixel_size
	_hand.pixel_size = pixel_size
	_off_hand.pixel_size = pixel_size
	_tool.pixel_size = pixel_size
	_hand.position.y = _hand.position.z * _vertical_per_depth
	_frame = -1
	_bob = -1


func set_equipment(visual: HandEquipmentVisual) -> void:
	_visual = visual
	_tool.visible = visual != null and visual.texture != null
	_tool.texture = visual.texture if visual != null else null
	_grip_dirty = true


func present(facing: Vector3, machine: ActorStateMachine, delta := 0.0, grounded := false) -> void:
	if texture == null:
		return
	var heading := machine.attack_direction if not machine.attack_direction.is_zero_approx() else facing
	var frame := _facing_frame(heading)
	var bob := 0
	var stride := 0
	if machine.state == ActorStateMachine.State.RUN:
		var steps := machine.elapsed / maxf(profile.run_step_seconds, 0.01)
		var step := int(steps)
		bob = step % 2 * profile.run_bob_pixels
		stride = 1 if step % 2 == 0 else -1
		if grounded:
			var pulse := 1.0 - (steps - step)
			run_shake_pixels = profile.run_shake_amplitude * Vector2(stride, -1.0) * pulse * pulse
	elif machine.state == ActorStateMachine.State.WALK:
		bob = int(machine.elapsed / profile.walk_step_seconds) % 2 * profile.walk_bob_pixels
	if (stride == 0 or not grounded) and not run_shake_pixels.is_zero_approx():
		var fade := maxf(profile.run_shake_fade_seconds, 0.01)
		run_shake_pixels = run_shake_pixels.move_toward(Vector2.ZERO, profile.run_shake_amplitude.length() * delta / fade)
	var turned := frame != _frame
	if turned:
		_frame = frame
		var x := frame * profile.frame_size.x
		region_rect = Rect2(x, profile.head_height, profile.frame_size.x, profile.frame_size.y - profile.head_height)
		_head.region_rect = Rect2(x, 0, profile.frame_size.x, profile.head_height)
	if turned or bob != _bob or stride != _stride:
		_grip_dirty = true
		_bob = bob
		_stride = stride
		_present_body(frame, bob, stride != 0)
	if _grip_dirty:
		_grip.visible = _tool.visible or stride != 0
		_off_hand.visible = stride != 0
	var swinging := machine.action != null
	if _grip.visible and (_grip_dirty or swinging or _was_swinging):
		_present_grip(frame, stride, machine)
		_grip_dirty = false
	_was_swinging = swinging


func _present_body(frame: int, bob: int, running: bool) -> void:
	var lean := profile.run_lean_pixels if running else 0
	var lean_x := 0
	var lean_y := 0
	var torso_lift := 0
	match frame:
		0: lean_y = -lean
		1: lean_x = -lean
		2: lean_x = lean
		3:
			lean_y = lean
			torso_lift = lean
	offset = Vector2(lean_x, bob + torso_lift - profile.head_height * 0.5)
	var neck_height := (profile.frame_size.y - profile.head_height) * 0.5
	_head.position = Vector3(lean_x * 2, neck_height + bob + lean_y, 0.0) * pixel_size


func _present_grip(frame: int, stride: int, machine: ActorStateMachine) -> void:
	var swing_offset := Vector2.ZERO
	var angle := _visual.rest_angle if _tool.visible else 0.0
	var mirrored := frame == 1
	var mirror := -1.0 if mirrored else 1.0
	var action := machine.action if _tool.visible else null
	var elapsed := machine.elapsed
	var weapon := action as MeleeWeapon
	if weapon != null:
		var direction := weapon.sweep_direction(machine.attack_direction, elapsed)
		var projected := Vector2(direction.x * mirror, -direction.z * _screen_depth).normalized()
		var raised := clampf(elapsed / weapon.impact_time(), 0.0, 1.0)
		var recovery := 0.0
		if elapsed > weapon.impact_end_time():
			recovery = _stepped(inverse_lerp(weapon.impact_end_time(), weapon.duration, elapsed))
		var weight := _stepped(raised) * (1.0 - recovery)
		var reach_offset := Vector2(projected.x, -projected.y) * _visual.impact_offset.x
		swing_offset = _visual.raised_offset.lerp(reach_offset, raised) * weight
		angle = rad_to_deg(lerp_angle(deg_to_rad(angle), atan2(-projected.x, projected.y), weight))
	elif action != null:
		var impact := action.impact_time()
		var raised := impact * _visual.raise_fraction
		if elapsed < raised:
			var weight := _stepped(elapsed / raised)
			swing_offset = Vector2.ZERO.lerp(_visual.raised_offset, weight)
			angle = lerpf(angle, _visual.raised_angle, weight)
		elif elapsed < impact:
			var weight := _stepped(inverse_lerp(raised, impact, elapsed))
			swing_offset = _visual.raised_offset.lerp(_visual.impact_offset, weight)
			angle = lerpf(_visual.raised_angle, _visual.impact_angle, weight)
		else:
			var weight := _stepped(inverse_lerp(impact, action.duration, elapsed))
			swing_offset = _visual.impact_offset.lerp(Vector2.ZERO, weight)
			angle = lerpf(_visual.impact_angle, angle, weight)
	var hand := profile.hand_positions[frame]
	var arm_swing := Vector2(profile.run_arm_swing_pixels) * stride
	arm_swing.x *= mirror
	var lean := Vector2(offset.x, 0.0)
	var bob := offset.y + profile.head_height * 0.5
	var pixel := hand + lean + arm_swing + Vector2(swing_offset.x * mirror, swing_offset.y).round()
	var depth := -profile.grip_depth if frame == 3 else profile.grip_depth
	var pose := _grip_pose(pixel, bob, depth)
	if _grip.position != pose:
		_grip.position = pose
	if stride != 0:
		var far_hand := Vector2(-hand.x, hand.y) + lean - arm_swing
		_off_hand.position = _grip_pose(far_hand, bob, -profile.grip_depth)
	if not _tool.visible:
		return
	if _grip_dirty or _tool.flip_h != mirrored:
		_tool.flip_h = mirrored
		var pivot := _visual.grip_pixel - _visual.texture.get_size() * 0.5
		_tool.offset = Vector2(-pivot.x * mirror, pivot.y)
	var rotation_radians := deg_to_rad(angle * mirror)
	if not is_equal_approx(_tool.rotation.z, rotation_radians):
		_tool.rotation.z = rotation_radians


func _grip_pose(pixel: Vector2, bob: float, depth: float) -> Vector3:
	# Move along the camera ray to change depth without shifting the on-screen pixel.
	return Vector3(pixel.x * pixel_size, (bob - pixel.y) * pixel_size + depth * _vertical_per_depth, depth)


func _stepped(weight: float) -> float:
	var steps := float(_visual.steps_per_phase)
	return floorf(clampf(weight, 0.0, 1.0) * steps) / steps


func _facing_frame(facing: Vector3) -> int:
	if absf(facing.x) > absf(facing.z):
		return 1 if facing.x < 0.0 else 2
	return 3 if facing.z < 0.0 else 0
