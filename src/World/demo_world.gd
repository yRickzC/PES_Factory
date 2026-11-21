extends "res://addons/ldk/core/World/world_session.gd"

# O inverso de cos(inclinação) mantém os pixels quadrados nos sprites verticais.
# Avatar e Canopy usam CAMERA_OFFSET.length() / CAMERA_OFFSET.z como escala em Y.
const Preferences = preload("res://addons/ldk/core/Settings/game_preferences.gd")

const CAMERA_OFFSET := Vector3(0, 27, 16.5)
const SPRINT_MODIFIERS: Array[StringName] = [&"core:sprint"]
const BUILD_MODIFIERS: Array[StringName] = [&"core:sprint", &"core:build_layer"]
const WEAPON_RETICLE: Texture2D = preload("res://assets/core/textures/weapon_reticle.tres")
const STARTING_ITEMS := [&"core:timber", &"core:slab", &"core:stairs", &"core:roof", &"core:fence", &"core:water"]
const Hotbar = preload("res://addons/ldk/core/Inventory/slot_hotbar.gd")
const InventorySettings = preload("res://addons/ldk/core/Inventory/inventory_settings.gd")
const HotbarConfig = preload("res://src/UI/hotbar_config.gd")
const CraftingQueue = preload("res://addons/ldk/core/Crafting/crafting_queue.gd")
const Mining = preload("res://addons/ldk/core/Voxel/Data/voxel_mining.gd")
const MiningConfig = preload("res://addons/ldk/core/Voxel/Data/voxel_mining_config.gd")
const ConstructionConfig = preload("res://addons/ldk/core/Voxel/Targeting/voxel_construction_config.gd")
const WorldPreset = preload("res://addons/ldk/core/World/world_definition.gd")
const EnvironmentView = preload("res://addons/ldk/core/World/world_environment_view.gd")
const WorldSaves = preload("res://addons/ldk/core/World/world_save_store.gd")
const SaveManager = preload("res://addons/ldk/core/World/save_manager.gd")
const PauseMenu = preload("res://src/UI/Menu/pause_menu.gd")
const MAIN_MENU := "res://src/UI/Menu/main_menu.tscn"

@export_group("Preset do mundo")
## Preset usado para iniciar a partida, com regras de geração, ambiente, física e ponto inicial.
@export var world_definition: WorldPreset

@export_group("Interação com o terreno")
## Ajusta o alcance, a mira, o destaque do alvo e a aparência da prévia de bloco.
@export var targeting: VoxelTargetingConfig = preload("res://assets/core/Settings/block_targeting.tres")
## Ajusta a mira e o alcance da construção por camada enquanto seu atalho estiver pressionado.
@export var construction: ConstructionConfig = preload("res://assets/core/Settings/block_construction.tres")
## Ajusta a velocidade de mineração e a recuperação do dano em blocos e objetos.
@export var mining_config: MiningConfig = preload("res://assets/core/Settings/block_mining.tres")

@export_group("Inventário e barra rápida")
## Define quantos slots o jogador tem na bolsa e na barra rápida.
@export var inventory_settings: InventorySettings = preload("res://src/UI/inventory_settings.tres")
## Ajusta o visual e a posição da barra de acesso rápido.
@export var hotbar_config: HotbarConfig = preload("res://src/UI/hotbar.tres")

var active_world_seed: int
var _inventory: SlotInventory
var _hotbar: Hotbar
var _crafting: CraftingQueue
var _mining: Mining
var _prop_mining: Mining
var _last_mined_cell := Vector3i.ZERO
var _target := VoxelTargeting.new()
var _target_view := VoxelTargetView.new()
var _cutaway := VoxelCutawayView.new()
var _catalog: VoxelCatalog
var _items: ContentRegistry
var _entities: ContentRegistry
var _placement: VoxelBiomePlacement
var _place_requested := false
var _place_on_layer := false
var _place_screen := Vector2.ZERO
var _layer_construction_active := false
var _mine_pressed := false
var _mine_held := false
var _mine_hit_prop := false
var _attack_screen := Vector2.ZERO
var _selected_item: InventoryItem
var _attack_cell := Vector3i.ZERO
var _attack_target: Resource
var _attack_hits_prop := false
var _pending_impact: EquipmentAction
var _pending_melee: MeleeWeapon
var _pending_window := Vector2.ZERO
var _melee_heading := Vector3.ZERO
var _melee_hits: Dictionary[int, bool] = {}
var _melee_buffer := 0.0
var _save_read_error := false
var _saves: SaveManager
var _autosave_elapsed := 0.0
var _owns_quit := false
var _avatar_height: float
var _avatar_anchor: Vector3
@onready var _world: VoxelWorld = $World
@onready var _props: VoxelPropView = $World/Props
@onready var _wildlife: WildlifePopulation = $World/Wildlife
@onready var _player: DemoVoxelPlayer = $Player
@onready var _avatar: Sprite3D = $Player/Avatar
@onready var _camera: Camera3D = $Camera3D
@onready var _bag: DemoInventoryView = $Inventory
@onready var _environment_view: EnvironmentView = $Environment


func prepare_persistence() -> Error:
	if world_definition == null:
		world_definition = WorldPreset.new()
	var manager := SaveManager.new()
	var result := manager.open(world_save, world_definition.save_id, world_definition.generator_version)
	if result == OK:
		_saves = manager
	return result


func _ready() -> void:
	if world_definition == null:
		world_definition = WorldPreset.new()
	var environment := world_definition.environment
	_environment_view.configure(environment if environment != null else WorldPreset.EnvironmentSettings.new(), $Sun)
	var physics := world_definition.physics
	if physics == null:
		physics = WorldPreset.PhysicsSettings.new()
	var space := get_world_3d().space
	PhysicsServer3D.area_set_param(space, PhysicsServer3D.AREA_PARAM_GRAVITY, physics.gravity)
	PhysicsServer3D.area_set_param(space, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR, Vector3.DOWN)
	_player.configure_movement(physics)
	var content := DemoContent.load_content()
	if content == null:
		set_process_input(false)
		set_process_unhandled_input(false)
		set_physics_process(false)
		return
	_items = content.items
	_entities = content.entities
	var tiles := content.bake_tiles()
	_catalog = content.block_catalog(DemoContent.MISSING_BLOCK)
	active_world_seed = choose_world_seed(world_definition)
	print("Seed do mundo: %d" % active_world_seed)
	var generator := _create_generator(content)
	generator.world_seed = active_world_seed
	var materials := DemoVoxelMaterials.create(tiles.layers, _catalog, active_world_seed)
	_world.configure(generator, _catalog, materials)
	_mining = Mining.new(mining_config.recovery_delay, mining_config.recovery_seconds, mining_config.expire_after)
	_prop_mining = Mining.new(mining_config.recovery_delay, mining_config.recovery_seconds, mining_config.expire_after)
	_world.blocks_changed.connect(_mining.forget_cells)
	_world.chunk_unloaded.connect(_mining.forget_chunk)
	_world.add_child(_cutaway)
	add_child(_target_view)
	var blur := DemoVoxelMaterials.create_cutaway(materials[0] as ShaderMaterial)
	_target_view.configure(targeting, _cutaway.configure(_world, materials, blur), _world, tiles.layers)
	_target.configure(1, 4, [_player.get_rid()], WildlifePopulation.COLLISION_LAYER)
	_placement = _create_placement(generator, content)
	_props.configure(_world, _placement.for_chunk, _placement.instantiate, content.texture, _entities.find, _cutaway)
	_props.prop_removed.connect(_prop_mining.forget_cell)
	_player.spawn_point = _find_spawn(generator, _placement)
	_player.respawn()
	_player.world = _world
	_world.follow_target = _player
	_wildlife.configure(_world, generator, _player, _entities, content.texture)
	var settings := inventory_settings if inventory_settings != null else InventorySettings.new()
	_inventory = SlotInventory.new(settings.total_size())
	_hotbar = Hotbar.new(_inventory, settings.hot_bar_size)
	_crafting = CraftingQueue.new(_inventory, content.items, content.recipes)
	if not _load_world_state():
		for id in STARTING_ITEMS:
			_inventory.add(content.items.find(id) as InventoryItem, 8)
		_inventory.add(content.items.find(&"core:pickaxe") as InventoryItem, 1)
		_inventory.add(content.items.find(&"core:sword") as InventoryItem, 1)
	if not _save_read_error:
		_world.persistence_changed.connect(_on_persistent_chunk_changed)
		_world.chunk_unloaded.connect(_on_persistent_chunk_unloaded)
	_camera.look_at_from_position(_avatar.global_position + CAMERA_OFFSET, _avatar.global_position)
	_avatar_height = _player.configure_avatar(content.texture(&"core:explorer"), CAMERA_OFFSET)
	_avatar_anchor = _avatar.position
	$Player/Shadow.texture = content.texture(&"core:shadow")
	_sync_equipment()
	_inventory.changed.connect(_sync_equipment)
	_hotbar.selection_changed.connect(_sync_equipment.bind(true))
	_player.attack_impact.connect(_queue_impact)
	_player.attack_window.connect(_queue_melee_window)
	_bag.configure(_inventory, content.texture, _hotbar, hotbar_config)
	_bag.configure_crafting(_crafting, content.items, content.crafting_tags)
	_bag.open_changed.connect(_on_bag_open_changed)
	var pause_menu := PauseMenu.new()
	pause_menu.open_changed.connect(_on_pause_open_changed)
	pause_menu.save_and_exit = _save_and_exit
	add_child(pause_menu)
	_owns_quit = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false
	_sync_cursor()


func _exit_tree() -> void:
	if _saves != null:
		_saves.wait_for_write()
	if _owns_quit:
		get_tree().auto_accept_quit = true
	if DisplayServer.get_name() != "headless":
		Input.set_custom_mouse_cursor(null)
	_set_cursor_visible(true)


func _load_world_state() -> bool:
	if world_save == null:
		return false
	if _saves == null and prepare_persistence() != OK:
		_save_read_error = true
		return false
	var state := _saves.take_initial_state()
	if state.is_empty():
		return false
	var restored := _restore_legacy_state(state.legacy) if state.has("legacy") else _restore_world_state(state)
	if not restored:
		_save_read_error = true
		_inventory.restore_slots({}, _items)
		_report_save_error("O progresso deste mundo não pôde ser restaurado. Confira se os itens e receitas do save estão disponíveis.")
		return false
	return true


func _restore_world_state(state: Dictionary) -> bool:
	var player: Dictionary = state.player
	var facing: Variant = player.get("facing")
	var hp: Variant = player.get("hp")
	if not _valid_player_state(player.get("position"), player.get("hotbar")):
		return false
	if not facing is Vector3 or not facing.is_finite() or not hp is int or hp < 0 or hp > _player.max_hp:
		return false
	if not player.get("inventory") is Dictionary or not player.get("crafting") is Dictionary:
		return false
	if not _inventory.restore_slots(player.inventory, _items) or not _crafting.restore_state(player.crafting):
		return false
	for coord: Vector3i in state.chunks:
		_world.restore_persistent_chunk(coord, state.chunks[coord])
	_player.global_position = player.position
	_player.facing = facing
	_player.hp = hp
	_hotbar.select(player.hotbar)
	return true


func _restore_legacy_state(state: Dictionary) -> bool:
	if not _valid_player_state(state.get("player"), state.get("hotbar")):
		return false
	for field in ["blocks", "props", "inventory", "craft_delivery"]:
		if not state.get(field) is Dictionary:
			return false
	if not _inventory.restore_slots(state.inventory, _items) or not _crafting.restore_delivery(state.craft_delivery):
		return false
	if not _world.restore_prop_edits(state.props) or not _world.restore_block_edits(state.blocks, DemoContent.LEGACY_BLOCKS):
		_crafting.restore_delivery({})
		_world.restore_prop_edits({})
		return false
	_player.global_position = state.player
	_hotbar.select(state.hotbar)
	_mark_existing_chunks()
	return true


func _valid_player_state(position: Variant, slot: Variant) -> bool:
	return position is Vector3 and position.is_finite() and slot is int and (
		slot == -1 if _hotbar.size() == 0 else slot >= 0 and slot < _hotbar.size()
	)


func _on_persistent_chunk_changed(coord: Vector3i) -> void:
	if _saves != null:
		_saves.mark_dirty(coord)


func _on_persistent_chunk_unloaded(coord: Vector3i) -> void:
	if _saves != null and world_definition.save_on_chunk_unload:
		_saves.flush_on_unload(coord)


func _mark_existing_chunks() -> void:
	for coord in _world.persistent_chunk_coords():
		_saves.mark_dirty(coord)


func _snapshot_player() -> Dictionary:
	return {
		"position": _player.global_position,
		"facing": _player.facing,
		"hp": _player.hp,
		"inventory": _inventory.export_slots(),
		"hotbar": _hotbar.active_slot(),
		"crafting": _crafting.export_state(),
	}


func _process(delta: float) -> void:
	if _saves == null or _save_read_error:
		return
	var interval := world_definition.autosave_interval
	if interval > 0.0:
		_autosave_elapsed += delta
		if _autosave_elapsed >= interval:
			_autosave_elapsed = 0.0
			_saves.request_flush()
	var error := _saves.process(_world.export_persistent_chunk, _snapshot_player)
	if error != OK:
		_report_save_error("Falha no salvamento automático. %s" % error_string(error))


func _flush_world_save() -> String:
	if _save_read_error:
		return "O progresso existente não pôde ser lido e foi preservado."
	if world_save == null:
		var store := WorldSaves.new()
		world_save = store.create_world("Mundo %d" % active_world_seed, str(active_world_seed))
		if world_save == null:
			return "Não foi possível criar o save do mundo."
	if _saves == null:
		var error := prepare_persistence()
		if error != OK:
			return "Não foi possível abrir o save do mundo. %s" % error_string(error)
		_mark_existing_chunks()
	var result := _saves.flush(_world.export_persistent_chunk, _snapshot_player)
	if result != OK:
		return "Não foi possível salvar o mundo. %s" % error_string(result)
	return ""


func _save_and_exit() -> String:
	if _save_read_error:
		# Returning to the selector remains possible after an incompatible mod update.
		get_tree().change_scene_to_file(world_selection_path if not world_selection_path.is_empty() else MAIN_MENU)
		return ""
	var error := _flush_world_save()
	if not error.is_empty():
		return error
	var result := get_tree().change_scene_to_file(MAIN_MENU)
	return "" if result == OK else "Mundo salvo. Não foi possível abrir o menu principal."


func _report_save_error(message: String) -> void:
	push_warning(message)
	if DisplayServer.get_name() != "headless":
		var dialog := AcceptDialog.new()
		dialog.process_mode = Node.PROCESS_MODE_ALWAYS
		dialog.dialog_text = message
		dialog.confirmed.connect(dialog.queue_free)
		dialog.canceled.connect(dialog.queue_free)
		add_child(dialog)
		dialog.popup_centered()


func _create_generator(content: ContentDB) -> DemoVoxelGenerator:
	return DemoVoxelGenerator.new(content, _catalog, world_definition.generation)


func _create_placement(generator: DemoVoxelGenerator, content: ContentDB) -> VoxelBiomePlacement:
	return VoxelBiomePlacement.new(generator, content)


func _find_spawn(generator: DemoVoxelGenerator, placement: VoxelBiomePlacement) -> Vector3:
	var props_by_chunk: Dictionary[Vector3i, Dictionary] = {}
	var origin := world_definition.spawn_origin
	# Check the nearest tiles first, sampling props once per visited chunk.
	for distance in range(world_definition.spawn_search_radius + 1):
		for dx in range(-distance, distance + 1):
			var dz := distance - absi(dx)
			for side in (1 if dz == 0 else 2):
				var cell := origin + Vector2i(dx, dz * (1 - 2 * side))
				var column := generator.sample_column(cell.x, cell.y)
				if generator.column_is_flooded(column):
					continue
				var support := Vector3i(cell.x, column.x, cell.y)
				var chunk := VoxelChunkData.chunk_of(support)
				if not props_by_chunk.has(chunk):
					props_by_chunk[chunk] = placement.for_chunk(chunk)
				var prop := props_by_chunk[chunk].get(support) as ContentScene
				if prop == null or prop.collision == null:
					return Vector3(support) + Vector3(0.5, 1.1, 0.5)
	var column := generator.sample_column(origin.x, origin.y)
	var height := generator.water_level if generator.column_is_flooded(column) else column.x
	return Vector3(origin.x + 0.5, height + 1.1, origin.y + 0.5)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventMouseButton):
		return
	if Preferences.current.released(event, &"core:mine"):
		_mine_held = false
	if not event.is_pressed() and not Preferences.current.held(&"core:build_layer"):
		_end_construction()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_clear_pending_actions()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST and _owns_quit:
		var error := _flush_world_save() if not _save_read_error else ""
		if error.is_empty():
			get_tree().quit()
		else:
			_report_save_error(error)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventMouseButton):
		return
	if _bag.handle_hotbar_shortcut(event):
		get_viewport().set_input_as_handled()
		return
	if _bag.is_open():
		return
	var building: bool = construction != null and Preferences.current.held(&"core:build_layer")
	if Preferences.current.pressed(event, &"core:respawn"):
		_clear_pending_actions()
		_player.respawn()
	elif Preferences.current.pressed(event, &"core:zoom_in"):
		_camera.size = clampf(_camera.size - 1.0, 12.0, 26.0)
	elif Preferences.current.pressed(event, &"core:zoom_out"):
		_camera.size = clampf(_camera.size + 1.0, 12.0, 26.0)
	elif not building and Preferences.current.pressed_with_held_modifiers(event, &"core:mine", SPRINT_MODIFIERS):
		_mine_held = true
		_mine_pressed = true
		_mine_hit_prop = false
		var click := event as InputEventMouseButton
		_attack_screen = click.position if click != null else get_viewport().get_mouse_position()
	elif Preferences.current.pressed_with_held_modifiers(
		event, &"core:place", BUILD_MODIFIERS if building else SPRINT_MODIFIERS
	):
		_place_requested = true
		_place_on_layer = building
		var mouse_event := event as InputEventMouseButton
		_place_screen = mouse_event.position if mouse_event != null else get_viewport().get_mouse_position()
	else:
		return
	get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if _crafting.is_running():
		_crafting.advance(delta)
	_camera.global_position = _player.to_global(_avatar_anchor) + CAMERA_OFFSET
	_update_camera_shake()
	_cutaway.update_view(_player.global_position, CAMERA_OFFSET, 1.36, _avatar_height, delta)
	var enabled := not _bag.is_open()
	var constructing: bool = construction != null and enabled and Preferences.current.held(&"core:build_layer")
	_mine_held = _mine_held and Preferences.current.held(&"core:mine")
	var place := _place_requested and _place_on_layer == constructing
	var equipment := _active_equipment()
	var weapon := equipment.action as MeleeWeapon if equipment != null else null
	var screen := _place_screen if place else get_viewport().get_mouse_position()
	var facing_aim := targeting.aim_mode == VoxelTargetingConfig.AimMode.FACING
	if constructing:
		var feet := _world.to_local(_player.global_position)
		var player_cell := Vector3i(feet.floor())
		player_cell.y = floori(feet.y + 0.025)
		if facing_aim and construction.aim_mode == ConstructionConfig.AimMode.INHERIT_TARGETING:
			var forward_cell := player_cell + Vector3i(_player.facing)
			var layer_point := Vector3(forward_cell) + Vector3(0.5, construction.cursor_plane_height, 0.5)
			screen = _camera.unproject_position(_world.to_global(layer_point))
		var ray := _camera.project_ray_normal(screen)
		_target.pick_layer(_world, _camera.project_ray_origin(screen), ray,
			_player.global_position, player_cell.y, construction)
		_layer_construction_active = true
		_mine_held = false
	else:
		_end_construction()
		if enabled and weapon == null:
			if facing_aim:
				screen = _camera.unproject_position(_player.global_position + _player.facing * targeting.facing_distance)
			_pick_target(screen)
		elif weapon != null:
			_target.clear()
	if constructing or not enabled:
		_cancel_attack()
		if equipment != null:
			_mine_held = false
	else:
		_resolve_impact(delta)
		_resolve_melee()
	if enabled:
		if place:
			_place_target()
		elif not constructing:
			if weapon != null:
				_use_melee_input(weapon, delta)
			elif _mine_pressed or _mine_held:
				_use_mining_input(equipment, delta)
	_place_requested = false
	_mine_pressed = false
	_mining.advance_time(delta)
	_prop_mining.advance_time(delta)
	_target_view.update_target(_target, screen, enabled and weapon == null)
	var progress := _mining.progress(_target.cell) if enabled and _target.valid else 0.0
	if progress > 0.0:
		_target_view.update_mining_progress(_target.cell, progress)
	else:
		_target_view.update_mining_progress(_last_mined_cell, _mining.progress(_last_mined_cell))
	if enabled and _target.prop_valid:
		var support := _target.prop_support
		_highlight_prop(support, _prop_mining.progress(support))
	else:
		_props.set_highlight(null)
	var show_preview: bool = enabled and not _mine_held and not _player.is_attacking() \
		and progress == 0.0 and Preferences.current.option(&"placement_preview")
	var item := _placement_item() if show_preview else null
	var cell := _target.adjacent
	var block: VoxelCatalog.BakedBlock
	var entity: ContentScene
	if item != null:
		if item.entity_id.is_empty():
			block = _catalog.block(_catalog.id_for(item.block_id))
		else:
			entity = _entities.find(item.entity_id) as ContentScene
	_target_view.update_preview(cell, block, _world.connections_at(cell, block) if block != null else 0)
	_props.show_placement_preview(cell, entity, targeting.preview_opacity)
	_target_view.update_range_grid(_target, _camera, enabled and weapon == null)


func _update_camera_shake() -> void:
	var shake := _player.camera_shake_pixels()
	if not shake.is_zero_approx():
		var viewport_size := _camera.get_viewport().get_visible_rect().size
		var extent := viewport_size.x if _camera.keep_aspect == Camera3D.KEEP_WIDTH else viewport_size.y
		shake *= _camera.size / maxf(extent, 1.0)
	if _camera.h_offset != shake.x:
		_camera.h_offset = shake.x
	if _camera.v_offset != shake.y:
		_camera.v_offset = shake.y


func _pick_target(screen: Vector2) -> void:
	var actor := _player.global_position + Vector3.UP * targeting.interaction_height
	_target.pick(get_world_3d().direct_space_state, _world, _camera.project_ray_origin(screen),
		_camera.project_ray_normal(screen), actor, targeting, _cutaway.is_hidden, _props, _camera.far)


func _active_equipment() -> HandEquipment:
	return _selected_item.equipment if _selected_item != null else null


func _sync_equipment(slot_changed := false) -> void:
	var item := _hotbar.active_item()
	if item == _selected_item and not slot_changed:
		return
	var old_equipment := _selected_item.equipment if _selected_item != null else null
	var equipment := item.equipment if item != null else null
	_selected_item = item
	if old_equipment != null or equipment != null:
		_cancel_attack()
		_mine_held = false
		_mine_pressed = false
	_player.set_equipment(equipment)
	_sync_cursor()


func _use_mining_input(equipment: HandEquipment, delta: float) -> void:
	if equipment == null:
		_mine_target(delta)
		return
	var action := equipment.action
	if action == null or (not _mine_pressed and not action.repeat_while_held):
		return
	if _player.try_attack():
		_attack_hits_prop = _target.prop_valid
		_attack_cell = _target.prop_support if _attack_hits_prop else _target.cell
		_attack_target = _aimed_definition()


func _aimed_definition() -> Resource:
	if _target.prop_valid:
		return _props.definition_at(_target.prop_support)
	return _world.block_definition_at(_target.cell) if _target.valid else null


func _use_melee_input(weapon: MeleeWeapon, delta: float) -> void:
	if _mine_pressed:
		_melee_buffer = weapon.input_buffer_seconds
	if _player.in_hitstop():
		return
	var clicked := _mine_pressed or _melee_buffer > 0.0
	_melee_buffer = maxf(0.0, _melee_buffer - delta)
	if _player.is_attacking() or (not clicked and not (_mine_held and weapon.repeat_while_held)):
		return
	var screen := _attack_screen if clicked else get_viewport().get_mouse_position()
	var heading := _target.aim_melee(
		get_world_3d().direct_space_state, _camera.project_ray_origin(screen),
		_camera.project_ray_normal(screen), _player.global_position, _player.facing, weapon
	)
	if _player.try_attack(heading):
		_melee_heading = heading
		_melee_hits.clear()
		_melee_buffer = 0.0


func _queue_impact(action: EquipmentAction) -> void:
	# The actor ticks before the session updates the camera and resolves targeting.
	if action is VoxelMiningTool:
		_pending_impact = action


func _queue_melee_window(action: EquipmentAction, first: float, last: float) -> void:
	if action is MeleeWeapon:
		_pending_melee = action
		_pending_window = Vector2(first, last)


func _resolve_melee() -> void:
	var weapon := _pending_melee
	_pending_melee = null
	if weapon == null:
		return
	var origin := _player.global_position
	var contacts := _target.melee_hits(
		get_world_3d().direct_space_state, origin, _melee_heading, weapon, _pending_window, _melee_hits
	)
	var confirmed := false
	for contact in contacts:
		var body: CollisionObject3D = contact.body
		_melee_hits[body.get_instance_id()] = true
		if body.call(&"take_damage", weapon.damage, origin):
			_player.show_melee_hit(contact.position)
			confirmed = true
	if confirmed:
		_player.confirm_melee_hit(weapon, _melee_heading)
		_update_camera_shake()


func _resolve_impact(delta: float) -> void:
	if _pending_impact == null:
		return
	var action := _pending_impact as VoxelMiningTool
	var definition := _attack_target
	_pending_impact = null
	_attack_target = null
	if action == null or definition == null:
		return
	var cell := _target.prop_support if _target.prop_valid else _target.cell
	if cell == _attack_cell and _target.prop_valid == _attack_hits_prop and _aimed_definition() == definition:
		_mine_target(delta, action.work_per_impact / delta)


func _cancel_attack() -> void:
	_pending_impact = null
	_attack_target = null
	_pending_melee = null
	_melee_hits.clear()
	_melee_buffer = 0.0
	_player.cancel_attack()


func _highlight_prop(support: Vector3i, progress: float) -> void:
	var stages := maxi(1, targeting.mining_stages)
	var stage := ceili(progress * stages)
	var tint := Color.WHITE.lerp(targeting.color, targeting.opacity * targeting.color.a)
	var strength := float(stage) / stages * targeting.mining_opacity * targeting.mining_color.a
	tint = tint.lerp(targeting.mining_color, strength)
	tint.a = 1.0
	_props.set_highlight(support, tint)


func _on_bag_open_changed(open: bool) -> void:
	_player.input_enabled = not open
	_clear_pending_actions()
	_sync_cursor()


func _on_pause_open_changed(open: bool) -> void:
	if open:
		_clear_pending_actions()
	_sync_cursor()


func _sync_cursor() -> void:
	var menu_open := _bag.is_open() or get_tree().paused
	var equipment := _active_equipment()
	var armed := not menu_open and equipment != null and equipment.action is MeleeWeapon
	if DisplayServer.get_name() != "headless":
		var hotspot := Vector2(8, 8) if armed else Vector2.ZERO
		Input.set_custom_mouse_cursor(WEAPON_RETICLE if armed else null, Input.CURSOR_ARROW, hotspot)
	_set_cursor_visible(menu_open or armed)


func _set_cursor_visible(visible_cursor: bool) -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible_cursor else Input.MOUSE_MODE_HIDDEN


func _clear_pending_actions() -> void:
	_place_requested = false
	_mine_pressed = false
	_mine_held = false
	_mine_hit_prop = false
	if _player != null:
		_cancel_attack()
	if _props != null:
		_props.show_placement_preview(Vector3i.ZERO, null, 0.0)
	_end_construction()


func _end_construction() -> void:
	if _layer_construction_active:
		_layer_construction_active = false
		_target_view.update_preview(Vector3i.ZERO)


func _mine_prop(delta: float, speed: float) -> void:
	var support := _target.prop_support
	var definition := _props.definition_at(support)
	if definition == null or definition.breakable == null:
		return
	if _prop_mining.strike(support, delta, definition.breakable.duration(), speed) < 1.0:
		return
	if _world.mark_prop_removed(support):
		_collect_drops(definition.drops)
		_target.prop_valid = false
	else:
		_prop_mining.forget_cell(support)


func _mine_target(delta: float, effort_multiplier := 1.0) -> void:
	if not _target.prop_valid and (not _target.valid or _mine_hit_prop):
		return
	var tool := _hotbar.active_item()
	var speed := mining_config.base_speed * effort_multiplier * (tool.mining_speed_multiplier if tool != null else 1.0)
	if _target.prop_valid:
		# Holding the button after a prop disappears must not start digging through its support.
		_mine_hit_prop = true
		_mine_prop(delta, speed)
		return
	var struck := _target.cell
	var block := _world.block_definition_at(struck)
	if block == null or block.breakable == null:
		return
	var progress := _mining.strike(struck, delta, block.breakable.duration(), speed)
	if progress > 0.0:
		_last_mined_cell = struck
	if progress < 1.0:
		return
	if _world.set_block_key(struck, VoxelCatalog.AIR_KEY):
		_collect_drops(block.drops)
		_target.valid = false
	else:
		_mining.forget_cell(struck)


func _collect_drops(drops: ContentDrops) -> void:
	if drops == null:
		return
	var stacks: Dictionary[InventoryItem, int] = {}
	for id in drops.items:
		var item := _items.find(id) as InventoryItem
		if item != null:
			var quantity := drops.quantity_for(id)
			if quantity > 0:
				stacks[item] = quantity
	if not stacks.is_empty():
		_inventory.add_items(stacks)


func _place_target() -> void:
	var item := _placement_item()
	if item == null:
		return
	var cell := _target.adjacent
	var placed := _world.set_block_key(cell, item.block_id) if item.entity_id.is_empty() \
		else _world.plant_prop(cell + Vector3i.DOWN, item.entity_id)
	if placed:
		_inventory.remove(_hotbar.active_slot(), 1)


func _placement_item() -> InventoryItem:
	if _target.prop_valid or not _target.can_place:
		return null
	var item := _hotbar.active_item()
	if item == null:
		return null
	var cell := _target.adjacent
	var support := cell + Vector3i.DOWN
	if item.entity_id.is_empty():
		if _catalog.id_for(item.block_id) <= 0 or not _world.is_chunk_ready(VoxelChunkData.chunk_of(cell)) or not _world.can_edit(cell):
			return null
		var current := _world.get_block_key(cell)
		if current == ContentRegistry.normalize_id(item.block_id) or current not in [VoxelCatalog.AIR_KEY, &"core:water"]:
			return null
		if not _world.planted_prop_at(support).is_empty() and _props.definition_at(support) != null:
			return null
	else:
		var definition := _entities.find(item.entity_id) as ContentScene
		if not item.block_id.is_empty() or definition == null or not definition.has_batched_visual():
			return null
		if not _world.can_plant_prop(support) or _props.definition_at(support) != null:
			return null
	var block_bounds := AABB(Vector3(cell), Vector3.ONE)
	var player_bounds := AABB(
		_world.to_local(_player.global_position) - Vector3(0.29, 0.04, 0.29), Vector3(0.58, 1.45, 0.58)
	)
	if block_bounds.intersects(player_bounds):
		return null
	if not _target.placement_clear(get_world_3d().direct_space_state, _world, cell):
		return null
	return item
