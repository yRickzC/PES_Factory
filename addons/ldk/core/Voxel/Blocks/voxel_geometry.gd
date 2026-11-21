@tool
class_name VoxelGeometry
extends VoxelVisual

@export_group("Forma e texturas")
## Desenha um cubo inteiro e permite combinar suas faces com as dos blocos vizinhos. Desative para usar um modelo.
@export var cube := false
## IDs das seis texturas do cubo, na ordem +X, -X, +Y (topo), -Y (base), +Z, -Z.
@export var face_tiles: Array[StringName] = [&"", &"", &"", &"", &"", &""]
## Modelo visual usado para formatos como escadas, telhados e meios blocos.
@export var model: VoxelModel
## Escolhe a camada de desenho. 0 usa o material opaco, 1 usa o transparente.
@export_range(0, 1) var material_slot := 0

@export_group("Conexões")
## Modelo opcional da extensão voltada para +X. O jogo gira a extensão para cada vizinho conectado.
@export var connection_arm: VoxelModel


func bake_geometry() -> Resource:
	return self
