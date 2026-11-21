@tool
class_name WorldDefinition
extends Resource
## A complete world preset. Choose it before starting generation.

const Generation = preload("res://addons/ldk/core/Voxel/Generation/voxel_world_generation.gd")
const EnvironmentSettings = preload("res://addons/ldk/core/World/world_environment_config.gd")
const PhysicsSettings = preload("res://addons/ldk/core/World/world_physics_config.gd")
const MIN_SEED := -2147483648
const MAX_SEED := 2147483647

@export_group("Seed")
## Sorteia uma seed ao iniciar o mundo a partir deste preset. Desative para usar a seed fixa abaixo.
@export var randomize_seed := true
## Seed fixa do terreno e da distribuição procedural. Com o mesmo preset e a mesma seed, o gerador reproduz o mapa.
@export_range(MIN_SEED, MAX_SEED) var seed := 1729

@export_group("Persistência")
## Identificador estável do preset no save. Mantenha o mesmo ID ao mover seu arquivo.
@export var save_id: StringName
## Versão da geração. Incremente ao mudar a base procedural de forma incompatível com deltas antigos.
@export_range(1, 2147483647) var generator_version := 1
## Intervalo do salvamento automático em segundos. Zero desativa o temporizador.
@export_range(0.0, 3600.0, 1.0, "or_greater", "suffix:s") var autosave_interval := 60.0
## Agenda uma gravação quando um chunk com alterações ainda não salvas sai do streaming.
@export var save_on_chunk_unload := true

@export_group("Sistemas do mundo")
## Define os biomas, o relevo, a água e os objetos gerados no mapa.
@export var generation: Generation = Generation.new()
## Define o céu, a luz, as sombras e o ciclo de dia e noite.
@export var environment: EnvironmentSettings = EnvironmentSettings.new()
## Define a gravidade, o pulo e a forma como o jogador se movimenta pelo terreno.
@export var physics: PhysicsSettings = PhysicsSettings.new()

@export_group("Ponto inicial")
## Coordenada X/Z a partir da qual o jogo procura um ponto inicial em terra firme.
@export var spawn_origin := Vector2i.ZERO
## Distância horizontal máxima, em blocos, para procurar um ponto inicial perto da origem.
@export_range(0, 256, 1, "or_greater", "suffix:blocks") var spawn_search_radius := 32


func choose_seed() -> int:
	return random_seed() if randomize_seed else seed


static func random_seed() -> int:
	return randi() + MIN_SEED
