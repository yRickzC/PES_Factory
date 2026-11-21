# PES Factory

Projeto Godot 4.7 de um jogo voxel. A cena inicial registra e valida o conteúdo antes de abrir o menu principal.

## Pastas

- `assets/core/`: pacote nativo com definições individuais, texturas, cenas e presets.
- `assets/image/`: referências visuais.
- `addons/ldk/` contém o [editor de conteúdo LDK](addons/ldk/core/UI/editor/README.md) e os sistemas reutilizáveis de conteúdo, configurações, crafting, inventário, equipamento, feedback de dano, fauna, terreno voxel e mundo.
- `docs/`: referências declarativas da interface.
- `src/`: integração do pacote nativo, interface, menu, demonstração jogável e verificações.
- `graphify-out/` e `.godot/`: arquivos gerados pelas ferramentas, ignorados pelo Git e não tratados como conteúdo-fonte.

Cada pasta de conteúdo tem um `README.md` com seu resumo. As regras para manter esses resumos estão em `AGENTS.md`.

O [guia de pacotes](addons/ldk/core/Content/README.md) descreve o manifesto, a instalação de mods e o formato dos IDs.

## Controles padrão

- **WASD** move o personagem. Segure **Shift** enquanto se move para correr. **Espaço** pula e **R** reaparece.
- O **mouse** move a mira. O **botão esquerdo** minera, coleta ou ataca com uma arma equipada. O **direito** coloca o item ativo. Segure **F** e clique com o **botão direito** para construir na camada dos pés. Corrida e construção por camada têm atalhos próprios no menu **Controles**.
- **1–9** seleciona slots da Hotbar, a **roda do mouse** alterna entre eles e **X/Z** ajusta o zoom.
- **I** abre ou fecha a bolsa. Use **Tab**, **Shift + Tab** e **setas** para navegar, e **Enter** para confirmar.

Na Hotbar padrão, pressione **7** para equipar a picareta em um mundo novo. Em um mundo salvo, fabrique a picareta e mova-a para a Hotbar. Use o **botão esquerdo do mouse** para balançá-la.

Pressione **8** para equipar a espada em um mundo novo. Em um mundo salvo, fabrique-a com uma tábua e duas pedras. Mire no porco de perto e clique com o botão esquerdo. Ele foge ao receber dano e morre após quatro acertos de 3 HP.

## Salvamento

`addons/ldk/core/World/world_save_store.gd` cria, lista e abre mundos em `user://worlds`. O autosave grava as alterações de blocos e objetos, o estado do jogador, o inventário, a Hotbar e a fila de crafting. **Esc → Sair** aguarda a gravação final antes de voltar ao menu. O terreno intacto é regenerado pela seed. As preferências de controles, interface, áudio, vídeo e gameplay ficam em `user://game_settings.cfg`. [Formato e recuperação de saves](addons/ldk/core/World/README.md#persistência)

Os porcos são fauna temporária. A sessão mantém em memória apenas os grupos nas regiões próximas e os descarta ao se afastar.
