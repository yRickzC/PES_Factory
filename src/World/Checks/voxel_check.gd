extends SceneTree
## Run with Godot --headless --path . --script res://src/World/Checks/voxel_check.gd.

const DEMO := preload("res://src/World/demo.tscn")
const LANDMARK_GENERATOR := preload("res://src/World/Checks/landmark_generator.gd")
const LANDMARK_PLACEMENT := preload("res://src/World/Checks/landmark_placement.gd")
const Hotbar := preload("res://addons/ldk/core/Inventory/slot_hotbar.gd")
const CraftingQueue := preload("res://addons/ldk/core/Crafting/crafting_queue.gd")
const CraftingRecipe := preload("res://addons/ldk/core/Crafting/crafting_recipe.gd")
const Mining := preload("res://addons/ldk/core/Voxel/Data/voxel_mining.gd")
const WorldPreset := preload("res://addons/ldk/core/World/world_definition.gd")
const OVERWORLD: WorldPreset = preload("res://assets/core/Worlds/overworld.tres")
const TREE_TO_MINE := Vector3i(-5, 3, -1)

class LandmarkWorld extends "res://src/World/demo_world.gd":
	func _create_generator(content: ContentDB) -> DemoVoxelGenerator:
		return LANDMARK_GENERATOR.new(content, _catalog, world_definition.generation)

	func _create_placement(generator: DemoVoxelGenerator, content: ContentDB) -> VoxelBiomePlacement:
		return LANDMARK_PLACEMENT.new(generator, content)

class CountingBehavior extends VoxelBlockBehavior:
	var ticks := 0
	var readback := 0

	func interact(_cell: Vector3i, state: Dictionary) -> bool:
		readback = state.get("count", 0)
		return true

	func advance(_cell: Vector3i, state: Dictionary, _delta: float) -> bool:
		ticks += 1
		state["count"] = int(state.get("count", 0)) + 1
		return state["count"] < 2


var _content: ContentDB
var _catalog: VoxelCatalog
var _failures := 0
var _stream_frames := PackedFloat32Array()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_content = DemoContent.load_content(false)
	_catalog = _content.bake_blocks(_content.bake_tiles().indices, DemoContent.MISSING_BLOCK)
	_check_content()
	_check_data()
	_check_behavior()
	_check_inventory()
	await _check_crafting()
	_check_mining()
	_check_placement_faces()
	var generator := _generator(1729)
	_check_seed(generator)
	var catalog := _catalog
	_check_mesher(catalog)
	_check_fence(catalog)
	_benchmark(generator, catalog)
	await _check_demo()
	print("Voxel checks: %d failures" % _failures)
	quit(int(_failures != 0))


func _generator(value: int) -> DemoVoxelGenerator:
	var generator := DemoVoxelGenerator.new(_content, _catalog, OVERWORLD.generation)
	generator.world_seed = value
	generator.prepare()
	return generator


func _check_content() -> void:
	var manifest := ContentPack.new()
	manifest.content_namespace = "check"
	manifest.dependencies["core"] = "1.0.0"
	manifest.priority = 20
	manifest.conflicts.append("loser")
	var block := VoxelBlock.new()
	block.key = &"check@rock"
	block.breakable = ContentBreakable.new()
	block.breakable.seconds = 0.75
	manifest.components[&"check:hardness"] = block.breakable
	block.component_ids.append(&"check:hardness")
	block.drops = ContentDrops.new()
	block.drops.items[&"core:stone"] = 2
	manifest.blocks.append(block)
	var biome := VoxelBiome.new()
	biome.key = &"check@ridge"
	biome.surface = block.key
	biome.soil = &"core:earth"
	biome.bedrock = &"core:stone"
	biome.vegetation.append(&"core:tree")
	manifest.biomes.append(biome)
	var forest := (_content.biomes.find(&"core:forest") as VoxelBiome).duplicate() as VoxelBiome
	forest.vegetation.clear()
	manifest.biome_overrides.append(forest)
	var item := InventoryItem.new()
	item.id = &"check:rock"
	manifest.items.append(item)
	var recipe := CraftingRecipe.new()
	recipe.id = &"check@chip"
	recipe.product = &"check@rock"
	recipe.ingredients[&"core@stone"] = 1
	manifest.recipes.append(recipe)
	var directory := "user://registry_check"
	DirAccess.make_dir_recursive_absolute(directory)
	_pack_fixture(directory, manifest)
	var dependent := ContentPack.new()
	dependent.content_namespace = "dependent"
	dependent.priority = 100
	dependent.dependencies["check"] = "1.0.0"
	_pack_fixture(directory, dependent)
	var loser := ContentPack.new()
	loser.content_namespace = "loser"
	_pack_fixture(directory, loser)
	var incompatible := ContentPack.new()
	incompatible.content_namespace = "incompatible"
	incompatible.dependencies["check"] = "2.0.0"
	_pack_fixture(directory, incompatible)
	var escaped := ContentPack.new()
	escaped.content_namespace = "escaped"
	_pack_fixture(directory, escaped, "res://outside-content-package.tres")
	var library := DemoContent.start_library(directory)
	while not library.is_finished():
		library.step()
	var database := library.database
	_expect(library.phase == ContentLibrary.Phase.DONE and database.package_count() == 3
		and database.package_version("dependent") == "1.0.0" and library.issues.size() == 3,
		"package startup resolves dependencies, conflicts, versions and isolated PCK paths")
	var registered := database.biomes.find(biome.key) as VoxelBiome
	_expect(registered != null and registered.surface == block.key and database.entities.find(registered.vegetation[0]) != null,
		"loaded biome resolves content from multiple namespaces")
	_expect((database.biomes.find(forest.key) as VoxelBiome).vegetation.is_empty(), "explicit biome override")
	_expect(ContentRegistry.namespace_of(&"invalid@multiple@names").is_empty(), "invalid identifiers rejected")
	_expect(database.texture(&"check:unknown") == database.texture(&"other:unknown"), "shared missing texture")
	_expect(database.items.find(&"check@rock") == database.items.find(&"check:rock")
		and not database.items.register(&"check:duplicate", item), "aliases resolve to frozen definitions")
	_expect(database.component_for(database.blocks.find(&"check:rock"), &"check@hardness") == database.components.find(&"check:hardness"),
		"mod component references resolve to the shared definition")
	for id: StringName in [&"core:flower_gold", &"core:flower_rose", &"core:flower_lilac"]:
		var flower := database.entities.find(id) as ContentScene
		var flower_item := database.items.find(id) as InventoryItem
		_expect(flower != null and flower.drops != null and flower.drops.quantity_for(id) == 1
			and flower_item != null and flower_item.icon_id == id and flower_item.entity_id == id,
			"flowers can be collected and planted as the same color: %s" % id)
	var inventory := SlotInventory.new(2)
	inventory.add(database.items.find(&"core:stone") as InventoryItem, 1)
	var queue := CraftingQueue.new(inventory, database.items, database.recipes)
	_expect(queue.enqueue(&"check:chip"), "mod recipes accept legacy ingredient IDs")
	queue.advance(5.0)
	_expect(inventory.item_totals().get(&"check:rock", 0) == 1, "mod results use canonical inventory IDs")
	var catalog := database.block_catalog(DemoContent.MISSING_BLOCK)
	_expect(catalog.id_for(block.key) > 0 and catalog.key_for(catalog.resolve(&"check@absent")) == DemoContent.MISSING_BLOCK,
		"runtime block registration and fallback")
	var packed_definition := catalog.definition(catalog.id_for(block.key))
	_expect(packed_definition != null and packed_definition == database.blocks.find(block.key)
		and packed_definition.breakable != null and is_equal_approx(packed_definition.breakable.duration(), 0.75)
		and packed_definition.drops != null and packed_definition.drops.items.get(&"core:stone", 0) == 2,
		"mod pack preserves shared resistance and cross-namespace drops")
	if registered != null:
		var generator := VoxelHeightmapGenerator.new()
		generator.biomes.append(registered)
		generator.catalog = catalog
		generator.prepare()
		var column := generator.sample_column(0, 0)
		var surface := Vector3i(0, column.x, 0)
		var chunk := generator.generate_chunk(VoxelChunkData.chunk_of(surface), VoxelCancellation.new())
		_expect(catalog.key_for(chunk.id_at(VoxelChunkData.index_of(VoxelChunkData.local_of(surface)))) == &"check:rock",
			"registered mod biome supplies the generated surface")
	var wide_catalog := VoxelCatalog.new()
	for index in 256:
		var entry := VoxelBlock.new()
		entry.key = StringName("check@block_%d" % index)
		wide_catalog.register(entry)
	_expect(wide_catalog.id_for(&"check@block_255") == 256, "runtime registry exceeds byte IDs")
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)


func _pack_fixture(directory: String, pack: ContentPack, extra_path := "") -> void:
	var fixture := directory.path_join(pack.content_namespace + ".tres")
	var archive := directory.path_join(pack.content_namespace + ".pck")
	_expect(ResourceSaver.save(pack, fixture) == OK, "mod manifest serialization")
	var packer := PCKPacker.new()
	_expect(packer.pck_start(archive) == OK, "create test pack")
	_expect(packer.add_file("res://mods/%s/content.tres" % pack.content_namespace, fixture) == OK, "package mod manifest")
	if not extra_path.is_empty():
		_expect(packer.add_file(extra_path, fixture) == OK, "package out-of-scope file fixture")
	_expect(packer.flush() == OK, "finish test pack")


func _check_data() -> void:
	var cell := Vector3i(-1, 32, -17)
	_expect(VoxelChunkData.chunk_of(cell) == Vector3i(-1, 2, -2), "signed chunk division")
	_expect(VoxelChunkData.local_of(cell) == Vector3i(15, 0, 15), "signed local coordinates")
	var data := VoxelChunkData.new(PackedByteArray(), _catalog.id_for(&"core:stone"))
	var changes: Dictionary[int, int] = {4095: _catalog.id_for(&"core:slab")}
	var mixed := data.with_changes(changes)
	_expect(data.payload_bytes() == 0 and data.id_at(4095) == _catalog.id_for(&"core:stone"), "uniform snapshot")
	_expect(mixed.payload_bytes() == 4096 and mixed.id_at(4095) == _catalog.id_for(&"core:slab"), "mixed snapshot")
	var wide_edits: Dictionary[int, int] = {4095: 256}
	var wide := mixed.with_changes(wide_edits)
	_expect(wide.id_at(4095) == 256 and wide.id_at(4094) == _catalog.id_for(&"core:stone"),
		"wide snapshot promotion preserves all cells")
	changes[4095] = _catalog.id_for(&"core:stone")
	_expect(mixed.with_changes(changes).payload_bytes() == 0, "recompression")
	var world_data := VoxelWorldData.new()
	var coord := VoxelChunkData.chunk_of(cell)
	var flower := &"core:flower_lilac"
	world_data.install_chunk(coord, data)
	_expect(world_data.mark_prop_removed(cell) and world_data.plant_prop(cell, flower)
		and not world_data.is_prop_removed(cell) and not world_data.plant_prop(cell, flower),
		"replanting replaces a removal and refuses duplicate placement")
	world_data.unload_chunk(coord)
	_expect(world_data.prop_edits(coord).get(cell) == flower, "planted flowers survive streaming")
	_expect(world_data.mark_prop_removed(cell) and world_data.is_prop_removed(cell)
		and not world_data.mark_prop_removed(cell), "replanted flowers can only be collected once")


func _check_behavior() -> void:
	var catalog := VoxelCatalog.new()
	var definition := VoxelBlock.new()
	var behavior := CountingBehavior.new()
	definition.key = &"test@counting"
	definition.behavior = behavior
	_expect(catalog.register(definition), "behavior-only composition")
	catalog.freeze()
	definition = VoxelBlock.new()
	definition.key = &"test@late"
	_expect(not catalog.register(definition), "worker catalog cannot change")
	var active := VoxelActiveBlocks.new()
	var cell := Vector3i(-16, 21, 0)
	var coord := VoxelChunkData.chunk_of(cell)
	var data := VoxelChunkData.new(PackedByteArray(), 1)
	active.interact(cell, behavior)
	for i in 3:
		active.advance_chunk(coord, data, catalog, 0.01)
	_expect(active.chunk_coords().is_empty() and behavior.ticks == 2, "idle cells stop updating")
	active.interact(cell, behavior)
	_expect(behavior.readback == 2, "behavior state survives inactivity")
	active.clear(cell)
	active.interact(cell, behavior)
	_expect(behavior.readback == 0, "removing a block clears behavior state")


func _check_inventory() -> void:
	var inventory := SlotInventory.new(3)
	var first := InventoryItem.new()
	first.id = &"test@first"
	first.stack_limit = 4
	var second := InventoryItem.new()
	second.id = &"test@second"
	_expect(inventory.add(first, 6) == 6 and inventory.count_at(0) == 4, "inventory splits at stack limit")
	_expect(inventory.add(second, 3) == 3 and inventory.room_for(first) == 2, "inventory capacity by item")
	_expect(inventory.add(first, 3) == 2, "inventory reports partial add")
	_expect(inventory.remove(1, 3) == 3, "inventory removes a quantity")
	_expect(inventory.move(0, 1) == 3 and inventory.count_at(0) == 1, "inventory merges without overflow")
	_expect(inventory.move(2, 0, 1) == 0 and inventory.move(2, 0) == 3, "inventory swaps full stacks")
	_expect(inventory.remove(2, 1) == 1 and inventory.item_at(2) == null, "inventory clears an empty stack")
	_expect(inventory.move(1, 2, 2) == 2 and inventory.count_at(2) == 2, "inventory moves a partial stack")
	var hotbar := Hotbar.new(inventory, 2)
	hotbar.cycle(-1)
	_expect(hotbar.active_slot() == 1 and hotbar.active_item() == first, "hotbar wraps through inventory slots")
	inventory.move(0, 1)
	_expect(hotbar.active_item() == second, "hotbar reads the same stack after an inventory swap")


func _check_crafting() -> void:
	var log_item := _content.items.find(&"core:log") as InventoryItem
	var stone := _content.items.find(&"core:stone") as InventoryItem
	var timber := _content.recipes.find(&"core:timber") as CraftingRecipe
	var fence := _content.recipes.find(&"core:fence") as CraftingRecipe
	var inventory := SlotInventory.new(3)
	var queue := CraftingQueue.new(inventory, _content.items, _content.recipes)
	inventory.add(log_item, 1)
	_expect(queue.craftable_batches(fence.id) == 2 and queue.craftable_batches(&"core:roof") == 0,
		"crafting estimates available batches including intermediates without reserving stock")
	_expect(not queue.enqueue(&"core:roof") and inventory.count_at(0) == 1,
		"failed crafting plans leave inventory intact")
	_expect(queue.enqueue(fence.id) and inventory.item_at(0) == null,
		"crafting reserves the raw materials for intermediate recipes")
	queue.advance(timber.seconds + fence.seconds + 0.01)
	var totals := inventory.item_totals()
	_expect(queue.active_order() == null and totals.get(fence.product, 0) == fence.product_count
		and totals.get(timber.product, 0) == timber.product_count - fence.ingredients[timber.product],
		"crafting delivers the final product and unused intermediate stock")

	var small_inventory := SlotInventory.new(1)
	var small_queue := CraftingQueue.new(small_inventory, _content.items, _content.recipes)
	small_inventory.add(log_item, 1)
	_expect(small_queue.enqueue(fence.id), "chained order can be queued")
	small_queue.advance(timber.seconds)
	small_queue.cancel(small_queue.active_order())
	_expect(small_inventory.count_at(0) == timber.product_count
		and small_inventory.item_at(0).id == timber.product, "cancellation refunds completed intermediates")

	small_inventory.remove(0, small_inventory.count_at(0))
	small_inventory.add(log_item, 1)
	_expect(small_queue.enqueue(timber.id), "crafting can resume after cancellation")
	small_inventory.add(stone, 1)
	small_queue.advance(timber.seconds)
	_expect(small_queue.is_waiting_for_space() and not small_queue.is_running(),
		"full inventory pauses delivery")
	small_inventory.remove(0, 1)
	await process_frame
	_expect(not small_queue.is_waiting_for_space() and small_inventory.count_at(0) == timber.product_count,
		"pending items arrive after inventory space is freed")


func _check_mining() -> void:
	var mining := Mining.new(0.25, 0.5)
	var struck := Vector3i(-1, -1, 0)
	var other := struck + Vector3i(VoxelChunkData.SIZE, 0, 0)
	_expect(is_equal_approx(mining.strike(struck, 0.25, 2.0, 2.0), 0.25), "tool speed scales damage")
	mining.advance_time(0.25)
	mining.strike(other, 0.25, 1.0, 1.0)
	mining.advance_time(0.5)
	_expect(is_equal_approx(mining.progress(struck), 0.125), "damage recovers after its delay")
	_expect(is_equal_approx(mining.progress(other), 0.25), "equal local indices in different chunks are independent")
	mining.forget_chunk(VoxelChunkData.chunk_of(other))
	mining.advance_time(0.25)
	_expect(mining.progress(struck) == 0.0 and mining.progress(other) == 0.0, "damage expires or clears on unload")
	var elapsed := Mining.new(0.0, 0.0, 0.2)
	var progress := 0.0
	for tick in 10:
		progress = elapsed.strike(struck, 0.1, 1.0, 1.0)
		elapsed.advance_time(0.1)
		if tick < 9:
			_expect(progress < 1.0, "uninterrupted mining respects the full duration")
	_expect(progress == 1.0, "ten short strikes finish at the same time as one long strike")
	var expiring := Mining.new(2.0, 1.0, 0.5)
	expiring.strike(other, 0.25, 1.0, 1.0)
	expiring.advance_time(0.5)
	_expect(expiring.progress(other) == 0.25, "expiry is measured from the end of the last strike")
	expiring.advance_time(0.25)
	_expect(expiring.progress(other) == 0.0, "idle expiry can clear damage before recovery begins")


func _check_seed(generator: DemoVoxelGenerator) -> void:
	var coords: Array[Vector3i] = [
		Vector3i(-4, 0, 3), Vector3i(-3, 0, 3), Vector3i(5, 0, -4),
		Vector3i(-26, 0, -13), Vector3i(19, 0, 31),
	]
	var same := _generator(1729)
	var different := _generator(1730)
	var originals: Array[VoxelChunkData] = []
	var cancel := VoxelCancellation.new()
	var changed := false
	for coord in coords:
		originals.append(generator.generate_chunk(coord, cancel))
	for i in range(coords.size() - 1, -1, -1):
		var replica := same.generate_chunk(coords[i], cancel)
		var alternate := different.generate_chunk(coords[i], cancel)
		for index in VoxelChunkData.VOLUME:
			if originals[i].id_at(index) != replica.id_at(index):
				_expect(false, "seed varies with load order at %s" % coords[i])
				break
			changed = changed or originals[i].id_at(index) != alternate.id_at(index)
	_expect(changed, "alternate seeds affect voxel output")
	var climates: Dictionary[int, bool] = {}
	for z in range(-1024, 1025, 16):
		for x in range(-1024, 1025, 16):
			climates[generator.sample_column(x, z).y] = true
	_expect(climates.size() == generator.biomes.size(), "all configured biomes appear")
	_expect(climates.has(generator.biome_index(&"core:mountain")), "mountain appears in the default seed")


func _check_mesher(catalog: VoxelCatalog) -> void:
	var empty := VoxelChunkData.new()
	var full := VoxelChunkData.new(PackedByteArray(), _catalog.id_for(&"core:stone"))
	var water := VoxelChunkData.new(PackedByteArray(), _catalog.id_for(&"core:water"))
	var neighbors: Array[VoxelChunkData] = [empty, empty, empty, empty, empty, empty]
	var cancel := VoxelCancellation.new()
	var result := VoxelChunkMesher.new().build(full, neighbors, catalog, cancel)
	var top_layer := float(catalog.block(full.uniform_id()).tiles[VoxelChunkMesher.TOP_SIDE])
	_expect(result.vertex_count() == 56 and result.triangle_count() == 28, "only the top border splits greedy faces")
	_expect(result.collision.size() == 36, "greedy collision")
	_expect(result.surfaces[0].uv.has(Vector2(16, 0)), "greedy UV repeats per cell")
	_expect(result.surfaces[0].layers.has(Vector2(top_layer, 1.0)), "top drop marked on the east edge")
	neighbors[0] = full
	result = VoxelChunkMesher.new().build(full, neighbors, catalog, cancel)
	_expect(result.vertex_count() == 40 and result.collision.size() == 30, "solid seam culled")
	_expect(not result.surfaces[0].normals.has(Vector3.RIGHT), "neighbor owns the hidden side")
	var has_east_ledge := false
	for layer: Vector2 in result.surfaces[0].layers:
		has_east_ledge = has_east_ledge or (int(layer.y) & 1) != 0
	_expect(not has_east_ledge, "no ledge at the same-height chunk seam")
	neighbors[0] = water
	result = VoxelChunkMesher.new().build(water, neighbors, catalog, cancel)
	_expect(result.surfaces[0].indices.is_empty() and result.surfaces[1].vertices.size() == 20,
		"transparent seam and surface batch")
	_expect(result.collision.is_empty(), "water has no collision payload")
	cancel.cancel()
	_expect(VoxelChunkMesher.new().build(full, neighbors, catalog, cancel) == null, "cancellation")


func _check_fence(catalog: VoxelCatalog) -> void:
	var key := &"core:fence"
	var id := catalog.id_for(key)
	_expect(id > 0 and catalog.key_for(catalog.id_for(&"core:fence_turned")) == key,
		"old fence blocks use the same canonical definition")
	var empty := VoxelChunkData.new()
	var center := empty.with_changes({
		VoxelChunkData.index_of(Vector3i(15, 4, 5)): id,
		VoxelChunkData.index_of(Vector3i(15, 4, 6)): id,
	} as Dictionary[int, int])
	var east := empty.with_changes({
		VoxelChunkData.index_of(Vector3i(0, 4, 5)): id,
	} as Dictionary[int, int])
	var neighbors: Array[VoxelChunkData] = [east, empty, empty, empty, empty, empty]
	var cancel := VoxelCancellation.new()
	var joined := VoxelChunkMesher.new().build(center, neighbors, catalog, cancel)
	var across_edge := Vector3(16, 4.8125, 5.5625)
	var around_corner := Vector3(15.4375, 4.8125, 6)
	_expect(joined.surfaces[0].vertices.has(across_edge) and joined.collision.has(across_edge)
		and joined.surfaces[0].vertices.has(around_corner) and joined.collision.has(around_corner),
		"corner fence holds both rail directions across the chunk edge")
	var ghost := VoxelChunkMesher.preview_surface(catalog.block(id), (1 << 0) | (1 << 4))
	_expect(ghost.vertices.has(across_edge - Vector3(15, 4, 5))
		and ghost.vertices.has(around_corner - Vector3(15, 4, 5)), "fence preview shows the corner")
	neighbors[0] = empty
	var after_removal := VoxelChunkMesher.new().build(center, neighbors, catalog, cancel)
	_expect(not after_removal.surfaces[0].vertices.has(across_edge) and not after_removal.collision.has(across_edge)
		and after_removal.collision.has(around_corner), "removing a fence updates only its rail")


func _benchmark(generator: DemoVoxelGenerator, catalog: VoxelCatalog) -> void:
	var cancel := VoxelCancellation.new()
	var chunks: Dictionary[Vector3i, VoxelChunkData] = {}
	for z in range(-2, 3):
		for x in range(-2, 3):
			for y in range(-1, 2):
				var coord := Vector3i(x, y, z)
				chunks[coord] = generator.generate_chunk(coord, cancel)
	for greedy: bool in [false, true]:
		var vertices := 0
		var triangles := 0
		var surfaces := 0
		var elapsed := 0
		for z in range(-1, 2):
			for x in range(-1, 2):
				var coord := Vector3i(x, 0, z)
				var neighbors: Array[VoxelChunkData] = []
				for direction in VoxelChunkData.DIRECTIONS:
					neighbors.append(chunks[coord + direction])
				var started := Time.get_ticks_usec()
				var payload := VoxelChunkMesher.new().build(chunks[coord], neighbors, catalog, cancel, greedy)
				elapsed += Time.get_ticks_usec() - started
				vertices += payload.vertex_count()
				triangles += payload.triangle_count()
				for surface in payload.surfaces:
					surfaces += int(not surface.indices.is_empty())
		print("Greedy=%s  vertices=%d  triangles=%d  surfaces=%d  average_ms=%.2f"
			% [greedy, vertices, triangles, surfaces, elapsed / 9000.0])


func _check_demo() -> void:
	var scene := DEMO.instantiate()
	scene.set_script(LandmarkWorld)
	var demo := scene as LandmarkWorld
	demo.world_definition = OVERWORLD.duplicate() as WorldPreset
	demo.world_definition.randomize_seed = false
	root.add_child(demo)
	var world := demo.get_node("World") as VoxelWorld
	var player := demo.get_node("Player") as DemoVoxelPlayer
	var camera := demo.get_node("Camera3D") as Camera3D
	var props := demo.get_node("World/Props") as VoxelPropView
	var bag := demo.get_node("Inventory") as DemoInventoryView
	var started := Time.get_ticks_msec()
	if not await _settle(world):
		return
	_stream_frames.sort()
	var p95 := _stream_frames[ceili(_stream_frames.size() * 0.95) - 1]
	print("Initial window in %d ms  frame p95=%.2f ms  max=%.2f ms  %s" % [
		Time.get_ticks_msec() - started, p95, _stream_frames[-1], world.stats(),
	])
	for i in 12:
		await physics_frame
	await process_frame
	_expect(player.is_on_floor(), "character rests on terrain")
	_expect(camera.projection == Camera3D.PROJECTION_ORTHOGONAL and is_zero_approx(camera.basis.z.x),
		"orthographic camera aligns with the map axes")
	var cutaway := VoxelCutawayRegion.new(world)
	var overhang := Vector3i(-2, 14, 16)
	var stone := _catalog.id_for(&"core:stone")
	var obstruction: Dictionary[Vector3i, int] = {overhang: stone, overhang + Vector3i.UP: stone}
	_expect(world.set_blocks(obstruction), "place a tall distant obstruction")
	var cuts := cutaway.columns(Vector3(-1.5, 1.0, 8.5), Vector3(0, 27, 16.5), 1.36, 3.0)
	_expect(cuts.has(Vector2i(-2, 16)), "deep excavation clears foreground past the near wall and chunk border")
	obstruction[overhang] = 0
	obstruction[overhang + Vector3i.UP] = 0
	_expect(world.set_blocks(obstruction), "remove the test obstruction")
	_check_wall_cutaway(world, cutaway)
	_expect(not demo.has_node("Overlay"), "tutorial overlay removed")
	_expect(props.get_child_count() > 0 and world.get_block(Vector3i(-5, 4, -1)) == 0,
		"trees stream independently of block data")
	var trunk_ray := PhysicsRayQueryParameters3D.create(Vector3(-4.5, 8, -0.5), Vector3(-4.5, 4, -0.5), 4)
	_expect(not demo.get_world_3d().direct_space_state.intersect_ray(trunk_ray).is_empty(),
		"tree trunk has its own collider")
	_check_flat_placement(demo, world)
	_check_layer_targeting(demo, world)
	_expect(is_equal_approx(_floor_y(demo, 2.5, 3.5), 7.5), "inclined roof")
	_expect(is_equal_approx(_floor_y(demo, 6.5, 5.5), 4.5), "half slab")
	_expect(is_equal_approx(_floor_y(demo, 2.5, 6.75), 4.25), "stair ramp")
	_expect(is_equal_approx(_floor_y(demo, -2.5, 1.5), 4.75), "wall")
	_expect(is_equal_approx(_floor_y(demo, 1.5, 5.5), 6.0), "fence")
	_expect(world.get_block(Vector3i(13, 1, -6)) == _catalog.id_for(&"core:water"), "pond water present")
	_expect(is_equal_approx(_floor_y(demo, 13.5, -5.5), 1.0), "pond ray reaches the bedrock through water")
	_check_shadow(demo, player)
	var capture := OS.get_cmdline_user_args()
	if DisplayServer.get_name() != "headless" and not capture.is_empty():
		await RenderingServer.frame_post_draw
		print("Draw calls in captured frame: %d" % RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
		))
		_expect(root.get_texture().get_image().save_png(capture[0]) == OK, "viewport capture")
	var inventory_event := InputEventAction.new()
	inventory_event.action = &"core:inventory"
	inventory_event.pressed = true
	bag._input(inventory_event)
	_expect(bag.is_open() and not player.input_enabled, "inventory shortcut opens the bag and captures movement input")
	if DisplayServer.get_name() != "headless" and capture.size() > 1:
		await RenderingServer.frame_post_draw
		_expect(root.get_texture().get_image().save_png(capture[1]) == OK, "inventory capture")
	var slots := bag.get_node("%Slots") as GridContainer
	var quick_slots := bag.get_node("Screen/Hotbar").get_child(0)
	(quick_slots.get_child(0) as Button).pressed.emit()
	(slots.get_child(0) as Button).pressed.emit()
	(slots.get_child(0) as Button).pressed.emit()
	(slots.get_child(7) as Button).pressed.emit()
	var count := slots.get_child(7).get_child(1) as Label
	var moved_slot := demo._hotbar.size() + 7
	_expect(bag.active_slot() == moved_slot and count.text == "8" and demo._inventory.item_at(0) == null,
		"bag receives a hotbar stack and moves it across storage slots")
	demo._inventory.remove(moved_slot, 1)
	_expect(count.text == "7", "bag displays the updated stack after a removal")
	var quick_button := quick_slots.get_child(7) as Button
	(slots.get_child(7) as Button).pressed.emit()
	quick_button.pressed.emit()
	var quick_count := quick_button.get_child(1) as Label
	_expect(quick_count.text == "7" and demo._inventory.item_at(moved_slot) == null,
		"hotbar receives the original stack without duplicating it")
	(bag.get_node("%Close") as Button).pressed.emit()
	_expect(not bag.is_open() and player.input_enabled, "bag closes and returns movement input")
	var edit_point := camera.unproject_position(Vector3(0.5, 4.0, 9.5))
	demo.call("_pick_target", edit_point)
	demo.call("_place_target")
	var placed := Vector3i(0, 4, 9)
	_expect(world.get_block(placed) == _catalog.id_for(&"core:timber") and quick_count.text == "6",
		"placing spends a unit")
	if not await _settle(world):
		return
	edit_point = camera.unproject_position(Vector3(0.5, 5.0, 9.5))
	demo.call("_pick_target", edit_point)
	var duration := world.block_definition_at(placed).breakable.duration()
	demo.call("_mine_target", duration * 0.4)
	_expect(world.get_block(placed) == _catalog.id_for(&"core:timber") and quick_count.text == "6",
		"partial mining keeps the block and its drop")
	demo.call("_mine_target", duration * 0.65)
	_expect(world.get_block(placed) == 0 and quick_count.text == "7",
		"collecting adds the removed block")
	_expect(demo._mining.progress(placed) == 0.0, "destroying a block clears its temporary damage")
	await _check_equipped_mining(demo, world, camera, placed)
	_check_tree_mining(demo, props, world)
	await _check_live_jump(player)
	player.set_physics_process(false)
	var legacy_position := Vector3i(15, 30, 2)
	var missing_position := Vector3i(16, 30, 2)
	_expect(world.restore_block_edits({legacy_position: 3, missing_position: "check@missing"}, DemoContent.LEGACY_BLOCKS),
		"legacy and stable block edits load together")
	_expect(world.get_block_key(legacy_position) == &"core:stone", "legacy IDs use their original mapping")
	_expect(world.get_block_key(missing_position) == DemoContent.MISSING_BLOCK, "missing mod block has visible fallback")
	_expect(world.export_block_edits().get(missing_position) == &"check:missing", "missing mod ID survives export")
	_expect(world.set_block_key(missing_position, VoxelCatalog.AIR_KEY)
		and world.export_block_edits().get(missing_position) == VoxelCatalog.AIR_KEY, "editing replaces a missing block ID")
	var seam := Vector3i(15, 20, 7)
	var above := Vector3i(15, 32, 7)
	var edits: Dictionary[Vector3i, int] = {
		seam: _catalog.id_for(&"core:stone"), seam + Vector3i.RIGHT: _catalog.id_for(&"core:stone"),
		above: _catalog.id_for(&"core:stone"), above + Vector3i.DOWN: _catalog.id_for(&"core:stone"),
	}
	_expect(world.set_blocks(edits), "atomic structure edit across X and Y")
	if not await _settle(world):
		return
	_expect(is_equal_approx(_floor_y(demo, 15.5, 7.5, 31.0), 21.0), "collision on chunk edge")
	_expect(is_equal_approx(_floor_y(demo, 16.5, 7.5), 21.0), "collision past chunk edge")
	_expect(world.set_block(seam, 0), "remove terrain at chunk edge")
	if not await _settle(world):
		return
	_expect(_floor_y(demo, 15.5, 7.5, 31.0) < 21.0, "collision updated after removal")
	_expect(is_equal_approx(_floor_y(demo, 16.5, 7.5), 21.0), "adjacent collision preserved")
	player.global_position = Vector3(15.5, 17.0, 7.5)
	if not await _settle(world):
		return
	_expect(is_equal_approx(_floor_y(demo, 15.5, 7.5, 40.0), 33.0), "collision above vertical seam")
	player.global_position = Vector3(165.0, 40.0, -162.0)
	await process_frame
	await process_frame
	await process_frame
	player.global_position = Vector3(-165.0, 43.0, -162.0)
	if not await _settle(world):
		return
	_expect(world.is_chunk_ready(Vector3i(-11, 2, -11)), "stream signed and vertical chunks")
	_expect(world.get_block(Vector3i(165, 40, -162)) == VoxelWorldData.UNLOADED,
		"discard jobs from the superseded window")
	_expect(world.get_block(seam) == VoxelWorldData.UNLOADED, "previous window unloaded")
	_expect(props.get_child_count() == 0, "trees outside the loaded window are released")
	player.respawn()
	if not await _settle(world):
		return
	_expect(world.get_block(seam + Vector3i.RIGHT) == _catalog.id_for(&"core:stone"), "edit survives unload")
	_expect(world.get_block(above) == _catalog.id_for(&"core:stone"), "vertical halo receives sparse edits")
	_expect(props.get_child_count() > 0, "tree anchors return with the window")
	_expect(world.is_prop_removed(TREE_TO_MINE) and props.definition_at(TREE_TO_MINE) == null,
		"the mined tree stays removed when its chunk returns")
	var foundation := Vector3i(-2, 0, 8)
	var below := foundation + Vector3i.DOWN
	_expect(world.get_block_key(foundation) == &"core:bedrock" and world.block_definition_at(foundation).breakable == null,
		"foundation is indestructible at Y=0")
	_expect(not world.set_block(foundation, 0), "foundation cannot be excavated")
	_expect(world.restore_block_edits({foundation: VoxelCatalog.AIR_KEY, below: &"core:stone"})
		and world.get_block_key(foundation) == &"core:bedrock" and world.get_block(below) == 0,
		"old edits preserve the foundation and the empty chunk below")
	var shaft: Dictionary[Vector3i, int] = {}
	for y in range(1, 4):
		shaft[Vector3i(-2, y, 8)] = 0
	_expect(world.set_blocks(shaft), "excavate down to the foundation")
	player.global_position = Vector3(-1.5, 1.1, 8.5)
	player.set_physics_process(true)
	if not await _settle(world):
		return
	for i in 12:
		await physics_frame
	await process_frame
	var avatar := player.get_node("Avatar") as Sprite3D
	_expect(player.is_on_floor() and absf(player.global_position.y - 1.0) < 0.1,
		"player rests on the foundation")
	_expect(camera.unproject_position(avatar.global_position).distance_to(root.get_visible_rect().get_center()) < 1.0,
		"camera centers the player underground")


func _check_placement_faces() -> void:
	var config := VoxelTargetingConfig.new()
	var top := Vector3i.UP
	var front := Vector3i.BACK
	var no_face := Vector3i.ZERO
	var top_hits := {
		Vector3(0.5, 1.0, 0.5): top,
		Vector3(0.08, 1.0, 0.5): Vector3i.LEFT,
		Vector3(0.92, 1.0, 0.5): Vector3i.RIGHT,
		Vector3(0.5, 1.0, 0.08): Vector3i.FORWARD,
		Vector3(0.5, 1.0, 0.92): front,
	}
	for point: Vector3 in top_hits:
		_expect(VoxelTargeting.placement_face_at(top, point, no_face, config) == top_hits[point],
			"top impact selects the center or the corresponding side")
	_expect(VoxelTargeting.placement_face_at(front, Vector3(0.5, 0.5, 1.0), no_face, config) == front,
		"a direct hit in the middle of a side keeps that side")
	_expect(VoxelTargeting.placement_face_at(front, Vector3(0.02, 0.5, 1.0), no_face, config) == front,
		"a direct side hit keeps its normal near a vertical edge")
	_expect(VoxelTargeting.placement_face_at(front, Vector3(0.5, 0.08, 1.0), front, config) == Vector3i.DOWN,
		"the lower edge of a visible side can select the underside")
	_expect(VoxelTargeting.placement_face_at(Vector3i.DOWN, Vector3(0.5, 0.0, 0.5), no_face, config) == Vector3i.DOWN,
		"a direct underside hit selects the underside")
	var boundary := Vector3(0.22, 0.5, 0.5)
	_expect(VoxelTargeting.placement_face_at(top, boundary, top, config) == top
		and VoxelTargeting.placement_face_at(top, boundary, Vector3i.LEFT, config) == Vector3i.LEFT,
		"a half-height top uses the same stable side band as a cube")
	config.corner_priority = VoxelTargetingConfig.CornerPriority.Z_AXIS
	var corner := Vector3(0.08, 1.0, 0.09)
	_expect(VoxelTargeting.placement_face_at(top, corner, no_face, config) == Vector3i.FORWARD,
		"the configured axis breaks close corner ties")
	config.aim_mode = VoxelTargetingConfig.AimMode.FACING
	_expect(VoxelTargeting.placement_face_at(top, corner, no_face, config) == top,
		"facing mode keeps the geometric face")


func _check_flat_placement(demo: LandmarkWorld, world: VoxelWorld) -> void:
	var target := VoxelTargeting.new()
	var config := VoxelTargetingConfig.new()
	var space := demo.get_world_3d().direct_space_state
	var ground := Vector3i(2, 3, 8)
	var actor := Vector3(ground) + Vector3(0.5, 2.0, 0.5)
	var camera_ray_origin := actor + Vector3.UP * 4.0
	target.pick(space, world, camera_ray_origin, Vector3.DOWN, actor, config, Callable())
	_expect(target.valid and target.can_place and target.adjacent == ground + Vector3i.UP,
		"aiming at the center still builds above the selected ground tile")
	var distant_actor := actor + Vector3.RIGHT * (config.reach + 1.0)
	target.pick(space, world, camera_ray_origin, Vector3.DOWN, distant_actor, config, Callable(), null, 16.0)
	_expect(target.out_of_range and target.cell == ground and target.face == Vector3i.UP
		and not target.valid and not target.can_place,
		"a ray outside interaction reach still identifies the visible tile for the red grid")
	target.pick(space, world, camera_ray_origin, Vector3.DOWN, actor, config, Callable())
	_expect(target.valid and target.can_place and not target.out_of_range,
		"the same tile restores normal targeting when the player moves into reach")
	target.pick(space, world, camera_ray_origin, Vector3.UP, actor, config, Callable(), null, 0.5)
	_expect(not target.valid and not target.out_of_range, "a ray that misses clears the grid")
	for side: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
		var edge := camera_ray_origin + Vector3(side) * 0.4
		target.pick(space, world, edge, Vector3.DOWN, actor, config, Callable())
		_expect(target.valid and target.can_place and target.cell == ground and target.placement_face == side
			and target.adjacent == ground + side + Vector3i.UP,
			"aiming at a ground edge builds on top of the neighboring tile")
	var neighbor := ground + Vector3i.BACK
	var previous := world.get_block(neighbor)
	_expect(world.set_block(neighbor, 0), "open one side at the same height")
	target.pick(space, world, camera_ray_origin + Vector3.BACK * 0.4, Vector3.DOWN, actor, config, Callable())
	_expect(target.valid and target.can_place and target.adjacent == neighbor,
		"an open side keeps its same-height placement")
	_expect(world.set_block(neighbor, previous), "restore the ground next to the targeting fixture")


func _check_layer_targeting(demo: LandmarkWorld, world: VoxelWorld) -> void:
	var target := demo._target
	var config := demo.construction
	var feet := Vector3(-4.5, 4.0, 1.5)
	var hit := Vector3(-4.5, 4.0, -0.5)
	var to_camera := Vector3(0, 5, 3)
	var wall := Vector3i(-5, 4, 0)
	var previous := world.get_block(wall)
	_expect(world.set_block_key(wall, &"core:stone"), "layer targeting fixture has a foreground wall")
	target.pick_layer(world, hit + to_camera, -to_camera.normalized(), feet, 4, config)
	_expect(target.can_place and not target.valid and target.adjacent == Vector3i(-5, 4, -1),
		"layer ray crosses a wall and addresses the negative-coordinate destination")
	_expect(world.set_block(wall, previous), "remove the layer targeting fixture")
	_expect(not target.placement_clear(demo.get_world_3d().direct_space_state, world, target.adjacent),
		"layer placement cannot overlap the tree collider in the destination")
	target.pick_layer(world, hit + to_camera, Vector3.RIGHT, feet, 4, config)
	_expect(not target.can_place, "parallel ray clears the previous destination")
	target.pick_layer(world, hit + to_camera, -to_camera.normalized(), Vector3(32.5, 4, -0.5), 4, config)
	_expect(not target.can_place and target.out_of_range and target.cell == Vector3i(-5, 4, -1),
		"layer placement keeps the destination grid outside the configured reach")


func _check_equipped_mining(demo: LandmarkWorld, world: VoxelWorld, camera: Camera3D, cell: Vector3i) -> void:
	var previous_slot := demo._hotbar.active_slot()
	var item := demo._inventory.item_at(6)
	_expect(item != null and item.id == &"core:pickaxe" and item.equipment != null,
		"the seventh starter slot holds the registered pickaxe")
	if item == null or item.equipment == null:
		return
	var action := item.equipment.action as VoxelMiningTool
	_expect(action != null, "the pickaxe has a mining impact")
	if action == null or not world.set_block_key(cell, &"core:stone"):
		return
	if not await _settle(world):
		world.set_block_key(cell, VoxelCatalog.AIR_KEY)
		return
	var player := demo._player
	var machine := player._machine_state
	var grip := player.get_node("Avatar/Grip") as Node3D
	var screen := camera.unproject_position(Vector3(cell) + Vector3(0.5, 1.0, 0.5))
	var half_windup := action.impact_time() * 0.5
	var step := 1.0 / 60.0
	demo._hotbar.select(6)
	demo._pick_target(screen)
	demo._mine_pressed = true
	demo._use_mining_input(item.equipment, step)
	demo._mine_pressed = false
	machine.advance(half_windup, false)
	demo._resolve_impact(step)
	_expect(grip.visible and player.is_attacking() and demo._mining.progress(cell) == 0.0,
		"selecting the pickaxe shows it and the windup leaves the block untouched")
	demo._hotbar.select(previous_slot)
	machine.advance(action.duration, false)
	demo._resolve_impact(step)
	_expect(not grip.visible and not player.is_attacking() and demo._mining.progress(cell) == 0.0,
		"changing slots interrupts the attack before damage")
	demo._hotbar.select(6)
	demo._mine_pressed = true
	demo._use_mining_input(item.equipment, step)
	demo._mine_pressed = false
	machine.advance(action.impact_time() + step, true)
	demo._resolve_impact(step)
	var progress := demo._mining.progress(cell)
	var resistance := world.block_definition_at(cell).breakable.duration()
	var expected := action.work_per_impact * demo.mining_config.base_speed * item.mining_speed_multiplier / resistance
	_expect(is_equal_approx(progress, expected), "one swing applies mining work against the block resistance")
	machine.advance(action.duration, true)
	demo._resolve_impact(step)
	_expect(machine.state == ActorStateMachine.State.WALK and demo._mining.progress(cell) == progress,
		"recovery resumes locomotion without a second impact")
	machine.advance(step, false)
	_expect(machine.state == ActorStateMachine.State.IDLE, "stopping returns to idle")
	demo._hotbar.select(previous_slot)
	world.set_block_key(cell, VoxelCatalog.AIR_KEY)


func _check_tree_mining(demo: LandmarkWorld, props: VoxelPropView, world: VoxelWorld) -> void:
	var support := TREE_TO_MINE
	var sprite := props.targeting_sprite_at(support)
	_expect(sprite != null, "tree is available for mining")
	if sprite == null:
		return
	var definition := props.definition_at(support)
	var log_item := demo._items.find(&"core:log") as InventoryItem
	var room := demo._inventory.room_for(log_item)
	var ground := world.get_block(support)
	demo._target.prop_support = support
	demo._target.prop_valid = true
	demo._mine_target(1.0 / 60.0)
	_expect(props.targeting_sprite_at(support) == sprite and demo._inventory.room_for(log_item) == room,
		"a single hit leaves the tree standing and gives no drop")
	demo._mine_target(definition.breakable.duration())
	var received := room - demo._inventory.room_for(log_item)
	_expect(props.targeting_sprite_at(support) == null and received >= 4 and received <= 8,
		"sustained mining removes the tree and gives four to eight logs")
	demo._target.cell = support
	demo._target.valid = true
	demo._mine_target(2.0)
	_expect(world.get_block(support) == ground and demo._mining.progress(support) == 0.0,
		"the same held strike never mines the ground after an entity disappears")
	demo._clear_pending_actions()


func _check_wall_cutaway(world: VoxelWorld, cutaway: VoxelCutawayRegion) -> void:
	var center := Vector3i(-2, 12, 8)
	var stone := _catalog.id_for(&"core:stone")
	var wall: Dictionary[Vector3i, int] = {}
	for z in range(-1, 2):
		for x in range(-1, 2):
			if x != 0 or z != 0:
				wall[center + Vector3i(x, 0, z)] = stone
	_expect(world.set_blocks(wall), "place walls at the player's level")
	# Stand near the sideways tile boundary where the projection can overlap the side wall.
	var feet := Vector3(center) + Vector3(0.05, 0.0, 0.05)
	var view := Vector3(0, 27, 16.5)
	_expect(cutaway.columns(feet, view, 1.36, 3.0).is_empty(), "outdoor one-block steps stay opaque")
	var roof_cell := center + Vector3i.UP * 3
	_expect(world.set_block(roof_cell, stone), "place an isolated overhead block")
	_expect(cutaway.columns(feet, view, 1.36, 3.0).is_empty(), "an isolated block does not enclose a room")
	var roof: Dictionary[Vector3i, int] = {
		roof_cell: stone, roof_cell + Vector3i.LEFT: stone, roof_cell + Vector3i.RIGHT: stone,
	}
	_expect(world.set_blocks(roof), "extend the roof over the room")
	var covered_cuts := cutaway.columns(feet, view, 1.36, 3.0)
	_expect(covered_cuts.get(Vector2i(center.x, center.z + 1)) == center.y, "short foreground wall cuts under a roof")
	for x: int in [-1, 1]:
		_expect(not covered_cuts.has(Vector2i(center.x + x, center.z + 1)),
			"foreground corner stays opaque under a roof")
	_expect(covered_cuts.get(Vector2i(center.x, center.z)) == roof_cell.y, "continuous roof is cut")
	for cell in roof:
		roof[cell] = 0
	_expect(world.set_blocks(roof), "remove the test roof")
	for cell in wall.keys():
		wall[cell + Vector3i.UP] = stone
	_expect(world.set_blocks(wall), "extend the outdoor walls to two blocks")
	for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var cuts := cutaway.columns(feet, Vector3(direction.x * 16.5, 27, direction.y * 16.5), 1.36, 3.0)
		var front := Vector2i(center.x, center.z) + direction
		for cell in wall:
			if cell.y > center.y:
				continue
			var column := Vector2i(cell.x, cell.z)
			var expected := center.y if column == front else VoxelCutawayRegion.UNCUT
			_expect(cuts.get(column, VoxelCutawayRegion.UNCUT) == expected,
				"only the front center tile is cut at %s, camera %s" % [cell, direction])
	for cell in wall:
		wall[cell] = 0
	_expect(world.set_blocks(wall), "remove the wall cutaway fixture")


func _check_shadow(demo: Node3D, player: DemoVoxelPlayer) -> void:
	var shadow := player.get_node("Shadow") as ProjectedGroundShadow
	var feet := player.global_position
	shadow.project_from(feet)
	var baseline := shadow.global_position
	var baseline_height := shadow.height_above_ground
	var opacity := shadow.modulate.a
	var size := shadow.global_basis.x.length()
	shadow.project_from(feet + Vector3.UP * 1.5)
	_expect(shadow.visible and shadow.global_position.is_equal_approx(baseline)
		and is_equal_approx(shadow.height_above_ground, baseline_height + 1.5)
		and shadow.modulate.a < opacity and shadow.global_basis.x.length() < size,
		"jump shadow stays on ground and fades as height increases")
	for test: Vector3 in [Vector3(6.5, 6.0, 5.5), Vector3(2.5, 6.0, 6.75)]:
		shadow.project_from(test)
		var floor_y := _floor_y(demo, test.x, test.z, test.y)
		_expect(shadow.visible and is_equal_approx(shadow.height_above_ground, test.y - floor_y),
			"shadow uses the collider of an elevated shape")
	shadow.project_from(Vector3(2.5, 6.0, 6.75))
	_expect(shadow.global_basis.z.y > 0.0 and absf(shadow.global_basis.z.z) > 0.1,
		"shadow follows the stair ramp normal")
	shadow.project_from(Vector3(0, 100, 0))
	_expect(not shadow.visible, "shadow hides without a nearby surface")
	shadow.project_from(feet)


func _check_live_jump(player: DemoVoxelPlayer) -> void:
	var shadow := player.get_node("Shadow") as ProjectedGroundShadow
	var avatar := player.get_node("Avatar") as Sprite3D
	var ground := shadow.global_position
	var base := player.global_position.y
	var avatar_offset := avatar.global_position.y - base
	_expect(player.jump(), "jump starts when grounded")
	for i in 8:
		await physics_frame
	await process_frame
	_expect(player.global_position.y > base + 0.3 and shadow.global_position.is_equal_approx(ground)
		and is_equal_approx(avatar.global_position.y - player.global_position.y, avatar_offset),
		"player and avatar move together while the shadow stays on the floor")
	for i in 90:
		if player.is_on_floor():
			break
		await physics_frame
	await process_frame
	_expect(player.is_on_floor() and shadow.height_above_ground < 0.05, "jump lands with grounded shadow")


func _settle(world: VoxelWorld) -> bool:
	var time_limit := 15000 if DisplayServer.get_name() == "headless" else 90000
	var deadline := Time.get_ticks_msec() + time_limit
	await process_frame
	var previous := Time.get_ticks_usec()
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var now := Time.get_ticks_usec()
		_stream_frames.append((now - previous) / 1000.0)
		previous = now
		var stats := world.stats()
		if stats.wanted > 0 and stats.ready == stats.wanted and stats.pending == 0:
			await physics_frame
			await process_frame
			return true
	_expect(false, "streaming timed out: %s" % world.stats())
	return false


func _floor_y(demo: Node3D, x: float, z: float, start := 30.0) -> float:
	var ray := PhysicsRayQueryParameters3D.create(Vector3(x, start, z), Vector3(x, -8, z), 1)
	var hit := demo.get_world_3d().direct_space_state.intersect_ray(ray)
	return float(hit.position.y) if not hit.is_empty() else INF


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		push_error(label)
