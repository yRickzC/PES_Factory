extends Resource

enum TransparencyStyle { ORDERED_DITHER, PIXEL_HASH, SOFT_BLUR }
enum AimMode { CURSOR, INHERIT_TARGETING }

@export_group("Seleção por camada")
## Distância máxima para colocar blocos enquanto o atalho de construção por camada estiver pressionado.
@export_range(0.5, 20.0, 0.1) var reach := 6.0
## Escolhe entre usar sempre o cursor ou herdar o modo de mira normal durante a construção por camada.
@export var aim_mode := AimMode.CURSOR
## Altura do plano de mira dentro da célula. 0 usa a base e 1 usa o topo.
@export_range(0.0, 1.0, 0.05) var cursor_plane_height := 0.0

@export_group("Visibilidade do terreno")
## Torna transparentes os obstáculos que bloqueiam a visão do alvo na camada de construção.
@export var reveal_same_layer_obstacles := true
## Número de camadas acima da construção que ficam fora do corte por altura. 0 aplica o corte logo acima da camada atual.
@export_range(0, 8) var visible_layers_above := 0
## Opacidade das superfícies afetadas pelo corte. 0 as oculta e 1 as mantém sólidas.
@export_range(0.0, 1.0, 0.01) var obstacle_opacity := 0.1
## Escolhe o efeito visual dos blocos transparentes. Desfoque suaviza as texturas atingidas; as outras opções usam tramas de pixels.
@export var transparency_style := TransparencyStyle.SOFT_BLUR
