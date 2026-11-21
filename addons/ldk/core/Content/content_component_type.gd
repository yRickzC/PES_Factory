@tool
class_name ContentComponentType
extends Resource
## Metadata and default Resource for a component offered by a content editor.

@export var display_name: String
@export var category: String
@export_multiline var description: String
@export_multiline var purpose: String
@export var icon: Texture2D
@export var targets: Array[StringName] = []
@export var prototype: Resource


func new_component() -> Resource:
	# Keep Resource dependencies shared while giving the new node its own values.
	return prototype.duplicate_deep(Resource.DEEP_DUPLICATE_NONE) if prototype != null else null
