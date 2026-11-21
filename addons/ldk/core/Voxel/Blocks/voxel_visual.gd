@tool
class_name VoxelVisual
extends Resource
## Authoring contract for block visuals. Geometry is resolved before meshing.

const AUTHORED_OCCLUSION := -1

@export_group("Variação da textura superior")
## Sorteia a orientação da textura no topo de cubos opacos. A forma, as laterais e a colisão permanecem iguais.
@export var randomize_top_rotation := false
## Giros que o topo pode receber. Se nenhum estiver marcado, mantém 0°.
@export_flags("0°:1", "90°:2", "180°:4", "270°:8") var top_rotation_angles := 15
## IDs de texturas alternativas para o topo. A textura principal também participa do sorteio.
@export var top_texture_variants: Array[StringName] = []


## Return VoxelGeometry with the resolved shape, textures and material.
func bake_geometry() -> Resource:
	return null


## Return a six-face occlusion mask or defer to the block's authored Occlusion.
func automatic_occlusion() -> int:
	return AUTHORED_OCCLUSION


func validation_issue() -> String:
	return ""
