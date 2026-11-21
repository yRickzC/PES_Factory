extends VBoxContainer

signal submitted(world_name: String, seed_text: String)
signal cancelled

@onready var _world_name: LineEdit = %WorldName
@onready var _seed: LineEdit = %Seed
@onready var _status: Label = %Status


func _ready() -> void:
	%Back.pressed.connect(_cancel)
	%Create.pressed.connect(_submit)
	_world_name.text_submitted.connect(_focus_seed)
	_seed.text_submitted.connect(_submit_seed)


func begin(max_name_length: int) -> void:
	_world_name.max_length = max_name_length
	_world_name.clear()
	_seed.clear()
	_status.text = ""
	_world_name.grab_focus()


func show_error(message: String) -> void:
	_status.text = message


func _focus_seed(_text: String) -> void:
	_seed.grab_focus()


func _submit_seed(_text: String) -> void:
	_submit()


func _cancel() -> void:
	cancelled.emit()


func _submit() -> void:
	submitted.emit(_world_name.text, _seed.text)
