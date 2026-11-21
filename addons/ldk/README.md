# LDK

`plugin.cfg` identifica o addon no editor e `ldk.gd` fornece o ponto de entrada do plugin. `core/` contém os sistemas de conteúdo, crafting, inventário, equipamento, combate corpo a corpo, feedback de dano, fauna, terreno voxel e configuração de mundos.

A aba **LDK**, no seletor superior do editor, instancia o editor de conteúdo. `ldk.gd` registra os contextos Nativo e Mods e fornece a aba **Voxel**, que reúne Blocos, Biomas e Mundos e oferece edição de blocos em grafo. [Editor de conteúdo](core/UI/editor/README.md)

Para reutilizar os sistemas, copie a pasta completa para `res://addons/ldk/` no projeto de destino. O jogo de destino fornece suas próprias cenas, definições de conteúdo e materiais.

`core/Settings/` fornece as definições de preferências e atalhos usadas pelos projetos que integram o LDK.
