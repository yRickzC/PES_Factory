@tool
extends RefCounted
## Built-in descriptors stay available in contexts that read only mod folders.


static func register_into(registry: ContentRegistry) -> void:
	_register(registry, &"ldk:simple_texture", "SimpleTexture", "Visual",
		"Aplica uma textura às seis faces de um cubo opaco.",
		"Use em blocos cúbicos com a mesma aparência em todos os lados.", SimpleTexture.new())
	_register(registry, &"ldk:texture", "Texture", "Visual",
		"Configura texturas por face, modelos, transparência e extensões visuais.",
		"Use em blocos com aparência personalizada, como degraus e cercas.", VoxelGeometry.new())
	_register(registry, &"ldk:occlusion", "Occlusion", "Visual",
		"Define as faces encobertas e a união visual entre blocos vizinhos.",
		"Use para controlar a ocultação de faces com Texture avançado.", VoxelOcclusion.new())
	_register(registry, &"ldk:collision", "Collision", "Física",
		"Define a forma física do bloco.",
		"Use para bloquear movimentos ou dar apoio ao jogador.", VoxelCollision.new())
	_register(registry, &"ldk:interactable", "Interactable", "Interação",
		"Associa um Resource de comportamento ao bloco.",
		"Use para reagir a interações e atualizações do mundo.", VoxelBlockBehavior.new())
	_register(registry, &"ldk:breakable", "Breakable", "Comportamento",
		"Controla o tempo necessário para quebrar o bloco.",
		"Use para tornar o bloco minerável e habilitar a ligação de Drops.", ContentBreakable.new())
	_register(registry, &"ldk:drops", "Drops", "Comportamento",
		"Lista os itens e as quantidades entregues ao quebrar o bloco.",
		"Conecte ao Breakable para definir as recompensas de mineração.", ContentDrops.new())


static func _register(registry: ContentRegistry, id: StringName, display_name: String, category: String,
		description: String, purpose: String, prototype: Resource) -> void:
	var definition := ContentComponentType.new()
	definition.display_name = display_name
	definition.category = category
	definition.description = description
	definition.purpose = purpose
	definition.prototype = prototype
	definition.targets.append(&"block")
	registry.register(id, definition)
