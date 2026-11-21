@tool
extends HSplitContainer

const EditorContext := preload("res://addons/ldk/core/UI/editor/content_editor_context.gd")
const Catalog := preload("res://addons/ldk/core/UI/editor/voxel_editor_catalog.gd")
const ResourcePanel := preload("res://addons/ldk/core/UI/editor/content_resource_panel.gd")
const BlockEditor := preload("res://addons/ldk/core/UI/editor/block_graph_editor.gd")

@onready var _tree: Tree = %ResourceTree
@onready var _preview: ResourcePanel = %Editor
@onready var _block_graph: BlockEditor = %BlockGraph
@onready var _navigation_pane: PanelContainer = %NavigationPane
@onready var _preview_pane: PanelContainer = %PreviewPane

var _context_id: StringName
var _branches: Dictionary[String, TreeItem] = {}


func _ready() -> void:
	_tree.set_column_clip_content(0, true)
	_tree.item_selected.connect(_show_selection)
	theme_changed.connect(_style_panes)
	_style_panes()


func _style_panes() -> void:
	var tint := get_theme_color(&"font_color", &"Label")
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(tint, 0.05)
	frame.border_color = Color(tint, 0.25)
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(4)
	frame.set_content_margin_all(8.0)
	_navigation_pane.add_theme_stylebox_override(&"panel", frame)
	_preview_pane.add_theme_stylebox_override(&"panel", frame)


func show_context(context: EditorContext) -> void:
	var selected_path := ""
	var collapsed: Dictionary[String, bool] = {}
	if _context_id == context.id:
		var selected := _selected_entry()
		if selected != null:
			selected_path = selected.path
		for key in _branches:
			collapsed[key] = _branches[key].collapsed
	_context_id = context.id
	_block_graph.set_context(context)
	_branches.clear()

	_tree.set_block_signals(true)
	_tree.clear()
	var root := _tree.create_item()
	var leaves: Dictionary[String, TreeItem] = {}
	for category in Catalog.build(context):
		_add_branch(root, category, category.title, collapsed, leaves)
	if leaves.has(selected_path):
		var item := leaves[selected_path]
		item.select(0)
		_tree.scroll_to_item(item)
	_tree.set_block_signals(false)
	_show_selection()


func _add_branch(parent: TreeItem, branch: Catalog.Branch, key: String,
		collapsed: Dictionary[String, bool], leaves: Dictionary[String, TreeItem]) -> void:
	var item := _tree.create_item(parent)
	item.set_text(0, branch.title)
	item.collapsed = collapsed.get(key, key.contains("/"))
	_branches[key] = item

	var folders := branch.folders.keys()
	folders.sort_custom(func(a: String, b: String) -> bool:
		var order := a.naturalnocasecmp_to(b)
		return a < b if order == 0 else order < 0
	)
	for folder in folders:
		_add_branch(item, branch.folders[folder], key.path_join(folder), collapsed, leaves)

	var titles: Dictionary[String, int] = {}
	var namespaced_titles: Dictionary[String, int] = {}
	for entry in branch.entries:
		var title_key := entry.file_title.to_lower()
		var namespaced_key := title_key + ":" + entry.content_namespace
		titles[title_key] = titles.get(title_key, 0) + 1
		namespaced_titles[namespaced_key] = namespaced_titles.get(namespaced_key, 0) + 1

	branch.entries.sort_custom(func(a: Catalog.Entry, b: Catalog.Entry) -> bool:
		var order := a.file_title.naturalnocasecmp_to(b.file_title)
		return a.path < b.path if order == 0 else order < 0
	)
	for entry in branch.entries:
		var row := _tree.create_item(item)
		var title := entry.file_title
		var title_key := title.to_lower()
		if titles[title_key] > 1:
			title += " · " + entry.content_namespace
			if namespaced_titles[title_key + ":" + entry.content_namespace] > 1:
				title += " · " + entry.path
		row.set_text(0, title)
		row.set_tooltip_text(0, "%s\n%s" % [entry.content_namespace, entry.path])
		row.set_metadata(0, entry)
		leaves[entry.path] = row


func _selected_entry() -> Catalog.Entry:
	var item := _tree.get_selected()
	return item.get_metadata(0) as Catalog.Entry if item != null else null


func _show_selection() -> void:
	var entry := _selected_entry()
	var is_block := entry != null and entry.resource is VoxelBlock
	_preview.visible = not is_block
	_block_graph.visible = is_block
	if is_block:
		_block_graph.show_block(entry.resource as VoxelBlock, entry.path)
		return
	_block_graph.clear()
	if entry == null:
		_preview.show_resource(null)
	else:
		_preview.show_resource(entry.resource, entry.path, entry.content_namespace)
