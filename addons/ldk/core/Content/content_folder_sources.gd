@tool
extends RefCounted
## Snapshot of editable Resources discovered in configured folders.

var resources: Dictionary[String, Resource] = {}
var manifests: Array[ContentPack] = []
var issues := PackedStringArray()

var _read_directories := PackedStringArray()
var _ignored_directories: PackedStringArray
var _package_roots: Dictionary[String, PackedStringArray] = {}


func _init(directories: PackedStringArray, ignored: PackedStringArray, reload_from_disk: bool) -> void:
	for directory in directories:
		var path := normalize_directory(directory)
		if path.is_empty():
			issues.append("Pasta de leitura inválida (%s)." % directory)
		else:
			_read_directories.append(path)
	_ignored_directories = ignored.duplicate()
	var paths := _discover_files()
	var blocked := _ignored_dependencies(paths)
	var cache_mode := ResourceLoader.CACHE_MODE_REPLACE if reload_from_disk else ResourceLoader.CACHE_MODE_REUSE
	for path in paths:
		var ignored_dependency: String = blocked.get(path_key(path), "")
		if not ignored_dependency.is_empty():
			issues.append("%s depende de um arquivo em pasta ignorada (%s)." % [path, ignored_dependency])
			continue
		var resource := ResourceLoader.load(path, "", cache_mode)
		if resource == null:
			issues.append("Não foi possível carregar %s." % path)
			continue
		resources[path] = resource
		if resource is ContentPack:
			var manifest := resource as ContentPack
			manifests.append(manifest)
			var pack_namespace := manifest.content_namespace
			if pack_namespace.is_empty() or ContentRegistry.namespace_of(StringName(pack_namespace + ":pack")) != pack_namespace:
				continue
			var folder := path_key(path.get_base_dir())
			var namespaces: PackedStringArray = _package_roots.get(folder, PackedStringArray())
			if pack_namespace not in namespaces:
				namespaces.append(pack_namespace)
				_package_roots[folder] = namespaces


func package_root(path: String) -> String:
	var folder := path.get_base_dir()
	while not folder.is_empty():
		if _package_roots.has(path_key(folder)):
			return folder
		if folder.ends_with("://"):
			break
		folder = folder.get_base_dir()
	return ""


func package_namespace(root: String, declared_namespace: String) -> String:
	var namespaces: PackedStringArray = _package_roots.get(path_key(root), PackedStringArray())
	return namespaces[0] if namespaces.size() == 1 else declared_namespace


func relative_path(path: String, root: String) -> String:
	if not root.is_empty():
		return path.substr(_directory_prefix(root).length())
	var key := path_key(path)
	var best_prefix := ""
	for directory in _read_directories:
		var prefix := _directory_prefix(directory)
		if not key.begins_with(path_key(prefix)):
			continue
		# An overlapping read folder must not flatten an already visible branch.
		if best_prefix.is_empty() or prefix.length() < best_prefix.length():
			best_prefix = prefix
	return path.get_file() if best_prefix.is_empty() else path.substr(best_prefix.length())


static func _directory_prefix(path: String) -> String:
	return path if path.ends_with("/") else path + "/"


func _discover_files() -> Array[String]:
	var paths: Array[String] = []
	var pending: Array[String] = []
	var visited: Dictionary[String, bool] = {}
	for root in _read_directories:
		pending.append(root)
	while not pending.is_empty():
		var path: String = pending.pop_back()
		var key := path_key(path)
		if visited.has(key) or _is_ignored(path):
			continue
		visited[key] = true
		var directory := DirAccess.open(path)
		if directory == null:
			issues.append("Pasta de leitura indisponível (%s)." % path)
			continue
		for child in directory.get_directories():
			if not directory.is_link(child):
				pending.append(path.path_join(child))
		for file in directory.get_files():
			if file.get_extension().to_lower() in ["tres", "res"] and not directory.is_link(file):
				paths.append(path.path_join(file))
	paths.sort()
	return paths


func _is_ignored(path: String) -> bool:
	if _ignored_directories.is_empty() or not _is_resource_path(path):
		return false
	var key := path_key(path)
	for folder in _ignored_directories:
		var root := path_key(folder)
		var prefix := _directory_prefix(root)
		if key == root or key.begins_with(prefix):
			return true
	return false


func _ignored_dependencies(paths: Array[String]) -> Dictionary[String, String]:
	var blocked: Dictionary[String, String] = {}
	if _ignored_directories.is_empty():
		return blocked

	# Inspect dependency metadata once per path, then propagate exclusions to dependents.
	var pending := paths.duplicate()
	var seen: Dictionary[String, bool] = {}
	var dependents: Dictionary[String, PackedStringArray] = {}
	var excluded: Array[String] = []
	while not pending.is_empty():
		var path: String = pending.pop_back()
		var key := path_key(path)
		if seen.has(key):
			continue
		seen[key] = true
		if _is_ignored(path):
			blocked[key] = path
			excluded.append(key)
			continue
		for dependency in ResourceLoader.get_dependencies(path):
			var target := _dependency_path(path, dependency)
			if target.is_empty():
				continue
			var target_key := path_key(target)
			var users: PackedStringArray = dependents.get(target_key, PackedStringArray())
			users.append(key)
			dependents[target_key] = users
			pending.append(target)

	while not excluded.is_empty():
		var path: String = excluded.pop_back()
		for dependent in dependents.get(path, PackedStringArray()):
			if not blocked.has(dependent):
				blocked[dependent] = blocked[path]
				excluded.append(dependent)
	return blocked


static func _dependency_path(source: String, dependency: String) -> String:
	var path := dependency.get_slice("::", 0)
	if path.begins_with("uid://"):
		var uid := ResourceUID.text_to_id(path)
		path = ResourceUID.get_id_path(uid) if ResourceUID.has_id(uid) else dependency.get_slice("::", 2)
	if path.is_relative_path() and not path.is_empty():
		path = source.get_base_dir().path_join(path)
	return normalize_directory(path)


static func path_key(path: String) -> String:
	return path.to_lower() if OS.get_name() == "Windows" else path


static func normalize_directory(value: String) -> String:
	var path := value.strip_edges().replace("\\", "/")
	if not _is_resource_path(path):
		return ""
	var prefix := path.get_slice("://", 0) + "://"
	var parts := PackedStringArray()
	for segment in path.trim_prefix(prefix).split("/", false):
		if segment == "..":
			if parts.is_empty():
				return ""
			parts.remove_at(parts.size() - 1)
		elif segment != ".":
			parts.append(segment)
	return prefix + "/".join(parts)


static func _is_resource_path(path: String) -> bool:
	return path.begins_with("res://") or path.begins_with("user://")
