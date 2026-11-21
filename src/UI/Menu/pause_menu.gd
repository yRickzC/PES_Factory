extends CanvasLayer
## Controla a pausa, o foco modal e o retorno ao menu principal.

const Preferences = preload("res://addons/ldk/core/Settings/game_preferences.gd")

const THEME = preload("res://src/UI/Menu/pixel_menu_theme.tres")
const ControlsView = preload("res://src/UI/Menu/controls_view.gd")
const SettingsView = preload("res://src/UI/Menu/settings_view.gd")

signal open_changed(open: bool)

var save_and_exit: Callable
var _overlay := ColorRect.new()
var _menu := VBoxContainer.new()
var _controls := ControlsView.new()
var _settings := SettingsView.new()
var _status := Label.new()
var _resume_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_overlay.theme = THEME
	_overlay.color = Color(0.06, 0.13, 0.13, 0.58)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.hide()
	add_child(_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	panel.add_child(_menu)
	panel.add_child(_controls)
	panel.add_child(_settings)
	_controls.hide()
	_settings.hide()
	_controls.back_requested.connect(_show_menu)
	_settings.back_requested.connect(_show_menu)
	_menu.custom_minimum_size.x = 224
	_menu.add_theme_constant_override(&"separation", 6)
	var title := Label.new()
	title.text = "Jogo pausado"
	title.add_theme_font_size_override(&"font_size", 18)
	_menu.add_child(title)
	_resume_button = _add_button("Voltar ao jogo", _resume)
	_resume_button.theme_type_variation = &"PrimaryButton"
	_add_button("Configurações", _show_settings)
	_add_button("Controles", _show_controls)
	var exit := _add_button("Sair", _exit)
	exit.tooltip_text = "Salva este mundo e retorna ao menu principal."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.hide()
	_menu.add_child(_status)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventMouseButton):
		return
	if _controls.visible and _overlay.visible and _controls.is_capturing():
		_controls.capture_input(event)
		get_viewport().set_input_as_handled()
		return
	if _overlay.visible and event is InputEventMouseButton:
		return
	if not Preferences.current.pressed_with_held_modifiers(
		event, Preferences.current.defaults.protected_action, [&"core:sprint"]
	):
		return
	if _overlay.visible and (
		get_viewport().gui_get_focus_owner() is LineEdit and not Preferences.current.fallback_pressed(event)
	):
		return
	get_viewport().set_input_as_handled()
	if not _overlay.visible:
		get_tree().paused = true
		_overlay.show()
		_show_menu()
		open_changed.emit(true)
	elif _menu.visible:
		_resume()
	else:
		_show_menu()


func _add_button(title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 25
	button.pressed.connect(action)
	_menu.add_child(button)
	return button


func _show_menu() -> void:
	_controls.hide()
	_settings.hide()
	_menu.show()
	_resume_button.grab_focus()


func _show_settings() -> void:
	_menu.hide()
	_settings.open()


func _show_controls() -> void:
	_menu.hide()
	_controls.open()


func _resume() -> void:
	_overlay.hide()
	_status.hide()
	get_tree().paused = false
	open_changed.emit(false)


func _exit() -> void:
	var tree := get_tree()
	var result: String = save_and_exit.call()
	if result.is_empty():
		tree.paused = false
	else:
		_status.text = result
		_status.show()
