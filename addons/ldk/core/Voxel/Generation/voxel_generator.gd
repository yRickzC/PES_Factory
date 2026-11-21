class_name VoxelGenerator
extends Resource
## Configure once on the main thread, then sample concurrently without mutation.

@export_group("Seed do gerador")
## Valor que determina o resultado do ruído procedural. Ao iniciar o mundo, a seed da sessão é aplicada aqui.
@export var world_seed := 1729


func prepare() -> void:
	pass


func allows_edit(_cell: Vector3i) -> bool:
	return true


func generate_chunk(_coord: Vector3i, _cancel: VoxelCancellation) -> VoxelChunkData:
	return VoxelChunkData.new()
