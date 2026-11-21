class_name VoxelCutawayView
extends MeshInstance3D
## Updates a bounded column mask shared by the chunk shaders. Only newly exposed faces
## use this supplementary mesh. No cut modifies a chunk mesh, collider or block state.

signal prop_visibility_changed

const MASK_SIZE := 49
const UNCUT := VoxelCutawayRegion.UNCUT
const FADE_SECONDS := 0.20
const CUTAWAY_TRANSPARENCY := 0.9
const ConstructionConfig = preload("res://addons/ldk/core/Voxel/Targeting/voxel_construction_config.gd")

class Column:
	var previous: int
	var current: int
	var progress := 0.0

	func _init(from: int, to: int) -> void:
		previous = from
		current = to

	func height() -> int:
		return current if progress >= 0.5 else previous

var _world: VoxelWorld
var _region: VoxelCutawayRegion
var _materials: Array[Material]
var _terrain: ShaderMaterial
var _blur_pass: ShaderMaterial
var _image := Image.create_empty(MASK_SIZE, MASK_SIZE, false, Image.FORMAT_RGBAF)
var _texture: ImageTexture
var _caps := ImmediateMesh.new()
var _columns: Dictionary[Vector2i, Column] = {}
var _origin := Vector2i.ZERO
var _sample := Vector4i.ZERO
var _sample_height := 0
var _sample_view := Vector3.ZERO
var _dirty := true
var _caps_dirty := true
var _animating := false
var _enabled := false
var _construction_state: Dictionary[StringName, Variant] = {}
var _construction_bounds := Rect2i()
var _construction_caps_dirty := false


func configure(world: VoxelWorld, materials: Array[Material], blur_pass: ShaderMaterial = null) -> Array[Material]:
	_world = world
	_region = VoxelCutawayRegion.new(world)
	_materials = materials.duplicate()
	_world.blocks_changed.connect(_blocks_changed)
	_world.chunk_ready.connect(_chunk_changed)
	_world.chunk_unloaded.connect(_chunk_changed)
	_terrain = materials[0] as ShaderMaterial
	_blur_pass = blur_pass
	var cap_material := _terrain.duplicate() as ShaderMaterial
	cap_material.set_shader_parameter(&"cutaway_cap_pass", true)
	_materials.append(cap_material)
	if _blur_pass != null:
		_materials.append(_blur_pass)
	material_override = cap_material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh = _caps
	_image.fill(Color(UNCUT, UNCUT, 1.0, 0.0))
	_texture = ImageTexture.create_from_image(_image)
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter(&"cutaway_soft_blur", _blur_pass != null)
		material.set_shader_parameter(&"cutaway_columns", _texture)
		material.set_shader_parameter(&"voxel_from_world", _world.global_transform.affine_inverse())
		material.set_shader_parameter(&"voxel_normal_from_world", _world.global_basis.transposed())
	return _materials


func update_view(
	feet_global: Vector3, to_camera_global: Vector3, head_height: float,
	sprite_height: float, delta: float
) -> void:
	var feet := _world.to_local(feet_global)
	var view := _world.global_basis.inverse() * to_camera_global
	var sample := Vector4i(floori(feet.x * 4.0), floori(feet.y + 0.025),
		floori(feet.z * 4.0), ceili(feet.y + head_height - 0.025))
	var layer_changed := sample.y != _sample.y
	var height_sample := floori(feet.y * 4.0)
	if _dirty or sample != _sample or height_sample != _sample_height or not view.is_equal_approx(_sample_view):
		_sample = sample
		_sample_height = height_sample
		_sample_view = view
		_dirty = false
		var cuts := _region.columns(feet, view, head_height, sprite_height)
		_retarget(cuts, Vector2i(floori(feet.x), floori(feet.z)))
	if _animating:
		_advance(delta)
	elif layer_changed and _enabled and _construction_state.is_empty():
		prop_visibility_changed.emit()


func is_hidden(cell: Vector3i) -> bool:
	var column: Column = _columns.get(Vector2i(cell.x, cell.z))
	return column != null and cell.y >= column.height()


func prop_transparency(anchor: Vector3i) -> float:
	if not _construction_state.is_empty():
		if anchor.y > int(_construction_state[&"construction_cut"]):
			return 1.0 - float(_construction_state[&"construction_opacity"])
		return 0.0
	if anchor.y <= _sample.y:
		return 0.0
	var column: Column = _columns.get(Vector2i(anchor.x, anchor.z))
	if column == null:
		return 0.0
	var previous := 1.0 if anchor.y >= column.previous else 0.0
	var current := 1.0 if anchor.y >= column.current else 0.0
	return CUTAWAY_TRANSPARENCY * lerpf(previous, current, smoothstep(0.0, 1.0, column.progress))


func update_construction(
	player_cell: Vector3i, to_camera: Vector3, destination: Vector3i, has_destination: bool,
	config: ConstructionConfig
) -> void:
	var cut := player_cell.y + config.visible_layers_above
	var view := _world.global_basis.inverse() * to_camera
	var slope := Vector2(view.x, view.z) / view.y if view.y > 0.001 else Vector2.ZERO
	var state: Dictionary[StringName, Variant] = {
		&"construction_enabled": true,
		&"construction_layer": float(player_cell.y),
		&"construction_cut": float(cut),
		&"construction_opacity": config.obstacle_opacity,
		&"construction_style": config.transparency_style,
		&"construction_reveal_front": config.reveal_same_layer_obstacles,
		&"construction_slope": slope,
		&"construction_player": Vector2(player_cell.x, player_cell.z),
		&"construction_destination": Vector3(destination.x, destination.z, 1.0) if has_destination else Vector3.ZERO,
	}
	var chunk := VoxelChunkData.chunk_of(player_cell)
	var radius := _world.horizontal_radius
	var start := (Vector2i(chunk.x, chunk.z) - Vector2i.ONE * radius) * VoxelChunkData.SIZE
	var bounds := Rect2i(start, Vector2i.ONE * (2 * radius + 1) * VoxelChunkData.SIZE)
	var prop_cut_changed: bool = (
		_construction_state.get(&"construction_cut") != state[&"construction_cut"]
		or _construction_state.get(&"construction_opacity") != state[&"construction_opacity"]
	)
	var rebuild: bool = (
		_construction_caps_dirty or bounds != _construction_bounds
		or _construction_state.get(&"construction_layer") != state[&"construction_layer"]
		or _construction_state.get(&"construction_cut") != state[&"construction_cut"]
		or _construction_state.get(&"construction_reveal_front") != config.reveal_same_layer_obstacles
	)
	for parameter in state:
		if _construction_state.get(parameter) == state[parameter]:
			continue
		for material: ShaderMaterial in _materials:
			material.set_shader_parameter(parameter, state[parameter])
	_construction_state = state
	_update_blur_pass()
	_construction_bounds = bounds
	if rebuild:
		_rebuild_construction_caps(player_cell.y, cut, config.reveal_same_layer_obstacles)
		_construction_caps_dirty = false
	if prop_cut_changed:
		prop_visibility_changed.emit()


func clear_construction() -> bool:
	if _construction_state.is_empty():
		return false
	_construction_state.clear()
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter(&"construction_enabled", false)
	_update_blur_pass()
	_rebuild_caps()
	prop_visibility_changed.emit()
	return true


func _rebuild_construction_caps(layer: int, cut: int, reveal_front: bool) -> void:
	var faces: Dictionary[Vector4i, Vector2] = {}
	var end := _construction_bounds.end
	# Restore only top faces omitted by greedy meshing under the two possible cuts.
	# Cursor movement changes shader uniforms without touching these surfaces.
	for z in range(_construction_bounds.position.y, end.y):
		for x in range(_construction_bounds.position.x, end.x):
			_collect_face(faces, Vector3i(x, cut + 1, z), 2)
			if reveal_front:
				_collect_face(faces, Vector3i(x, layer, z), 2)
	_draw_caps(faces)


func _retarget(desired: Dictionary[Vector2i, int], center: Vector2i) -> void:
	var bounds := Rect2i(_origin, Vector2i(MASK_SIZE, MASK_SIZE))
	var changed := false
	# The mask follows only when its margin is exhausted, so adjacent movement keeps old fades.
	if not bounds.grow(-VoxelCutawayRegion.VIEW_REACH - 2).has_point(center):
		_origin = center - Vector2i(MASK_SIZE, MASK_SIZE) / 2
		bounds.position = _origin
		changed = true
		for column in _columns.keys():
			if not bounds.has_point(column):
				_columns.erase(column)
		for material: ShaderMaterial in _materials:
			material.set_shader_parameter(&"cutaway_origin", _origin)
	for column in _columns:
		var state := _columns[column]
		var next: int = desired.get(column, UNCUT)
		desired.erase(column)
		if next == state.current:
			continue
		changed = true
		if next == state.previous:
			state.previous = state.current
			state.current = next
			state.progress = 1.0 - state.progress
		else:
			state.previous = state.height()
			# Keep the preceding cut during continuous descent so the fade cannot stall.
			if next < state.current:
				state.previous = mini(state.previous, state.current)
			state.current = next
			state.progress = 0.0
		_animating = true
	for column in desired:
		_columns[column] = Column.new(UNCUT, desired[column])
		_animating = true
		changed = true
	if changed or _caps_dirty:
		_rebuild_caps()
		_caps_dirty = false
	if changed and not _animating:
		_upload()


func _advance(delta: float) -> void:
	_animating = false
	var removed := false
	for column in _columns.keys():
		var state := _columns[column]
		if state.progress >= 1.0 and state.previous == state.current:
			continue
		state.progress = minf(1.0, state.progress + delta / FADE_SECONDS)
		if state.progress < 1.0:
			_animating = true
		else:
			removed = removed or state.previous != state.current
			state.previous = state.current
			if state.current == UNCUT:
				_columns.erase(column)
	if removed:
		_rebuild_caps()
	_upload()


func _upload() -> void:
	var enable := not _columns.is_empty()
	var toggled := enable != _enabled
	if toggled:
		_enabled = enable
		for material: ShaderMaterial in _materials:
			material.set_shader_parameter(&"cutaway_enabled", enable)
		_update_blur_pass()
	if enable:
		_image.fill(Color(UNCUT, UNCUT, 1.0, 0.0))
		for column in _columns:
			var state := _columns[column]
			var texel := column - _origin
			_image.set_pixelv(texel, Color(state.previous, state.current, smoothstep(0.0, 1.0, state.progress), 0.0))
		_texture.update(_image)
	if (enable or toggled) and _construction_state.is_empty():
		prop_visibility_changed.emit()


func _update_blur_pass() -> void:
	if _blur_pass == null:
		return
	var show_blur := _enabled
	if not _construction_state.is_empty():
		var opacity: float = _construction_state[&"construction_opacity"]
		show_blur = (
			_construction_state[&"construction_style"] == ConstructionConfig.TransparencyStyle.SOFT_BLUR
			and opacity > 0.0 and opacity < 1.0
		)
	var next: Material = _blur_pass if show_blur else null
	if _terrain.next_pass != next:
		_terrain.next_pass = next


func _rebuild_caps() -> void:
	if not _construction_state.is_empty():
		return
	var faces: Dictionary[Vector4i, Vector2] = {}
	for column in _columns:
		var state := _columns[column]
		var first_height := mini(state.previous, state.current)
		if state.previous != UNCUT:
			_collect_face(faces, Vector3i(column.x, state.previous, column.y), 2)
		if state.current != UNCUT and state.current != state.previous:
			_collect_face(faces, Vector3i(column.x, state.current, column.y), 2)
		for side: int in [0, 1, 4, 5]:
			var normal := VoxelChunkData.DIRECTIONS[side]
			var neighbor: Column = _columns.get(column - Vector2i(normal.x, normal.z))
			if neighbor != null and neighbor.previous <= state.previous and neighbor.current <= state.current:
				if is_equal_approx(neighbor.progress, state.progress) or neighbor.previous == neighbor.current:
					continue
			var active_chunk_y := VoxelChunkData.chunk_of(Vector3i(0, _sample.y, 0)).y
			var top := (active_chunk_y + _world.vertical_radius + 1) * VoxelChunkData.SIZE
			if neighbor != null:
				top = mini(top, maxi(neighbor.previous, neighbor.current))
			for y in range(first_height, top):
				_collect_face(faces, Vector3i(column.x, y, column.y), side)
	_draw_caps(faces)


func _draw_caps(faces: Dictionary[Vector4i, Vector2]) -> void:
	_caps.clear_surfaces()
	if faces.is_empty():
		return
	_caps.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in faces:
		_add_face(Vector3i(face.x, face.y, face.z), face.w, faces[face])
	_caps.surface_end()


func _collect_face(faces: Dictionary[Vector4i, Vector2], hidden: Vector3i, side: int) -> void:
	var cell := hidden - VoxelChunkData.DIRECTIONS[side]
	if not _world.is_chunk_ready(VoxelChunkData.chunk_of(cell)):
		return
	var kept := _world.block_at(cell)
	var removed := _world.block_at(hidden)
	if kept == null or not kept.cube or kept.slot != 0 or removed == null:
		return
	if removed.opaque_sides & (1 << (side ^ 1)):
		var top_style := kept.top_style if side == 2 else 0
		faces[Vector4i(cell.x, cell.y, cell.z, side)] = Vector2(kept.tiles[side], top_style << 6)


func _add_face(cell: Vector3i, side: int, tile_data: Vector2) -> void:
	@warning_ignore("integer_division")
	var axis := side / 2
	var positive := side % 2 == 0
	var normal := Vector3(VoxelChunkData.DIRECTIONS[side])
	var start := Vector3(cell) + (normal if positive else Vector3.ZERO)
	var u := Vector3.ZERO
	var v := Vector3.ZERO
	u[(axis + 1) % 3] = 1.0
	v[(axis + 2) % 3] = 1.0
	var corners := [start, start + u, start + u + v, start + v]
	var triangles := [0, 2, 1, 0, 3, 2] if positive else [0, 1, 2, 0, 2, 3]
	for index: int in triangles:
		var point: Vector3 = corners[index]
		_caps.surface_set_normal(normal)
		_caps.surface_set_uv(VoxelChunkMesher.project_uv(point, axis))
		_caps.surface_set_uv2(tile_data)
		_caps.surface_add_vertex(point)


func _blocks_changed(cells: Array[Vector3i]) -> void:
	for cell in cells:
		var column := Vector2i(cell.x, cell.z)
		if _construction_bounds.has_point(column) and _changes_construction_cap(cell.y, cell.y):
			_construction_caps_dirty = true
		if Rect2i(_origin, Vector2i(MASK_SIZE, MASK_SIZE)).has_point(column):
			_dirty = true
			_caps_dirty = true


func _chunk_changed(chunk: Vector3i) -> void:
	var start := Vector2i(chunk.x, chunk.z) * VoxelChunkData.SIZE
	var bounds := Rect2i(start, Vector2i.ONE * VoxelChunkData.SIZE)
	var bottom := chunk.y * VoxelChunkData.SIZE
	if _construction_bounds.intersects(bounds) and _changes_construction_cap(bottom, bottom + VoxelChunkData.SIZE - 1):
		_construction_caps_dirty = true
	if Rect2i(_origin, Vector2i(MASK_SIZE, MASK_SIZE)).intersects(bounds):
		_dirty = true
		_caps_dirty = true


func _changes_construction_cap(bottom: int, top: int) -> bool:
	if _construction_state.is_empty():
		return false
	var cut := int(_construction_state[&"construction_cut"])
	var layer := int(_construction_state[&"construction_layer"])
	return (bottom <= cut + 1 and top >= cut) or (
		_construction_state[&"construction_reveal_front"] and bottom <= layer and top >= layer - 1
	)
