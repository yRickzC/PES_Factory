extends Resource

@export_group("Dimensões e posição")
## Distância, em pixels, da barra rápida até a borda inferior da tela.
@export_range(0, 32) var bottom_margin := 12
## Largura e altura mínimas, em pixels, de cada slot.
@export var slot_size := Vector2(31, 34)
## Tamanho, em pixels, dos ícones de itens na barra.
@export var icon_size := Vector2(20, 20)
## Espaço horizontal, em pixels, entre os slots.
@export_range(0, 12) var spacing := 2

@export_group("Aparência")
## Tamanho da letra para as quantidades de itens nos slots.
@export_range(6, 20) var font_size := 9
## Tema que define as cores, fontes e estilos dos controles da barra.
@export var theme: Theme
## Estilo do fundo e da borda da barra. Vazio usa o estilo do tema.
@export var panel_style: StyleBox
