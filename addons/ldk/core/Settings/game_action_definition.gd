@tool
class_name GameActionDefinition
extends Resource
## One shared entry in the input catalog.

## ID estável da ação usado pelo InputMap e pelas preferências salvas.
@export var id: StringName
## Nome da ação exibido na tela de controles.
@export var title: String
## ID da aba. Ações com o mesmo ID aparecem juntas.
@export var category: StringName
## Nome da aba exibida para a categoria.
@export var category_title: String
## Atalho padrão da ação. Aceita tecla física ou botão do mouse com modificadores.
@export var binding: InputEvent
## Ative para uma ação que precisa permanecer pressionada. Nesse caso a roda do mouse é indisponível.
@export var continuous := false
