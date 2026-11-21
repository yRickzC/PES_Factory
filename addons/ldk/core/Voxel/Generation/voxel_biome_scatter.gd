@tool
class_name VoxelBiomeScatter
extends Resource

@export_group("Conteúdo")
## Entidades sorteadas com a mesma chance entre as variantes registradas.
@export var variants: Array[StringName] = []

@export_group("Distribuição")
## Tamanho da célula que recebe um ponto candidato, em blocos.
@export_range(1, 128, 1, "suffix:blocos") var spacing := 5
## Chance de cada ponto iniciar um agrupamento. O preset do mundo multiplica este valor.
@export_range(0.0, 1.0, 0.01) var chance := 0.5
## Raio do agrupamento em blocos. Zero distribui objetos individuais.
@export_range(0, 12, 1, "suffix:blocos") var radius := 0
## Número de tentativas por agrupamento. Posições ocupadas ou inválidas são descartadas.
@export_range(1, 32) var attempts := 1

@export_group("Condições do terreno")
## Alturas mínima e máxima do bloco de suporte.
@export var elevation := Vector2i(-2147483648, 2147483647)
## Maior diferença de altura para os quatro vizinhos imediatos. -1 desativa o filtro.
@export_range(-1, 16, 1, "or_greater", "suffix:blocos") var max_step := -1
