class_name WildlifeView
extends Node3D
## Poses the authored scene from the simulation clock. It has no process loop.

const State = ActorStateMachine.State

@export_node_path("Node3D") var pose_path: NodePath
@export_node_path("Node3D") var head_path: NodePath
@export_node_path("Node3D") var legs_path: NodePath
@export_range(4, 16) var facing_steps := 8
@export_range(0.1, 20.0, 0.1) var wander_gait_hz := 1.65
@export_range(0.1, 20.0, 0.1) var flee_gait_hz := 2.75
@export_range(0.0, 0.15, 0.005) var gait_lift := 0.025
@export_range(0.0, 60.0, 1.0) var leg_swing_degrees := 26.0
@export_range(0.1, 12.0, 0.1) var forage_hz := 3.2
@export_range(0.0, 60.0, 1.0) var forage_dip_degrees := 30.0
@export_range(0.0, 90.0, 1.0) var death_roll_degrees := 72.0
@export_range(0.0, 1.0, 0.01) var death_sink := 0.18

@onready var _pose := get_node_or_null(pose_path) as Node3D
@onready var _head := get_node_or_null(head_path) as Node3D
var _legs: Array[Node3D] = []
var _was_idle := false


func _ready() -> void:
	var legs := get_node_or_null(legs_path)
	if legs != null:
		for child in legs.get_children():
			if child is Node3D:
				_legs.append(child)


func present(facing: Vector3, state: ActorStateMachine.State, elapsed: float, duration: float, moving: bool) -> void:
	var increment := TAU / facing_steps
	var yaw := snappedf(atan2(-facing.x, -facing.z), increment)
	if not is_equal_approx(rotation.y, yaw):
		rotation.y = yaw
	var idle := state == State.IDLE
	if idle and _was_idle:
		return
	_was_idle = idle
	var stride := 0.0
	if moving and (state == State.WANDER or state == State.FLEE):
		var cadence := flee_gait_hz if state == State.FLEE else wander_gait_hz
		stride = sin(elapsed * TAU * cadence)
	var collapse := clampf(elapsed / maxf(0.01, duration), 0.0, 1.0) if state == State.DEAD else 0.0
	if _pose != null:
		_pose.position.y = absf(stride) * gait_lift - collapse * death_sink
		_pose.rotation.z = deg_to_rad(death_roll_degrees) * collapse
	if _head != null:
		var sniff := 0.72 + 0.28 * sin(elapsed * TAU * forage_hz) if state == State.FORAGE else 0.0
		_head.rotation.x = -deg_to_rad(forage_dip_degrees) * sniff
	for index in _legs.size():
		_legs[index].rotation.x = deg_to_rad(leg_swing_degrees) * stride * (1.0 if index % 2 == 0 else -1.0)
