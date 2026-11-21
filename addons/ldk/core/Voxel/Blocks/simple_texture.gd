@tool
class_name SimpleTexture
extends VoxelVisual
## A full opaque cube with one registered texture on every face.

@export var texture: StringName

var _geometry: VoxelGeometry


func bake_geometry() -> Resource:
	if _geometry == null or _geometry.face_tiles[0] != texture:
		_geometry = VoxelGeometry.new()
		_geometry.cube = true
		_geometry.face_tiles.fill(texture)
	return _geometry


func automatic_occlusion() -> int:
	return 0b111111


func validation_issue() -> String:
	if texture.is_empty():
		return "Selecione uma textura para o SimpleTexture."
	if ContentRegistry.namespace_of(texture).is_empty():
		return "Use um ID namespace:nome para a textura."
	return ""
