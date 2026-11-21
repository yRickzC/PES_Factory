@tool
class_name ContentLibrary
extends RefCounted
## Discovers and validates packages, then publishes their shared ContentDB.

enum Phase { DISCOVER, MOUNT, READ, REGISTER, VALIDATE, DONE, FAILED }

const Pck = preload("res://addons/ldk/core/Content/content_pck.gd")
const FolderSources := preload("res://addons/ldk/core/Content/content_folder_sources.gd")
const MODS := "user://mods"
const API_VERSION := 1

static var _mounted: Dictionary[String, String] = {}

var database := ContentDB.new()
var phase := Phase.DISCOVER
var current_package := ""
var issues: Array[String] = []
var fatal_error := ""

var _native_manifest: String
var _mods_directory: String
var _archives: Array[String] = []
var _manifests: Dictionary[String, String] = {}
var _pending: Array[ContentPack] = []
var _remaining: Dictionary[String, bool] = {}
var _registered: Dictionary[String, ContentPack] = {}
var _cursor := 0
var _registration_total := 1
var _require_native := true


func _init(native_manifest: String, mods_directory := MODS) -> void:
	_native_manifest = native_manifest
	_mods_directory = mods_directory


static func from_manifests(manifests: Array[ContentPack]) -> ContentLibrary:
	# Editor sources are already resolved. Keep registration identical to startup.
	var library := ContentLibrary.new("", "")
	library._require_native = false
	for pack in manifests:
		library._queue_manifest(pack, pack.content_namespace if pack != null else "")
	library._start_registration()
	return library


static func discover_folders(
	directories: PackedStringArray,
	ignored: PackedStringArray,
	reload_from_disk := false,
) -> FolderSources:
	return FolderSources.new(directories, ignored, reload_from_disk)


func is_finished() -> bool:
	return phase == Phase.DONE or phase == Phase.FAILED


func progress() -> float:
	match phase:
		Phase.MOUNT:
			return 0.1 + 0.2 * _cursor / _archives.size()
		Phase.READ:
			return 0.3 + 0.25 * _cursor / _manifests.size()
		Phase.REGISTER:
			return 0.55 + 0.35 * (1.0 - float(_pending.size()) / _registration_total)
		Phase.VALIDATE:
			return 0.9
		Phase.DONE:
			return 1.0
		_:
			return 0.0


func step() -> void:
	# Each step leaves a checkpoint for the loading view to render.
	match phase:
		Phase.DISCOVER:
			_discover()
		Phase.MOUNT:
			_mount_next()
		Phase.READ:
			_read_next()
		Phase.REGISTER:
			_register_next()
		Phase.VALIDATE:
			database._finish_registration()
			current_package = ""
			for issue in database._validate_references():
				_reject("", issue)
			phase = Phase.DONE


func _discover() -> void:
	var folder := DirAccess.open(_mods_directory) if not _mods_directory.is_empty() else null
	if folder != null:
		var files := folder.get_files()
		files.sort()
		for file in files:
			if file.get_extension().to_lower() == "pck":
				_archives.append(file)
	_manifests["core"] = _native_manifest
	phase = Phase.MOUNT if not _archives.is_empty() else Phase.READ


func _mount_next() -> void:
	var file := _archives[_cursor]
	var id := file.get_basename()
	current_package = id
	var root := "mods/%s/" % id
	var path := _mods_directory.path_join(file)
	var manifest := "res://" + root + "content.tres"
	if id == "core" or not _valid_namespace(id):
		_reject(file, "Nome de pacote inválido ou reservado.")
	elif _mounted.has(id):
		if _mounted[id] == path:
			_manifests[id] = manifest
		else:
			_reject(file, "Namespace já montado por outro PCK.")
	else:
		var issue := Pck.inspect(path, root)
		if not issue.is_empty():
			_reject(file, issue)
		elif not ProjectSettings.load_resource_pack(path, false):
			_reject(file, "Falha ao montar o PCK.")
		else:
			_mounted[id] = path
			_manifests[id] = manifest
	_cursor += 1
	if _cursor == _archives.size():
		_cursor = 0
		phase = Phase.READ


func _read_next() -> void:
	var id: String = _manifests.keys()[_cursor]
	current_package = id
	var pack := ResourceLoader.load(_manifests[id]) as ContentPack
	_queue_manifest(pack, id)
	_cursor += 1
	if _cursor == _manifests.size() and not is_finished():
		_start_registration()


func _queue_manifest(pack: ContentPack, id: String) -> void:
	var issue := _manifest_issue(pack, id)
	if not issue.is_empty():
		_reject(id, issue)
	elif _remaining.has(id):
		_reject(id, "Mais de um manifesto declara o mesmo namespace (%s)." % pack.resource_path)
	else:
		_pending.append(pack)
		_remaining[id] = true


func _start_registration() -> void:
	_registration_total = maxi(1, maxi(_manifests.size(), _pending.size()))
	_pending.sort_custom(_comes_before)
	phase = Phase.REGISTER if not _pending.is_empty() else Phase.VALIDATE


func _register_next() -> void:
	for i in _pending.size():
		var pack := _pending[i]
		var waiting := false
		var issue := ""
		for dependency in pack.dependencies:
			var version := database.package_version(dependency)
			if version.is_empty() and _remaining.has(dependency):
				waiting = true
				continue
			if version.is_empty() or not _compatible(version, pack.dependencies[dependency]):
				issue = "Requer %s %s (mesma versão principal)." % [dependency, pack.dependencies[dependency]]
				break
		if waiting and issue.is_empty():
			continue
		current_package = pack.content_namespace
		_pending.remove_at(i)
		_remaining.erase(current_package)
		if issue.is_empty():
			issue = _register(pack)
		if not issue.is_empty():
			_reject(current_package, issue)
		if _pending.is_empty() and not is_finished():
			phase = Phase.VALIDATE
		return
	for pack in _pending:
		_reject(pack.content_namespace, "Ciclo de dependências ou dependência ligada a um ciclo.")
	_pending.clear()
	_remaining.clear()
	phase = Phase.VALIDATE


func _register(pack: ContentPack) -> String:
	for existing in _registered:
		if existing in pack.conflicts or pack.content_namespace in _registered[existing].conflicts:
			return "Conflito com o pacote %s." % existing
	var issue := database._register(pack)
	if issue.is_empty():
		_registered[pack.content_namespace] = pack
	return issue


func _reject(id: String, reason: String) -> void:
	var message := reason if id.is_empty() else "%s · %s" % [id, reason]
	issues.append(message)
	if id == "core" and _require_native:
		fatal_error = message
		phase = Phase.FAILED
		push_error(message)
	else:
		push_warning(message)


static func _manifest_issue(pack: ContentPack, id: String) -> String:
	if pack == null or pack.content_namespace != id or not _valid_namespace(id):
		return "Manifesto inválido ou namespace divergente."
	if pack.api_version != API_VERSION:
		return "API de conteúdo incompatível (pacote %d, jogo %d)." % [pack.api_version, API_VERSION]
	if _version(pack.version).x < 0:
		return "Versão do pacote inválida. Use major.minor.patch."
	if id == "core" and not pack.dependencies.is_empty():
		return "O pacote nativo precisa carregar primeiro."
	for dependency in pack.dependencies:
		if dependency == id or not _valid_namespace(dependency) or _version(pack.dependencies[dependency]).x < 0:
			return "Dependência inválida (%s)." % dependency
	for conflict in pack.conflicts:
		if conflict == id or not _valid_namespace(conflict) or pack.dependencies.has(conflict):
			return "Conflito declarado inválido (%s)." % conflict
	return ""


static func _valid_namespace(id: String) -> bool:
	return not id.is_empty() and ContentRegistry.namespace_of(StringName(id + ":pack")) == id


static func _comes_before(a: ContentPack, b: ContentPack) -> bool:
	if a.content_namespace == "core" or b.content_namespace == "core":
		return a.content_namespace == "core" and b.content_namespace != "core"
	if a.priority != b.priority:
		return a.priority > b.priority
	return a.content_namespace < b.content_namespace


static func _compatible(installed: String, required: String) -> bool:
	var actual := _version(installed)
	var minimum := _version(required)
	return actual.x == minimum.x and (actual.y > minimum.y or (actual.y == minimum.y and actual.z >= minimum.z))


static func _version(value: String) -> Vector3i:
	var parts := value.split(".")
	if parts.size() != 3:
		return Vector3i(-1, 0, 0)
	var version := Vector3i.ZERO
	for i in 3:
		var part := parts[i]
		if not part.is_valid_int() or part.length() > 9 or str(part.to_int()) != part or part.begins_with("-"):
			return Vector3i(-1, 0, 0)
		version[i] = part.to_int()
	return version
