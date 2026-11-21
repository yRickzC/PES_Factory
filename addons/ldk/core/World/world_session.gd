extends Node3D
## Context assigned by the loader before the world's nodes enter the tree.

const Save = preload("res://addons/ldk/core/World/world_save.gd")
const Preset = preload("res://addons/ldk/core/World/world_definition.gd")

var world_save: Save
var world_selection_path: String


func prepare_persistence() -> Error:
	return OK


func choose_world_seed(definition: Preset) -> int:
	return world_save.seed if world_save != null else definition.choose_seed()
