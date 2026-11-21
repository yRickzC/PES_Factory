@tool
class_name ContentSceneCollision
extends Resource

@export_group("Colisão estática")
## Forma física reutilizada por todas as instâncias desta definição.
@export var shape: Shape3D
## Deslocamento da forma em relação à origem do objeto.
@export var offset := Vector3.ZERO
## Camadas nas quais os raios e corpos podem detectar a colisão.
@export_flags_3d_physics var layers := 1
## Camadas de outros corpos que esta colisão considera.
@export_flags_3d_physics var mask := 0


func attach_to(root: Node3D) -> void:
	if shape == null:
		return
	var body := StaticBody3D.new()
	body.collision_layer = layers
	body.collision_mask = mask
	var collider := CollisionShape3D.new()
	collider.position = offset
	collider.shape = shape
	body.add_child(collider)
	root.add_child(body)
