@tool
class_name ContentDrops
extends Resource

@export_group("Recompensas de quebra")
## IDs das recompensas e quantidade mínima de cada item.
@export var items: Dictionary[StringName, int] = {}
## Quantidade máxima por item. Se omitida, a quantidade é fixa.
@export var maximum_by_item: Dictionary[StringName, int] = {}


func quantity_for(id: StringName) -> int:
	var minimum: int = items.get(id, 0)
	var maximum: int = maximum_by_item.get(id, minimum)
	return randi_range(minimum, maximum) if maximum > minimum else minimum
