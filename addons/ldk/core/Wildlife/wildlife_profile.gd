@tool
class_name WildlifeProfile
extends Resource
## Shared definition. Health, goals and state timers belong to live actors.

@export_group("Attributes")
@export_range(1, 1000) var max_health := 10
@export_range(0.1, 12.0, 0.05) var walk_speed := 1.55
@export_range(0.1, 16.0, 0.05) var flee_speed := 3.15
@export_range(0.1, 40.0, 0.1) var acceleration := 8.0
@export_range(0.05, 1.0, 0.01) var ground_probe_distance := 0.4
@export_range(0, 3) var max_step_down := 1
## Minimum landing speed before fall damage starts. Zero fall damage per speed disables it.
@export_range(0.0, 40.0, 0.1) var safe_landing_speed := 7.5
@export_range(0.0, 10.0, 0.1) var fall_damage_per_speed := 2.0
@export var hit_feedback: HitFeedbackProfile

@export_group("Behaviour")
@export var idle_seconds := Vector2(0.7, 2.7)
@export var wander_seconds := Vector2(1.5, 4.0)
@export var forage_seconds := Vector2(1.0, 2.8)
@export var cooling_seconds := Vector2(1.8, 3.5)
@export var flee_seconds := Vector2(2.0, 3.8)
@export_range(0.0, 5.0, 0.05) var death_seconds := 0.4
@export_range(0.0, 1.0, 0.01) var forage_chance := 0.42
@export_range(0.0, 1.0, 0.01) var cooling_chance := 0.28
@export_range(0, 12) var cooling_search_cells := 6
@export var cooling_blocks: Array[StringName] = []
@export var forage_ground: Array[StringName] = []
@export_range(0.0, 24.0, 0.1) var cohesion_distance := 5.0
@export_range(0.0, 1.0, 0.01) var cohesion_strength := 0.7

@export_group("Spawn")
## Probability of finding one group in a horizontal chunk, indexed by biome ID.
@export var chance_by_biome: Dictionary[StringName, float] = {}
@export var spawn_ground: Array[StringName] = []
@export var elevation := Vector2i(-32, 80)
@export_range(0, 4) var max_spawn_slope := 1
@export var group_size := Vector2i(2, 4)
@export_range(1, 16) var region_limit := 4
@export_range(1, 8) var group_radius := 4
@export_range(1, 64) var group_attempts := 22
@export_range(0.0, 64.0, 0.5) var spawn_min_distance := 6.0
@export_range(1.0, 96.0, 0.5) var spawn_distance := 27.0
@export_range(1.0, 120.0, 0.5) var unload_distance := 36.0
