extends SceneTree
## Run write, read, recover and legacy as separate processes with APPDATA inside res://.godot/.

const Store = preload("res://addons/ldk/core/World/world_save_store.gd")
const Codec = preload("res://addons/ldk/core/World/chunk_save_codec.gd")
const GAME := "res://src/World/demo.tscn"
const SELECTOR := "res://src/UI/Menu/world_selection.tscn"
const EXPECTED := "user://save-check.dat"
const SEED := 1729
const STONE := &"core:stone"
const FLOWER := &"core:flower_gold"
const MACHINE := &"check:machine"

var _store := Store.new()
var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var sandbox := ProjectSettings.globalize_path("res://.godot/").replace("\\", "/")
	if not OS.get_user_data_dir().replace("\\", "/").begins_with(sandbox):
		printerr("Use APPDATA apontando para uma pasta de teste em ", sandbox)
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	match args[0] if args.size() == 1 else "":
		"write":
			await _write()
		"read":
			await _read(false)
		"recover":
			await _read(true)
		"legacy":
			await _legacy()
		_:
			_expect(false, "Informe write, read, recover ou legacy.")
	if _failed:
		quit(1)


func _write() -> void:
	var sparse := {0: VoxelCatalog.AIR_KEY, 4095: STONE}
	var dense := {}
	for cell in range(1, VoxelChunkData.VOLUME):
		dense[cell] = STONE if cell % 2 == 0 else VoxelCatalog.AIR_KEY
	var packed := Codec.encode(dense)
	_expect(not Codec.encode(sparse).dense and Codec.decode(Codec.encode(sparse)) == sparse, "delta local inclui ar")
	_expect(packed.dense and Codec.decode(packed) == dense, "paleta compactada preserva células procedurais e ar")

	var save := _store.create_world("Verificação de persistência", str(SEED))
	if not _expect(save != null, "criação pela seleção de mundos") or not _launch(save.id):
		return
	await scene_changed
	var demo = current_scene
	demo.set_physics_process(false)
	demo._player.set_physics_process(false)
	var spawn: Vector3 = demo._player.global_position
	var origin := Vector3i(spawn.floor())
	var chunk := VoxelChunkData.chunk_of(origin)
	if not _expect(await _wait_for(func(): return demo._world.is_chunk_ready(chunk)), "streaming no spawn"):
		return
	var supports: Array[Vector3i] = []
	for offset: Vector3i in [Vector3i(2, 0, 0), Vector3i(0, 0, 2), Vector3i(-2, 0, 0), Vector3i(0, 0, -2), Vector3i(2, 0, 2)]:
		var column := origin + offset
		for y in range(origin.y + 3, maxi(1, origin.y - 4), -1):
			var support := Vector3i(column.x, y, column.z)
			if demo._world.can_plant_prop(support) and demo._props.definition_at(support) == null \
				and demo._world.block_definition_at(support).breakable != null:
				supports.append(support)
				break
	if not _expect(supports.size() >= 3, "três superfícies válidas perto do jogador"):
		return
	var hole := supports[0]
	var built := supports[1] + Vector3i.UP
	var plant := supports[2]
	var item := demo._items.find(FLOWER) as InventoryItem
	var old_timber: int = demo._inventory.count_at(0)
	await physics_frame
	demo._target.valid = true
	demo._target.cell = hole
	demo._mine_target(10.0)
	_place(demo, built, 0)
	_expect(demo._world.get_block_key(hole) == VoxelCatalog.AIR_KEY, "mineração pelo jogo")
	_expect(demo._world.get_block_key(built) == &"core:timber" and demo._inventory.count_at(0) == old_timber - 1,
		"construção pelo jogo consome item")
	_expect(demo._inventory.add(item, 2) == 2, "adiciona flores à bolsa")
	var flower_slot := _slot_of(demo._inventory, FLOWER)
	_expect(flower_slot >= 0 and (flower_slot == 8 or demo._inventory.move(flower_slot, 8) == 2), "organiza flores na Hotbar")
	_place(demo, plant + Vector3i.UP, 8)
	_expect(demo._world.planted_prop_at(plant) == FLOWER and demo._inventory.count_at(8) == 1, "planta entidade")
	_expect(demo._world.set_persistent_component_state(built, MACHINE, {"items": [FLOWER, 3]}), "estado esparso")

	demo._player.global_position = spawn + Vector3(112.0, 0.0, 0.0)
	var dirty_chunk := VoxelChunkData.chunk_of(built)
	var unloaded := func() -> bool:
		return demo._saves._commit.get("revision", 0) == 1 and not demo._world.is_chunk_ready(dirty_chunk)
	if not _expect(await _wait_for(unloaded), "descarregamento grava chunks sujos"):
		return

	demo.world_definition.autosave_interval = 0.05
	demo._player.global_position = spawn
	demo._player.hp = 43
	demo._hotbar.select(6)
	_expect(demo._crafting.enqueue(&"core:slab", 2) and demo._crafting.enqueue(&"core:fence"), "duas ordens de crafting")
	demo._crafting.advance(0.85)
	if not _expect(await _wait_for(func(): return demo._saves._commit.get("revision", 0) == 2), "autosave periódico"):
		return
	demo.world_definition.autosave_interval = 0.0
	var previous: Dictionary = demo._snapshot_player()
	demo._player.hp = 31
	demo._player.facing = Vector3.LEFT
	_expect(demo._world.set_persistent_component_state(built, MACHINE, {"items": [FLOWER, 5]}), "edita estado após autosave")
	var pig: Node3D = load("res://assets/core/Entities/pig.tscn").instantiate()
	demo._wildlife.add_child(pig)
	pig.global_position = spawn + Vector3(6.0, 0.0, 6.0)
	var expected := {"id": save.id, "previous": previous, "current": demo._snapshot_player(),
		"hole": hole, "built": built, "plant": plant}
	var file := FileAccess.open(EXPECTED, FileAccess.WRITE)
	if not _expect(file != null, "abre arquivo auxiliar de verificação"):
		return
	file.store_var(expected)
	file.close()
	if not _failed:
		print("OK: mineração, construção, plantio, descarga e autosave. Fechando pela notificação da janela.")
		demo.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		_expect(FileAccess.file_exists(save.storage_path().path_join("commit-1.dat")), "fechamento publica o save")


func _read(recovery: bool) -> void:
	var file := FileAccess.open(EXPECTED, FileAccess.READ)
	if not _expect(file != null, "execute write antes de read ou recover"):
		return
	var expected: Dictionary = file.get_var()
	file.close()
	var saves := _store.list_worlds()
	var save_index := saves.find_custom(func(save): return save.id == expected.id)
	if not _expect(save_index >= 0 and saves[save_index].seed == SEED, "mundo e seed no seletor"):
		return
	if recovery:
		var latest := saves[save_index].storage_path().path_join("commit-1.dat")
		var interrupted := FileAccess.open(latest, FileAccess.WRITE)
		if not _expect(interrupted != null, "simula a interrupção do último commit"):
			return
		interrupted.store_8(0)
		interrupted.close()
	if not _launch(expected.id):
		return
	await scene_changed
	var demo = current_scene
	demo.set_physics_process(false)
	demo._player.set_physics_process(false)
	demo._wildlife.set_physics_process(false)
	_expect(demo.active_world_seed == SEED, "seed restaurada")
	_expect(demo._saves._commit.revision == (2 if recovery else 3), "revisão esperada")
	_expect(demo._snapshot_player() == expected["previous" if recovery else "current"],
		"posição, direção, HP, slots, Hotbar, reserva e progresso da fila")
	_expect(demo._selected_item != null and demo._selected_item.id == &"core:pickaxe"
		and demo._active_equipment() != null, "picareta ativa restaurada")
	_expect(demo._wildlife.get_child_count() == 0, "porco temporário sem entrada persistente")
	var chunk := VoxelChunkData.chunk_of(expected.built)
	var ready := func() -> bool:
		return demo._world.is_chunk_ready(chunk) and demo._world.is_chunk_ready(VoxelChunkData.chunk_of(expected.hole))
	_expect(await _wait_for(ready), "regeneração dos chunks editados")
	_expect(demo._world.get_block_key(expected.hole) == VoxelCatalog.AIR_KEY, "buraco restaurado sobre o terreno regenerado")
	_expect(demo._world.get_block_key(expected.built) == &"core:timber", "bloco construído restaurado")
	_expect(demo._world.planted_prop_at(expected.plant) == FLOWER, "flor restaurada")
	var components: Dictionary = demo._world.persistent_component_states(expected.built)
	_expect(components.get(MACHINE) == {"items": [FLOWER, 3 if recovery else 5]}, "estado esparso pertence à revisão")
	var slab_slot := _slot_of(demo._inventory, &"core:slab")
	var before: int = demo._inventory.count_at(slab_slot)
	demo._crafting.advance(10.0)
	_expect(demo._crafting.orders().is_empty() and demo._inventory.count_at(slab_slot) == before + 4,
		"a fila continua e entrega exatamente o lote que falta")
	if not _failed:
		print("OK: ", "recuperação da revisão anterior" if recovery else "reabertura e retomada da fila")
		quit()


func _legacy() -> void:
	var save := _store.create_world("Verificação da migração", str(SEED))
	if not _expect(save != null, "cria mundo legado"):
		return
	var file := FileAccess.open(save.storage_path().path_join("state.dat"), FileAccess.WRITE)
	if not _expect(file != null, "abre arquivo legado"):
		return
	var position := Vector3(0.5, 6.1, 0.5)
	var hole := Vector3i(0, 3, -1)
	file.store_buffer(var_to_bytes([1, {"player": position, "hotbar": 0,
		"inventory": {0: [&"core:timber", 2]}, "craft_delivery": {&"core:timber": 1},
		"props": {}, "blocks": {hole: VoxelCatalog.AIR_KEY}}]))
	file.close()
	if not _launch(save.id):
		return
	await scene_changed
	var demo = current_scene
	_expect(demo._player.global_position == position and demo._inventory.count_at(0) == 3, "restaura entrega e jogador antigos")
	var coord := VoxelChunkData.chunk_of(hole)
	var index := VoxelChunkData.index_of(VoxelChunkData.local_of(hole))
	_expect(demo._world.export_persistent_chunk(coord).blocks.get(index) == VoxelCatalog.AIR_KEY, "restaura edição antiga")
	if not _expect(demo._save_and_exit().is_empty(), "salva e retorna ao menu principal"):
		return
	await scene_changed
	if not _launch(save.id):
		return
	await scene_changed
	demo = current_scene
	_expect(demo._saves._commit.get("revision", 0) == 1 and demo._inventory.count_at(0) == 3,
		"reabre o save migrado sem repetir a entrega")
	_expect(demo._world.export_persistent_chunk(coord).blocks.get(index) == VoxelCatalog.AIR_KEY,
		"reabre a edição pelo novo formato")
	if not _failed:
		print("OK: migração do formato legado, saída para o menu e reabertura")
		quit()


func _launch(id: String) -> bool:
	var error := _store.launch(self, id, GAME, SELECTOR)
	return _expect(error == OK, "abre mundo pelo seletor (%s)" % error_string(error))


func _place(demo: Node, cell: Vector3i, slot: int) -> void:
	demo._hotbar.select(slot)
	demo._target.adjacent = cell
	demo._target.can_place = true
	demo._place_target()


func _slot_of(inventory: SlotInventory, id: StringName) -> int:
	var slots := inventory.export_slots()
	for slot in slots:
		if slots[slot][0] == id:
			return slot
	return -1


func _wait_for(condition: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await process_frame
	return false


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		_failed = true
		printerr("FALHOU: ", message)
	return condition
