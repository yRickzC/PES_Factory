class_name VoxelChunkJob
extends RefCounted
## Task-owned output. It may be read after WorkerThreadPool has joined this task.

var coord: Vector3i
var task_id: int
var revision: int
var cancel := VoxelCancellation.new()
var generated: VoxelChunkData
var geometry: VoxelMeshPayload
var elapsed_usec: int


func generate(generator: VoxelGenerator) -> void:
	var started := Time.get_ticks_usec()
	if not cancel.is_cancelled():
		generated = generator.generate_chunk(coord, cancel)
	elapsed_usec = Time.get_ticks_usec() - started


func mesh(
	center: VoxelChunkData, neighbors: Array[VoxelChunkData], catalog: VoxelCatalog
) -> void:
	var started := Time.get_ticks_usec()
	if not cancel.is_cancelled():
		geometry = VoxelChunkMesher.new().build(center, neighbors, catalog, cancel)
	elapsed_usec = Time.get_ticks_usec() - started
