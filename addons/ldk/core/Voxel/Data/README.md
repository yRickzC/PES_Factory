# Dados voxel

`voxel_chunk_data.gd` representa snapshots de chunks e converte posições locais em índices e vice-versa. `voxel_world_data.gd` mantém edições de blocos e objetos e estados persistentes de componentes. As edições de objetos ficam agrupadas por chunk de apoio, com o ID estável para um plantio e um ID vazio para uma remoção. Estados de componentes ocupam mapas esparsos por chunk, célula e ID de componente. `voxel_mining.gd` acompanha dano temporário de mineração, configurado por `voxel_mining_config.gd`.

`VoxelWorldData` valida e copia os valores simples aceitos pela persistência, como números, vetores, strings, arrays e dicionários. A rotação visual é derivada na View e dispensa dados extras por célula.
