@tool
extends EditorPlugin

const Workspace := preload("res://addons/ldk/core/UI/editor/content_editor.gd")
const WORKSPACE_SCENE_PATH := "res://addons/ldk/core/UI/editor/content_editor.tscn"
const VOXEL_SCENE_PATH := "res://addons/ldk/core/UI/editor/voxel_editor_panel.tscn"
const EditorContext := preload("res://addons/ldk/core/UI/editor/content_editor_context.gd")
const VoxelPanel := preload("res://addons/ldk/core/UI/editor/voxel_editor_panel.gd")

var _workspace: Workspace


func _enter_tree() -> void:
	var scene := ResourceLoader.load(
		WORKSPACE_SCENE_PATH,
		"PackedScene",
		ResourceLoader.CACHE_MODE_REPLACE_DEEP,
	) as PackedScene
	if scene == null:
		push_error("LDK: falha ao carregar a cena do editor de conteúdo.")
		return
	_workspace = scene.instantiate() as Workspace
	_workspace.hide()
	EditorInterface.get_editor_main_screen().add_child(_workspace)
	if _workspace.is_node_ready():
		_register_workspace()
	else:
		_workspace.ready.connect(_register_workspace, CONNECT_ONE_SHOT)


func _register_workspace() -> void:
	var native := PackedStringArray(ProjectSettings.get_setting("ldk/content_editor/native_directories", PackedStringArray()))
	var mods := PackedStringArray(ProjectSettings.get_setting("ldk/content_editor/mod_directories", PackedStringArray()))
	_workspace.register_context(EditorContext.new(&"ldk.native", "Nativo", native))
	_workspace.register_context(EditorContext.new(&"ldk.mods", "Mods", mods))
	var scene := ResourceLoader.load(
		VOXEL_SCENE_PATH,
		"PackedScene",
		ResourceLoader.CACHE_MODE_REPLACE_DEEP,
	) as PackedScene
	if scene == null:
		push_error("LDK: falha ao carregar a aba Voxel.")
		return
	var panel := scene.instantiate() as VoxelPanel
	_workspace.register_category(&"voxel", "Voxel", panel, panel.show_context)


func _exit_tree() -> void:
	if is_instance_valid(_workspace):
		_workspace.hide()
		_workspace.queue_free()
		_workspace = null


func _has_main_screen() -> bool:
	return true


func _get_plugin_name() -> String:
	return "LDK"


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("GridMap", "EditorIcons")


func _make_visible(visible: bool) -> void:
	if is_instance_valid(_workspace):
		_workspace.visible = visible
