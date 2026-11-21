@tool
class_name ContentBreakable
extends Resource

const MIN_SECONDS := 0.05

@export_group("Resistência")
## Tempo necessário para destruir o bloco ou objeto com velocidade de mineração 1.
@export_range(0.05, 30.0, 0.05, "or_greater", "suffix:s") var seconds := 0.5


func duration() -> float:
	return maxf(MIN_SECONDS, seconds)
