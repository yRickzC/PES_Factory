# Apresentação voxel

`voxel_chunk_mesher.gd` cria as malhas e `voxel_chunk_view.gd` apresenta chunks. `voxel_mesh_payload.gd` transporta resultados. `voxel_cutaway_*` controla o corte visual. `voxel_prop_view.gd` apresenta objetos gerados e plantados. Um plantio atualiza os lotes de sprites do chunk de apoio, reaproveitando a malha do sprite usada pela prévia de plantio. Os shaders cuidam dos tiles, água e efeitos de superfície.

`voxel_surface_effects.gdshaderinc` fornece os efeitos de mira, mineração e recorte comuns aos shaders de terreno e água. Quando o jogo fornece um material de desfoque, `VoxelCutawayView` o ativa como passe adicional durante o recorte e reaproveita a máscara, as malhas e as texturas dos chunks.

`voxel_prop_blur.gdshader` suaviza o sprite das entidades em cena quando a base fica acima da camada visível no recorte contextual ou no modo de construção. `VoxelPropView` restaura o material original no mesmo nível e compartilha o material de desfoque por textura. A mira continua usando a máscara original do sprite.

`voxel_prop_batch.gd` desenha os detalhes sem colisão com um `MultiMeshInstance3D` por definição e chunk, compartilhando a malha e o material. A remoção e o destaque atualizam somente a transformação ou a cor de uma instância. Árvores e rochas com colisão usam suas cenas compostas. [Godot — MultiMeshInstance3D](https://docs.godotengine.org/en/stable/tutorials/3d/using_multi_mesh_instance.html)

`voxel_top_texture.gdshaderinc` escolhe a variante e o ângulo de UV de cada célula superior a partir da seed e da posição global. `VoxelChunkMesher` preserva o greedy meshing entre faces com o mesmo estilo e `VoxelCutawayView` usa o mesmo índice ao expor topos no recorte.
