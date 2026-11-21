@tool
extends VBoxContainer
## Read-only Resource preview shared by category panels.

@onready var _title: Label = %Title
@onready var _origin: Label = %Origin
@onready var _properties: TextEdit = %Properties
@onready var _inspect: Button = %Inspect

var _resource: Resource


func _ready() -> void:
	_inspect.pressed.connect(_inspect_resource)


func show_resource(resource: Resource, path := "", content_namespace := "") -> void:
	_resource = resource
	var has_resource := resource != null
	_origin.visible = has_resource
	_properties.visible = has_resource
	_inspect.visible = has_resource
	if not has_resource:
		_title.text = "Selecione um Resource na árvore."
		_title.tooltip_text = ""
		_origin.text = ""
		_properties.clear()
		return

	var file_name := path.get_file()
	_title.text = "%s · %s" % [file_name, _resource_type(resource)]
	_title.tooltip_text = _title.text
	_origin.text = "%s\n%s" % [content_namespace, path]
	_origin.tooltip_text = path
	var lines := PackedStringArray()
	for property in resource.get_property_list():
		var usage: int = property.usage
		if not (usage & PROPERTY_USAGE_EDITOR):
			continue
		if usage & (PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SUBGROUP):
			continue
		var property_name: String = property.name
		if property_name in ["script", "resource_name", "resource_path", "resource_local_to_scene"]:
			continue
		lines.append("%s: %s" % [property_name.capitalize(), _format_value(resource.get(property_name))])
	_properties.text = "\n".join(lines) if not lines.is_empty() else "Sem propriedades para exibir."


func _inspect_resource() -> void:
	if _resource != null:
		EditorInterface.edit_resource(_resource)


static func _resource_type(resource: Resource) -> String:
	var script := resource.get_script() as Script
	if script != null and not script.get_global_name().is_empty():
		return script.get_global_name()
	return resource.get_class()


static func _format_value(value: Variant) -> String:
	if value is Resource:
		return value.resource_path if not value.resource_path.is_empty() else _resource_type(value)
	match typeof(value):
		TYPE_NIL:
			return "—"
		TYPE_ARRAY, TYPE_DICTIONARY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, \
		TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, \
		TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, \
		TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY:
			return "%s (%d)" % [type_string(typeof(value)), value.size()]
		_:
			return str(value)
