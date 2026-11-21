@tool
class_name ContentScene
extends Resource

## ID estável da entidade ou estrutura. Pacotes legados podem declará-lo apenas no manifesto.
@export var id: StringName

@export_group("Aparência e física")
## Apresentação do objeto, incluindo os sprites que usam texturas registradas.
@export var visual: ContentSceneVisual
## Forma física independente da cena visual. Vazio permite objetos somente visuais.
@export var collision: ContentSceneCollision

@export_group("Fauna temporária")
## Simulação e spawn do ator. Vazio mantém o objeto no fluxo de props estáticos.
@export var wildlife: WildlifeProfile

@export_group("Mineração e recompensas")
## Resistência compartilhada do objeto. Vazio torna o objeto indestrutível.
@export var breakable: ContentBreakable
## Itens entregues ao destruir o objeto. Vazio desativa as recompensas.
@export var drops: ContentDrops

@export_group("Extensões do pacote")
## IDs de componentes adicionais, consultáveis no ContentDB pelos sistemas que os utilizam.
@export var component_ids: Array[StringName] = []


func has_batched_visual() -> bool:
	return wildlife == null and collision == null and visual != null and not visual.batch_texture.is_empty() \
		and visual.batch_size.x > 0.0 and visual.batch_size.y > 0.0


func instantiate(texture_lookup: Callable) -> Node3D:
	if wildlife != null or (visual == null and collision == null):
		return null
	var root := visual.instantiate(texture_lookup) if visual != null else Node3D.new()
	if root != null and collision != null:
		collision.attach_to(root)
	return root
