@tool
class_name EquipmentAction
extends Resource
## Timing and movement rules shared by hand equipment actions.

@export_range(0.05, 5.0, 0.01, "or_greater", "suffix:s") var duration := 0.42
@export_range(0.05, 0.95, 0.01) var impact_fraction := 0.5
## Minimum time between the starts of consecutive attacks.
@export_range(0.0, 5.0, 0.01, "or_greater", "suffix:s") var cooldown := 0.0
@export_range(0.0, 1.0, 0.05) var movement_scale := 0.0
@export var repeat_while_held := true


func impact_time() -> float:
	return duration * impact_fraction


func impact_end_time() -> float:
	return impact_time()
