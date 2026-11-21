extends RefCounted

const GROUND_ELEVATION := 3

static func create() -> Dictionary[Vector3i, StringName]:
	var cells: Dictionary[Vector3i, StringName] = {}
	_cabin(cells)
	for x in range(-5, 0):
		cells[Vector3i(x, 4, 1)] = &"core:wall"
		cells[Vector3i(x, 3, 2)] = &"core:paving"
	for z in range(7, 11):
		for x in range(2, 4):
			cells[Vector3i(x, 3, z)] = &"core:paving"
	for x in range(6, 9):
		cells[Vector3i(x, 4, 5)] = &"core:slab"
	return cells


static func _cabin(cells: Dictionary[Vector3i, StringName]) -> void:
	for x in 6:
		for z in 6:
			cells[Vector3i(x, 4, z)] = &"core:timber"
			if z > 3:
				continue
			for y in range(5, 7):
				var is_door := x == 2 and z == 3
				if not is_door and (x in [0, 5] or z in [0, 3]):
					var wall := &"core:sill" if y == 5 else &"core:plaster"
					if z == 3 and y == 6 and x in [1, 4]:
						wall = &"core:window"
					cells[Vector3i(x, y, z)] = wall
	for x in range(-1, 7):
		cells[Vector3i(x, 7, 0)] = &"core:roof_reversed"
		cells[Vector3i(x, 7, 3)] = &"core:roof"
		for z in [1, 2]:
			cells[Vector3i(x, 7, z)] = &"core:plaster"
			cells[Vector3i(x, 8, z)] = &"core:roof_reversed" if z == 1 else &"core:roof"
	for x in [0, 1, 4, 5]:
		cells[Vector3i(x, 5, 5)] = &"core:fence"
	for x in [2, 3]:
		cells[Vector3i(x, 4, 6)] = &"core:stairs"
	for x in [0, 5]:
		cells[Vector3i(x, 5, 4)] = &"core:fence"
