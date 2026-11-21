extends RefCounted
## Copy-on-write regions. The two commit slots each describe one complete world state.

const Codec = preload("res://addons/ldk/core/World/chunk_save_codec.gd")
const FORMAT := 2
const REGION_SHIFT := 2
const MAX_FILE_BYTES := 64 * 1024 * 1024
const MAGIC := 0x4c444b53
const HEADER_BYTES := 36


static func load_world(path: String, identity: Array) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var found := false
	for slot in 2:
		var file := _commit_path(path, slot)
		found = found or FileAccess.file_exists(file)
		var data: Variant = _read(file)
		if data is Dictionary and data.get("revision") is int and data.revision > 0 \
			and (data.revision & 1) == slot:
			candidates.append(data)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.revision > b.revision)
	for data in candidates:
		if data.get("format") != FORMAT or data.get("identity") != identity:
			return {"error": ERR_FILE_UNRECOGNIZED}
		if not data.get("player") is Dictionary or not data.get("regions") is Dictionary:
			continue
		if not VoxelWorldData.is_persistent_value(data.player):
			continue
		var edits: Variant = _load_regions(path, data.regions)
		if edits != null:
			return {"error": OK, "commit": data, "chunks": edits}
	return {"error": ERR_FILE_CORRUPT if found else OK}


static func commit(path: String, previous: Dictionary, identity: Array, chunks: Dictionary, player: Dictionary) -> Dictionary:
	var revision: int = previous.get("revision", 0) + 1
	var old_index: Dictionary = previous.get("regions", {})
	var next_index := old_index.duplicate()
	var grouped := {}
	for coord: Vector3i in chunks:
		var region := region_of(coord)
		if not grouped.has(region):
			grouped[region] = {}
		grouped[region][coord] = chunks[coord]

	var created := PackedStringArray()
	var error := OK
	for region: Vector3i in grouped:
		var records := {}
		if old_index.has(region):
			var existing: Variant = _read_region(path, old_index[region], region)
			if existing == null:
				error = ERR_FILE_CORRUPT
				break
			records = existing
		for coord: Vector3i in grouped[region]:
			var record: Dictionary = grouped[region][coord]
			if record.blocks.is_empty() and record.props.is_empty() and record.components.is_empty():
				records.erase(coord)
				continue
			records[coord] = [Codec.encode(record.blocks), record.props, record.components]
		if records.is_empty():
			next_index.erase(region)
			continue
		var token := Crypto.new().generate_random_bytes(16).hex_encode()
		if not _valid_token(token):
			error = ERR_CANT_CREATE
			break
		var file := _region_path(path, token)
		error = _publish(file, [region, records])
		if error != OK:
			break
		created.append(file)
		next_index[region] = token

	var next := {"format": FORMAT, "revision": revision, "identity": identity, "regions": next_index, "player": player}
	if error == OK:
		var slot := _commit_path(path, revision & 1)
		var replaced: Variant = _read(slot)
		error = _publish(slot, next)
		if error == OK:
			_clean_replaced(path, replaced, old_index, next_index)
			return {"error": OK, "commit": next}
	for file in created:
		DirAccess.remove_absolute(file)
	return {"error": error}


static func region_of(coord: Vector3i) -> Vector3i:
	return Vector3i(coord.x >> REGION_SHIFT, coord.y >> REGION_SHIFT, coord.z >> REGION_SHIFT)


static func _load_regions(path: String, index: Dictionary) -> Variant:
	var chunks := {}
	for coord: Variant in index:
		if not coord is Vector3i or not _valid_token(index[coord]):
			return null
		var records: Variant = _read_region(path, index[coord], coord)
		if records == null:
			return null
		for chunk: Variant in records:
			if not chunk is Vector3i or region_of(chunk) != coord:
				return null
			var value: Variant = records[chunk]
			if not value is Array or value.size() != 3:
				return null
			var blocks: Variant = Codec.decode(value[0])
			if blocks == null or not _valid_props(value[1]) or not _valid_components(value[2]):
				return null
			chunks[chunk] = {"blocks": blocks, "props": value[1], "components": value[2]}
	return chunks


static func _valid_props(props: Variant) -> bool:
	if not props is Dictionary:
		return false
	for cell: Variant in props:
		var id: Variant = props[cell]
		if not _valid_cell(cell) or not (id is StringName or id is String):
			return false
		if not String(id).is_empty() and ContentRegistry.namespace_of(StringName(id)).is_empty():
			return false
	return true


static func _valid_components(cells: Variant) -> bool:
	if not cells is Dictionary:
		return false
	for cell: Variant in cells:
		if not _valid_cell(cell) or not cells[cell] is Dictionary:
			return false
		for id: Variant in cells[cell]:
			if not (id is StringName or id is String) or ContentRegistry.namespace_of(StringName(id)).is_empty():
				return false
			if not VoxelWorldData.is_persistent_value(cells[cell][id]):
				return false
	return true


static func _valid_cell(cell: Variant) -> bool:
	return cell is int and cell >= 0 and cell < VoxelChunkData.VOLUME


static func _valid_token(token: Variant) -> bool:
	return token is String and token.length() == 32 and token.is_valid_hex_number() \
		and not token.begins_with("-") and not token.begins_with("+")


static func _read_region(path: String, token: String, region: Vector3i) -> Variant:
	var value: Variant = _read(_region_path(path, token))
	if value is Array and value.size() == 2 and value[0] == region and value[1] is Dictionary:
		return value[1]
	return null


static func _read(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var length := file.get_length()
	if length <= HEADER_BYTES or length > MAX_FILE_BYTES or file.get_32() != MAGIC:
		return null
	var digest := file.get_buffer(32)
	var payload := file.get_buffer(length - HEADER_BYTES)
	if payload.size() != length - HEADER_BYTES or digest != _digest(payload):
		return null
	return bytes_to_var(payload)


static func _publish(path: String, data: Variant) -> Error:
	var payload := var_to_bytes(data)
	if payload.is_empty() or payload.size() + HEADER_BYTES > MAX_FILE_BYTES:
		return ERR_INVALID_DATA
	var pending := path + ".tmp"
	var file := FileAccess.open(pending, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var stored := file.store_32(MAGIC) and file.store_buffer(_digest(payload)) and file.store_buffer(payload)
	file.flush()
	var error := file.get_error()
	file.close()
	if not stored and error == OK:
		error = ERR_FILE_CANT_WRITE
	if error == OK:
		error = DirAccess.rename_absolute(pending, path)
	if error != OK:
		DirAccess.remove_absolute(pending)
	return error


static func _digest(bytes: PackedByteArray) -> PackedByteArray:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish()


static func _clean_replaced(path: String, replaced: Variant, old_index: Dictionary, next_index: Dictionary) -> void:
	if not replaced is Dictionary or not replaced.get("regions") is Dictionary:
		return
	var live := {}
	for token: Variant in old_index.values():
		live[token] = true
	for token: Variant in next_index.values():
		live[token] = true
	for token: Variant in replaced.regions.values():
		if _valid_token(token) and not live.has(token):
			DirAccess.remove_absolute(_region_path(path, token))


static func _commit_path(path: String, slot: int) -> String:
	return path.path_join("commit-%d.dat" % slot)


static func _region_path(path: String, token: String) -> String:
	return path.path_join("region-%s.dat" % token)
