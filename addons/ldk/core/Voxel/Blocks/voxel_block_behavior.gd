@tool
class_name VoxelBlockBehavior
extends Resource
## Shared hooks run on the main thread. Keep per-cell state in the given dictionary.
## Return true to schedule (or keep) updates while this cell is in the active region.


func interact(_cell: Vector3i, _state: Dictionary) -> bool:
	return false


func advance(_cell: Vector3i, _state: Dictionary, _delta: float) -> bool:
	return false
