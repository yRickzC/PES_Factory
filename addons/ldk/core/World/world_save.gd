extends RefCounted
## Metadata and storage location for one saved world.

const ROOT := "user://worlds"
const STATE_FILE := "state.dat"
const STATE_VERSION := 1

var id: String
var display_name: String
var seed: int
var created_at: int
var last_accessed_at := 0


func _init(world_id: String, world_name: String, world_seed: int, created: int) -> void:
	id = world_id
	display_name = world_name
	seed = world_seed
	created_at = created


func storage_path() -> String:
	return ROOT.path_join(id)


## Um mundo recém-criado retorna um dicionário vazio. Um arquivo inválido retorna null.
func read_legacy_state() -> Variant:
	var path := storage_path().path_join(STATE_FILE)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {} if FileAccess.get_open_error() == ERR_FILE_NOT_FOUND else null
	var value: Variant = bytes_to_var(file.get_buffer(file.get_length()))
	if not value is Array or value.size() != 2 or value[0] != STATE_VERSION or not value[1] is Dictionary:
		return null
	return value[1]
