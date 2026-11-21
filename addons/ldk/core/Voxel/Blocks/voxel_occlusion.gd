@tool
class_name VoxelOcclusion
extends Resource

@export_group("Ocultação de faces")
## Lados que cobrem completamente a face correspondente do bloco vizinho.
@export_flags("+X", "-X", "+Y", "-Y", "+Z", "-Z") var full_sides := 0
## Blocos com o mesmo valor diferente de 0 escondem as faces da divisa entre si. Útil para superfícies de água contínuas.
@export_range(0, 255) var merge_group := 0
