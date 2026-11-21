@tool
class_name VoxelWorldBiome
extends Resource
## A biome reference and its placement rules for one world.

@export_group("Presença no mundo")
## Recurso do bioma incluído neste preset. Blocos, relevo e objetos vêm da definição do bioma.
@export var biome: VoxelBiome
## Peso deste bioma neste mundo. Valores maiores favorecem sua ocorrência. 0 exclui o bioma da seleção.
@export_range(0.0, 10.0, 0.01, "or_greater") var frequency_weight := 1.0
## Multiplicador do tamanho da região deste bioma. Valores acima de 1 ampliam sua área no mapa climático.
@export_range(0.25, 4.0, 0.01, "or_greater") var region_size_scale := 1.0

@export_group("Clima e transição")
## Usa a temperatura e a umidade definidas abaixo para este mundo.
@export var override_climate := false
## Clima preferido deste bioma no mundo. X é temperatura e Y é umidade, ambos de -1 a 1.
@export var climate := Vector2.ZERO
## Largura que este bioma contribui para a faixa de transição de materiais. 0 reduz sua contribuição a zero. -1 herda a largura do bioma ou do mundo.
@export_range(-1.0, 512.0, 1.0, "or_greater", "suffix:blocks") var material_transition_width := -1.0
