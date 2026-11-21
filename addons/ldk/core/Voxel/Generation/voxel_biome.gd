@tool
class_name VoxelBiome
extends Resource
## Climate anchors are normalized to [-1, 1].

@export_group("Identidade e clima")
## ID único do bioma, no formato [code]namespace:nome[/code], usado pelo registro e pelos presets de mundo.
@export var key: StringName
## Clima em que o bioma tende a aparecer. X é temperatura e Y é umidade, ambos de -1 a 1.
@export var climate := Vector2.ZERO
## Peso relativo que favorece a ocorrência deste bioma em relação a outros com clima parecido.
@export_range(0.01, 10.0) var distribution_weight := 1.0

@export_group("Relevo")
## Perfil com a altura, a amplitude das ondulações e os limites de elevação deste bioma.
@export var terrain_relief: VoxelBiomeRelief
## Deslocamento sobre a altura base do mundo. Só é usado quando o bioma está sem perfil próprio de relevo.
@export var elevation_offset := 0.0
## Amplitude das ondulações quando o bioma está sem perfil próprio de relevo.
@export_range(0.0, 100.0) var relief := 4.0

@export_group("Camadas do terreno")
## ID do bloco que cobre o topo do terreno.
@export var surface: StringName
## ID do bloco colocado logo abaixo da superfície.
@export var soil: StringName
## Número de camadas de solo abaixo da superfície antes da rocha.
@export_range(0, 32) var soil_depth := 2
## ID da rocha que preenche o subsolo abaixo das camadas de solo.
@export var bedrock: StringName
## ID do líquido que cobre terrenos baixos neste bioma. Vazio usa o bloco de água padrão do mundo.
@export var water: StringName
## Largura da faixa de transição entre os materiais deste bioma e os dos vizinhos. -1 herda o padrão do mundo.
@export_range(-1.0, 512.0, 1.0, "or_greater", "suffix:blocks") var material_transition_width := -1.0

## Blocos alternativos para o topo, com as mesmas funções e recompensas do bloco principal.
@export var surface_variants: Array[StringName] = []
## Blocos alternativos para o solo abaixo da superfície.
@export var soil_variants: Array[StringName] = []
## Chance de escolher um tile alternativo em cada coluna. A superfície e o solo são sorteados separadamente.
@export_range(0.0, 1.0, 0.01) var terrain_variant_chance := 0.0

@export_group("Objetos procedurais")
## IDs de entidades usadas como vegetação, como árvores.
@export var vegetation: Array[StringName] = []
## IDs de outras entidades candidatas a aparecer na geração deste bioma.
@export var entities: Array[StringName] = []
## IDs de estruturas candidatas a aparecer na geração deste bioma.
@export var structures: Array[StringName] = []
## Espaçamento em blocos entre os pontos candidatos. Valores maiores tendem a deixar os objetos mais distantes.
@export_range(1, 128) var spawn_spacing := 11
## Probabilidade base de gerar um objeto em cada ponto candidato válido. A configuração do mundo multiplica essa chance.
@export_range(0.0, 1.0) var spawn_chance := 0.8
## Faixa de altura para gerar objetos. O primeiro valor é o Y mínimo da superfície e o segundo é o máximo.
@export var spawn_height := Vector2i(-2147483648, 2147483647)
## Regras adicionais de distribuição. Regras anteriores têm preferência em posições compartilhadas.
@export var scatter: Array[VoxelBiomeScatter] = []

@export_group("Dados adicionais")
## IDs de itens associados ao bioma. O gerador atual só valida essas referências.
@export var items: Array[StringName] = []
## Metadados ambientais do bioma. A iluminação e a atmosfera atuais vêm do preset de mundo.
@export var environment: Dictionary = {}
