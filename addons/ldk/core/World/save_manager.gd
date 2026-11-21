extends RefCounted
## Main-thread snapshot and dirty tracking. A single worker publishes each transaction.

const Files = preload("res://addons/ldk/core/World/world_save_files.gd")
const Save = preload("res://addons/ldk/core/World/world_save.gd")

var _path: String
var _identity: Array
var _commit: Dictionary = {}
var _dirty: Dictionary[Vector3i, bool] = {}
var _writing: Dictionary[Vector3i, bool] = {}
var _thread: Thread
var _initial: Dictionary = {}
var _requested := false


func open(world: Save, preset_id: StringName, generator_version: int) -> Error:
	_path = world.storage_path()
	_identity = [world.id, world.seed, preset_id, generator_version]
	var loaded := Files.load_world(_path, _identity)
	if loaded.error != OK:
		return loaded.error
	if loaded.has("commit"):
		_commit = loaded.commit
		_initial = {"player": _commit.player, "chunks": loaded.chunks}
	else:
		var legacy: Variant = world.read_legacy_state()
		if legacy == null:
			return ERR_FILE_CORRUPT
		if not legacy.is_empty():
			_initial = {"legacy": legacy}
	return OK


func take_initial_state() -> Dictionary:
	var state := _initial
	_initial = {}
	return state


func mark_dirty(coord: Vector3i) -> void:
	_dirty[coord] = true


func flush_on_unload(coord: Vector3i) -> void:
	_requested = _requested or _dirty.has(coord)


func request_flush() -> void:
	_requested = true


func process(collect_chunk: Callable, collect_player: Callable) -> Error:
	if _thread != null and not _thread.is_alive():
		var error := wait_for_write()
		if error != OK:
			return error
	if not _requested or _thread != null:
		return OK
	return _start(collect_chunk, collect_player)


func flush(collect_chunk: Callable, collect_player: Callable) -> Error:
	# Retry a failed async transaction with the latest snapshot.
	wait_for_write()
	var error := _start(collect_chunk, collect_player)
	return wait_for_write() if error == OK else error


func wait_for_write() -> Error:
	if _thread == null:
		return OK
	var result: Dictionary = _thread.wait_to_finish()
	_thread = null
	if result.error == OK:
		_commit = result.commit
	else:
		_dirty.merge(_writing)
	_writing.clear()
	return result.error


func _start(collect_chunk: Callable, collect_player: Callable) -> Error:
	_requested = false
	var player: Dictionary = collect_player.call()
	if _dirty.is_empty() and _commit.get("player") == player:
		return OK
	if not VoxelWorldData.is_persistent_value(player):
		return ERR_INVALID_DATA
	var chunks := {}
	for coord in _dirty:
		chunks[coord] = collect_chunk.call(coord)
	_thread = Thread.new()
	var error := _thread.start(Files.commit.bind(_path, _commit, _identity, chunks, player), Thread.PRIORITY_LOW)
	if error != OK:
		_thread = null
		return error
	_writing = _dirty
	_dirty = {}
	return OK
