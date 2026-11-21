@tool
class_name ContentPack
extends Resource

const Recipe = preload("res://addons/ldk/core/Crafting/crafting_recipe.gd")
const CraftingTag = preload("res://addons/ldk/core/Crafting/crafting_tag.gd")
const InputAction = preload("res://addons/ldk/core/Settings/game_action_definition.gd")

@export_group("Identidade do pacote")
## Prefixo dos IDs do conteúdo. Use [code]core[/code] para o jogo base ou o identificador do mod para conteúdo externo.
@export var content_namespace: String
## Versão do pacote no formato major.minor.patch.
@export var version := "1.0.0"
## Versão da API de conteúdo para a qual o pacote foi criado.
@export_range(1, 1000) var api_version := 1
## Versão mínima exigida por namespace. Uma versão major diferente é incompatível.
@export var dependencies: Dictionary[String, String] = {}
## Pacotes incompatíveis. O primeiro pacote aceito pela ordem de carregamento tem preferência.
@export var conflicts: Array[String] = []
## Entre pacotes prontos para registro, valores maiores recebem prioridade.
@export var priority := 0

@export_group("Recursos e objetos")
## Mapa de IDs para imagens usadas pelos blocos, objetos e ícones do pacote.
@export var textures: Dictionary[StringName, Texture2D] = {}
## Texturas que devem ser abertas somente no primeiro uso.
@export var deferred_textures: Dictionary[StringName, String] = {}
## Definições de blocos que o pacote adiciona ao registro do jogo.
@export var blocks: Array[VoxelBlock] = []
## Definições de itens que o pacote disponibiliza ao inventário e às receitas.
@export var items: Array[InventoryItem] = []
## Mapa de IDs para cenas de entidades, como árvores e outros objetos do mundo.
@export var entities: Dictionary[StringName, ContentScene] = {}
## Mapa de IDs para cenas de estruturas usadas na geração.
@export var structures: Dictionary[StringName, ContentScene] = {}
## Componentes compartilhados e descritores ContentComponentType para os editores LDK.
@export var components: Dictionary[StringName, Resource] = {}

@export_group("Biomas")
## Novos biomas que o pacote disponibiliza aos presets de mundo.
@export var biomes: Array[VoxelBiome] = []
## Definições que substituem biomas existentes pelo mesmo ID, inclusive de outro pacote.
@export var biome_overrides: Array[VoxelBiome] = []

@export_group("Fabricação")
## Receitas que o pacote adiciona à fabricação.
@export var recipes: Array[Recipe] = []
## Categorias que o pacote disponibiliza como abas de receitas.
@export var crafting_tags: Array[CraftingTag] = []

@export_group("Controles")
## Ações reconfiguráveis do pacote, agrupadas por categoria na tela de controles.
@export var input_actions: Array[InputAction] = []

