extends RefCounted
## Catalog, metadata persistence and launch for independently stored worlds.

const Save = preload("res://addons/ldk/core/World/world_save.gd")
const Session = preload("res://addons/ldk/core/World/world_session.gd")
const Preset = preload("res://addons/ldk/core/World/world_definition.gd")

const METADATA_FILE := "world.cfg"
const ACCESS_FILE := "access.dat"
const ACCESS_RECORD_BYTES := 8
const SECTION := "world"
const FORMAT_VERSION := 1
const MAX_NAME_LENGTH := 48
const ID_BYTES := 16

var last_error: Error = OK
var skipped_worlds := 0


func list_worlds() -> Array[Save]:
	var worlds: Array[Save] = []
	skipped_worlds = 0
	last_error = DirAccess.make_dir_recursive_absolute(Save.ROOT)
	if last_error != OK:
		return worlds
	var directory := DirAccess.open(Save.ROOT)
	if directory == null:
		last_error = DirAccess.get_open_error()
		return worlds
	for id in directory.get_directories():
		if not _is_world_id(id) or directory.is_link(id):
			continue
		var world := _read_metadata(id)
		if world == null:
			skipped_worlds += 1
			continue
		worlds.append(world)
	worlds.sort_custom(_more_recent)
	return worlds


func create_world(world_name: String, seed_input: String) -> Save:
	var clean_name := world_name.strip_edges()
	if clean_name.is_empty() or clean_name.length() > MAX_NAME_LENGTH:
		last_error = ERR_INVALID_PARAMETER
		return null

	var seed_text := seed_input.strip_edges()
	var seed: int
	if seed_text.is_empty():
		seed = Preset.random_seed()
	else:
		if not seed_text.is_valid_int():
			last_error = ERR_INVALID_DATA
			return null
		seed = seed_text.to_int()
		if seed < Preset.MIN_SEED or seed > Preset.MAX_SEED:
			last_error = ERR_INVALID_DATA
			return null

	last_error = DirAccess.make_dir_recursive_absolute(Save.ROOT)
	if last_error != OK:
		return null
	var crypto := Crypto.new()
	var created_at := _now()
	for _attempt in range(3):
		var id := crypto.generate_random_bytes(ID_BYTES).hex_encode()
		if not _is_world_id(id):
			last_error = ERR_CANT_CREATE
			return null
		var world := Save.new(id, clean_name, seed, created_at)
		last_error = DirAccess.make_dir_absolute(world.storage_path())
		if last_error == ERR_ALREADY_EXISTS:
			continue
		if last_error != OK:
			return null

		var config := ConfigFile.new()
		config.set_value(SECTION, "version", FORMAT_VERSION)
		config.set_value(SECTION, "id", world.id)
		config.set_value(SECTION, "name", world.display_name)
		config.set_value(SECTION, "seed", world.seed)
		config.set_value(SECTION, "created_at", world.created_at)
		last_error = _write_metadata(world, config)
		if last_error != OK:
			DirAccess.remove_absolute(world.storage_path())
			return null
		return world
	return null


func launch(tree: SceneTree, world_id: String, gameplay_path: String, selection_path: String) -> Error:
	var directory := DirAccess.open(Save.ROOT)
	if directory == null or not _is_world_id(world_id) or directory.is_link(world_id):
		return ERR_FILE_NOT_FOUND
	var world := _read_metadata(world_id)
	if world == null:
		return ERR_FILE_CORRUPT

	var packed_scene := ResourceLoader.load(gameplay_path, "PackedScene") as PackedScene
	if packed_scene == null:
		return ERR_CANT_OPEN
	var instance := packed_scene.instantiate()
	if not instance is Session:
		if instance != null:
			instance.free()
		return ERR_CANT_CREATE
	var session := instance as Session

	session.world_save = world
	session.world_selection_path = selection_path
	var error := session.prepare_persistence()
	if error != OK:
		session.free()
		return error
	world.last_accessed_at = _now()
	error = _record_access(world)
	if error == OK:
		error = tree.change_scene_to_node(session)
	if error != OK:
		session.free()
	return error


func _read_metadata(id: String) -> Save:
	var path := Save.ROOT.path_join(id).path_join(METADATA_FILE)
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return null
	if config.get_value(SECTION, "version", 0) != FORMAT_VERSION:
		return null
	if config.get_value(SECTION, "id", "") != id:
		return null
	var world_name: Variant = config.get_value(SECTION, "name", "")
	var seed: Variant = config.get_value(SECTION, "seed", "")
	var created: Variant = config.get_value(SECTION, "created_at", -1)
	if not world_name is String or world_name.strip_edges().is_empty() or world_name.length() > MAX_NAME_LENGTH:
		return null
	if not seed is int or seed < Preset.MIN_SEED or seed > Preset.MAX_SEED:
		return null
	if not created is int or created <= 0:
		return null
	var world := Save.new(id, world_name, seed, created)
	world.last_accessed_at = _read_last_access(world)
	return world


func _write_metadata(world: Save, config: ConfigFile) -> Error:
	var path := world.storage_path().path_join(METADATA_FILE)
	var pending := path + ".tmp"
	var file := FileAccess.open(pending, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var expected := config.encode_to_text().to_utf8_buffer()
	var stored := file.store_buffer(expected)
	file.close()

	var error := ERR_FILE_CANT_WRITE
	if stored and FileAccess.get_file_as_bytes(pending) == expected:
		error = DirAccess.rename_absolute(pending, path)
	if error != OK:
		DirAccess.remove_absolute(pending)
	return error


func _read_last_access(world: Save) -> int:
	var file := FileAccess.open(world.storage_path().path_join(ACCESS_FILE), FileAccess.READ)
	if file == null:
		return 0
	var length := file.get_length()
	var complete_length := length - length % ACCESS_RECORD_BYTES
	if complete_length == 0:
		return 0
	file.seek(complete_length - ACCESS_RECORD_BYTES)
	return maxi(0, file.get_64())


func _record_access(world: Save) -> Error:
	# Append fixed-size timestamps so a partial write leaves the previous access readable.
	var path := world.storage_path().path_join(ACCESS_FILE)
	var file := FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null and FileAccess.get_open_error() == ERR_FILE_NOT_FOUND:
		file = FileAccess.open(path, FileAccess.WRITE_READ)
	if file == null:
		return FileAccess.get_open_error()
	var length := file.get_length()
	file.seek(length - length % ACCESS_RECORD_BYTES)
	var stored := file.store_64(world.last_accessed_at)
	file.close()
	return OK if stored else ERR_FILE_CANT_WRITE


static func _is_world_id(id: String) -> bool:
	return id.length() == ID_BYTES * 2 and id.is_valid_hex_number() and not id.begins_with("-") and not id.begins_with("+")


static func _now() -> int:
	return maxi(1, int(Time.get_unix_time_from_system()))


static func _more_recent(a: Save, b: Save) -> bool:
	if a.last_accessed_at != b.last_accessed_at:
		return a.last_accessed_at > b.last_accessed_at
	if a.created_at != b.created_at:
		return a.created_at > b.created_at
	return a.id < b.id
