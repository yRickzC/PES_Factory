@tool
extends Resource

@export_group("Aba de fabricação")
## ID único da categoria, no formato [code]namespace:nome[/code], usado pelas receitas para escolher a aba.
@export var id: StringName
## Nome exibido na aba de fabricação.
@export var title: String
## Ordem da aba. Valores menores aparecem primeiro.
@export var order: int
