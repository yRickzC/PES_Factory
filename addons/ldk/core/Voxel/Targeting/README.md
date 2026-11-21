# Mira, construção e combate

`voxel_targeting.gd` localiza blocos e mantém a face atingida separada da face de colocação. No modo cursor usado pela demo, o centro do topo seleciona a célula de cima e suas bordas apontam para as laterais conforme `side_edge_width`. Se o raio atingir diretamente uma lateral, a colocação segue essa face, com uma faixa inferior configurável para selecionar a base. As faixas usam coordenadas locais da célula. Enquanto o atalho de construção por camada estiver pressionado (F por padrão), a demo projeta o cursor na camada dos pés.

Quando `side_edge_width` está ativo, mirar na borda do topo com um vizinho sólido na lateral pode selecionar a célula acima desse vizinho. A prévia e a colocação usam esse mesmo destino e passam pelas validações normais de alcance, ocupação e colisão. A opção `place_over_side_neighbor` controla esse comportamento.

`voxel_targeting_config.gd` configura alcance, faixas das bordas, prioridade dos cantos, estabilidade da seleção e aparência da prévia. `voxel_construction_config.gd` configura o modo por camada. `voxel_target_view.gd` apresenta o alvo e reutiliza a geometria da prévia. `voxel_placement_ghost.gdshader` desenha a peça com suas texturas, e `voxel_placement_outline.gdshader` marca a base da célula de destino mesmo através de paredes.

A mira usa o comprimento do raio da câmera para detectar o alvo visível e mede o alcance de interação a partir do jogador. Fora do alcance, a View projeta um contorno reutilizável na interface, acima da iluminação do mundo. A cor é configurada em `out_of_range_color`.

A View carrega os dois shaders desta pasta do addon.

Na demo, o modo por camada preserva a visibilidade normal do terreno.

A seleção de objetos mineráveis consulta o componente `Breakable` da definição compartilhada. Sprites em lote podem ser atingidos pelos pixels visíveis e passam pela mesma verificação de alcance e obstrução dos objetos em cena.

A checagem de colocação aceita uma máscara física adicional para bloquear células ocupadas por atores móveis. A demonstração inclui a camada da fauna nessa checagem.

Para armas corpo a corpo, `VoxelTargeting` projeta o cursor no plano do golpe e orienta o arco para a forma atingível sob a mira, quando visível. Durante a janela ativa, amostra uma caixa orientada no arco, respeita altura, alcance e colisões do terreno e dos objetos, e devolve contatos de corpos que implementam `take_damage(amount, source_position) -> bool`. O chamador mantém os alvos já atingidos no golpe.
