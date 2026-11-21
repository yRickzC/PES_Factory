class_name VoxelChunkView
extends Node3D
## A pooled presentation for one chunk. All scene, GPU and physics work stays here.

var vertex_count := 0
var triangle_count := 0
var surface_count := 0

var _visual := MeshInstance3D.new()
var _body := StaticBody3D.new()
var _shape := CollisionShape3D.new()


func _init() -> void:
	add_child(_visual)
	add_child(_body)
	_body.add_child(_shape)


func apply(coord: Vector3i, payload: VoxelMeshPayload, materials: Array[Material]) -> void:
	position = Vector3(coord * VoxelChunkData.SIZE)
	var mesh := ArrayMesh.new()
	for slot in payload.surfaces.size():
		var surface := payload.surfaces[slot]
		if surface.indices.is_empty():
			continue
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface.mesh_arrays())
		mesh.surface_set_material(mesh.get_surface_count() - 1, materials[slot])
	surface_count = mesh.get_surface_count()
	_visual.mesh = mesh if surface_count > 0 else null
	vertex_count = payload.vertex_count()
	triangle_count = payload.triangle_count()
	if payload.collision.is_empty():
		_shape.shape = null
	else:
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(payload.collision)
		_shape.shape = shape
	show()


func release() -> void:
	hide()
	_visual.mesh = null
	_shape.shape = null
