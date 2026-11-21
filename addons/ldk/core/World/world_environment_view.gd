extends WorldEnvironment
## Applies a shared preset without writing the animated values back to its assets.

const Settings = preload("res://addons/ldk/core/World/world_environment_config.gd")

var _settings: Settings
var _sun: DirectionalLight3D
var _phase := 0.0
var _ambient_energy: float
var _background_energy: float
var _night_tint: ColorRect


func _ready() -> void:
	set_process(false)


func configure(settings: Settings, sun: DirectionalLight3D) -> void:
	_settings = settings
	_sun = sun
	var atmosphere := settings.atmosphere if settings.atmosphere != null else Environment.new()
	environment = atmosphere.duplicate() as Environment if settings.cycle_enabled else atmosphere
	_ambient_energy = atmosphere.ambient_light_energy
	_background_energy = atmosphere.background_energy_multiplier
	sun.rotation_degrees = settings.sun_rotation
	sun.light_color = settings.sun_color
	sun.light_energy = settings.sun_energy
	sun.shadow_enabled = settings.shadows_enabled
	sun.directional_shadow_mode = settings.shadow_mode
	sun.directional_shadow_max_distance = settings.shadow_distance
	_phase = fposmod(settings.start_hour / 24.0, 1.0)
	set_process(settings.cycle_enabled)
	if _night_tint != null:
		_night_tint.hide()
	if settings.cycle_enabled:
		if _night_tint == null and settings.night_world_tint != Color.WHITE:
			_create_night_tint()
		_update_lighting()


func _create_night_tint() -> void:
	# Composite after the 3D scene and before the HUD so unlit sprites also darken.
	var tint_layer := CanvasLayer.new()
	tint_layer.name = "NightTint"
	tint_layer.layer = -1
	add_child(tint_layer)

	var tint_material := CanvasItemMaterial.new()
	tint_material.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	tint_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_night_tint = ColorRect.new()
	_night_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_night_tint.material = tint_material
	tint_layer.add_child(_night_tint)
	_night_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_phase = fposmod(_phase + delta / maxf(1.0, _settings.cycle_duration), 1.0)
	_update_lighting()


func _update_lighting() -> void:
	# Noon is the preset sun direction. At the horizon the light crossfades to moonlight.
	var angle := (_phase - 0.5) * TAU
	var elevation := cos(angle)
	var twilight := maxf(0.01, _settings.twilight_width)
	var daylight := smoothstep(-twilight, twilight, elevation)
	var rotation := _settings.sun_rotation
	rotation.x *= absf(elevation)
	rotation.y += _settings.sun_azimuth_swing * sin(angle)
	_sun.rotation_degrees = rotation
	_sun.light_energy = lerpf(_settings.night_energy, _settings.sun_energy, daylight)
	_sun.light_color = _settings.night_color.lerp(_settings.sun_color, daylight)
	environment.ambient_light_energy = _ambient_energy * lerpf(_settings.night_ambient_multiplier, 1.0, daylight)
	environment.background_energy_multiplier = _background_energy * lerpf(_settings.night_background_multiplier, 1.0, daylight)
	if _night_tint != null:
		_night_tint.visible = daylight < 1.0 and _settings.night_world_tint != Color.WHITE
		if _night_tint.visible:
			_night_tint.color = _settings.night_world_tint.lerp(Color.WHITE, daylight)
