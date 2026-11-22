# Interface do jogo

`inventory.tscn` e `inventory_slot_button.gd` apresentam os slots. `demo_inventory.gd`, `demo_hotbar.gd` e `demo_crafting.gd` ligam o inventário, a barra e o registro de receitas à interface. `crafting_queue_view.gd` apresenta a fila. As configurações da UI ficam nos `.tres` desta pasta. Os ícones vêm do pacote, e a inicialização e o menu ficam em `Menu/`.

A barra rápida mostra os ícones e o slot selecionado. A quantidade aparece apenas para itens empilháveis, tanto na bolsa quanto na barra rápida. **I** abre ou fecha o inventário. Na bolsa, use **Tab**, **Shift + Tab** ou **setas** para navegar. Pressione **Enter** na origem e no destino para mover, mesclar ou trocar pilhas, inclusive entre a bolsa e a Hotbar. `hotbar.tres` configura a apresentação da barra. Os atalhos ficam em `src/Settings/`.

Arraste itens entre os slots da bolsa e da barra rápida. Um slot vazio recebe a pilha inteira. Itens iguais empilham até o limite e o excedente fica na origem. Slots com outro item ou uma pilha cheia rejeitam a soltura.

Na fabricação, um clique ou o foco pelo teclado mostra os detalhes da receita. Dê um clique duplo ou pressione **Enter** na receita em foco para enfileirar um lote. Pressione **Enter** em um pedido em foco para cancelá-lo.
