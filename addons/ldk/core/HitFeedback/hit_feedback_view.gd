class_name HitFeedbackView
extends RefCounted
## Drives a visual root and exposes its camera impulse.

const FLASH_SHADER: Shader = preload("res://addons/ldk/core/HitFeedback/hit_flash.gdshader")
const SHAKE_STEPS: Array[Vector2] = [
	Vector2(1.0, 0.5), Vector2(-0.85, -0.55), Vector2(0.65, -0.7),
	Vector2(-0.45, 0.4), Vector2(0.25, -0.25),
]

var _visual: Node3D
var _rest_scale: Vector3
var _rest_position: Vector3
var _received: HitFeedbackProfile
var _confirmed: HitFeedbackProfile
var _received_age := 0.0
var _confirmed_age := 0.0
var _received_frame := -1
var _confirmed_frame := -1
var _recoil_direction := Vector3.ZERO
var _flash_mesh: ShaderMaterial
var _flash_sprites: Dictionary[Sprite3D, ShaderMaterial] = {}
var _previous_overlays: Dictionary[GeometryInstance3D, Material] = {}


func _init(visual: Node3D) -> void:
	_visual = visual
	_rest_scale = visual.scale
	_rest_position = visual.position


func receive(profile: HitFeedbackProfile) -> void:
	_received = profile
	_received_age = 0.0
	_received_frame = Engine.get_physics_frames()
	_clear_flash()
	if profile.flash_strength > 0.0 and profile.flash_seconds > 0.0:
		_flash(_visual, profile.flash_strength)
		for node in _visual.find_children("*", "GeometryInstance3D", true, false):
			_flash(node as Node3D, profile.flash_strength)
		if _flash_mesh != null:
			_flash_mesh.set_shader_parameter(&"strength", profile.flash_strength)
	_present_deformation()


func confirm(profile: HitFeedbackProfile, direction: Vector3) -> void:
	_confirmed = profile
	_confirmed_age = 0.0
	_confirmed_frame = Engine.get_physics_frames()
	_recoil_direction = Vector3(-direction.x, 0.0, -direction.z).normalized()
	_present_recoil()


func advance(delta: float) -> void:
	if _received == null and _confirmed == null:
		return
	var frame := Engine.get_physics_frames()
	if _received != null and frame != _received_frame:
		_received_age += delta
		if not _previous_overlays.is_empty() and _received_age >= _received.flash_seconds:
			_clear_flash()
		_present_deformation()
		if _received_age >= maxf(_received.flash_seconds, _received.deformation_seconds):
			_received = null
	if _confirmed != null and frame != _confirmed_frame:
		_confirmed_age += delta
		_present_recoil()
		if _confirmed_age >= maxf(_confirmed.recoil_seconds, _confirmed.camera_shake_seconds):
			_confirmed = null


func camera_shake_pixels() -> Vector2:
	if _confirmed == null or _confirmed_age >= _confirmed.camera_shake_seconds:
		return Vector2.ZERO
	var step := _shake_step(_confirmed_age / _confirmed.camera_shake_seconds)
	return (SHAKE_STEPS[step] * _confirmed.camera_shake_pixels).round()


func reset() -> void:
	_received = null
	_confirmed = null
	_clear_flash()
	_visual.scale = _rest_scale
	_visual.position = _rest_position


func _present_deformation() -> void:
	var next_scale := _rest_scale
	if _received_age < _received.deformation_seconds:
		var progress := _received_age / _received.deformation_seconds
		var squash := _received.squash_scale
		var stretch := _received.stretch_scale
		var multiplier := squash.lerp(stretch, smoothstep(0.12, 0.42, progress))
		if progress >= 0.42:
			multiplier = stretch.lerp(Vector3.ONE, smoothstep(0.42, 1.0, progress))
		next_scale *= multiplier
	if _visual.scale != next_scale:
		_visual.scale = next_scale


func _present_recoil() -> void:
	var next_position := _rest_position
	if _confirmed_age < _confirmed.recoil_seconds:
		var sample := SHAKE_STEPS[_shake_step(_confirmed_age / _confirmed.recoil_seconds)]
		var side := Vector3(-_recoil_direction.z, 0.0, _recoil_direction.x)
		var offset := _recoil_direction * absf(sample.x) + side * sample.y * 0.35
		var parent := _visual.get_parent() as Node3D
		if parent != null:
			offset = parent.global_basis.inverse() * offset
		next_position += offset * _confirmed.recoil_distance
	if _visual.position != next_position:
		_visual.position = next_position


func _flash(node: Node3D, strength: float) -> void:
	var surface := node as GeometryInstance3D
	var material: ShaderMaterial
	if surface is MeshInstance3D:
		if _flash_mesh == null:
			_flash_mesh = _make_flash()
		material = _flash_mesh
	elif surface is Sprite3D:
		var sprite := surface as Sprite3D
		if sprite.texture == null:
			return
		if not _flash_sprites.has(sprite):
			_flash_sprites[sprite] = _make_flash()
		material = _flash_sprites[sprite]
		var mask := sprite.texture
		if mask is AtlasTexture:
			mask = (mask as AtlasTexture).atlas
		material.set_shader_parameter(&"masked", true)
		material.set_shader_parameter(&"mask_texture", mask)
		var cutoff := sprite.alpha_scissor_threshold if sprite.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD else 0.0
		material.set_shader_parameter(&"alpha_cutoff", cutoff)
		material.set_shader_parameter(&"billboard_mode", sprite.billboard)
		material.set_shader_parameter(&"strength", strength)
	if material == null:
		return
	_previous_overlays[surface] = surface.material_overlay
	surface.material_overlay = material


func _clear_flash() -> void:
	for surface in _previous_overlays:
		if is_instance_valid(surface):
			surface.material_overlay = _previous_overlays[surface]
	_previous_overlays.clear()


static func _make_flash() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FLASH_SHADER
	return material


static func _shake_step(progress: float) -> int:
	return mini(int(progress * SHAKE_STEPS.size()), SHAKE_STEPS.size() - 1)
