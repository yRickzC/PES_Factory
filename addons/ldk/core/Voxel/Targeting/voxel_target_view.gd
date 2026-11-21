class_name VoxelTargetView
extends CanvasLayer
## Applies selection to the existing chunk surfaces and draws an optional pixel reticle.

var _materials: Array[Material]
var _reticle: Sprite2D
var _range_grid: Line2D
var _preview := MeshInstance3D.new()
var _preview_meshes: Dictionary[int, ArrayMesh] = {}
var _shown := false
var _cell := Vector3i.ZERO
var _normal := Vector3.ZERO
var _plane := 0.0
var _whole_block := false
var _mining_cell := Vector3i.ZERO
var _mining_stage := 0
var _mining_stages: int


func configure(
	config: VoxelTargetingConfig, materials: Array[Material], world: Node3D, tiles: Texture2DArray
) -> void:
	_materials = materials
	_mining_stages = maxi(1, config.mining_stages)
	var settings := Vector3(config.opacity, config.fill_opacity, config.outline_width)
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter(&"target_color", config.color)
		material.set_shader_parameter(&"target_settings", settings)
		material.set_shader_parameter(&"target_style", config.style)
		material.set_shader_parameter(&"mining_color", config.mining_color)
		material.set_shader_parameter(&"mining_edge_color", config.mining_edge_color)
		material.set_shader_parameter(&"mining_opacity", config.mining_opacity)
	layer = 1
	_range_grid = Line2D.new()
	_range_grid.points = PackedVector2Array([
		Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5),
	])
	_range_grid.closed = true
	_range_grid.default_color = config.out_of_range_color
	_range_grid.width = config.outline_width
	_range_grid.hide()
	add_child(_range_grid)
	_reticle = Sprite2D.new()
	_reticle.texture = config.reticle_texture
	_reticle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_reticle.offset = config.reticle_offset
	_reticle.scale = Vector2.ONE * config.reticle_scale
	_reticle.hide()
	add_child(_reticle)
	var ghost := ShaderMaterial.new()
	ghost.shader = preload("res://addons/ldk/core/Voxel/Targeting/voxel_placement_ghost.gdshader")
	ghost.set_shader_parameter(&"tile_layers", tiles)
	ghost.set_shader_parameter(&"opacity", config.preview_opacity)
	_preview.material_override = ghost
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if config.preview_outline_width > 0.0 and config.preview_outline_color.a > 0.0:
		var outline := ShaderMaterial.new()
		outline.shader = preload("res://addons/ldk/core/Voxel/Targeting/voxel_placement_outline.gdshader")
		outline.render_priority = 1
		outline.set_shader_parameter(&"outline_color", config.preview_outline_color)
		outline.set_shader_parameter(&"outline_width", config.preview_outline_width)
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE
		var footprint := MeshInstance3D.new()
		footprint.mesh = plane
		footprint.position = Vector3(0.5, 0.0, 0.5)
		footprint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		footprint.material_override = outline
		_preview.add_child(footprint)
	_preview.hide()
	world.add_child(_preview)


func update_preview(cell: Vector3i, block: VoxelCatalog.BakedBlock = null, connections := 0) -> void:
	if block == null or (not block.cube and block.visual == null):
		_preview.hide()
		return
	var key := block.get_instance_id() if block.cube else block.visual_for(connections).get_instance_id()
	if not _preview_meshes.has(key):
		var mesh := ArrayMesh.new()
		var surface := VoxelChunkMesher.preview_surface(block, connections)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface.mesh_arrays())
		_preview_meshes[key] = mesh
	if _preview.mesh != _preview_meshes[key]:
		_preview.mesh = _preview_meshes[key]
	if _preview.position != Vector3(cell):
		_preview.position = Vector3(cell)
	_preview.show()


func update_mining_progress(cell: Vector3i, progress: float) -> void:
	var stage := ceili(clampf(progress, 0.0, 1.0) * _mining_stages)
	if stage == _mining_stage and (stage == 0 or cell == _mining_cell):
		return
	_mining_stage = stage
	_mining_cell = cell
	for material: ShaderMaterial in _materials:
		if stage > 0:
			material.set_shader_parameter(&"mining_cell", Vector3(cell))
		material.set_shader_parameter(&"mining_progress", float(stage) / _mining_stages)


func update_range_grid(target: VoxelTargeting, camera: Camera3D, enabled: bool) -> void:
	_range_grid.visible = enabled and target.out_of_range
	if not _range_grid.visible:
		return
	var world := _preview.get_parent() as Node3D
	var center := Vector3(target.cell) + Vector3.ONE * 0.5
	var axis := Vector3(target.face).abs().max_axis_index()
	center[axis] = target.local_point[axis]
	var across := Vector3.BACK if axis == Vector3.AXIS_X else Vector3.RIGHT
	var vertical := Vector3.BACK if axis == Vector3.AXIS_Y else Vector3.UP
	var screen := camera.unproject_position(world.to_global(center))
	var x := camera.unproject_position(world.to_global(center + across)) - screen
	var y := camera.unproject_position(world.to_global(center + vertical)) - screen
	var projection := Transform2D(x, y, screen)
	if _range_grid.transform != projection:
		_range_grid.transform = projection


func update_target(target: VoxelTargeting, screen: Vector2, enabled: bool) -> void:
	_reticle.visible = enabled and _reticle.texture != null
	if _reticle.visible:
		_reticle.position = screen.round()
	var show_target := enabled and target.valid
	var plane := target.normal.dot(target.local_point - Vector3(target.cell))
	if show_target == _shown and (
		not show_target or (_cell == target.cell and _normal.is_equal_approx(target.normal)
		and is_equal_approx(_plane, plane) and _whole_block == target.whole_block)
	):
		return
	_shown = show_target
	_cell = target.cell
	_normal = target.normal
	_plane = plane
	_whole_block = target.whole_block
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter(&"target_enabled", _shown)
		if _shown:
			material.set_shader_parameter(&"target_cell", Vector3(_cell))
			material.set_shader_parameter(&"target_normal", _normal)
			material.set_shader_parameter(&"target_plane", _plane)
			material.set_shader_parameter(&"target_whole_block", _whole_block)
