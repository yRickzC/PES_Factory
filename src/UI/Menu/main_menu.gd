extends Control

const SELECTION_PATH := "res://src/UI/Menu/world_selection.tscn"

@onready var _status: Label = %Status


func _ready() -> void:
	%Play.pressed.connect(_open_world_selection)
	%Quit.pressed.connect(_quit)
	%Play.grab_focus()
	if not DemoContent.startup_issues.is_empty():
		_status.text = "%d aviso(s) ao carregar conteúdo." % DemoContent.startup_issues.size()
		_status.tooltip_text = "\n".join(DemoContent.startup_issues)
		_status.show()


func _open_world_selection() -> void:
	var error := get_tree().change_scene_to_file(SELECTION_PATH)
	if error != OK:
		_status.text = "Falha ao abrir a seleção de mundos."
		_status.show()


func _quit() -> void:
	get_tree().quit()
