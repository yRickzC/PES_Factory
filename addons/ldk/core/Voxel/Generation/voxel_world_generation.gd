@tool
class_name VoxelWorldGeneration
extends Resource

const BiomeRule = preload("res://addons/ldk/core/Voxel/Generation/voxel_world_biome.gd")

@export_group("Distribuição dos biomas")
## Biomas disponíveis neste mundo e suas regras locais. Sem entradas válidas, usa os biomas registrados.
@export var biomes: Array[BiomeRule] = []
## Escala nominal das regiões, em blocos. Valores maiores fazem os biomas se estenderem por uma área maior.
@export_range(1.0, 2048.0, 1.0, "or_greater", "suffix:blocks") var biome_region_size := 320.0
## Multiplicador da frequência da temperatura e da umidade. Aumente para o clima mudar mais rápido pelo mapa.
@export_range(0.01, 4.0, 0.01, "or_greater") var climate_frequency_scale := 0.70
## Quantidade de camadas de ruído no clima. Valores maiores adicionam detalhes menores ao desenho das regiões.
@export_range(1, 8) var climate_octaves := 2
## Influência dos pesos de bioma na distribuição. Em 0, a escolha depende da proximidade climática e da escala da região.
@export_range(0.0, 1.0, 0.01) var distribution_weight_strength := 0.12

@export_group("Transição de materiais")
## Largura padrão da faixa em que os blocos de superfície de dois biomas se alternam.
@export_range(0.0, 512.0, 1.0, "or_greater", "suffix:blocks") var material_transition_width := 40.0
## Controla o tamanho das manchas de material nas fronteiras. Valores maiores produzem manchas menores.
@export_range(0.001, 1.0, 0.001) var material_noise_frequency := 0.09
## Controla a formação de manchas na fronteira. Em 0 a alternância é por bloco, em 1 segue o ruído de manchas.
@export_range(0.0, 1.0, 0.01) var material_patchiness := 0.65

@export_group("Relevo")
## Altura de referência para biomas sem recurso próprio de relevo. O deslocamento de cada bioma é somado a esse valor.
@export var base_height := 4
## Frequência do relevo para biomas sem recurso próprio. Valores maiores aproximam as ondulações.
@export_range(0.0001, 1.0, 0.0001) var elevation_frequency := 0.008
## Quantidade de camadas de ruído no relevo. Valores maiores acrescentam variações de menor escala.
@export_range(1, 8) var elevation_octaves := 3
## Multiplica a variação de altura de todos os biomas. Em 0, cada bioma usa sua altura base antes das transições e depressões.
@export_range(0.0, 8.0, 0.01, "or_greater") var amplitude_scale := 1.0
## Multiplica a frequência de relevo de todos os biomas. Valores maiores aproximam as ondulações.
@export_range(0.01, 8.0, 0.01, "or_greater") var elevation_frequency_scale := 1.0
## Reforça a suavidade dos perfis. Valores maiores deixam áreas mais planas entre os extremos do relevo.
@export_range(0.0, 1.0, 0.01) var elevation_smoothness := 0.25
## Largura padrão, em blocos, para misturar as alturas de biomas vizinhos.
@export_range(0.0, 512.0, 1.0, "or_greater", "suffix:blocks") var relief_transition_width := 64.0
## Inclinação desejada em blocos verticais por bloco horizontal. Valores menores suavizam o relevo. 0 desativa esse ajuste global.
@export_range(0.0, 2.0, 0.01, "or_greater") var desired_max_slope := 0.22

@export_group("Água e fundo do mundo")
## Altura Y até a qual a água preenche o espaço sobre o terreno baixo.
@export var water_level := 2
## ID do bloco de água padrão. Cada bioma pode escolher outro líquido.
@export var water_key: StringName
## ID do bloco do fundo do mundo. Deixe vazio para desativar o piso global.
@export var floor_key: StringName
## Altura Y do piso global. Com um bloco de fundo válido, o gerador bloqueia edições nessa camada e abaixo dela.
@export var floor_y := 0

@export_group("Depressões")
## Cria depressões naturais no relevo. Elas podem alagar quando ficam abaixo do nível da água.
@export var basins_enabled := false
## Frequência do ruído das depressões. Valores menores produzem depressões mais largas e espaçadas.
@export_range(0.0001, 1.0, 0.0001) var basin_frequency := 0.003
## Quantidade de camadas de ruído usadas no formato das depressões.
@export_range(1, 8) var basin_octaves := 2
## Faixa de valores do ruído que aumenta gradualmente o corte, do início até a profundidade máxima.
@export var basin_thresholds := Vector2(0.26, 0.54)
## Profundidade máxima solicitada para as depressões. O controle de inclinação pode reduzir esse valor.
@export_range(0.0, 32.0, 0.1, "or_greater", "suffix:blocks") var basin_depth := 3.0

@export_group("Objetos procedurais")
## Multiplica a chance de gerar vegetação, entidades e estruturas dos biomas. 0 desativa essa geração.
@export_range(0.0, 2.0, 0.01, "or_greater") var prop_chance_scale := 1.0
