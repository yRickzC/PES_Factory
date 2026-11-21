extends DemoVoxelGenerator
## Fixed terrain and landmarks for the scene integration checks.

const LANDMARK := preload("res://src/World/Checks/landmark_blocks.gd")

@export_group("Marco de verificação")
## Altura Y do terreno e da construção de referência no mapa de verificação.
@export var landmark_elevation := LANDMARK.GROUND_ELEVATION
## Coordenada X/Z em torno da qual o terreno é nivelado para o marco.
@export var landmark_center := Vector2(1, 4)
## Raios em blocos para o início em X e o fim em Y da transição do terreno nivelado para o terreno procedural.
@export var landmark_blend_radii := Vector2(8.5, 19.0)
## Raio em blocos que usa a pradaria ao redor do marco.
@export var landmark_meadow_radius := 9.0

@export_group("Lago de verificação")
## Coordenada X/Z que centraliza a depressão do lago de verificação.
@export var pond_center := Vector2(13, -5)
## Escalas aplicadas à distância em X e Z. Aumentar um componente estreita o lago naquele eixo.
@export var pond_axis_scale := Vector2(1.0, 1.23)
## Raios em blocos para o início em X e o fim em Y da transição da parte plana do fundo para a margem.
@export var pond_blend_radii := Vector2(3.5, 11.0)
## Altura Y do fundo plano do lago. O lago enche se o fundo ficar abaixo do nível da água.
@export var pond_bed_height := 0.0

var _meadow: int
var _desert: int

var _landmark_chunks: Dictionary[Vector3i, Dictionary] = {}


func _init(content: ContentDB, block_catalog: VoxelCatalog, generation: Generation) -> void:
	super(content, block_catalog, generation)
	_meadow = biome_index(&"core:meadow")
	_desert = biome_index(&"core:desert")


func prepare() -> void:
	super.prepare()
	_landmark_chunks.clear()
	var cells := LANDMARK.create()
	var offset := Vector3i.UP * (landmark_elevation - LANDMARK.GROUND_ELEVATION)
	for source in cells:
		var cell := source + offset
		if not allows_edit(cell):
			continue
		var coord := VoxelChunkData.chunk_of(cell)
		if not _landmark_chunks.has(coord):
			var edits: Dictionary[int, int] = {}
			_landmark_chunks[coord] = edits
		_landmark_chunks[coord][VoxelChunkData.index_of(VoxelChunkData.local_of(cell))] = catalog.resolve(cells[source])


func height_limits() -> Vector2i:
	var limits := super.height_limits()
	limits.x = mini(limits.x, mini(landmark_elevation, floori(pond_bed_height)))
	limits.y = maxi(limits.y, maxi(landmark_elevation, ceili(pond_bed_height)))
	return limits


func _sample_column(x: int, z: int) -> Vector2:
	var column := super._sample_column(x, z)
	var point := Vector2(x, z)
	var meadow := point.distance_to(landmark_center)
	var landmark_blend := smoothstep(landmark_blend_radii.x, landmark_blend_radii.y, meadow)
	var height := lerpf(landmark_elevation, column.x, landmark_blend)
	if meadow < landmark_meadow_radius:
		column.y = _meadow
	var pond := ((point - pond_center) * pond_axis_scale).length()
	if pond < pond_blend_radii.y:
		height = lerpf(pond_bed_height, height, smoothstep(pond_blend_radii.x, pond_blend_radii.y, pond))
		if roundi(height) <= water_level + 1:
			column.y = _desert
	column.x = height
	return column


func generate_chunk(coord: Vector3i, cancel: VoxelCancellation) -> VoxelChunkData:
	var data := super.generate_chunk(coord, cancel)
	if data == null or cancel.is_cancelled():
		return null
	if _landmark_chunks.has(coord):
		return data.with_changes(_landmark_chunks[coord])
	return data

