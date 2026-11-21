# Blocos voxel

`VoxelBlock` reúne geometria, colisão, oclusão, resistência, drops e comportamento opcionais. `VoxelModel` descreve as formas especiais. `VoxelCatalog` indexa as definições por ID compacto durante o registro e prepara os dados destinados à View. `VoxelBlockBehavior` fornece os pontos de interação e atualização. `VoxelActiveBlocks` guarda estados preenchidos e agenda somente as células que solicitaram outro tick.

`VoxelBlock` valida geometria, colisão e conexões no editor e no jogo. A validação de `VoxelModel` lê os dados exportados mesmo quando a instância do script do modelo ainda está indisponível no editor. O ContentDB consulta essa validação no registro e prepara o catálogo compacto quando o mundo usa o terreno pela primeira vez. Componentes adicionais podem ser associados à definição por ID.

O campo `VoxelBlock.geometry` aceita Resources `VoxelVisual`. `SimpleTexture` guarda apenas o ID da textura e usa o cubo inteiro com seis faces iguais, UVs padrão, material opaco e oclusão em todas as faces. `Texture` (`VoxelGeometry`) mantém a configuração por face, os modelos personalizados e a oclusão definida no bloco. Ambos passam pelo mesmo catálogo e mesher de chunks. A colisão é definida pelo componente `Collision`.

Para criar um preset visual, estenda `VoxelVisual` com um script `@tool`. `bake_geometry()` devolve uma `VoxelGeometry` para leitura durante a validação e preparação do catálogo. `automatic_occlusion()` pode devolver uma máscara de seis faces para substituir a configuração de oclusão do bloco. `validation_issue()` permite informar dados de autoria inválidos.

Os Resources de bloco aparecem em **LDK > Voxel > Blocos**. Selecione um bloco para consultar suas propriedades e referências aos componentes.

`VoxelVisual` configura a rotação determinística das texturas superiores de cubos opacos, os ângulos permitidos e as variantes. `VoxelCatalog` prepara uma tabela compartilhada por estilo e o mesher reutiliza o mesmo estilo nas faces superiores fundidas.
