extends RefCounted
## Transient damage owned by the interaction system. Clear edited or unloaded cells via signals.

class Damage:
	var progress: float
	var touched_at: float

const CLEANUP_INTERVAL := 0.25

var _chunks: Dictionary[Vector3i, Dictionary] = {}
var _time := 0.0
var _next_cleanup := 0.0
var _recovery_delay: float
var _recovery_seconds: float
var _expire_after: float


func _init(recovery_delay: float, recovery_seconds: float, expire_after := 0.0) -> void:
	_recovery_delay = maxf(0.0, recovery_delay)
	_recovery_seconds = maxf(0.0, recovery_seconds)
	_expire_after = maxf(0.0, expire_after)


func progress(cell: Vector3i) -> float:
	var key := VoxelChunkData.chunk_of(cell)
	if not _chunks.has(key):
		return 0.0
	var damage: Damage = _chunks[key].get(_index(cell))
	return _remaining(damage, _time)


## Speed is the effective multiplier after applying tool and gameplay modifiers.
func strike(cell: Vector3i, step: float, break_seconds: float, speed: float) -> float:
	if step <= 0.0 or break_seconds <= 0.0 or speed <= 0.0:
		return progress(cell)
	var key := VoxelChunkData.chunk_of(cell)
	if not _chunks.has(key):
		var new_cells: Dictionary[int, Damage] = {}
		_chunks[key] = new_cells
	var cells := _chunks[key]
	var index := _index(cell)
	var damage: Damage = cells.get(index)
	var next := _remaining(damage, _time) + speed * step / break_seconds
	if damage == null:
		damage = Damage.new()
		cells[index] = damage
	# Equivalent elapsed durations can add up to just below 1 at different tick rates.
	damage.progress = 1.0 if next >= 1.0 or is_equal_approx(next, 1.0) else next
	damage.touched_at = _time + step
	return damage.progress


func advance_time(step: float) -> void:
	_time += maxf(0.0, step)
	if _chunks.is_empty() or _time < _next_cleanup:
		return
	_next_cleanup = _time + CLEANUP_INTERVAL
	for key: Vector3i in _chunks.keys():
		var cells := _chunks[key]
		for index: int in cells.keys():
			if _remaining(cells[index], _time) == 0.0:
				cells.erase(index)
		if cells.is_empty():
			_chunks.erase(key)


func forget_chunk(key: Vector3i) -> void:
	_chunks.erase(key)


func forget_cells(cells: Array[Vector3i]) -> void:
	for cell in cells:
		forget_cell(cell)


func forget_cell(cell: Vector3i) -> void:
	var key := VoxelChunkData.chunk_of(cell)
	if not _chunks.has(key):
		return
	var cells := _chunks[key]
	cells.erase(_index(cell))
	if cells.is_empty():
		_chunks.erase(key)


func _remaining(damage: Damage, now: float) -> float:
	if damage == null:
		return 0.0
	var idle := now - damage.touched_at
	if _expire_after > 0.0 and idle >= _expire_after:
		return 0.0
	var recovery := idle - _recovery_delay
	if recovery <= 0.0:
		return damage.progress
	if recovery >= _recovery_seconds:
		return 0.0
	return damage.progress * (1.0 - recovery / _recovery_seconds)


func _index(cell: Vector3i) -> int:
	return VoxelChunkData.index_of(VoxelChunkData.local_of(cell))
