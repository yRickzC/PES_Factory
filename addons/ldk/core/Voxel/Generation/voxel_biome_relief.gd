@tool
class_name VoxelBiomeRelief
extends Resource
## Elevations refer to the Y coordinate of the surface block.

@export_group("Altura e ondulação")
## Altura Y de referência do bloco na superfície deste bioma.
@export var base_height := 8.0
## Variação de altura em blocos em torno da altura base, antes dos ajustes globais.
@export_range(0.0, 100.0, 0.1, "or_greater") var amplitude := 1.5
## Frequência do ruído de elevação. Valores maiores fazem as ondulações acontecerem em distâncias menores.
@export_range(0.0001, 1.0, 0.0001) var noise_frequency := 0.008
## Achata variações pequenas e preserva os picos do ruído. A suavidade global pode reforçar esse efeito.
@export_range(0.0, 1.0, 0.01) var smoothness := 0.5
## Altura Y mínima e máxima do perfil antes da mistura com outros biomas, nessa ordem. Infinito deixa o extremo livre.
@export var elevation_limits := Vector2(-INF, INF)

@export_group("Transição e inclinação")
## Largura solicitada da transição de altura com biomas vizinhos. -1 herda a largura do mundo.
@export_range(-1.0, 512.0, 1.0, "or_greater", "suffix:blocks") var transition_blocks := -1.0
## Inclinação desejada em blocos verticais por bloco horizontal. -1 herda do mundo. 0 desativa o ajuste neste bioma.
@export_range(-1.0, 2.0, 0.01, "or_greater") var desired_max_slope := -1.0
## Legacy adjustment for profiles that used climate-space widths.
@export_storage var transition_width := 0.14

@export_group("Afloramentos")
## Altura extra em blocos nas formações de terreno, antes dos ajustes globais. Zero desativa as formações.
@export_range(0.0, 32.0, 0.1, "or_greater", "suffix:blocks") var outcrop_height := 0.0
## Frequência do ruído das formações. Valores menores criam agrupamentos mais largos e espaçados.
@export_range(0.0001, 1.0, 0.0001) var outcrop_frequency := 0.072
## Número de camadas de ruído. Valores maiores acrescentam detalhes menores às formações.
@export_range(1, 8) var outcrop_octaves := 2
## Valores do ruído em que as formações começam a subir e atingem a altura máxima, respectivamente.
@export var outcrop_thresholds := Vector2(0.12, 0.54)


func limit_elevation(height: float) -> float:
	return clampf(height, minf(elevation_limits.x, elevation_limits.y),
		maxf(elevation_limits.x, elevation_limits.y))
