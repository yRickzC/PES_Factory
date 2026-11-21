@tool
class_name PlayerSpriteProfile
extends Resource
## Source atlas layout, grip coordinates and stepping cadence for the explorer.

@export var frame_size := Vector2i(16, 26)
@export var head_height := 16
@export var hand_region := Rect2(5, 13, 3, 2)
## Atlas order: down, left, right, up. Coordinates are relative to the frame center.
@export var hand_positions := PackedVector2Array([
	Vector2(5, 6), Vector2(-5, 6), Vector2(5, 6), Vector2(5, 4)
])
@export var grip_depth := 0.12
@export_range(0.05, 1.0, 0.01, "suffix:s") var walk_step_seconds := 0.14
@export_range(0, 4, 1, "suffix:px") var walk_bob_pixels := 1

@export_group("Corrida")
@export_range(0.05, 1.0, 0.01, "suffix:s") var run_step_seconds := 0.10
@export_range(0, 4, 1, "suffix:px") var run_bob_pixels := 2
@export var run_arm_swing_pixels := Vector2i(1, 2)
@export_range(0, 3, 1, "suffix:px") var run_lean_pixels := 1
## Intensidade horizontal e vertical da câmera a cada passada, em pixels do viewport.
@export var run_shake_amplitude := Vector2(0.7, 0.9)
@export_range(0.01, 1.0, 0.01, "suffix:s") var run_shake_fade_seconds := 0.12
