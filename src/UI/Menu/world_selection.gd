extends Control

const SaveStore = preload("res://addons/ldk/core/World/world_save_store.gd")
const CreateForm = preload("res://src/UI/Menu/create_world_form.gd")
const MAIN_MENU_PATH := "res://src/UI/Menu/main_menu.tscn"

@export_group("Entrada no mundo")
## Cena de jogo aberta ao criar um mundo ou carregar um save pelo menu.
@export_file("*.tscn") var gameplay_scene_path: String

var _store := SaveStore.new()
@onready var _list_panel: VBoxContainer = %ListPanel
@onready var _form_panel: CenterContainer = %FormPanel
@onready var _form: CreateForm = %CreateWorldForm
@onready var _worlds: Tree = %Worlds
@onready var _status: Label = %Status
@onready var _load_button: Button = %Load
@onready var _create_button: Button = %NewWorld


func _ready() -> void:
	_worlds.set_column_title(0, "Mundo")
	_worlds.set_column_title(1, "Criação (UTC)")
	_worlds.set_column_title(2, "Último acesso (UTC)")
	_worlds.set_column_title(3, "Seed")
	_worlds.set_column_custom_minimum_width(0, 124)
	_worlds.set_column_custom_minimum_width(1, 99)
	_worlds.set_column_custom_minimum_width(2, 114)
	_worlds.set_column_custom_minimum_width(3, 80)
	_worlds.set_column_expand_ratio(0, 3)
	_worlds.item_selected.connect(_sync_load_button)
	_worlds.nothing_selected.connect(_sync_load_button)
	_worlds.item_activated.connect(_open_selected)
	_load_button.pressed.connect(_open_selected)
	_create_button.pressed.connect(_show_create_form)
	%Back.pressed.connect(_back)
	_form.submitted.connect(_create_world)
	_form.cancelled.connect(_back)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()


func _refresh(preferred_id := "") -> void:
	_worlds.clear()
	var root := _worlds.create_item()
	var preferred: TreeItem
	for world in _store.list_worlds():
		var item := _worlds.create_item(root)
		item.set_text(0, world.display_name)
		item.set_text_overrun_behavior(0, TextServer.OVERRUN_TRIM_ELLIPSIS)
		item.set_tooltip_text(0, "%s\nID %s" % [world.display_name, world.id])
		item.set_text(1, _display_date(world.created_at))
		item.set_text(2, _display_date(world.last_accessed_at))
		item.set_text(3, str(world.seed))
		item.set_metadata(0, world.id)
		if world.id == preferred_id:
			preferred = item

	_status.text = "Abra a pausa com Esc para salvar e voltar ao menu principal."
	if _store.last_error != OK:
		_status.text = "Não foi possível listar os mundos salvos."
	elif _store.skipped_worlds > 0:
		_status.text = "Mundos ilegíveis ou incompatíveis: %d." % _store.skipped_worlds
	elif root.get_child_count() == 0:
		_status.text = "Nenhum mundo salvo. Crie um para jogar."

	if preferred == null:
		preferred = root.get_first_child()
	if preferred != null:
		preferred.select(0)
		_worlds.scroll_to_item(preferred)
		_worlds.grab_focus()
	else:
		_create_button.grab_focus()
	_sync_load_button()


func _sync_load_button() -> void:
	_load_button.disabled = _worlds.get_selected() == null


func _open_selected() -> void:
	var selected := _worlds.get_selected()
	if selected == null:
		return
	var world_id: String = selected.get_metadata(0)
	var error := _store.launch(get_tree(), world_id, gameplay_scene_path, scene_file_path)
	if error != OK:
		_status.text = "Não foi possível carregar o mundo. (%s)" % error_string(error)


func _show_create_form() -> void:
	_list_panel.hide()
	_form_panel.show()
	_form.begin(SaveStore.MAX_NAME_LENGTH)


func _show_list() -> void:
	_form_panel.hide()
	_list_panel.show()


func _create_world(world_name: String, seed_text: String) -> void:
	var world := _store.create_world(world_name, seed_text)
	if world != null:
		_show_list()
		_refresh(world.id)
		return

	match _store.last_error:
		ERR_INVALID_PARAMETER:
			_form.show_error("Informe um nome para o mundo.")
		ERR_INVALID_DATA:
			_form.show_error("Use uma seed inteira entre -2147483648 e 2147483647.")
		_:
			_form.show_error("Não foi possível salvar o mundo.")


func _back() -> void:
	if _form_panel.visible:
		_show_list()
		_create_button.grab_focus()
		return
	var error := get_tree().change_scene_to_file(MAIN_MENU_PATH)
	if error != OK:
		_status.text = "Não foi possível voltar ao menu principal."


static func _display_date(timestamp: int) -> String:
	if timestamp == 0:
		return "Nunca"
	var date := Time.get_datetime_dict_from_unix_time(timestamp)
	return "%02d/%02d/%04d %02d:%02d" % [date.day, date.month, date.year, date.hour, date.minute]
