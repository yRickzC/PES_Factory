@tool
class_name VoxelBlock
extends Resource

@export_group("Identidade do bloco")
## ID único do bloco, no formato [code]namespace:nome[/code], usado pela geração, itens e saves.
@export var key: StringName
## IDs antigos aceitos para localizar este bloco ao carregar conteúdo que ainda usa esses nomes.
@export var legacy_keys: Array[StringName] = []

@export_group("Aparência e física")
## Forma e texturas do bloco. Define o que aparece no mundo.
@export var geometry: VoxelVisual
## Forma física que bloqueia movimentos e faz o bloco servir de apoio.
@export var collision: VoxelCollision
## Define quais faces de blocos vizinhos podem ser descartadas na renderização.
@export var occlusion: VoxelOcclusion
## Quantidade de giros de 90 graus no eixo Y aplicados à definição do bloco.
@export_range(0, 3) var quarter_turns := 0

@export_group("Interação e conexões")
## Componente opcional que define como o bloco reage a eventos do mundo.
@export var behavior: VoxelBlockBehavior
## Blocos vizinhos com o mesmo grupo podem se conectar pelos lados. Vazio desativa a conexão automática.
@export var connection_group: StringName

@export_group("Mineração e recompensas")
## Resistência compartilhada do bloco. Vazio torna o bloco indestrutível.
@export var breakable: ContentBreakable
## Itens entregues ao destruir o bloco. Vazio desativa as recompensas.
@export var drops: ContentDrops

@export_group("Extensões do pacote")
## IDs de componentes adicionais, consultáveis no ContentDB pelos sistemas que os utilizam.
@export var component_ids: Array[StringName] = []


static func bake_geometry(visual: VoxelVisual) -> VoxelGeometry:
	if visual == null:
		return null
	var script := visual.get_script() as Script
	if Engine.is_editor_hint() and script != null and not script.is_tool():
		# A non-tool mod script is a placeholder while the Godot editor is open.
		return visual as VoxelGeometry
	return visual.bake_geometry() as VoxelGeometry


## Returns the first geometry problem found while loading this definition.
static func geometry_issue(definition: VoxelBlock) -> String:
	if definition == null:
		return "A definição do bloco está ausente."
	var visual := bake_geometry(definition.geometry)
	var collider := definition.collision
	if definition.geometry != null and visual == null:
		return "O componente visual precisa fornecer uma VoxelGeometry. Scripts personalizados precisam de @tool no editor."
	if visual != null:
		var script := definition.geometry.get_script() as Script
		if not Engine.is_editor_hint() or script == null or script.is_tool():
			var issue := definition.geometry.validation_issue()
			if not issue.is_empty():
				return issue
		if visual.material_slot < 0 or visual.material_slot > 1:
			return "A camada visual deve ser 0 ou 1."
		if visual.cube and visual.face_tiles.size() != 6:
			return "O cubo visual precisa de seis faces."
		if not visual.cube and visual.model != null and not VoxelModel.is_valid_data(visual.model, true):
			return "Os dados do modelo visual são inválidos."
		if visual.connection_arm != null and (visual.cube or visual.model == null or not VoxelModel.is_valid_data(visual.connection_arm, true)):
			return "A extensão visual precisa de um modelo base e de dados válidos."
	if collider != null:
		if not collider.cube and collider.model != null and not VoxelModel.is_valid_data(collider.model, false):
			return "Os dados do modelo de colisão são inválidos."
		if collider.connection_arm != null and (collider.cube or collider.model == null or not VoxelModel.is_valid_data(collider.connection_arm, false)):
			return "A extensão de colisão precisa de um modelo base e de dados válidos."
	var has_arms := (visual != null and visual.connection_arm != null) or (collider != null and collider.connection_arm != null)
	if has_arms and ContentRegistry.namespace_of(definition.connection_group).is_empty():
		return "Grupo de conexão '%s' inválido. Use namespace:nome." % definition.connection_group
	return ""
