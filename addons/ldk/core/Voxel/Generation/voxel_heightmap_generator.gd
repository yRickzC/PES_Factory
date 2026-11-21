class_name VoxelHeightmapGenerator
extends VoxelGenerator
## A heightmap strategy. Volume generators use the same VoxelGenerator contract.

const Generation = preload("res://addons/ldk/core/Voxel/Generation/voxel_world_generation.gd")
const BiomeRule = preload("res://addons/ldk/core/Voxel/Generation/voxel_world_biome.gd")

@export_group("Geração de terreno")
## Configurações usadas para calcular biomas, altura e água. Na partida, o gerador recebe o Resource do mundo.
@export var settings: Generation = Generation.new()
var biomes: Array[VoxelBiome] = []
var water_level: int
var floor_y: int

var _rules: Dictionary[StringName, BiomeRule]
var _elevation: Array[FastNoiseLite]
var _centers: Array[float]
var _elevation_limits: Array[Vector2]
var _amplitudes: Array[float]
var _smoothness: Array[float]
var _outcrop_noises: Array[FastNoiseLite]
var _outcrop_shapes: Array[Vector3]
var _soil_depths: Array[int]
var _relief_widths: Array[float]
var _material_widths: Array[float]
var _anchors: Array[Vector2]
var _inverse_sizes: Array[float]
var _weight_biases: Array[float]
var _widest_relief := 0.0
var _temperature: FastNoiseLite
var _moisture: FastNoiseLite
var _material_noise: FastNoiseLite
var _material_patchiness: float
var _basin_noise: FastNoiseLite
var _basin_depth := 0.0
var _basin_band: Vector2
var catalog: VoxelCatalog
var _water: PackedInt32Array
var _terrain: Array[Vector3i]
var _surface_variants: Array[PackedInt32Array]
var _soil_variants: Array[PackedInt32Array]
var _variant_chances: PackedFloat32Array
var _wide := false
var _limits: Vector2i
var _common_base := 0
var _deepest_soil := 0
var _floor_id := 0


func select_biomes(registry: ContentRegistry) -> void:
	biomes.clear()
	_rules.clear()
	for rule in settings.biomes:
		if rule == null or rule.biome == null:
			continue
		var key := ContentRegistry.normalize_id(rule.biome.key)
		if _rules.has(key):
			continue
		_rules[key] = rule
		if rule.frequency_weight <= 0.0:
			continue
		var registered := registry.find(key) as VoxelBiome
		biomes.append(registered if registered != null else rule.biome)
	if not biomes.is_empty():
		return
	if not settings.biomes.is_empty():
		push_warning("The world has no enabled biome. Using the registered biomes.")
		_rules.clear()
	for key in registry.ids():
		biomes.append(registry.find(key) as VoxelBiome)


func prepare() -> void:
	assert(not biomes.is_empty())
	water_level = settings.water_level
	floor_y = settings.floor_y
	_material_patchiness = settings.material_patchiness
	var climate_frequency := maxf(0.000001, settings.climate_frequency_scale / maxf(1.0, settings.biome_region_size))
	_temperature = _noise(0x4DB5AF, climate_frequency, settings.climate_octaves)
	_moisture = _noise(0x72E139, climate_frequency, settings.climate_octaves)
	_material_noise = _noise(0x07DE2A, settings.material_noise_frequency, 1)
	_prepare_basins()
	_limits = height_limits()
	_floor_id = 0 if settings.floor_key.is_empty() else maxi(0, catalog.id_for(settings.floor_key))
	if not settings.floor_key.is_empty() and _floor_id == 0:
		push_warning("Unknown world floor block: %s" % settings.floor_key)
	if _floor_id != 0:
		_limits.x = maxi(_limits.x, floor_y)
		_limits.y = maxi(_limits.y, floor_y)
	_elevation.clear()
	_centers.clear()
	_elevation_limits.clear()
	_amplitudes.clear()
	_smoothness.clear()
	_outcrop_noises.clear()
	_outcrop_shapes.clear()
	_soil_depths.clear()
	_relief_widths.clear()
	_material_widths.clear()
	_anchors.clear()
	_inverse_sizes.clear()
	_weight_biases.clear()
	_terrain.clear()
	_surface_variants.clear()
	_soil_variants.clear()
	_variant_chances.clear()
	_water.clear()
	_widest_relief = 0.0
	_wide = _floor_id > 255
	var noises: Dictionary[float, FastNoiseLite] = {}
	for biome in biomes:
		var profile := _relief_for(biome)
		var frequency := maxf(0.000001, profile.noise_frequency * settings.elevation_frequency_scale)
		if not noises.has(frequency):
			noises[frequency] = _noise(0x29A37D, frequency, settings.elevation_octaves)
		_elevation.append(noises[frequency])
		_prepare_biome(biome, profile, frequency, climate_frequency)
		var terrain := Vector3i(catalog.resolve(biome.surface), catalog.resolve(biome.soil), catalog.resolve(biome.bedrock))
		_terrain.append(terrain)
		var liquid := settings.water_key if biome.water.is_empty() else biome.water
		var water := 0 if liquid.is_empty() else catalog.resolve(liquid)
		_water.append(water)
		_wide = _wide or maxi(maxi(terrain.x, terrain.y), maxi(terrain.z, water)) > 255
		_surface_variants.append(_resolve_variants(biome.surface_variants))
		_soil_variants.append(_resolve_variants(biome.soil_variants))
		_variant_chances.append(biome.terrain_variant_chance)
	_common_base = _terrain[0].z
	_deepest_soil = 0
	for index in biomes.size():
		if _terrain[index].z != _common_base:
			_common_base = 0
		_deepest_soil = maxi(_deepest_soil, _soil_depths[index])


func _resolve_variants(keys: Array[StringName]) -> PackedInt32Array:
	var variants := PackedInt32Array()
	for key in keys:
		var id := catalog.id_for(key)
		if id > 0:
			variants.append(id)
			_wide = _wide or id > 255
	return variants


static func _variant(base: int, alternatives: PackedInt32Array, roll: int, chance: float) -> int:
	if float(roll & 65535) / 65536.0 >= chance:
		return base
	return alternatives[(roll >> 16) % alternatives.size()]


func _prepare_biome(biome: VoxelBiome, profile: VoxelBiomeRelief, frequency: float, climate_frequency: float) -> void:
	var rule: BiomeRule = _rules.get(ContentRegistry.normalize_id(biome.key))
	var size_scale := rule.region_size_scale if rule != null else 1.0
	var weight := biome.distribution_weight * (rule.frequency_weight if rule != null else 1.0)
	_anchors.append(rule.climate if rule != null and rule.override_climate else biome.climate)
	_inverse_sizes.append(1.0 / maxf(0.01, size_scale))
	_weight_biases.append(log(maxf(0.0001, weight)) * settings.distribution_weight_strength)

	var smoothness := lerpf(profile.smoothness, 1.0, settings.elevation_smoothness)
	var amplitude := profile.amplitude * settings.amplitude_scale
	var slope := profile.desired_max_slope if profile.desired_max_slope >= 0.0 else settings.desired_max_slope
	var half_width := profile.transition_blocks * 0.5
	if profile.transition_blocks < 0.0:
		half_width = settings.relief_transition_width * 0.5 * profile.transition_width / 0.14
	if slope > 0.0:
		# Estimate fBm slope from frequency, octaves and shaping. Widen joins between distant elevations.
		var noise_gradient := 2.0 * frequency * (settings.elevation_octaves + 1) * (1.0 + smoothness)
		amplitude = minf(amplitude, slope / noise_gradient)
		var center := profile.limit_elevation(profile.base_height)
		var difference := maxf(center - _limits.x, _limits.y - center)
		half_width = maxf(half_width, difference / slope)
	_amplitudes.append(amplitude)
	_smoothness.append(smoothness)
	_centers.append(profile.base_height)
	_elevation_limits.append(Vector2(minf(profile.elevation_limits.x, profile.elevation_limits.y),
		maxf(profile.elevation_limits.x, profile.elevation_limits.y)))
	var outcrop_height := maxf(0.0, profile.outcrop_height * settings.amplitude_scale)
	var outcrop_noise: FastNoiseLite
	if outcrop_height > 0.0:
		var outcrop_frequency := maxf(0.000001, profile.outcrop_frequency * settings.elevation_frequency_scale)
		outcrop_noise = _noise(0x4E2F79, outcrop_frequency, profile.outcrop_octaves)
	var thresholds := profile.outcrop_thresholds
	var start := minf(thresholds.x, thresholds.y)
	var peak := maxf(start + 0.001, maxf(thresholds.x, thresholds.y))
	_outcrop_noises.append(outcrop_noise)
	_outcrop_shapes.append(Vector3(start, peak, outcrop_height))
	_soil_depths.append(biome.soil_depth)
	# Convert block widths to score differences using the characteristic climate gradient.
	var gradient := 2.0 * climate_frequency
	var width := half_width * gradient
	_relief_widths.append(width)
	_widest_relief = maxf(_widest_relief, width)
	var material_width := settings.material_transition_width
	if biome.material_transition_width >= 0.0:
		material_width = biome.material_transition_width
	if rule != null and rule.material_transition_width >= 0.0:
		material_width = rule.material_transition_width
	_material_widths.append(material_width * 0.5 * gradient)


func _prepare_basins() -> void:
	_basin_noise = null
	if not settings.basins_enabled or settings.basin_depth <= 0.0:
		return
	var frequency := maxf(0.000001, settings.basin_frequency)
	_basin_noise = _noise(0x5B953B, frequency, settings.basin_octaves)
	_basin_band.x = minf(settings.basin_thresholds.x, settings.basin_thresholds.y)
	_basin_band.y = maxf(_basin_band.x + 0.001, maxf(settings.basin_thresholds.x, settings.basin_thresholds.y))
	_basin_depth = settings.basin_depth
	if settings.desired_max_slope > 0.0:
		var gradient := 3.0 * frequency * (settings.basin_octaves + 1)
		_basin_depth = minf(_basin_depth, settings.desired_max_slope * (_basin_band.y - _basin_band.x) / gradient)


func biome_index(key: StringName) -> int:
	for index in biomes.size():
		if biomes[index].key == key:
			return index
	return -1


func height_limits() -> Vector2i:
	var low := INF
	var high := -INF
	for biome in biomes:
		var profile := _relief_for(biome)
		var amplitude := profile.amplitude * settings.amplitude_scale
		low = minf(low, profile.limit_elevation(profile.base_height - amplitude))
		var outcrop_height := maxf(0.0, profile.outcrop_height * settings.amplitude_scale)
		high = maxf(high, profile.limit_elevation(profile.base_height + amplitude + outcrop_height))
	if settings.basins_enabled:
		low -= settings.basin_depth
	return Vector2i(floori(low), ceili(high))


## Returns the elevation bounds computed during prepare(), including the world floor.
func surface_height_limits() -> Vector2i:
	return _limits


func sample_column(x: int, z: int) -> Vector2i:
	var column := _sample_column(x, z)
	var height := roundi(column.x)
	return Vector2i(maxi(height, floor_y) if _floor_id != 0 else height, int(column.y))


func column_is_flooded(column: Vector2i) -> bool:
	return column.x < water_level and _water[column.y] != 0


## Continuous height and material index. Height modifiers run before rounding to the grid.
func _sample_column(x: int, z: int) -> Vector2:
	var climate := Vector2(
		_temperature.get_noise_2d(x, z), _moisture.get_noise_2d(x, z)
	)
	var nearest := 0
	var second := 0
	var nearest_distance := INF
	var second_distance := INF
	for i in biomes.size():
		var distance := _climate_distance(climate, i)
		if distance < nearest_distance:
			second = nearest
			second_distance = nearest_distance
			nearest = i
			nearest_distance = distance
		elif distance < second_distance:
			second = i
			second_distance = distance
	var gap := second_distance - nearest_distance
	var height := _sample_relief(nearest, x, z)
	if gap < _widest_relief:
		height = _blend_relief(climate, nearest, nearest_distance, x, z, height)
	if _basin_noise != null:
		var carve := smoothstep(_basin_band.x, _basin_band.y, _basin_noise.get_noise_2d(x, z))
		height -= carve * _basin_depth
	return Vector2(height, _sample_material(nearest, second, gap, x, z))


func _blend_relief(climate: Vector2, nearest: int, score: float, x: int, z: int, height: float) -> float:
	# All tied profiles have equal weight. Material dither never affects this height.
	var sum := height
	var weights := 1.0
	for i in biomes.size():
		if i == nearest:
			continue
		var gap := _climate_distance(climate, i) - score
		var width := _relief_widths[i]
		if gap < width:
			var weight := 1.0 - smoothstep(0.0, width, gap)
			sum += _sample_relief(i, x, z) * weight
			weights += weight
	return sum / weights


func _sample_material(nearest: int, second: int, gap: float, x: int, z: int) -> int:
	var width := (_material_widths[nearest] + _material_widths[second]) * 0.5
	if gap >= width:
		return nearest
	var blend := 0.5 * (1.0 - smoothstep(0.0, width, gap))
	var grain := float(hash(Vector3i(x, world_seed, z)) & 1023) / 1024.0
	var patch := clampf(_material_noise.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)
	var sample := lerpf(grain, patch, _material_patchiness)
	# Keep the same orientation of the noise as the two climate scores cross.
	if nearest < second:
		return nearest if sample < 1.0 - blend else second
	return second if sample < blend else nearest


func allows_edit(cell: Vector3i) -> bool:
	return _floor_id == 0 or cell.y > floor_y


func generate_chunk(coord: Vector3i, cancel: VoxelCancellation) -> VoxelChunkData:
	var origin := coord * VoxelChunkData.SIZE
	var top := origin.y + VoxelChunkData.SIZE - 1
	if _floor_id != 0 and top < floor_y:
		return VoxelChunkData.new()
	if origin.y > maxi(_limits.y, water_level):
		return VoxelChunkData.new()
	if _common_base != 0 and top < _limits.x - _deepest_soil and (_floor_id == 0 or origin.y > floor_y):
		return VoxelChunkData.new(PackedByteArray(), _common_base)
	var cells: Variant = PackedInt32Array() if _wide else PackedByteArray()
	cells.resize(VoxelChunkData.VOLUME)
	var first := maxi(0, floor_y - origin.y) if _floor_id != 0 else 0
	for z in VoxelChunkData.SIZE:
		if cancel.is_cancelled():
			return null
		for x in VoxelChunkData.SIZE:
			var global_x := origin.x + x
			var global_z := origin.z + z
			var column := sample_column(global_x, global_z)
			var terrain := _terrain[column.y]
			var soil_depth := _soil_depths[column.y]
			var chance := _variant_chances[column.y]
			if chance > 0.0:
				var surfaces := _surface_variants[column.y]
				if column.x >= origin.y and column.x <= top and not surfaces.is_empty():
					var roll := hash(Vector3i(global_x, world_seed ^ 0x319DC7, global_z))
					terrain.x = _variant(terrain.x, surfaces, roll, chance)
				# A column retains the same subsoil across vertical chunk boundaries.
				var soils := _soil_variants[column.y]
				if soil_depth > 0 and column.x > origin.y and column.x - soil_depth <= top and not soils.is_empty():
					var roll := hash(Vector3i(global_x, world_seed ^ 0x8E75C3, global_z))
					terrain.y = _variant(terrain.y, soils, roll, chance)
			var offset := x + VoxelChunkData.SIZE * z
			var last := mini(top, maxi(column.x, water_level)) - origin.y
			for y in range(first, last + 1):
				var world_y := y + origin.y
				var id := terrain.z
				if _floor_id != 0 and world_y == floor_y:
					id = _floor_id
				elif world_y > column.x:
					id = _water[column.y]
				elif world_y == column.x:
					id = terrain.x
				elif world_y >= column.x - soil_depth:
					id = terrain.y
				cells[offset + y * VoxelChunkData.AREA] = id
	return VoxelChunkData.new(cells)


func _relief_for(biome: VoxelBiome) -> VoxelBiomeRelief:
	if biome.terrain_relief != null:
		return biome.terrain_relief
	var profile := VoxelBiomeRelief.new()
	profile.base_height = settings.base_height + biome.elevation_offset
	profile.amplitude = biome.relief
	profile.noise_frequency = settings.elevation_frequency
	profile.smoothness = 0.0
	return profile


func _sample_relief(index: int, x: int, z: int) -> float:
	var noise := clampf(_elevation[index].get_noise_2d(x, z), -1.0, 1.0)
	var shape := noise * lerpf(1.0, absf(noise), _smoothness[index])
	var height := _centers[index] + _amplitudes[index] * shape
	var outcrop := _outcrop_noises[index]
	if outcrop != null:
		var settings_for_outcrop := _outcrop_shapes[index]
		var rise := smoothstep(settings_for_outcrop.x, settings_for_outcrop.y, outcrop.get_noise_2d(x, z))
		height += rise * settings_for_outcrop.z
	var limits := _elevation_limits[index]
	return clampf(height, limits.x, limits.y)


func _climate_distance(climate: Vector2, index: int) -> float:
	return climate.distance_to(_anchors[index]) * _inverse_sizes[index] - _weight_biases[index]


func _noise(salt: int, frequency: float, octaves: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = world_seed ^ salt
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	return noise
