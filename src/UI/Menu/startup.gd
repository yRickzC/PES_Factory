extends Control

const MENU := "res://src/UI/Menu/main_menu.tscn"

@onready var _stage: Label = %Stage
@onready var _detail: Label = %Detail
@onready var _counts: Label = %Counts
@onready var _progress: ProgressBar = %Progress


func _ready() -> void:
	%Quit.pressed.connect(get_tree().quit)
	_start.call_deferred()


func _start() -> void:
	var library := DemoContent.start_library()
	while not library.is_finished():
		var phase := library.phase
		_stage.text = _stage_name(phase)
		await get_tree().process_frame
		library.step()
		_progress.value = library.progress()
		var count := library.database.package_count()
		var packages := "1 pacote" if count == 1 else "%d pacotes" % count
		_counts.text = "%s · %d definições" % [packages, library.database.definition_count()]
		if not library.current_package.is_empty():
			var package_id := library.current_package
			var version := library.database.package_version(package_id)
			_detail.text = package_id if version.is_empty() else "%s · v%s" % [package_id, version]
		else:
			_detail.text = ""
	if library.phase == ContentLibrary.Phase.FAILED:
		_show_error(library.fatal_error)
		return
	DemoContent.publish(library)
	_stage.text = "Conteúdo pronto"
	if not library.issues.is_empty():
		_detail.text = "%d avisos de conteúdo" % library.issues.size()
	await get_tree().process_frame
	await get_tree().process_frame
	var result := get_tree().change_scene_to_file(MENU)
	if result != OK:
		_show_error(error_string(result))


func _show_error(reason: String) -> void:
	_stage.text = "Falha na inicialização"
	_detail.text = reason
	%Quit.show()
	%Quit.grab_focus()


func _stage_name(phase: ContentLibrary.Phase) -> String:
	match phase:
		ContentLibrary.Phase.DISCOVER:
			return "Procurando pacotes"
		ContentLibrary.Phase.MOUNT:
			return "Verificando arquivos PCK"
		ContentLibrary.Phase.READ:
			return "Lendo definições"
		ContentLibrary.Phase.REGISTER:
			return "Registrando pacotes"
		_:
			return "Validando referências"
