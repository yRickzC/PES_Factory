# Interface do jogo

`inventory.tscn` e `inventory_slot_button.gd` apresentam os slots. `demo_inventory.gd`, `demo_hotbar.gd` e `demo_crafting.gd` ligam o inventário, a barra e o registro de receitas à interface. `crafting_queue_view.gd` apresenta a fila. As configurações da UI ficam nos `.tres` desta pasta. Os ícones vêm do pacote, e a inicialização e o menu ficam em `Menu/`.

A barra rápida mostra os ícones, as quantidades e o slot selecionado. **I** abre ou fecha o inventário. Na bolsa, use **Tab**, **Shift + Tab** ou **setas** para navegar. Pressione **Enter** na origem e no destino para mover, mesclar ou trocar pilhas, inclusive entre a bolsa e a Hotbar. O foco em uma receita mostra seus detalhes. **Enter** enfileira a receita em foco ou cancela um pedido em foco. `hotbar.tres` configura a apresentação da barra. Os atalhos ficam em `src/Settings/`.
