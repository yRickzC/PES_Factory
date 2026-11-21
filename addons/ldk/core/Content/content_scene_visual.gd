@tool
class_name ContentSceneVisual
extends Resource

@export_group("Cena e aparência")
## Cena Node3D que representa o objeto no mundo.
@export var scene: PackedScene
## Referência alternativa para carregar a cena no primeiro uso.
@export_file("*.tscn", "*.scn") var scene_path: String
## Mapa dos caminhos dos sprites para os IDs de texturas do registro.
@export var sprite_textures: Dictionary[NodePath, StringName] = {}
## Caminho relativo do Sprite3D que recebe o destaque de mira e o efeito de quebra.
@export var targeting_sprite: NodePath

@export_group("Sprite em lote")
## ID da textura de um objeto sem colisão desenhado junto com as outras instâncias do chunk.
@export var batch_texture: StringName
## Largura e altura do plano vertical em unidades do mundo. O pivô fica no centro da base.
@export var batch_size := Vector2.ONE

var _resolved_scene: PackedScene
var _load_attempted := false


func instantiate(texture_lookup: Callable) -> Node3D:
	var visual_scene := scene
	if visual_scene == null:
		if not _load_attempted:
			_load_attempted = true
			if ResourceLoader.exists(scene_path, "PackedScene"):
				_resolved_scene = ResourceLoader.load(scene_path, "PackedScene") as PackedScene
		visual_scene = _resolved_scene
	if visual_scene == null:
		return null
	var root := visual_scene.instantiate()
	if not root is Node3D:
		root.free()
		return null
	for path in sprite_textures:
		var sprite := root.get_node_or_null(path) as Sprite3D
		if sprite != null:
			sprite.texture = texture_lookup.call(sprite_textures[path])
	return root as Node3D
