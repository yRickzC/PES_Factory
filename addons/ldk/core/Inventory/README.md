# Inventário

Modelo de itens e armazenamento. `inventory_item.gd` define itens, `inventory_settings.gd` configura capacidade, `slot_inventory.gd` guarda e move pilhas e `slot_hotbar.gd` expõe uma faixa de acesso rápido do mesmo inventário.

As operações de inventário tratam IDs legados e canônicos como o mesmo item.

Um item pode referenciar um bloco para construção em `block_id` ou uma entidade decorativa em `entity_id`, como as flores plantáveis.

O campo opcional `equipment` associa o item a um equipamento de mão. A Hotbar fornece o item ativo para a sessão equipar no ator.

O catálogo **Inventário** do editor LDK lista as definições de itens registradas para o contexto de edição.

`SlotInventory` exporta as pilhas ocupadas com IDs estáveis e valida o snapshot antes de restaurar seus slots.
