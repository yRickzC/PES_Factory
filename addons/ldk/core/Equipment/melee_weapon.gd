@tool
class_name MeleeWeapon
extends EquipmentAction
## The shared timing and geometry of a directional melee sweep.

@export_range(1, 1000) var damage := 3
@export_range(0.1, 10.0, 0.05) var reach := 1.8
@export_range(0.1, 2.0, 0.05) var sweep_width := 0.42
@export_range(1.0, 180.0, 1.0, "degrees") var arc_degrees := 106.0
@export_range(0.05, 3.0, 0.05) var origin_height := 0.48
@export_range(0.05, 3.0, 0.05) var hit_height := 0.76
@export_range(0.06, 1.0, 0.01) var active_end_fraction := 0.64
@export_range(0.0, 0.25, 0.01, "suffix:s") var input_buffer_seconds := 0.09
@export_flags_3d_physics var target_mask := 8
## Response on the attacker after at least one target accepts damage.
@export var hit_feedback: HitFeedbackProfile


func impact_end_time() -> float:
	return clampf(duration * active_end_fraction, impact_time(), duration)


func sweep_direction(heading: Vector3, elapsed: float) -> Vector3:
	var start := impact_time()
	var end := impact_end_time()
	var progress := clampf(inverse_lerp(start, end, elapsed), 0.0, 1.0) if end > start else 0.0
	return heading.rotated(Vector3.UP, deg_to_rad(arc_degrees) * (0.5 - progress))
