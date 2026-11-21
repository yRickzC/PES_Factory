class_name DemoVoxelMaterials
extends RefCounted


static func create(layers: Texture2DArray, catalog: VoxelCatalog, world_seed: int) -> Array[Material]:
	var terrain := ShaderMaterial.new()
	terrain.shader = preload("res://assets/core/shaders/terrain.gdshader")
	terrain.set_shader_parameter("tile_layers", layers)
	terrain.set_shader_parameter("voxel_top_styles", ImageTexture.create_from_image(catalog.top_styles_image()))
	# A shader int is 32 bits. Fold in the upper half of the saved seed.
	terrain.set_shader_parameter("voxel_texture_seed", world_seed ^ (world_seed >> 32))
	var water := ShaderMaterial.new()
	water.shader = preload("res://assets/core/shaders/water.gdshader")
	water.set_shader_parameter("tile_layers", layers)
	return [terrain, water]


static func create_cutaway(terrain: ShaderMaterial) -> ShaderMaterial:
	var blur := ShaderMaterial.new()
	blur.shader = preload("res://assets/core/shaders/terrain_blur.gdshader")
	for parameter: StringName in [&"tile_layers", &"voxel_top_styles", &"voxel_texture_seed"]:
		blur.set_shader_parameter(parameter, terrain.get_shader_parameter(parameter))
	return blur
