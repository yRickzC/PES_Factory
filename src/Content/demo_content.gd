class_name DemoContent
extends RefCounted

const Preferences = preload("res://addons/ldk/core/Settings/game_preferences.gd")

const NATIVE := "res://assets/core/content.tres"
const MISSING_BLOCK := &"core:missing_block"
const LEGACY_BLOCKS: Array[StringName] = [
	&"core:air", &"core:grass", &"core:earth", &"core:stone", &"core:sand", &"core:moss",
	&"core:water", &"core:timber", &"core:slab", &"core:stairs", &"core:roof",
	&"core:roof_reversed", &"core:fence", &"core:fence_turned", &"core:log", &"core:leaves",
	&"core:paving", &"core:wall", &"core:clay", &"core:plaster", &"core:sill", &"core:window",
]


static var _database: ContentDB
static var startup_issues: Array[String] = []


static func start_library(directory := ContentLibrary.MODS) -> ContentLibrary:
	return ContentLibrary.new(NATIVE, directory)


static func publish(library: ContentLibrary) -> void:
	_database = library.database
	startup_issues = library.issues
	if Preferences.current != null:
		Preferences.current.register_content(_database.input_actions)


static func load_content(include_mods := true) -> ContentDB:
	if include_mods and _database != null:
		return _database
	var library := start_library(ContentLibrary.MODS if include_mods else "")
	while not library.is_finished():
		library.step()
	if library.phase != ContentLibrary.Phase.DONE:
		return null
	if include_mods:
		publish(library)
	return library.database
