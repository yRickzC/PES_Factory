@tool
extends VBoxContainer
## Edits a draft list of directories. The parent decides when to save it.

const EditorContext := preload("res://addons/ldk/core/UI/editor/content_editor_context.gd")

@onready var _tags: HFlowContainer = %Tags
@onready var _message: Label = %Message
@onready var _picker: FileDialog = %DirectoryPicker
@onready var _confirmation: ConfirmationDialog = %RemoveDirectory

var _directories := PackedStringArray()
var _pending_removal := ""
var _pending_tag: Button


func _ready() -> void:
	var locations: PopupMenu = %ChooseDirectory.get_popup()
	locations.add_item("Projeto (res://)")
	locations.add_item("Dados do usuário (user://)")
	locations.index_pressed.connect(_open_picker)
	_picker.dir_selected.connect(_add_directory)
	_confirmation.confirmed.connect(_remove_directory)
	_confirmation.canceled.connect(_clear_removal)


func set_directories(paths: PackedStringArray) -> void:
	_message.text = ""
	_clear_removal()
	if paths == _directories:
		return
	_directories = paths.duplicate()
	for tag in _tags.get_children():
		_tags.remove_child(tag)
		tag.queue_free()
	for path in _directories:
		_add_tag(path)
	%Empty.visible = _directories.is_empty()


func get_directories() -> PackedStringArray:
	return _directories.duplicate()


func _open_picker(index: int) -> void:
	_picker.access = FileDialog.ACCESS_RESOURCES if index == 0 else FileDialog.ACCESS_USERDATA
	_picker.popup_centered_ratio.call_deferred(0.6)


func _add_directory(selected_path: String) -> void:
	var path := EditorContext.normalize_directory(selected_path)
	if path.is_empty() or not DirAccess.dir_exists_absolute(path):
		_message.text = "Selecione uma pasta existente do projeto ou dos dados do usuário."
		return
	var key := EditorContext.path_key(path)
	for existing in _directories:
		if EditorContext.path_key(EditorContext.normalize_directory(existing)) == key:
			_message.text = "Essa pasta já está na lista."
			return
	_directories.append(path)
	_add_tag(path)
	%Empty.hide()
	_message.text = ""


func _add_tag(path: String) -> void:
	var tag := Button.new()
	var folder := path.get_file() if not path.ends_with("://") else path
	if folder.length() > 25:
		folder = folder.left(24) + "…"
	tag.text = "%s ×" % folder
	tag.tooltip_text = path
	tag.accessibility_name = "Remover pasta %s" % path
	tag.pressed.connect(_confirm_removal.bind(path, tag))
	_tags.add_child(tag)


func _confirm_removal(path: String, tag: Button) -> void:
	_pending_removal = path
	_pending_tag = tag
	_confirmation.dialog_text = "Remover esta pasta da configuração?\n%s\n\nOs arquivos serão preservados." % path
	_confirmation.popup_centered(Vector2i(420, 0))


func _remove_directory() -> void:
	var index := _directories.find(_pending_removal)
	if index < 0 or _pending_tag == null:
		return
	_directories.remove_at(index)
	_tags.remove_child(_pending_tag)
	_pending_tag.queue_free()
	_clear_removal()
	_message.text = ""
	%Empty.visible = _directories.is_empty()


func _clear_removal() -> void:
	_pending_removal = ""
	_pending_tag = null
