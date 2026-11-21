extends MultiMeshInstance3D
## A chunk-local group of sprites with a single shared mesh and material.

const HIDDEN := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)

var _active: PackedByteArray
var _active_count := 0
var size: Vector2
var texture: Texture2D


static func make_quad(sprite: Texture2D, dimensions: Vector2) -> QuadMesh:
	var material := StandardMaterial3D.new()
	material.albedo_texture = sprite
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = dimensions
	quad.material = material
	return quad


func configure(quad: QuadMesh, count: int, chunk_origin: Vector3i) -> void:
	var material := quad.material as StandardMaterial3D
	texture = material.albedo_texture
	size = quad.size
	position = Vector3(chunk_origin)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = quad
	multimesh.instance_count = count
	_active.resize(count)
	var margin := Vector3(size.x * 0.5, size.y + 1.0, 0.0)
	multimesh.custom_aabb = AABB(Vector3(-margin.x, 0.0, 0.0), Vector3.ONE * VoxelChunkData.SIZE + margin + Vector3(margin.x, 0.0, 0.0))
	hide()
	for index in count:
		multimesh.set_instance_transform(index, HIDDEN)
		multimesh.set_instance_color(index, Color.WHITE)


func is_active(index: int) -> bool:
	return _active[index] != 0


func set_active(index: int, support: Vector3i, active: bool) -> bool:
	if is_active(index) == active:
		return false
	_active[index] = int(active)
	_active_count += 1 if active else -1
	if active:
		var center := Vector3(support) - position + Vector3(0.5, 1.0 + size.y * 0.5, 0.5)
		multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, center))
	else:
		multimesh.set_instance_transform(index, HIDDEN)
	visible = _active_count > 0
	return true
