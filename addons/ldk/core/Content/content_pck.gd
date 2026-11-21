extends RefCounted
## Checks the directory of standalone Godot PCK v2–v4 files before mounting them.
## See Godot core/io/file_access_pack.h and PackedSourcePCK::try_open_pack().

const MAGIC := 0x43504447
const RELATIVE_FILE_BASE := 2
const ENTRY_BYTES := 36
const MAX_PATH_BYTES := 4096


static func inspect(path: String, package_root: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 36 or file.get_32() != MAGIC:
		return "PCK independente inválido."
	var format := file.get_32()
	var major := file.get_32()
	var minor := file.get_32()
	file.get_32() # Engine patch.
	var flags := file.get_32()
	var file_base := file.get_64()
	var engine := Engine.get_version_info()
	if format < 2 or format > 4 or major != engine.major or minor > engine.minor:
		return "Versão do PCK incompatível com o Godot em uso."
	if (flags & ~RELATIVE_FILE_BASE) != 0:
		return "PCK precisa ter índice aberto e arquivos completos."

	var directory := 96 if format == 2 else file.get_64()
	var length := file.get_length()
	if directory < 36 or directory > length - 4 or file_base < 0 or file_base > length:
		return "Índice do PCK fora do arquivo."
	file.seek(directory)
	var count := file.get_32()
	if count == 0 or count > (length - file.get_position()) / (ENTRY_BYTES + 4):
		return "Índice do PCK incompleto."

	var files: Dictionary[String, bool] = {}
	for _index in count:
		if file.get_position() > length - 4:
			return "Índice do PCK incompleto."
		var path_size := file.get_32()
		if path_size <= 0 or path_size > MAX_PATH_BYTES or path_size > length - file.get_position() - ENTRY_BYTES:
			return "Caminho inválido no índice do PCK."
		var bytes := file.get_buffer(path_size)
		var zero := bytes.find(0)
		if zero >= 0:
			for i in range(zero, bytes.size()):
				if bytes[i] != 0:
					return "Caminho inválido no índice do PCK."
			bytes = bytes.slice(0, zero)
		var name := bytes.get_string_from_utf8().trim_prefix("res://")
		var offset := file.get_64()
		var size := file.get_64()
		file.get_buffer(16) # File checksum.
		var entry_flags := file.get_32()
		if entry_flags != 0 or offset < 0 or size < 0 or offset > length - file_base or size > length - file_base - offset:
			return "O PCK contém um arquivo removido, parcial ou criptografado."
		if not name.begins_with(package_root) or name != name.simplify_path() or "\\" in name or ":" in name or name.ends_with("/"):
			return "Arquivo fora do namespace do pacote (%s)." % name
		var folded := name.to_lower()
		if files.has(folded):
			return "Caminho repetido no PCK (%s)." % name
		files[folded] = name == package_root + "content.tres"
	if not files.get(package_root + "content.tres", false):
		return "Manifesto content.tres ausente do PCK."
	return ""
