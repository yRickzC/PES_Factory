@tool
extends Resource
## Shared definition. Ingredients and product refer to registered item IDs.

@export_group("Identidade e descrição")
## ID único da receita no formato [code]namespace:nome[/code], usado pelo registro e pela fila.
@export var id: StringName
## ID da categoria que determina em qual aba a receita aparece.
@export var tag: StringName
## Nome exibido ao selecionar a receita.
@export var title: String
## Texto exibido no painel de detalhes da receita.
@export_multiline var description: String

@export_group("Ingredientes")
## Mapa de IDs de itens para as quantidades consumidas por lote produzido.
@export var ingredients: Dictionary[StringName, int] = {}

@export_group("Resultado e tempo")
## ID do item entregue ao terminar a fabricação.
@export var product: StringName
## Quantidade do item produzido por lote.
@export_range(1, 9999) var product_count := 1
## Tempo, em segundos, para produzir um lote depois que ele entra em execução.
@export_range(0.05, 3600.0, 0.05, "suffix:s") var seconds := 0.5
