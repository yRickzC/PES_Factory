class_name VoxelBiomePlacement
extends RefCounted
## Finds deterministic scene props using biome rules. Positions are support cells.

var _generator: VoxelHeightmapGenerator
var _content: ContentDB
var _spacing: Array[int] = []
var _chance_scale: float
var _scatter: Array[ScatterEntry] = []
var _surface_limits: Vector2i


class ScatterEntry:
	var biome_index: int
	var salt: int
	var rule: VoxelBiomeScatter
	var variants: Array[ContentScene] = []


func _init(generator: VoxelHeightmapGenerator, content: ContentDB) -> void:
	_generator = generator
	_content = content
	_surface_limits = generator.surface_height_limits()
	_chance_scale = generator.settings.prop_chance_scale
	if _chance_scale <= 0.0:
		return
	for index in generator.biomes.size():
		var biome := generator.biomes[index]
		for rule_index in biome.scatter.size():
			var rule := biome.scatter[rule_index]
			if rule == null or rule.chance <= 0.0:
				continue
			var entry := ScatterEntry.new()
			entry.biome_index = index
			entry.salt = hash(biome.key) ^ hash(rule_index + 0x4A61)
			entry.rule = rule
			for id in rule.variants:
				var definition := content.entities.find(id) as ContentScene
				if definition != null and definition.wildlife == null:
					entry.variants.append(definition)
			if not entry.variants.is_empty():
				_scatter.append(entry)
		if biome.vegetation.is_empty() and biome.entities.is_empty() and biome.structures.is_empty():
			continue
		var spacing := maxi(1, biome.spawn_spacing)
		if spacing not in _spacing:
			_spacing.append(spacing)


func for_chunk(coord: Vector3i) -> Dictionary[Vector3i, ContentScene]:
	var placements: Dictionary[Vector3i, ContentScene] = {}
	var bottom := coord.y * VoxelChunkData.SIZE
	if bottom > _surface_limits.y or bottom + VoxelChunkData.SIZE <= _surface_limits.x:
		return placements
	var bounds := Rect2i(Vector2i(coord.x, coord.z) * VoxelChunkData.SIZE, Vector2i.ONE * VoxelChunkData.SIZE)
	for spacing in _spacing:
		var first := ((Vector2(bounds.position) - Vector2.ONE * 5) / spacing).ceil()
		var last := ((Vector2(bounds.end) - Vector2.ONE * 3) / spacing).floor()
		for z in range(int(first.y), int(last.y) + 1):
			for x in range(int(first.x), int(last.x) + 1):
				var roll := hash(Vector3i(x, _generator.world_seed ^ 968, z))
				var anchor := Vector2i(x, z) * spacing + Vector2i(2 + (roll & 3), 2 + ((roll >> 8) & 3))
				if bounds.has_point(anchor) and allows_procedural(anchor):
					place(placements, anchor, coord, spacing, roll)
	var columns: Dictionary[Vector2i, Vector2i] = {}
	for entry in _scatter:
		_scatter_into(placements, columns, bounds, bottom, entry)
	return placements


func _scatter_into(placements: Dictionary[Vector3i, ContentScene], columns: Dictionary[Vector2i, Vector2i],
		bounds: Rect2i, bottom: int, entry: ScatterEntry) -> void:
	var rule := entry.rule
	var spacing := maxi(1, rule.spacing)
	var radius := maxi(0, rule.radius)
	var chance := rule.chance * _chance_scale
	# Neighbouring grid cells may contribute members of a patch that crosses this chunk.
	var area := bounds.grow(radius)
	var first := (Vector2(area.position) / spacing).floor()
	var last := (Vector2(area.end - Vector2i.ONE) / spacing).floor()
	var grid_seed := _generator.world_seed ^ entry.salt
	for z in range(int(first.y), int(last.y) + 1):
		for x in range(int(first.x), int(last.x) + 1):
			var roll := hash(Vector3i(x, grid_seed, z))
			if float(roll & 65535) / 65536.0 >= chance:
				continue
			var anchor := Vector2i(x, z) * spacing + Vector2i((roll >> 16) % spacing, (roll >> 24) % spacing)
			if not area.has_point(anchor) or _column(columns, anchor).y != entry.biome_index:
				continue
			_scatter_patch(placements, columns, bounds, bottom, entry, anchor, roll)


func _scatter_patch(placements: Dictionary[Vector3i, ContentScene], columns: Dictionary[Vector2i, Vector2i],
		bounds: Rect2i, bottom: int, entry: ScatterEntry, anchor: Vector2i, patch_seed: int) -> void:
	var rule := entry.rule
	var radius := maxi(0, rule.radius)
	var diameter := radius * 2 + 1
	var attempts := 1 if radius == 0 else rule.attempts
	for index in attempts:
		var roll := hash(Vector3i(anchor.x, patch_seed ^ (index * 0x5BD1E995), anchor.y))
		var offset := Vector2i(roll % diameter - radius, (roll >> 16) % diameter - radius)
		if index == 0:
			offset = Vector2i.ZERO
		var cell := anchor + offset
		if offset.length_squared() > radius * radius or not bounds.has_point(cell) or not allows_procedural(cell):
			continue
		var column := _column(columns, cell)
		if column.y != entry.biome_index or column.x < bottom or column.x >= bottom + VoxelChunkData.SIZE:
			continue
		if column.x < rule.elevation.x or column.x > rule.elevation.y or _generator.column_is_flooded(column):
			continue
		var support := Vector3i(cell.x, column.x, cell.y)
		if not placements.has(support) and _slope_allows(columns, cell, column.x, rule.max_step):
			placements[support] = entry.variants[(roll >> 8) % entry.variants.size()]


func _slope_allows(columns: Dictionary[Vector2i, Vector2i], cell: Vector2i, elevation: int, max_step: int) -> bool:
	if max_step < 0:
		return true
	for side in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if absi(_column(columns, cell + side).x - elevation) > max_step:
			return false
	return true


func _column(columns: Dictionary[Vector2i, Vector2i], cell: Vector2i) -> Vector2i:
	if not columns.has(cell):
		columns[cell] = _generator.sample_column(cell.x, cell.y)
	return columns[cell]


func allows_procedural(_anchor: Vector2i) -> bool:
	return true


func spawn_sample(roll: int) -> float:
	return float((roll >> 16) & 65535) / 65536.0


func instantiate(definition: ContentScene) -> Node3D:
	return definition.instantiate(_content.texture)


func place(placements: Dictionary[Vector3i, ContentScene], anchor: Vector2i, coord: Vector3i,
		spacing: int, roll: int) -> void:
	var column := _generator.sample_column(anchor.x, anchor.y)
	var support := Vector3i(anchor.x, column.x, anchor.y)
	if VoxelChunkData.chunk_of(support) != coord or _generator.column_is_flooded(column):
		return
	var biome := _generator.biomes[column.y]
	if column.x < biome.spawn_height.x or column.x > biome.spawn_height.y:
		return
	if spacing > 0:
		if maxi(1, biome.spawn_spacing) != spacing or biome.spawn_chance <= 0.0:
			return
		if spawn_sample(roll) >= biome.spawn_chance * _chance_scale:
			return
	var count := biome.vegetation.size() + biome.entities.size() + biome.structures.size()
	if count == 0 or placements.has(support):
		return
	var pick := posmod(roll >> 8, count)
	var resources := _content.entities
	var id: StringName
	if pick < biome.vegetation.size():
		id = biome.vegetation[pick]
	elif pick < biome.vegetation.size() + biome.entities.size():
		id = biome.entities[pick - biome.vegetation.size()]
	else:
		id = biome.structures[pick - biome.vegetation.size() - biome.entities.size()]
		resources = _content.structures
	var definition := resources.find(id) as ContentScene
	if definition != null and definition.wildlife == null:
		placements[support] = definition

