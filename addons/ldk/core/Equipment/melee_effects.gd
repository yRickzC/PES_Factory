@tool
class_name MeleeEffects
extends Resource
## Pixel-art settings for the motion trail and the confirmed hit.

@export var trail_texture: Texture2D
@export var trail_color := Color("#d0f9dd")
@export_range(0.01, 0.3, 0.005, "suffix:s") var trail_seconds := 0.085
@export_range(0.01, 0.2, 0.005) var trail_pixel_size := 0.063
@export_range(0.1, 1.0, 0.05) var trail_reach_fraction := 0.83
@export_range(0.0, 1.0, 0.05) var trail_height := 0.28
@export var hit_texture: Texture2D
@export var hit_color := Color("#ffe497")
@export_range(0.01, 1.0, 0.01, "suffix:s") var hit_seconds := 0.17
@export_range(0.01, 0.2, 0.005) var hit_pixel_size := 0.08
@export_range(0.0, 2.0, 0.05) var hit_height_offset := 0.55
