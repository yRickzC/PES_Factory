@tool
extends RefCounted
## Preferences and cached content for one independent editing context.

const FolderSources := ContentLibrary.FolderSources
const SETTINGS_DIR := "user://ldk/content_editor"

var id: StringName
var title: String
var content_namespace := "core"
var read_directories := PackedStringArray()
var ignored_directories := PackedStringArray()
var settings_issue := ""
var issues := PackedStringArray()
var revision := 0
var database: ContentDB
var sources: FolderSources

var _settings_path: String
var _reload_from_disk := false


func _init(context_id: StringName, context_title: String, default_directories: PackedStringArray, default_namespace := "core") -> void:
	id = context_id
	title = context_title
	content_namespace = default_namespace
	read_directories = default_directories.duplicate()
	_settings_path = SETTINGS_DIR.path_join(String(id).sha256_text() + ".cfg")
	_load_preferences()


func apply_preferences(new_namespace: String, directories: PackedStringArray, ignored: PackedStringArray) -> String:
	new_namespace = new_namespace.strip_edges()
	if not _valid_namespace(new_namespace):
		return "O namespace deve começar com uma letra minúscula e usar apenas letras minúsculas, números ou sublinhados."
	for raw in directories + ignored:
		if not raw.strip_edges().is_empty() and normalize_directory(raw).is_empty():
			return "Pasta inválida (%s). Use res:// ou user://." % raw
	var roots := _unique_directories(directories)
	var exclusions := _unique_directories(ignored)
	var directories_changed := roots != read_directories or exclusions != ignored_directories
	if settings_issue.is_empty() and not directories_changed and new_namespace == content_namespace:
		return ""

	var preferences := ConfigFile.new()
	preferences.set_value("content", "namespace", new_namespace)
	preferences.set_value("content", "read_directories", roots)
	preferences.set_value("content", "ignored_directories", exclusions)
	var error := DirAccess.make_dir_recursive_absolute(SETTINGS_DIR)
	if error == OK:
		var temporary := "%s.%d.%d.tmp" % [_settings_path, OS.get_process_id(), Time.get_ticks_usec()]
		error = preferences.save(temporary)
		if error == OK:
			error = DirAccess.rename_absolute(temporary, _settings_path)
		if error != OK and FileAccess.file_exists(temporary):
			DirAccess.remove_absolute(temporary)
	if error != OK:
		return "Falha ao salvar as configurações (%s)." % error_string(error)

	if directories_changed:
		_clear_sources()
	content_namespace = new_namespace
	read_directories = roots
	ignored_directories = exclusions
	settings_issue = ""
	revision += 1
	return ""


func invalidate_sources() -> void:
	_clear_sources()
	_reload_from_disk = true
	revision += 1


func ensure_loaded() -> void:
	if database != null:
		return
	if sources == null:
		sources = ContentLibrary.discover_folders(read_directories, ignored_directories, _reload_from_disk)
		_reload_from_disk = false

	var library := ContentLibrary.from_manifests(sources.manifests)
	while not library.is_finished():
		library.step()
	database = library.database
	issues = sources.issues + PackedStringArray(library.issues)


func _load_preferences() -> void:
	if not FileAccess.file_exists(_settings_path):
		return
	var preferences := ConfigFile.new()
	var error := preferences.load(_settings_path)
	if error != OK:
		settings_issue = "Falha ao ler as configurações salvas (%s)." % error_string(error)
		return
	var saved_namespace: Variant = preferences.get_value("content", "namespace", content_namespace)
	var saved_directories: Variant = preferences.get_value("content", "read_directories", read_directories)
	var saved_ignored: Variant = preferences.get_value("content", "ignored_directories", ignored_directories)
	if saved_namespace is String and _valid_namespace(saved_namespace) and saved_directories is PackedStringArray and saved_ignored is PackedStringArray:
		content_namespace = saved_namespace
		read_directories = saved_directories
		ignored_directories = _unique_directories(saved_ignored)
	else:
		settings_issue = "As configurações salvas deste contexto são inválidas."


func _clear_sources() -> void:
	database = null
	sources = null
	issues.clear()


static func _valid_namespace(package: String) -> bool:
	return not package.is_empty() and ContentRegistry.namespace_of(StringName(package + ":pack")) == package


static func _unique_directories(values: PackedStringArray) -> PackedStringArray:
	var result := PackedStringArray()
	var seen: Dictionary[String, bool] = {}
	for value in values:
		var path := normalize_directory(value)
		var key := path_key(path)
		if not path.is_empty() and not seen.has(key):
			result.append(path)
			seen[key] = true
	return result


static func path_key(path: String) -> String:
	return FolderSources.path_key(path)


static func normalize_directory(value: String) -> String:
	return FolderSources.normalize_directory(value)
