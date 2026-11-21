@tool
class_name InventoryItem
extends Resource
## Definição compartilhada. Configure antes de inserir no inventário.

@export_group("Identidade e aparência")
## ID único do item, no formato [code]namespace:nome[/code], usado pelo inventário e pelas receitas.
@export var id: StringName
## Nome que aparece na interface de inventário e de fabricação.
@export var title: String
## ID da textura exibida no slot do item.
@export var icon_id: StringName

@export_group("Armazenamento")
## Quantidade máxima deste item que cabe em um único slot.
@export_range(1, 9999) var stack_limit := 64

@export_group("Uso no mundo")
## ID do bloco que o item pode posicionar. Vazio indica que o item não coloca blocos.
@export var block_id: StringName
## ID da entidade decorativa sem colisão que este item coloca. Use este campo com Block ID vazio.
@export var entity_id: StringName
## Multiplica a velocidade de mineração enquanto o item está selecionado. 1 mantém a velocidade padrão, 2 dobra e 0 impede minerar.
@export_range(0.0, 10.0, 0.05, "or_greater") var mining_speed_multiplier := 1.0
## Equipamento exibido na mão quando este item ocupa o slot ativo.
@export var equipment: HandEquipment
