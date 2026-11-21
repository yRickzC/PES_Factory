class_name VoxelMeshPayload
extends RefCounted
## Worker output with CPU-side buffers. Engine meshes and shapes are built by the view.

class Surface extends RefCounted:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var layers := PackedVector2Array()
	var indices := PackedInt32Array()

	func add_vertex(point: Vector3, normal: Vector3, tex_uv: Vector2, tile: Vector2) -> void:
		vertices.append(point)
		normals.append(normal)
		uv.append(tex_uv)
		layers.append(tile)

	func mesh_arrays() -> Array:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_TEX_UV2] = layers
		arrays[Mesh.ARRAY_INDEX] = indices
		return arrays


var surfaces: Array[Surface] = [Surface.new(), Surface.new()]
var collision := PackedVector3Array()


func vertex_count() -> int:
	return surfaces[0].vertices.size() + surfaces[1].vertices.size()


func triangle_count() -> int:
	@warning_ignore("integer_division")
	return (surfaces[0].indices.size() + surfaces[1].indices.size()) / 3


func is_empty() -> bool:
	return collision.is_empty() and vertex_count() == 0
