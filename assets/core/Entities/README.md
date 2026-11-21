# Entidades nativas

`tree.tres`, `tree_broadleaf.tres` e `tree_pine.tres` configuram suas próprias copas, colisões e resistências. Elas compartilham a cena `tree.tscn` e `tree_drops.tres`, que sorteia de quatro a oito troncos por árvore.

`meadow_grass.tres`, `flower_gold.tres`, `flower_rose.tres`, `flower_lilac.tres`, `mountain_pebbles.tres` e `mountain_shards.tres` são detalhes mineráveis renderizados em lote. `mountain_boulder.tres` usa `boulder.tscn` para o sprite e a sombra, com colisão definida separadamente. As texturas do manifesto são resolvidas no primeiro uso.

O componente `Drops` de cada flor entrega um item da mesma cor à bolsa.

`pig.tres` registra os componentes de `core:pig`, com 10 HP, velocidades de caminhada e fuga, frequência por bioma e grupos de dois a quatro nas planícies e florestas. Também define o solo para fuçar, os blocos que atraem o porco para a margem e o preset de feedback ao receber dano. `pig.tscn` é a apresentação voxel, com focinho e pernas articulados.
