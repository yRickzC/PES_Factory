@tool
class_name WorldEnvironmentConfig
extends Resource
## The native Environment holds sky, background, ambient light and atmosphere.

@export_group("Atmosfera")
## Recurso do Godot que define o céu, a luz ambiente e efeitos como névoa.
@export var atmosphere: Environment = Environment.new()

@export_group("Sol e sombras")
## Orientação da luz direcional em graus. Com ciclo de dia e noite, serve como referência ao meio-dia.
@export var sun_rotation := Vector3(-50.0, 152.0, 0.0)
## Cor da luz direcional durante o dia ou com o ciclo desativado.
@export var sun_color := Color.WHITE
## Intensidade da luz direcional durante o dia ou com o ciclo desativado.
@export_range(0.0, 16.0, 0.01, "or_greater") var sun_energy := 1.0
## Ativa as sombras projetadas pela luz direcional.
@export var shadows_enabled := true
## Método que distribui a resolução das sombras em profundidade. Afeta a nitidez perto e longe da câmera.
@export var shadow_mode := DirectionalLight3D.SHADOW_ORTHOGONAL
## Distância máxima da câmera em que a luz direcional projeta sombras.
@export_range(0.0, 256.0, 1.0, "or_greater", "suffix:m") var shadow_distance := 48.0

@export_group("Ciclo de dia e noite")
## Faz a direção e a cor da luz variarem com o horário.
@export var cycle_enabled := false
## Hora inicial, de 0 a 24, quando o ciclo está ativo.
@export_range(0.0, 24.0, 0.1, "suffix:h") var start_hour := 12.0
## Tempo real, em segundos, para completar 24 horas no mundo.
@export_range(1.0, 3600.0, 1.0, "or_greater", "suffix:s") var cycle_duration := 900.0
## Valores maiores prolongam a transição de luz ao amanhecer e ao entardecer.
@export_range(0.01, 1.0, 0.01) var twilight_width := 0.24
## Variação horizontal da direção da luz ao longo do ciclo, em graus.
@export_range(0.0, 180.0, 1.0, "degrees") var sun_azimuth_swing := 90.0

@export_group("Iluminação noturna")
## Multiplica as cores do cenário à noite, inclusive as dos sprites sem iluminação. Branco mantém as cores originais.
@export_color_no_alpha var night_world_tint := Color.WHITE
## Cor da luz direcional durante a noite.
@export var night_color := Color(0.58, 0.69, 0.90)
## Intensidade da luz direcional durante a noite.
@export_range(0.0, 16.0, 0.01, "or_greater") var night_energy := 0.18
## Fração da intensidade da luz ambiente preservada à noite. 0 apaga a contribuição ambiente.
@export_range(0.0, 1.0, 0.01) var night_ambient_multiplier := 0.45
## Fração do brilho do fundo preservada à noite. 1 mantém o brilho de referência.
@export_range(0.0, 1.0, 0.01) var night_background_multiplier := 0.43
