@tool
extends RefCounted
## Builds the virtual hierarchy from a context's cached folder snapshot.

const EditorContext := preload("res://addons/ldk/core/UI/editor/content_editor_context.gd")
const CATEGORY_TITLES := ["Blocos", "Biomas", "Mundos"]
const CATEGORY_FOLDERS := [
	["block", "blocks", "bloco", "blocos"],
	["biome", "biomes", "bioma", "biomas"],
	["world", "worlds", "mundo", "mundos"],
]


class Entry:
	var resource: Resource
	var path: String
	var content_namespace: String
	var file_title: String

	func _init(value: Resource, source_path: String, source_namespace: String) -> void:
		resource = value
		path = source_path
		content_namespace = source_namespace
		file_title = path.get_file().get_basename()


class Branch:
	var title: String
	var folders: Dictionary[String, Branch] = {}
	var entries: Array[Entry] = []

	func _init(branch_title: String) -> void:
		title = branch_title

	func folder(folder_title: String) -> Branch:
		if not folders.has(folder_title):
			folders[folder_title] = Branch.new(folder_title)
		return folders[folder_title]


static func build(context: EditorContext) -> Array[Branch]:
	var categories: Array[Branch] = []
	for title: String in CATEGORY_TITLES:
		categories.append(Branch.new(title))

	var sources := context.sources
	for path in sources.resources:
		var resource := sources.resources[path]
		var category := _category_index(resource)
		if category < 0:
			continue
		var package_root := sources.package_root(path)
		var declared_namespace := ""
		if resource is VoxelBlock or resource is VoxelBiome:
			var key: StringName = resource.get(&"key")
			declared_namespace = ContentRegistry.namespace_of(key)
		var package := sources.package_namespace(package_root, declared_namespace)
		if package.is_empty():
			package = context.content_namespace

		var relative := sources.relative_path(path, package_root)
		var folders := _relative_folders(relative, CATEGORY_FOLDERS[category])
		var branch := categories[category]
		for folder_title in folders:
			branch = branch.folder(folder_title)
		branch.entries.append(Entry.new(resource, path, package))
	return categories


static func _category_index(resource: Resource) -> int:
	if resource is VoxelBlock:
		return 0
	if resource is VoxelBiome:
		return 1
	if resource is WorldDefinition:
		return 2
	return -1


static func _relative_folders(relative_path: String, category_folders: Array) -> PackedStringArray:
	var segments := relative_path.split("/", false)
	var folders := segments.slice(0, segments.size() - 1)
	for index in folders.size():
		if folders[index].to_lower() in category_folders:
			return folders.slice(index + 1)
	return folders
