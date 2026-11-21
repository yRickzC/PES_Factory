extends Resource

@export_group("Velocidade de mineração")
## Multiplicador global da velocidade de quebra antes dos bônus da ferramenta. 2 reduz à metade o tempo de mineração.
@export_range(0.1, 10.0, 0.05, "or_greater") var base_speed := 1.0

@export_group("Recuperação do dano")
## Tempo sem minerar até o bloco ou objeto começar a recuperar o dano de quebra.
@export_range(0.0, 30.0, 0.05, "or_greater", "suffix:s") var recovery_delay := 0.8
## Tempo que a recuperação leva para apagar todo o progresso guardado após a espera.
@export_range(0.0, 30.0, 0.05, "or_greater", "suffix:s") var recovery_seconds := 1.4
## Tempo máximo sem minerar para descartar o progresso. 0 deixa apenas a recuperação apagar o dano.
@export_range(0.0, 30.0, 0.05, "or_greater", "suffix:s") var expire_after := 0.0
