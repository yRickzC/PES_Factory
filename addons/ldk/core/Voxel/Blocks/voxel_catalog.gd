class_name VoxelCatalog
extends RefCounted
## Registers shared Resources and bakes read-only data for meshing workers.

class BakedBlock extends RefCounted:
	var cube := false
	var tiles := PackedByteArray()
	var top_style := 0
	var visual: VoxelModel
	var slot := 0
	var opaque_sides := 0
	var merge_group := 0
	var solid_cube := false
	var solid_sides := 0
	var collision: VoxelModel
	var connection_group: StringName
	var connected_visual: Dictionary[int, VoxelModel] = {}
	var connected_collision: Dictionary[int, VoxelModel] = {}

	func connects_to(neighbor: BakedBlock) -> bool:
		return neighbor != null and not connection_group.is_empty() and connection_group == neighbor.connection_group

	func visual_for(connections: int) -> VoxelModel:
		return connected_visual.get(connections, visual) if connections != 0 else visual

	func collision_for(connections: int) -> VoxelModel:
		return connected_collision.get(connections, collision) if connections != 0 else collision


const AIR_KEY := &"core:air"
const CONNECTION_SIDES := [0, 1, 4, 5]
const TOP_STYLE_LIMIT := 1 << 15

var _missing_key: StringName
var _tile_indices: Dictionary
var _keys: Dictionary[StringName, int] = {}
var _definitions: Array[VoxelBlock] = []
var _baked: Array[BakedBlock] = []
var _top_styles := PackedByteArray([0, 0, 0, 0])
var _top_style_offsets: Dictionary[PackedByteArray, int] = {}
var _frozen := false


func _init(tile_indices: Dictionary = {}, missing_key: StringName = &"") -> void:
	_missing_key = ContentRegistry.normalize_id(missing_key)
	_tile_indices = tile_indices
	_definitions.append(null)
	_baked.append(BakedBlock.new())
	_keys[AIR_KEY] = 0


static func has_valid_geometry(definition: VoxelBlock) -> bool:
	return VoxelBlock.geometry_issue(definition).is_empty()


func register(definition: VoxelBlock) -> bool:
	if _frozen or not has_valid_geometry(definition):
		return false
	var main_key := ContentRegistry.normalize_id(definition.key)
	var owner_namespace := ContentRegistry.namespace_of(main_key)
	if owner_namespace.is_empty() or _keys.has(main_key):
		return false
	var aliases: Dictionary[StringName, bool] = {}
	for legacy_key in definition.legacy_keys:
		var key := ContentRegistry.normalize_id(legacy_key)
		if ContentRegistry.namespace_of(key) != owner_namespace or key == main_key or _keys.has(key) or aliases.has(key):
			return false
		aliases[key] = true
	var block := BakedBlock.new()
	var turns := posmod(definition.quarter_turns, 4)
	var geometry := VoxelBlock.bake_geometry(definition.geometry)
	if geometry != null:
		block.cube = geometry.cube
		block.slot = geometry.material_slot
		if geometry.cube:
			block.tiles.resize(6)
			for side in 6:
				var tile := ContentRegistry.normalize_id(geometry.face_tiles[side])
				block.tiles[_rotate_side(side, turns)] = _tile_indices.get(tile, 0)
			if block.slot == 0:
				block.top_style = _register_top_style(definition.geometry, block.tiles[2])
		elif geometry.model != null:
			block.visual = _bake_model(geometry.model, turns)
	var collider := definition.collision
	if collider != null:
		block.solid_cube = collider.cube
		block.solid_sides = 63 if collider.cube else _rotate_mask(collider.full_sides, turns)
		if not collider.cube and collider.model != null:
			block.collision = _bake_model(collider.model, turns)
	var automatic_mask := definition.geometry.automatic_occlusion() if geometry != null else VoxelVisual.AUTHORED_OCCLUSION
	if automatic_mask != VoxelVisual.AUTHORED_OCCLUSION:
		block.opaque_sides = _rotate_mask(automatic_mask, turns)
	elif definition.occlusion != null:
		block.opaque_sides = _rotate_mask(definition.occlusion.full_sides, turns)
		block.merge_group = definition.occlusion.merge_group
	var visual_arm: VoxelModel = geometry.connection_arm if geometry != null else null
	var collision_arm: VoxelModel = collider.connection_arm if collider != null else null
	if visual_arm != null or collision_arm != null:
		block.connection_group = ContentRegistry.normalize_id(definition.connection_group)
		if visual_arm != null:
			block.connected_visual = _bake_connections(block.visual, visual_arm)
		if collision_arm != null:
			if visual_arm == collision_arm and geometry.model == collider.model:
				block.connected_collision = block.connected_visual
			else:
				block.connected_collision = _bake_connections(block.collision, collision_arm)
	var id := _baked.size()
	_keys[main_key] = id
	for key in aliases:
		_keys[key] = id
	_definitions.append(definition)
	_baked.append(block)
	return true


func freeze() -> void:
	_frozen = true


## RGBA header (packed turns, alternative count, turn count, unused), then one texel per layer.
func top_styles_image() -> Image:
	var rows := ceili(float(_top_styles.size()) / 1024.0)
	var pixels := _top_styles.duplicate()
	pixels.resize(rows * 1024)
	return Image.create_from_data(256, rows, false, Image.FORMAT_RGBA8, pixels)


func _register_top_style(visual: VoxelVisual, base_layer: int) -> int:
	var angles := visual.top_rotation_angles & 15 if visual.randomize_top_rotation else 1
	if angles == 0:
		angles = 1
	var layers := PackedByteArray([base_layer])
	for id in visual.top_texture_variants:
		var layer: int = _tile_indices.get(ContentRegistry.normalize_id(id), 0)
		if layer != 0 and not layers.has(layer):
			layers.append(layer)
	if angles == 1 and layers.size() == 1:
		return 0
	var packed_turns := 0
	var turn_count := 0
	for turn in 4:
		if (angles & (1 << turn)) != 0:
			packed_turns |= turn << (turn_count * 2)
			turn_count += 1
	var style := PackedByteArray([packed_turns, layers.size() - 1, turn_count, 0])
	style.append_array(layers)
	if _top_style_offsets.has(style):
		return _top_style_offsets[style]
	var offset := _top_styles.size() >> 2
	if offset >= TOP_STYLE_LIMIT:
		push_warning("Texture variation table is full.")
		return 0
	_top_styles.append_array(style.slice(0, 4))
	for layer in layers:
		_top_styles.append_array(PackedByteArray([layer, 0, 0, 0]))
	_top_style_offsets[style] = offset
	return offset


func has_id(id: int) -> bool:
	return id >= 0 and id < _baked.size() and _baked[id] != null


func id_for(key: StringName) -> int:
	var id: int = _keys.get(key, -1)
	return id if id >= 0 else _keys.get(ContentRegistry.normalize_id(key), -1)


func key_for(id: int) -> StringName:
	if id == 0:
		return AIR_KEY
	return ContentRegistry.normalize_id(_definitions[id].key) if has_id(id) else &""


func resolve(key: StringName) -> int:
	var id := id_for(key)
	return id if id >= 0 else _keys.get(_missing_key, 0)


func block(id: int) -> BakedBlock:
	# Unregistered generator output is rendered as air.
	return _baked[id] if has_id(id) else _baked[0]


func definition(id: int) -> VoxelBlock:
	return _definitions[id] if id >= 0 and id < _definitions.size() else null


func behavior_for(id: int) -> VoxelBlockBehavior:
	var entry := definition(id)
	return entry.behavior if entry != null else null


static func _rotate_side(side: int, turns: int) -> int:
	var direction := VoxelChunkData.DIRECTIONS[side]
	for turn in turns:
		direction = Vector3i(direction.z, direction.y, -direction.x)
	return VoxelChunkData.DIRECTIONS.find(direction)


static func _rotate_mask(mask: int, turns: int) -> int:
	var rotated := 0
	for side in 6:
		if mask & (1 << side):
			rotated |= 1 << _rotate_side(side, turns)
	return rotated


func _bake_model(source: VoxelModel, turns: int) -> VoxelModel:
	var model := VoxelModel.new()
	model.vertices = source.vertices.duplicate()
	model.uv = source.uv.duplicate()
	for tile in source.tiles:
		model.runtime_tiles.append(_tile_indices.get(ContentRegistry.normalize_id(tile), 0))
	model.boundaries = source.boundaries.duplicate()
	for i in model.vertices.size():
		var vertex := model.vertices[i]
		for turn in turns:
			vertex = Vector3(vertex.z, vertex.y, 1.0 - vertex.x)
		model.vertices[i] = vertex
	for i in model.boundaries.size():
		if model.boundaries[i] >= 0:
			model.boundaries[i] = _rotate_side(model.boundaries[i], turns)
	return model


func _bake_connections(base: VoxelModel, arm: VoxelModel) -> Dictionary[int, VoxelModel]:
	var arms: Dictionary[int, VoxelModel] = {}
	for turns in 4:
		arms[_rotate_side(0, turns)] = _bake_model(arm, turns)
	var models: Dictionary[int, VoxelModel] = {}
	for combination in range(1, 16):
		var model := VoxelModel.new()
		model.vertices = base.vertices.duplicate()
		model.uv = base.uv.duplicate()
		model.runtime_tiles = base.runtime_tiles.duplicate()
		model.boundaries = base.boundaries.duplicate()
		var mask := 0
		for i in CONNECTION_SIDES.size():
			if (combination & (1 << i)) == 0:
				continue
			var side: int = CONNECTION_SIDES[i]
			var extension := arms[side]
			mask |= 1 << side
			model.vertices.append_array(extension.vertices)
			model.uv.append_array(extension.uv)
			model.runtime_tiles.append_array(extension.runtime_tiles)
			model.boundaries.append_array(extension.boundaries)
		models[mask] = model
	return models
