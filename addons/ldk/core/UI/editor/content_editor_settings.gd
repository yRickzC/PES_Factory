@tool
extends ScrollContainer

signal context_selected(index: int)
signal closed

const EditorContext := preload("res://addons/ldk/core/UI/editor/content_editor_context.gd")
const DirectoryTagSelector := preload("res://addons/ldk/core/UI/editor/directory_tag_selector.gd")

@onready var _contexts: OptionButton = %Contexts
@onready var _namespace: LineEdit = %Namespace
@onready var _read_directories: DirectoryTagSelector = %ReadDirectories
@onready var _ignored_directories: DirectoryTagSelector = %IgnoredDirectories
@onready var _message: Label = %Message

var _context: EditorContext


func _ready() -> void:
	var tabs: TabContainer = %DirectoryTabs
	tabs.set_tab_title(tabs.get_tab_idx_from_control(_read_directories), "Pastas de leitura")
	tabs.set_tab_title(tabs.get_tab_idx_from_control(_ignored_directories), "Pastas ignoradas")
	_contexts.item_selected.connect(func(index: int) -> void: context_selected.emit(index))
	%Save.pressed.connect(_save)
	%Back.pressed.connect(func() -> void: closed.emit())


func add_context(title: String) -> void:
	_contexts.add_item(title)


func show_context(index: int, context: EditorContext) -> void:
	_context = context
	_contexts.select(index)
	_namespace.text = context.content_namespace
	_read_directories.set_directories(context.read_directories)
	_ignored_directories.set_directories(context.ignored_directories)
	_message.text = context.settings_issue


func _save() -> void:
	var issue := _context.apply_preferences(
		_namespace.text,
		_read_directories.get_directories(),
		_ignored_directories.get_directories(),
	)
	if issue.is_empty():
		closed.emit()
	else:
		_message.text = issue
