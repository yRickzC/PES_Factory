# Definições de blocos

Cada definição de bloco tem um `.tres` associado ao manifesto `../content.tres` por um ID estável. Edite `Breakable` para configurar o tempo de mineração e `Drops` para configurar os IDs e as quantidades dos itens obtidos. Água e rocha de fundo deixam `Breakable` vazio.

`solid.tres` e `opaque.tres` são componentes compartilhados de colisão e oclusão. Os modelos de geometrias especiais ficam em `Models/`.

`grass_flecked.tres`, `earth_pebbled.tres` e `stone_mottled.tres` definem variantes usadas na geração. Elas conservam as propriedades e recompensas do terreno base e resolvem seus próprios tiles pelo manifesto.

Grama, terra, pedra, areia, musgo e suas variações naturais usam rotações de topo a cada quarto de volta. Os Resources principais da grama e da pedra também alternam variantes de textura.
