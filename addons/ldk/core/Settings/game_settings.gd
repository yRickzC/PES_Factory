@tool
class_name GameSettings
extends Resource
## Authored defaults. Player overrides live separately.

const Action = preload("res://addons/ldk/core/Settings/game_action_definition.gd")

@export_group("Controles")
## Ações nativas disponíveis para configurar. Pacotes podem adicionar suas próprias ações.
@export var actions: Array[Action] = []
## Ação que sempre retém um atalho para impedir que o menu fique inacessível.
@export var protected_action: StringName
## Atalho reservado que funciona mesmo quando a ação protegida é remapeada.
@export var protected_binding: InputEvent

@export_group("Áudio")
## Nível inicial (de zero a um) do barramento Master.
@export_range(0.0, 1.0, 0.01) var master_volume := 1.0

@export_group("Vídeo")
## Inicia o jogo em tela cheia.
@export var fullscreen := false
## Sincroniza a apresentação ao monitor, quando suportado.
@export var vsync := true

@export_group("Gameplay")
## Exibe o fantasma do item antes de posicioná-lo no mundo.
@export var placement_preview := true
