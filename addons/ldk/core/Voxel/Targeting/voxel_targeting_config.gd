class_name VoxelTargetingConfig
extends Resource

enum AimMode { CURSOR, FACING }
enum Style { OUTLINE, FILL, OUTLINE_AND_FILL }
enum CornerPriority { NEAREST, X_AXIS, Z_AXIS }

@export_group("Mira e alcance")
## Escolhe se a mira segue o cursor ou a direção para a qual o jogador está virado.
@export var aim_mode := AimMode.CURSOR
## Distância máxima para selecionar um bloco ou objeto com a mira.
@export_range(0.5, 20.0, 0.1) var reach := 6.0
## Distância máxima para colocar um bloco no modo normal, medida até o centro da célula de destino.
@export_range(0.5, 20.0, 0.1) var placement_distance := 6.0
## No modo direção, distância à frente do jogador usada para projetar a mira.
@export_range(0.5, 20.0, 0.1) var facing_distance := 2.5
## Altura acima dos pés usada como referência ao medir o alcance das interações.
@export_range(0.0, 2.0, 0.05) var interaction_height := 0.9
## Permite que blocos sem colisão, como água, sejam selecionados pela mira.
@export var select_non_solid := false

@export_group("Seleção de faces")
## Largura da faixa do topo que seleciona uma face lateral. Zero exige mirar diretamente na face lateral.
@export_range(0.0, 0.45, 0.01) var side_edge_width := 0.22
## Ao mirar na borda do topo, usa a célula acima do vizinho se ele ocupar a lateral selecionada.
@export var place_over_side_neighbor := true
## Largura da faixa junto à base de uma lateral visível que seleciona a face inferior. Zero desativa o atalho.
@export_range(0.0, 0.45, 0.01) var bottom_edge_width := 0.18
## Margem em unidades de bloco que mantém a face atual estável perto da divisão entre regiões.
@export_range(0.0, 0.12, 0.005) var face_hysteresis := 0.035
## Desempata bordas próximas nos cantos do topo, usando a mais próxima, o eixo X ou o eixo Z.
@export var corner_priority := CornerPriority.NEAREST

@export_group("Destaque do alvo")
## Escolhe se o alvo recebe contorno, preenchimento ou os dois.
@export var style := Style.OUTLINE_AND_FILL
## Cor do contorno e do preenchimento sobre o bloco selecionado.
@export var color := Color("#ffe49b")
## Cor do contorno quando a célula sob a mira está fora do alcance.
@export var out_of_range_color := Color("#ff4545")
## Opacidade geral do destaque. Multiplica também a intensidade do preenchimento.
@export_range(0.0, 1.0, 0.01) var opacity := 0.85
## Intensidade da cor sobre a superfície selecionada quando o estilo usa preenchimento.
@export_range(0.0, 1.0, 0.01) var fill_opacity := 0.16
## Espessura do contorno do bloco, em unidades do mundo.
@export_range(0.01, 0.25, 0.01) var outline_width := 0.075

@export_group("Ícone da mira")
## Textura opcional do ícone de mira. Vazio deixa visível apenas o destaque do alvo.
@export var reticle_texture: Texture2D
## Deslocamento do ícone em pixels em relação ao ponto marcado.
@export var reticle_offset := Vector2.ZERO
## Multiplicador do tamanho do ícone da mira na tela.
@export_range(0.5, 4.0, 0.25) var reticle_scale := 1.0

@export_group("Prévia de construção")
## Opacidade do bloco fantasma que mostra onde a peça será posicionada.
@export_range(0.0, 1.0, 0.01) var preview_opacity := 0.48
## Cor e opacidade do contorno da célula de destino, visível mesmo atrás de uma parede.
@export var preview_outline_color := Color(0.78, 0.96, 0.74, 0.76)
## Espessura em unidades de bloco do contorno na base da célula. Zero desativa o contorno.
@export_range(0.0, 0.2, 0.01) var preview_outline_width := 0.04

@export_group("Efeito de quebra")
## Número de etapas visuais das rachaduras até o bloco quebrar.
@export_range(1, 16) var mining_stages := 8
## Cor principal das rachaduras durante a quebra.
@export var mining_color := Color("#3c2c31")
## Cor das bordas iluminadas das rachaduras.
@export var mining_edge_color := Color("#ffe6b5a6")
## Opacidade geral do efeito de rachaduras.
@export_range(0.0, 1.0, 0.01) var mining_opacity := 0.86
