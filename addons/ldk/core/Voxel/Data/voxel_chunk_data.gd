class_name VoxelChunkData
extends RefCounted
## Immutable after construction. Only mixed chunks allocate a cell buffer.

const SIZE := 16
const AREA := SIZE * SIZE
const VOLUME := AREA * SIZE
const DIRECTIONS: Array[Vector3i] = [
	Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN,
	Vector3i.BACK, Vector3i.FORWARD,
]

var _uniform_id: int
var _cells := PackedByteArray()
var _wide_cells := PackedInt32Array()


## Takes ownership of cells. The caller can discard its reference after construction.
func _init(cells: Variant = PackedByteArray(), uniform_id := 0) -> void:
	_uniform_id = uniform_id
	if cells.is_empty():
		return
	assert(cells.size() == VOLUME)
	_uniform_id = cells[0]
	for id in cells:
		if id != _uniform_id:
			if cells is PackedInt32Array:
				_wide_cells = cells
			else:
				_cells = cells
			_uniform_id = -1
			return


static func chunk_of(cell: Vector3i) -> Vector3i:
	# Arithmetic right shift is floor division by 16, including negative cells.
	return Vector3i(cell.x >> 4, cell.y >> 4, cell.z >> 4)


static func local_of(cell: Vector3i) -> Vector3i:
	return Vector3i(cell.x & 15, cell.y & 15, cell.z & 15)


static func index_of(local: Vector3i) -> int:
	return local.x + SIZE * local.z + AREA * local.y


static func local_from_index(index: int) -> Vector3i:
	return Vector3i(index & 15, index >> 8, (index >> 4) & 15)


func uniform_id() -> int:
	return _uniform_id


func id_at(index: int) -> int:
	if _uniform_id >= 0:
		return _uniform_id
	return _cells[index] if _wide_cells.is_empty() else _wide_cells[index]


func payload_bytes() -> int:
	return _cells.size() + _wide_cells.size() * 4


func with_changes(changes: Dictionary[int, int]) -> VoxelChunkData:
	if changes.is_empty():
		return self
	var wide := not _wide_cells.is_empty() or _uniform_id > 255
	for id in changes.values():
		if id > 255:
			wide = true
			break
	var cells: Variant
	if wide:
		cells = PackedInt32Array(Array(_cells)) if _wide_cells.is_empty() else _wide_cells.duplicate()
	else:
		cells = _cells.duplicate()
	if _uniform_id >= 0:
		cells.resize(VOLUME)
		cells.fill(_uniform_id)
	for index in changes:
		cells[index] = changes[index]
	return VoxelChunkData.new(cells)
