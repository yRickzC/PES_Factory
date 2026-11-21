# Crafting

Tipos e lógica de fabricação: `crafting_recipe.gd` define receitas, `crafting_tag.gd` define categorias, `crafting_planner.gd` calcula materiais e resultados e `crafting_queue.gd` administra pedidos em andamento.

A fila usa o planejador e opera sobre os slots de `../Inventory/`. Receitas e categorias vêm do banco de conteúdo. Ingredientes e produtos usam IDs canônicos, aceitando referências legadas de pacotes antigos.

As definições de receitas e categorias também ficam disponíveis no catálogo **Fabricação** do editor LDK.

Ao salvar o mundo, `CraftingQueue` registra as ordens, os lotes pendentes, o tempo decorrido, os materiais reservados e as entregas aguardando espaço na bolsa. A próxima sessão retoma a fila sem cobrar novamente os materiais já reservados. A restauração confere os IDs e compara os ingredientes, os produtos e a duração das receitas ativas para detectar mudanças incompatíveis.
