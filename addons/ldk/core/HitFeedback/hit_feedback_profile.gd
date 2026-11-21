@tool
class_name HitFeedbackProfile
extends Resource
## Shared tuning for an impact. Each actor owns its own timers and movement.

@export_group("Impact")
@export_range(0.0, 0.2, 0.005, "suffix:s") var hitstop_seconds := 0.045
@export_range(0.0, 20.0, 0.05, "suffix:m/s") var knockback_speed := 4.2
@export_range(0.0, 1.0, 0.01, "suffix:s") var knockback_seconds := 0.16

@export_group("Damage taken")
@export_range(0.0, 1.0, 0.01) var flash_strength := 1.0
@export_range(0.0, 0.5, 0.005, "suffix:s") var flash_seconds := 0.08
@export_range(0.0, 0.5, 0.01, "suffix:s") var deformation_seconds := 0.16
@export var squash_scale := Vector3(1.12, 0.78, 1.12)
@export var stretch_scale := Vector3(0.96, 1.10, 0.96)

@export_group("Confirmed attack")
@export_range(0.0, 0.5, 0.005, "suffix:m") var recoil_distance := 0.08
@export_range(0.0, 0.5, 0.005, "suffix:s") var recoil_seconds := 0.10
@export_range(0.0, 10.0, 0.5, "suffix:px") var camera_shake_pixels := 2.0
@export_range(0.0, 0.5, 0.005, "suffix:s") var camera_shake_seconds := 0.12
