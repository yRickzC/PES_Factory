extends Resource
## Storage and quick slots are ranges of the same SlotInventory.

@export_group("Capacidade")
## Número de slots exclusivos da bolsa. A capacidade total soma este valor ao tamanho da barra rápida.
@export_range(1, 240) var inventory_size := 12
## Número de slots do inventário reservados para a barra rápida. 0 desativa a barra.
@export_range(0, 12) var hot_bar_size := 9


func total_size() -> int:
	return inventory_size + hot_bar_size
