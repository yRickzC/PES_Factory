class_name DemoVoxelGenerator
extends VoxelHeightmapGenerator

func _init(content: ContentDB, block_catalog: VoxelCatalog, generation: Generation) -> void:
	catalog = block_catalog
	settings = generation if generation != null else Generation.new()
	select_biomes(content.biomes)
