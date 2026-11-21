@tool
class_name VoxelModel
extends Resource
## Clockwise triangle soup in cell space, with UVs in repeating cell units.
## A boundary of -1 marks a triangle that cannot be culled by a neighbor.

@export_group("Triângulos do modelo")
## Coordenadas dentro da célula, em grupos de três vértices em ordem horária por triângulo.
@export var vertices := PackedVector3Array()
## Um valor por triângulo. Use -1 se um vizinho nunca deve ocultá-lo ou 0 a 5 para os lados +X, -X, +Y, -Y, +Z, -Z.
@export var boundaries := PackedInt32Array()

@export_group("Mapeamento de texturas")
## Uma coordenada de textura por vértice. Uma unidade de UV corresponde a uma repetição do tile.
@export var uv := PackedVector2Array()
## Um ID de textura por triângulo do modelo visual.
@export var tiles: Array[StringName] = []

var runtime_tiles := PackedByteArray()


func is_valid(for_render: bool) -> bool:
	return is_valid_data(self, for_render)


## Reads exported geometry even when the editor has a placeholder script instance.
static func is_valid_data(model: VoxelModel, for_render: bool) -> bool:
	if model == null:
		return false
	var model_vertices: Variant = model.get(&"vertices")
	var model_boundaries: Variant = model.get(&"boundaries")
	if not model_vertices is PackedVector3Array or not model_boundaries is PackedInt32Array:
		return false
	var vertex_count: int = model_vertices.size()
	@warning_ignore("integer_division")
	var triangles := vertex_count / 3
	if vertex_count % 3 != 0 or model_boundaries.size() != triangles:
		return false
	if for_render:
		var model_uv: Variant = model.get(&"uv")
		var model_tiles: Variant = model.get(&"tiles")
		if not model_uv is PackedVector2Array or not model_tiles is Array:
			return false
		if model_uv.size() != vertex_count or model_tiles.size() != triangles:
			return false
	for side: int in model_boundaries:
		if side < -1 or side >= 6:
			return false
	return true
