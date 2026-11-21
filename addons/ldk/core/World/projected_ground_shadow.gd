class_name ProjectedGroundShadow
extends Sprite3D
## Reusable ground projection, updated from the actor's physics step.

@export_group("Projeção no chão")
## Camadas físicas em que a sombra procura chão, escadas e plataformas.
@export_flags_3d_physics var ground_mask := 1
## Distância máxima de projeção abaixo dos pés. A sombra some se nenhuma superfície válida for encontrada.
@export var reach := 12.0

var height_above_ground := 0.0
var _ray := PhysicsRayQueryParameters3D.new()
var _tint: Color


func _ready() -> void:
	top_level = true
	_tint = modulate
	_ray.collision_mask = ground_mask
	hide()


func exclude_body(body: CollisionObject3D) -> void:
	_ray.exclude = [body.get_rid()]


func project_from(feet: Vector3) -> void:
	_ray.from = feet + Vector3.UP * 0.16
	_ray.to = feet - Vector3.UP * reach
	var hit := get_world_3d().direct_space_state.intersect_ray(_ray)
	if hit.is_empty():
		hide()
		return
	var ground: Vector3 = hit.position
	var normal: Vector3 = hit.normal
	if normal.y <= 0.05:
		hide()
		return
	height_above_ground = maxf(feet.y - ground.y, 0.0)
	var fade := clampf(height_above_ground / 2.5, 0.0, 1.0)
	var right := Vector3.RIGHT.slide(normal).normalized()
	var basis_on_ground := Basis(right, normal.cross(right), normal)
	var size := lerpf(1.0, 0.76, fade)
	global_transform = Transform3D(basis_on_ground.scaled_local(Vector3(size, size, 1.0)), ground + normal * 0.021)
	modulate = Color(_tint, _tint.a * lerpf(1.0, 0.52, fade))
	show()

