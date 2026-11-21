@tool
class_name ContentDB
extends RefCounted
## Shared definition indexes for one startup session. Registration finishes before gameplay.

const MAX_TILE_LAYERS := 256
const Recipe = preload("res://addons/ldk/core/Crafting/crafting_recipe.gd")
const BuiltinComponentTypes := preload("res://addons/ldk/core/Content/builtin_component_types.gd")

var blocks := ContentRegistry.new()
var items := ContentRegistry.new()
var entities := ContentRegistry.new()
var textures := ContentRegistry.new()
var structures := ContentRegistry.new()
var biomes := ContentRegistry.new()
var recipes := ContentRegistry.new()
var crafting_tags := ContentRegistry.new()
var components := ContentRegistry.new()
var input_actions := ContentRegistry.new()

var _packages: Dictionary[String, String] = {}
var _claimed_blocks: Dictionary[StringName, bool] = {VoxelCatalog.AIR_KEY: true}
var _overrides: Dictionary[StringName, VoxelBiome] = {}
var _definition_count := 0
var _custom_components: Dictionary[Resource, Dictionary] = {}
var _tiles: Dictionary = {}
var _catalog: VoxelCatalog
var _catalog_fallback: StringName
var _missing: ImageTexture


func _init() -> void:
	BuiltinComponentTypes.register_into(components)


func component_types(target: StringName) -> Dictionary[StringName, ContentComponentType]:
	var available: Dictionary[StringName, ContentComponentType] = {}
	for id in components.ids():
		var entry := components.find(id) as ContentComponentType
		if entry != null and target in entry.targets and entry.prototype != null:
			available[id] = entry
	return available


func _missing_texture() -> ImageTexture:
	if _missing != null:
		return _missing
	var image := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color("#371d42"))
	image.fill_rect(Rect2i(0, 0, 8, 8), Color("#e273ac"))
	image.fill_rect(Rect2i(8, 8, 8, 8), Color("#e273ac"))
	_missing = ImageTexture.create_from_image(image)
	return _missing


func package_version(id: String) -> String:
	return _packages.get(id, "")


func package_count() -> int:
	return _packages.size()


func definition_count() -> int:
	return _definition_count


func _register(pack: ContentPack) -> String:
	var owner_id := pack.content_namespace
	var groups := [
		_entries(pack.blocks, &"key"), _entries(pack.items, &"id"), pack.entities,
		_texture_entries(pack), pack.structures, _entries(pack.biomes, &"key"),
		_entries(pack.recipes, &"id"), _entries(pack.crafting_tags, &"id"), pack.components,
		_entries(pack.input_actions, &"id"),
	]
	var registries := [blocks, items, entities, textures, structures, biomes, recipes, crafting_tags, components, input_actions]
	var block_claims: Dictionary[StringName, bool] = {}
	var targets: Dictionary[StringName, VoxelBiome] = {}
	for i in groups.size():
		var group: Variant = groups[i]
		if group == null:
			return "Definição vazia ou ID repetido."
		var seen: Dictionary[StringName, bool] = {}
		for id: StringName in group:
			var key := ContentRegistry.normalize_id(id)
			var definition: Resource = group[id]
			if ContentRegistry.namespace_of(id) != owner_id or definition == null:
				return "ID fora do pacote ou definição vazia (%s)." % id
			if seen.has(key) or registries[i].find(key) != null:
				return "ID em conflito (%s)." % key
			seen[key] = true
			if definition is ContentScene and not definition.id.is_empty():
				if ContentRegistry.normalize_id(definition.id) != key:
					return "O ID da cena diverge do manifesto (%s)." % key
			if i == 0:
				var block := definition as VoxelBlock
				var geometry_issue := VoxelBlock.geometry_issue(block)
				if not geometry_issue.is_empty():
					return "Geometria de bloco inválida (%s). %s" % [key, geometry_issue]
				var keys: Array[StringName] = [id]
				keys.append_array(block.legacy_keys)
				for block_id in keys:
					var canonical := ContentRegistry.normalize_id(block_id)
					if ContentRegistry.namespace_of(block_id) != owner_id or _claimed_blocks.has(canonical) or block_claims.has(canonical):
						return "ID de bloco ou alias em conflito (%s)." % block_id
					block_claims[canonical] = true
	for biome in pack.biome_overrides:
		if biome == null:
			return "Substituição de bioma vazia."
		var key := ContentRegistry.normalize_id(biome.key)
		var owner := ContentRegistry.namespace_of(biome.key)
		if owner.is_empty() or targets.has(key) or (owner != owner_id and not pack.dependencies.has(owner)):
			return "Substituição de bioma exige ID único e dependência declarada (%s)." % key
		if biomes.find(key) == null and not groups[5].has(key):
			return "Bioma a substituir não encontrado (%s)." % key
		targets[key] = biome
	for i in groups.size():
		for id: StringName in groups[i]:
			registries[i].register(id, groups[i][id])
			_definition_count += 1
	_claimed_blocks.merge(block_claims)
	# Dependents load after their dependencies; competing packages are ordered by priority.
	_overrides.merge(targets)
	_packages[owner_id] = pack.version
	return ""


func _finish_registration() -> void:
	for id in _overrides:
		biomes.replace(id, _overrides[id])
	_overrides.clear()
	for registry: ContentRegistry in [blocks, items, entities, textures, structures, biomes, recipes, crafting_tags, components, input_actions]:
		registry.freeze()


func _validate_references() -> Array[String]:
	var warnings: Array[String] = []
	var terrain_tiles: Dictionary[StringName, bool] = {}
	for id in blocks.ids():
		var block := blocks.find(id) as VoxelBlock
		if block.drops != null:
			_validate_drops(id, block.drops, warnings)
		_index_components(id, block, block.component_ids, warnings)
		var tiles := _block_tiles(block)
		_validate_refs(id, tiles, textures, warnings)
		for tile in tiles:
			terrain_tiles[tile] = true
	if terrain_tiles.size() >= MAX_TILE_LAYERS:
		warnings.append("Limite de %d texturas de terreno excedido." % (MAX_TILE_LAYERS - 1))
	for registry: ContentRegistry in [entities, structures]:
		for id in registry.ids():
			var scene := registry.find(id) as ContentScene
			if scene.drops != null:
				_validate_drops(id, scene.drops, warnings)
			if scene.visual != null:
				_validate_refs(id, scene.visual.sprite_textures.values(), textures, warnings)
				if not scene.visual.batch_texture.is_empty():
					_validate_refs(id, [scene.visual.batch_texture], textures, warnings)
					if not scene.has_batched_visual():
						warnings.append("%s usa um sprite em lote com colisão ou dimensões inválidas." % id)
				elif scene.visual.scene == null and not ResourceLoader.exists(scene.visual.scene_path, "PackedScene"):
					warnings.append("%s usa uma cena visual ausente (%s)." % [id, scene.visual.scene_path])
			if scene.wildlife != null:
				var profile := scene.wildlife
				if scene.collision == null or scene.collision.shape == null:
					warnings.append("%s precisa de uma forma de colisão para ativar a fauna." % id)
				_validate_refs(id, profile.chance_by_biome.keys(), biomes, warnings)
				_validate_refs(id, profile.spawn_ground, blocks, warnings)
				_validate_refs(id, profile.forage_ground, blocks, warnings)
				_validate_refs(id, profile.cooling_blocks, blocks, warnings)
			_index_components(id, scene, scene.component_ids, warnings)
	for id in textures.ids():
		var entry := textures.find(id)
		if entry is ContentTexture and not ResourceLoader.exists(entry.path, "Texture2D"):
			warnings.append("%s usa um arquivo de textura ausente (%s)." % [id, entry.path])
	for id in biomes.ids():
		var biome := biomes.find(id) as VoxelBiome
		for key in [biome.surface, biome.soil, biome.bedrock, biome.water]:
			if not key.is_empty() and not _claimed_blocks.has(ContentRegistry.normalize_id(key)):
				warnings.append("%s usa um bloco ausente (%s)." % [id, key])
		_validate_refs(id, biome.surface_variants, blocks, warnings)
		_validate_refs(id, biome.soil_variants, blocks, warnings)
		for rule in biome.scatter:
			if rule != null:
				_validate_refs(id, rule.variants, entities, warnings)
		_validate_refs(id, biome.vegetation, entities, warnings)
		_validate_refs(id, biome.entities, entities, warnings)
		_validate_refs(id, biome.items, items, warnings)
		_validate_refs(id, biome.structures, structures, warnings)
	for id in items.ids():
		var item := items.find(id) as InventoryItem
		if not item.block_id.is_empty() and not _claimed_blocks.has(ContentRegistry.normalize_id(item.block_id)):
			warnings.append("%s usa um bloco ausente (%s)." % [id, item.block_id])
		if not item.entity_id.is_empty():
			var entity := entities.find(item.entity_id) as ContentScene
			if entity == null or not entity.has_batched_visual():
				warnings.append("%s usa uma entidade decorativa ausente ou inválida (%s)." % [id, item.entity_id])
			if not item.block_id.is_empty():
				warnings.append("%s deve escolher entre posicionar bloco ou entidade." % id)
		if not item.icon_id.is_empty() and textures.find(item.icon_id) == null:
			warnings.append("%s usa um ícone ausente (%s)." % [id, item.icon_id])
	for id in recipes.ids():
		var recipe := recipes.find(id) as Recipe
		_validate_refs(id, [recipe.product], items, warnings)
		_validate_refs(id, recipe.ingredients.keys(), items, warnings)
		if not recipe.tag.is_empty():
			_validate_refs(id, [recipe.tag], crafting_tags, warnings)
	return warnings


func _index_components(owner: StringName, definition: Resource, ids: Array[StringName], warnings: Array[String]) -> void:
	var indexed: Dictionary[StringName, Resource] = {}
	for id in ids:
		var component := components.find(id)
		if component == null:
			warnings.append("%s usa um componente ausente (%s)." % [owner, id])
		else:
			indexed[ContentRegistry.normalize_id(id)] = component
	if not indexed.is_empty():
		_custom_components[definition] = indexed


func component_for(definition: Resource, id: StringName) -> Resource:
	if not _custom_components.has(definition):
		return null
	return _custom_components[definition].get(ContentRegistry.normalize_id(id))


func _validate_refs(owner: StringName, ids: Array, registry: ContentRegistry, warnings: Array[String]) -> void:
	for id: StringName in ids:
		if registry.find(id) == null:
			warnings.append("%s referencia um ID ausente (%s)." % [owner, id])


func _validate_drops(owner: StringName, drops: ContentDrops, warnings: Array[String]) -> void:
	_validate_refs(owner, drops.items.keys(), items, warnings)
	for id in drops.maximum_by_item:
		if not drops.items.has(id) or drops.maximum_by_item[id] < drops.items[id]:
			warnings.append("%s usa um intervalo de recompensa inválido (%s)." % [owner, id])


func _texture(id: StringName) -> Texture2D:
	var registered := textures.find(id)
	if registered is ContentTexture:
		return registered.resolve()
	return registered as Texture2D


func block_catalog(missing_key: StringName = &"") -> VoxelCatalog:
	if _catalog == null or _catalog_fallback != missing_key:
		_catalog = bake_blocks(bake_tiles().indices, missing_key)
		_catalog_fallback = missing_key
	return _catalog


func texture(id: StringName) -> Texture2D:
	var found := _texture(id)
	return found if found != null else _missing_texture()


func bake_tiles() -> Dictionary:
	if not _tiles.is_empty():
		return _tiles
	var images: Array[Image] = [_missing_texture().get_image()]
	var indices: Dictionary[StringName, int] = {}
	var requested: Dictionary[StringName, bool] = {}
	for id in blocks.ids():
		var block := blocks.find(id) as VoxelBlock
		for tile in _block_tiles(block):
			requested[tile] = true
	for id: StringName in requested:
		var resource := _texture(id)
		if resource == null or images.size() >= MAX_TILE_LAYERS:
			push_warning("Missing tile or texture array full: %s" % id)
			continue
		var image := resource.get_image()
		if image == null or image.is_empty() or (image.is_compressed() and image.decompress() != OK):
			push_warning("Cannot read tile: %s" % id)
			continue
		image.convert(Image.FORMAT_RGBA8)
		image.clear_mipmaps()
		if image.get_size() != Vector2i(16, 16):
			image.resize(16, 16, Image.INTERPOLATE_NEAREST)
		indices[id] = images.size()
		images.append(image)
	var layers := Texture2DArray.new()
	var result := layers.create_from_images(images)
	if result != OK:
		push_error("Cannot create terrain texture array: %s" % error_string(result))
	_tiles = { "layers": layers, "indices": indices }
	return _tiles


static func _block_tiles(block: VoxelBlock) -> Array[StringName]:
	var tiles: Dictionary[StringName, bool] = {}
	var geometry := VoxelBlock.bake_geometry(block.geometry)
	if geometry == null:
		return tiles.keys()
	var sources: Array = [geometry.face_tiles] if geometry.cube else []
	if geometry.cube and geometry.material_slot == 0:
		sources.append(block.geometry.top_texture_variants)
	if not geometry.cube and geometry.model != null:
		sources.append(geometry.model.tiles)
	if geometry.connection_arm != null:
		sources.append(geometry.connection_arm.tiles)
	for source in sources:
		for id: StringName in source:
			if not id.is_empty():
				tiles[ContentRegistry.normalize_id(id)] = true
	return tiles.keys()


func bake_blocks(indices: Dictionary, missing_key: StringName = &"") -> VoxelCatalog:
	var catalog := VoxelCatalog.new(indices, missing_key)
	for id in blocks.ids():
		if not catalog.register(blocks.find(id) as VoxelBlock):
			push_warning("Invalid block definition: %s" % id)
	catalog.freeze()
	return catalog


static func _texture_entries(pack: ContentPack) -> Variant:
	var result: Dictionary = {}
	result.merge(pack.textures)
	for id in pack.deferred_textures:
		var path := pack.deferred_textures[id]
		if result.has(id) or not path.begins_with("res://"):
			return null
		var deferred := ContentTexture.new()
		deferred.path = path
		result[id] = deferred
	return result


static func _entries(resources: Array, property: StringName) -> Variant:
	var definitions: Dictionary[StringName, Resource] = {}
	for resource: Resource in resources:
		if resource == null:
			return null
		var id := ContentRegistry.normalize_id(StringName(resource.get(property)))
		if definitions.has(id):
			return null
		definitions[id] = resource
	return definitions
