class_name VoxelPropView
extends Node3D
## Presents scene props and batched sprites at the support cells supplied by the game.

signal prop_removed(support: Vector3i)

const PropBatch = preload("res://addons/ldk/core/Voxel/View/voxel_prop_batch.gd")
const PROP_BLUR = preload("res://addons/ldk/core/Voxel/View/voxel_prop_blur.gdshader")

var _world: VoxelWorld
var _instantiate: Callable
var _placements: Callable
var _texture: Callable
var _entity: Callable
var _cutaway: VoxelCutawayView
var _candidates: Dictionary[Vector3i, Dictionary] = {}
var _instances: Dictionary[Vector3i, Node3D] = {}
var _target_sprites: Dictionary[Vector3i, Sprite3D] = {}
var _blur_materials: Dictionary[Texture2D, ShaderMaterial] = {}
var _original_materials: Dictionary[Vector3i, Material] = {}
var _opacity_masks: Dictionary[Texture2D, BitMap] = {}
var _quads: Dictionary[ContentSceneVisual, QuadMesh] = {}
var _chunk_batches: Dictionary[Vector3i, Dictionary] = {}
var _batch_slots: Dictionary[Vector3i, int] = {}
var _batch_extent := Vector2.ZERO
var _highlight_support: Variant = null
var _highlight_tint := Color.WHITE
var _sprite_color := Color.WHITE
var _preview: MeshInstance3D
var _preview_material: StandardMaterial3D


func definition_at(support: Vector3i) -> ContentScene:
	var chunk := VoxelChunkData.chunk_of(support)
	if _instances.has(support) or (_batch_slots.has(support) and _batch_for(support).is_active(_batch_slots[support])):
		return _candidates[chunk][support]
	return null


func pick_sprite(origin: Vector3, direction: Vector3, limit: float, nearby_depth := 0.0) -> Dictionary:
	var hit := {}
	for support in _target_sprites:
		var sprite := _target_sprites[support]
		var inverse := sprite.global_transform.affine_inverse()
		var start := inverse * origin
		var ray := inverse.basis * direction
		if is_zero_approx(ray.z):
			continue
		var depth := -start.z / ray.z
		if depth < 0.0 or depth >= limit:
			continue
		var point := start + ray * depth
		var rect := sprite.get_item_rect()
		var pixel := Vector2(point.x, -point.y) / sprite.pixel_size
		pixel.y += rect.position.y + rect.end.y
		if not rect.has_point(pixel):
			continue
		var texture_pixel := pixel - rect.position
		if sprite.flip_h:
			texture_pixel.x = rect.size.x - 1.0 - floorf(texture_pixel.x)
		if sprite.flip_v:
			texture_pixel.y = rect.size.y - 1.0 - floorf(texture_pixel.y)
		texture_pixel += Vector2(sprite.frame_coords) * rect.size
		if sprite.region_enabled:
			texture_pixel += sprite.region_rect.position
		var mask := _opacity_mask(sprite.texture)
		var texel := Vector2i(texture_pixel.floor())
		if mask != null and (not Rect2i(Vector2i.ZERO, mask.get_size()).has_point(texel) or not mask.get_bitv(texel)):
			continue
		hit = {"support": support, "depth": depth, "root": _instances[support]}
		limit = depth
	var batch_hit := _pick_batch(origin, direction, nearby_depth, limit)
	return hit if batch_hit.is_empty() else batch_hit


func _pick_batch(origin: Vector3, direction: Vector3, first: float, limit: float) -> Dictionary:
	if _batch_slots.is_empty() or first >= limit:
		return {}
	var start := to_local(origin)
	var ray := global_basis.inverse() * direction
	if is_zero_approx(ray.z):
		return {}
	var hit := {}
	var near := start + ray * first
	var far := start + ray * limit
	for z in range(ceili(minf(near.z, far.z) - 0.5), floori(maxf(near.z, far.z) - 0.5) + 1):
		var depth := (z + 0.5 - start.z) / ray.z
		if depth < first or depth >= limit:
			continue
		var point := start + ray * depth
		var half_width := _batch_extent.x * 0.5
		for x in range(ceili(point.x - half_width - 0.5), floori(point.x + half_width - 0.5) + 1):
			for y in range(ceili(point.y - 1.0 - _batch_extent.y), floori(point.y - 1.0) + 1):
				var support := Vector3i(x, y, z)
				if not _batch_slots.has(support):
					continue
				var batch := _batch_for(support)
				if not batch.is_active(_batch_slots[support]):
					continue
				var uv := Vector2((point.x - x - 0.5) / batch.size.x + 0.5, 1.0 - (point.y - y - 1.0) / batch.size.y)
				if not Rect2(Vector2.ZERO, Vector2.ONE).has_point(uv):
					continue
				var mask := _opacity_mask(batch.texture)
				if mask != null and not mask.get_bitv(Vector2i(uv * Vector2(mask.get_size()))):
					continue
				hit = {"support": support, "depth": depth, "root": null}
				limit = depth
	return hit


func _opacity_mask(texture: Texture2D) -> BitMap:
	if not _opacity_masks.has(texture):
		var image := texture.get_image()
		var mask: BitMap
		if image != null and (not image.is_compressed() or image.decompress() == OK):
			mask = BitMap.new()
			mask.create_from_image_alpha(image, 0.5)
		_opacity_masks[texture] = mask
	return _opacity_masks[texture]


func body_hit(body: Node, depth: float) -> Dictionary:
	var root := body as Node3D
	while root != null and root.get_parent() != self:
		root = root.get_parent() as Node3D
	if root == null:
		return {}
	var support := Vector3i(root.position.floor()) + Vector3i.DOWN
	if _instances.get(support) != root or _target_sprites.has(support):
		return {}
	return {"support": support, "depth": depth, "root": root}


func targeting_sprite_at(support: Vector3i) -> Sprite3D:
	return _target_sprites.get(support)


func set_highlight(support: Variant, tint: Color = Color.WHITE) -> void:
	if support == _highlight_support and tint == _highlight_tint:
		return
	if support != _highlight_support:
		if _highlight_support != null:
			_tint_prop(_highlight_support, Color.WHITE)
		_highlight_support = support
		var sprite: Sprite3D = _target_sprites.get(support) if support != null else null
		_sprite_color = sprite.modulate if sprite != null else Color.WHITE
	_highlight_tint = tint
	if support != null:
		_tint_prop(support, tint)


func _tint_prop(support: Vector3i, tint: Color) -> void:
	if _batch_slots.has(support):
		_batch_for(support).multimesh.set_instance_color(_batch_slots[support], tint)
	elif _target_sprites.has(support):
		_target_sprites[support].modulate = _sprite_color * tint


func configure(
	world: VoxelWorld, placements: Callable, instantiate_prop: Callable,
	texture_lookup: Callable = Callable(), entity_lookup: Callable = Callable(),
	cutaway: VoxelCutawayView = null
) -> void:
	_world = world
	_placements = placements
	_instantiate = instantiate_prop
	_texture = texture_lookup
	_entity = entity_lookup
	_cutaway = cutaway
	if _cutaway != null:
		_cutaway.prop_visibility_changed.connect(_update_cutaway)
	_world.chunk_ready.connect(_attach_chunk)
	_world.chunk_unloaded.connect(_detach_chunk)
	_world.blocks_changed.connect(_refresh_cells)
	_world.prop_destroyed.connect(_remove_prop)
	if _entity.is_valid() and _texture.is_valid():
		_world.prop_planted.connect(_attach_planted)


func _update_cutaway() -> void:
	for support in _target_sprites:
		_apply_cutaway(support, _target_sprites[support])


func _apply_cutaway(support: Vector3i, sprite: Sprite3D) -> void:
	# The support is the ground block. Its top is the prop's layer, regardless of sprite height.
	var strength := _cutaway.prop_transparency(support + Vector3i.UP)
	if is_zero_approx(strength):
		if _original_materials.has(support):
			sprite.material_override = _original_materials[support]
			sprite.set_instance_shader_parameter(&"cut_strength", null)
			sprite.set_instance_shader_parameter(&"uv_bounds", null)
			_original_materials.erase(support)
		return
	if not _original_materials.has(support):
		var texture := sprite.texture
		var frame := sprite.region_rect if sprite.region_enabled else Rect2(Vector2.ZERO, texture.get_size())
		frame.size /= Vector2(sprite.hframes, sprite.vframes)
		frame.position += Vector2(sprite.frame_coords) * frame.size
		if texture is AtlasTexture:
			var atlas := texture as AtlasTexture
			if atlas.atlas == null:
				return
			frame.position += atlas.region.position - atlas.margin.position
			frame = frame.intersection(atlas.region)
			texture = atlas.atlas
		if not frame.has_area():
			return
		if not _blur_materials.has(texture):
			var blur := ShaderMaterial.new()
			blur.shader = PROP_BLUR
			blur.set_shader_parameter(&"sprite_texture", texture)
			_blur_materials[texture] = blur
		_original_materials[support] = sprite.material_override
		sprite.material_override = _blur_materials[texture]
		var first := frame.position / texture.get_size()
		var last := frame.end / texture.get_size()
		sprite.set_instance_shader_parameter(&"uv_bounds", Vector4(first.x, first.y, last.x, last.y))
	sprite.set_instance_shader_parameter(&"cut_strength", strength)


func show_placement_preview(cell: Vector3i, definition: ContentScene, opacity: float) -> void:
	if definition == null or not definition.has_batched_visual() or not _texture.is_valid():
		if _preview != null:
			_preview.hide()
		return
	var quad := _quad_for(definition.visual)
	if _preview == null:
		_preview = MeshInstance3D.new()
		_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_preview_material = quad.material.duplicate() as StandardMaterial3D
		_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_preview_material.albedo_color = Color(1.0, 1.0, 1.0, opacity)
		_preview.material_override = _preview_material
		add_child(_preview)
	if _preview.mesh != quad:
		_preview.mesh = quad
		_preview_material.albedo_texture = (quad.material as StandardMaterial3D).albedo_texture
	if _preview_material.albedo_color.a != opacity:
		_preview_material.albedo_color = Color(1.0, 1.0, 1.0, opacity)
	var center := Vector3(cell) + Vector3(0.5, quad.size.y * 0.5, 0.5)
	if _preview.position != center:
		_preview.position = center
	_preview.show()


func _attach_chunk(coord: Vector3i) -> void:
	var candidates: Dictionary[Vector3i, ContentScene] = _placements.call(coord)
	if _entity.is_valid() and _texture.is_valid():
		var edits := _world.prop_edits(coord)
		for support in edits:
			if not edits[support].is_empty():
				var definition := _entity.call(edits[support]) as ContentScene
				if definition != null and definition.has_batched_visual():
					candidates[support] = definition
	if candidates.is_empty():
		return
	_candidates[coord] = candidates
	if _texture.is_valid():
		_attach_batches(coord, candidates)
	for support in candidates:
		_refresh_prop(support)


func _attach_planted(support: Vector3i, id: StringName) -> void:
	var definition := _entity.call(id) as ContentScene
	if definition == null or not definition.has_batched_visual():
		return
	var coord := VoxelChunkData.chunk_of(support)
	var candidates: Dictionary[Vector3i, ContentScene] = _candidates.get(coord, {} as Dictionary[Vector3i, ContentScene])
	_clear_batches(coord)
	candidates[support] = definition
	_candidates[coord] = candidates
	_attach_batches(coord, candidates)
	for anchor in candidates:
		if _batch_slots.has(anchor):
			_refresh_prop(anchor)
	if _highlight_support != null and _batch_slots.has(_highlight_support):
		_tint_prop(_highlight_support, _highlight_tint)


func _attach_batches(coord: Vector3i, candidates: Dictionary[Vector3i, ContentScene]) -> void:
	var groups: Dictionary[ContentScene, Array] = {}
	for support in candidates:
		var definition := candidates[support]
		if not definition.has_batched_visual() or _world.is_prop_removed(support):
			continue
		if not groups.has(definition):
			groups[definition] = []
		groups[definition].append(support)
	if groups.is_empty():
		return
	var batches: Dictionary[ContentScene, PropBatch] = {}
	for definition in groups:
		var supports := groups[definition]
		var batch := PropBatch.new()
		batch.configure(_quad_for(definition.visual), supports.size(), coord * VoxelChunkData.SIZE)
		batches[definition] = batch
		add_child(batch)
		for index in supports.size():
			_batch_slots[supports[index]] = index
	_chunk_batches[coord] = batches


func _quad_for(visual: ContentSceneVisual) -> QuadMesh:
	if not _quads.has(visual):
		_quads[visual] = PropBatch.make_quad(_texture.call(visual.batch_texture), visual.batch_size)
		_batch_extent = _batch_extent.max(visual.batch_size)
	return _quads[visual]


func _batch_for(support: Vector3i) -> PropBatch:
	var chunk := VoxelChunkData.chunk_of(support)
	return _chunk_batches[chunk][_candidates[chunk][support]]


func _detach_chunk(coord: Vector3i) -> void:
	if not _candidates.has(coord):
		return
	for support: Vector3i in _candidates[coord]:
		_remove_prop(support)
	_clear_batches(coord)
	_candidates.erase(coord)


func _clear_batches(coord: Vector3i) -> void:
	if not _chunk_batches.has(coord):
		return
	for support: Vector3i in _candidates[coord]:
		_batch_slots.erase(support)
	for batch: PropBatch in _chunk_batches[coord].values():
		batch.hide()
		batch.queue_free()
	_chunk_batches.erase(coord)


func _refresh_cells(cells: Array[Vector3i]) -> void:
	for cell in cells:
		_refresh_prop(cell)
		_refresh_prop(cell + Vector3i.DOWN)


func _refresh_prop(support: Vector3i) -> void:
	if _world.is_prop_removed(support):
		return
	var candidates: Dictionary = _candidates.get(VoxelChunkData.chunk_of(support), {})
	var prefab := candidates.get(support) as ContentScene
	if prefab == null:
		return
	if _world.get_block(support) <= 0 or _world.get_block(support + Vector3i.UP) != 0:
		_remove_prop(support)
	elif _batch_slots.has(support):
		_batch_for(support).set_active(_batch_slots[support], support, true)
	elif not _instances.has(support):
		var prop := _instantiate.call(prefab) as Node3D
		if prop == null:
			return
		prop.position = Vector3(support) + Vector3(0.5, 1.0, 0.5)
		add_child(prop)
		_instances[support] = prop
		if prefab.visual != null and not prefab.visual.targeting_sprite.is_empty():
			var sprite := prop.get_node_or_null(prefab.visual.targeting_sprite) as Sprite3D
			if sprite != null and sprite.texture != null:
				_target_sprites[support] = sprite
				if _cutaway != null:
					_apply_cutaway(support, sprite)


func _remove_prop(support: Vector3i) -> void:
	if support == _highlight_support:
		set_highlight(null)
	if _batch_slots.has(support):
		if _batch_for(support).set_active(_batch_slots[support], support, false):
			prop_removed.emit(support)
	elif _instances.has(support):
		var prop := _instances[support]
		_instances.erase(support)
		_target_sprites.erase(support)
		_original_materials.erase(support)
		prop.hide()
		# Edits can arrive during a physics step. Defer removing the body from the tree.
		prop.queue_free()
		prop_removed.emit(support)
