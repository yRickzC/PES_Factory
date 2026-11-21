# Pacote nativo

`content.tres` registra as definições do namespace `core`. Adicione cada definição em seu próprio `.tres` e associe-a ao manifesto. O guia do LDK descreve o mesmo formato para pacotes externos.

- `Blocks/`, `Items/`, `Entities/` e `Biomes/` contêm as definições que o mundo e o inventário consultam, incluindo as variantes de terreno e regras de população.
- As flores registram uma entidade e um item por cor. Cada par compartilha a textura e o ID entre categorias.
- `Recipes/` e `CraftingTags/` contêm as receitas e categorias da fabricação à mão.
- `Worlds/` e `Settings/` contêm os presets de mundo, interação e feedback de dano usados pela cena da demo.
- `textures/` contém os tiles e os sprites. `shaders/` contém os materiais visuais do terreno e da água.
- `content.tres` registra a picareta e a espada com seus ícones e receitas. `Settings/player_sprite.tres` configura a apresentação do Explorer. `textures/` também contém a mira e os efeitos de combate.
- O manifesto registra `core:pig` em `Entities/`, com um perfil de fauna temporária e sua cena visual.

No preset de exportação do jogo, use `Export all resources in the project` ou inclua explicitamente `assets/core/` para empacotar o manifesto e os arquivos referenciados por caminho.

Os topos dos blocos naturais em `Blocks/` usam variação de UV configurável. `shaders/terrain.gdshader` mantém a amostragem Nearest do terreno ao aplicar a variação.
