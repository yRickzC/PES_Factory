@tool
class_name VoxelCollision
extends Resource

@export_group("Forma física")
## Usa a célula inteira como colisão. Desative para usar o formato do modelo abaixo.
@export var cube := false
## Modelo físico usado para permitir passagem, apoio ou degraus conforme o formato escolhido.
@export var model: VoxelModel
## Lados totalmente sólidos que permitem descartar superfícies internas da malha física dos vizinhos.
@export_flags("+X", "-X", "+Y", "-Y", "+Z", "-Z") var full_sides := 0

@export_group("Conexões")
## Colisão opcional da extensão voltada para +X, girada para cada vizinho conectado.
@export var connection_arm: VoxelModel
