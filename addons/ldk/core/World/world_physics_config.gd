@tool
class_name WorldPhysicsConfig
extends Resource
## Y-up physics parameters. Jump speed is the initial upward velocity.

@export_group("Movimento no chão")
## Velocidade horizontal do jogador em metros por segundo.
@export_range(0.0, 40.0, 0.1, "or_greater", "suffix:m/s") var movement_speed := 5.4
## Distância para manter o jogador apoiado ao descer pequenas diferenças de altura ou inclinações.
@export_range(0.0, 2.0, 0.01, "or_greater", "suffix:m") var floor_snap_length := 0.35
## Inclinação máxima, em graus, que o jogador considera chão. Superfícies mais íngremes contam como parede.
@export_range(0.0, 89.9, 0.1, "degrees") var floor_max_angle := rad_to_deg(0.87)

@export_group("Corrida")
## Multiplicador da velocidade horizontal ao correr.
@export_range(1.0, 4.0, 0.05, "or_greater") var sprint_speed_multiplier := 1.5
## Aceleração horizontal para alcançar a velocidade alvo.
@export_range(1.0, 100.0, 1.0, "or_greater", "suffix:m/s²") var move_acceleration := 40.0
## Desaceleração horizontal ao reduzir a velocidade ou parar.
@export_range(1.0, 100.0, 1.0, "or_greater", "suffix:m/s²") var move_deceleration := 50.0

@export_group("Gravidade e pulo")
## Aceleração para baixo. Valores maiores aceleram a queda e reduzem a altura do pulo.
@export_range(0.0, 100.0, 0.1, "or_greater", "suffix:m/s²") var gravity := 9.8
## Velocidade vertical inicial do pulo. Valores maiores fazem o jogador subir mais.
@export_range(0.0, 40.0, 0.1, "or_greater", "suffix:m/s") var jump_speed := 5.4
## Repete o pulo ao aterrissar enquanto o comando permanece pressionado.
@export var repeat_jump_while_held := true
