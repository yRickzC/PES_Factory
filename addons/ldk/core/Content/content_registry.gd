@tool
class_name ContentRegistry
extends RefCounted

var _entries: Dictionary[StringName, Resource] = {}
var _frozen := false


static func normalize_id(id: StringName) -> StringName:
	var value := String(id)
	return StringName(value.replace("@", ":")) if "@" in value else id


static func namespace_of(id: StringName) -> String:
	var parts := String(normalize_id(id)).split(":")
	if parts.size() != 2:
		return ""
	for part in parts:
		if part.is_empty() or part[0] < "a" or part[0] > "z":
			return ""
		for character in part:
			if character not in "abcdefghijklmnopqrstuvwxyz0123456789_":
				return ""
	return parts[0]


func register(id: StringName, resource: Resource) -> bool:
	id = normalize_id(id)
	if _frozen or namespace_of(id).is_empty() or resource == null or _entries.has(id):
		return false
	_entries[id] = resource
	return true


func find(id: StringName) -> Resource:
	var resource: Resource = _entries.get(id)
	return resource if resource != null else _entries.get(normalize_id(id))


func ids() -> Array[StringName]:
	return _entries.keys()


func replace(id: StringName, resource: Resource) -> bool:
	id = normalize_id(id)
	if _frozen or not _entries.has(id) or resource == null:
		return false
	_entries[id] = resource
	return true


func freeze() -> void:
	_frozen = true

