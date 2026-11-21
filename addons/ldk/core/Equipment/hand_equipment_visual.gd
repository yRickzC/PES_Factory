@tool
class_name HandEquipmentVisual
extends Resource
## Pixel offsets use the source image's axes. Swing angles use the sprite's local Z axis.

@export var texture: Texture2D
@export var grip_pixel := Vector2.ZERO
@export var rest_angle := 0.0
@export var raised_angle := 45.0
@export var impact_angle := -75.0
@export var raised_offset := Vector2(-1.0, -4.0)
@export var impact_offset := Vector2(5.0, -1.0)
@export_range(0.1, 0.9, 0.05) var raise_fraction := 0.55
@export_range(1, 8, 1) var steps_per_phase := 2
@export var melee_effects: MeleeEffects
