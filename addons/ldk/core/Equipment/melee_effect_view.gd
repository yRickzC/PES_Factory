class_name MeleeEffectView
extends Node3D
## Uses the attack clock for the trail and presents confirmed contacts in world space.

const TRAIL_SAMPLES := 7

var _trail: Array[Sprite3D] = []
var _hits: Array[Hit] = []


class Hit:
	var sprite: Sprite3D
	var remaining := 0.0
	var duration: float
	var color: Color


func present(machine: ActorStateMachine, effects: MeleeEffects, delta: float) -> void:
	advance_hits(delta)
	var weapon := machine.action as MeleeWeapon
	if weapon == null or effects == null or effects.trail_texture == null:
		_hide_trail()
		return
	var elapsed := machine.elapsed
	var newest := minf(elapsed, weapon.impact_end_time())
	var oldest := maxf(weapon.impact_time(), elapsed - effects.trail_seconds)
	if newest <= oldest:
		_hide_trail()
		return
	if _trail.is_empty():
		for index in TRAIL_SAMPLES:
			_trail.append(_make_sprite())
	var origin := global_position + Vector3.UP * (weapon.origin_height + effects.trail_height)
	var radius := weapon.reach * effects.trail_reach_fraction
	for index in TRAIL_SAMPLES:
		var weight := float(index) / (TRAIL_SAMPLES - 1)
		var elapsed_sample := lerpf(oldest, newest, weight)
		var direction := weapon.sweep_direction(machine.attack_direction, elapsed_sample)
		var sprite := _trail[index]
		sprite.texture = effects.trail_texture
		sprite.global_position = origin + direction * radius
		sprite.pixel_size = effects.trail_pixel_size * lerpf(0.55, 1.0, weight)
		sprite.modulate = _fade(effects.trail_color, (elapsed - elapsed_sample) / effects.trail_seconds)
		sprite.show()


func show_hit(effects: MeleeEffects, point: Vector3) -> void:
	if effects == null or effects.hit_texture == null:
		return
	var hit: Hit
	for slot in _hits:
		if slot.remaining <= 0.0:
			hit = slot
			break
	if hit == null:
		hit = Hit.new()
		hit.sprite = _make_sprite()
		_hits.append(hit)
	hit.duration = effects.hit_seconds
	hit.remaining = hit.duration
	hit.color = effects.hit_color
	hit.sprite.texture = effects.hit_texture
	hit.sprite.global_position = point + Vector3.UP * effects.hit_height_offset
	hit.sprite.pixel_size = effects.hit_pixel_size
	hit.sprite.modulate = hit.color
	hit.sprite.show()


func advance_hits(delta: float) -> void:
	for hit in _hits:
		if hit.remaining > 0.0:
			hit.remaining -= delta
			if hit.remaining <= 0.0:
				hit.sprite.hide()
			else:
				hit.sprite.modulate = _fade(hit.color, 1.0 - hit.remaining / hit.duration)


func _hide_trail() -> void:
	for sprite in _trail:
		if sprite.visible:
			sprite.hide()


func _make_sprite() -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.top_level = true
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.hide()
	add_child(sprite)
	return sprite


static func _fade(color: Color, age: float) -> Color:
	color.a *= 1.0 - floorf(clampf(age, 0.0, 1.0) * 4.0) * 0.25
	return color
