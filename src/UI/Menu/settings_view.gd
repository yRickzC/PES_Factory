extends VBoxContainer
## Exibe preferências do jogador e escreve alterações individuais.

const Preferences = preload("res://addons/ldk/core/Settings/game_preferences.gd")

signal back_requested

var _status := Label.new()
var _volume := SpinBox.new()
var _toggles: Dictionary[StringName, CheckButton] = {}


func _ready() -> void:
	custom_minimum_size.x = 292
	add_theme_constant_override(&"separation", 6)
	var title := Label.new()
	title.text = "Configurações"
	title.add_theme_font_size_override(&"font_size", 17)
	add_child(title)
	var audio := HBoxContainer.new()
	var volume_label := Label.new()
	volume_label.text = "Áudio · Volume geral"
	volume_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	audio.add_child(volume_label)
	_volume.suffix = "%"
	_volume.min_value = 0
	_volume.max_value = 100
	_volume.step = 5
	_volume.value_changed.connect(_set_volume)
	audio.add_child(_volume)
	add_child(audio)
	_add_toggle("Vídeo · Tela cheia", &"fullscreen")
	_add_toggle("Vídeo · Sincronização vertical", &"vsync")
	_add_toggle("Gameplay · Prévia de posicionamento", &"placement_preview")
	_status.custom_minimum_size.y = 20
	add_child(_status)
	var back := Button.new()
	back.text = "Voltar"
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	back.pressed.connect(back_requested.emit)
	add_child(back)
	Preferences.current.options_changed.connect(_sync)
	_sync()


func open() -> void:
	_status.text = ""
	show()
	_volume.get_line_edit().grab_focus()


func _add_toggle(title: String, key: StringName) -> void:
	var control := CheckButton.new()
	control.text = title
	control.toggled.connect(_set_toggle.bind(key))
	add_child(control)
	_toggles[key] = control


func _sync() -> void:
	_volume.set_value_no_signal(float(Preferences.current.option(&"master_volume")) * 100.0)
	for key in _toggles:
		_toggles[key].set_pressed_no_signal(Preferences.current.option(key))


func _set_volume(value: float) -> void:
	_save(&"master_volume", value / 100.0)


func _set_toggle(value: bool, key: StringName) -> void:
	_save(key, value)


func _save(key: StringName, value: Variant) -> void:
	var result: Error = Preferences.current.set_option(key, value)
	_status.text = "" if result == OK else "Não foi possível salvar as preferências."
	if result != OK:
		_sync()
