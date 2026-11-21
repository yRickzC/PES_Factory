@tool
class_name VoxelMiningTool
extends EquipmentAction
## Applies this many seconds of mining work at the action's impact.

@export_range(0.05, 5.0, 0.01, "or_greater", "suffix:s") var work_per_impact := 0.65
