# Geração voxel

Regras de geração procedural: `voxel_generator.gd` define o contrato, `voxel_heightmap_generator.gd` gera o terreno, `voxel_world_generation.gd` reúne as opções do mundo e os recursos `voxel_biome*.gd` descrevem biomas, relevo e distribuição de objetos.

O gerador de relevo consome as regras de bioma em `voxel_world_biome.gd` e resolve os biomas do preset no banco de conteúdo, preservando overrides e IDs legados.

`voxel_biome_relief.gd` configura afloramentos opcionais. O gerador amostra o ruído da seed em coordenadas globais e mistura a elevação adicional com o relevo dos biomas vizinhos. As formações usam os materiais do terreno e entram no cálculo da altura máxima para o carregamento dos chunks.

`voxel_biome_scatter.gd` define espaçamento, chance, tamanho dos agrupamentos, variantes registradas, altitude e inclinação. `voxel_biome_placement.gd` distribui entidades usando a seed e uma grade de coordenadas globais. Cada chunk consulta os pontos de agrupamentos que alcançam sua área. Os campos `surface_variants` e `soil_variants` selecionam alternativas de terreno por coluna e mantêm a mesma escolha quando a camada cruza uma borda vertical. [Vintage Story — Simple Worldgen](https://wiki.vintagestory.at/Modding:Content_Tutorial_Simple_Worldgen)

As definições de bioma ficam disponíveis em **LDK > Voxel > Biomas**. Os Resources de geração e suas regras também são carregados na inspeção de presets.

`VoxelBiomePlacement` distribui props estáticos. Entidades com perfil de fauna são ativadas pelo sistema de população, que consulta o gerador para obter o bioma e a altura.
