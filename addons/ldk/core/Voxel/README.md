# Mundo voxel

## Mapa das pastas

- `Blocks/`: definições de blocos, formas, colisão, oclusão e comportamentos.
- `Data/`: chunks, edições esparsas, estados persistentes de componentes e dano temporário de mineração.
- `Generation/`: biomas, relevo, variantes de terreno e distribuição de objetos.
- `Streaming/`: carregamento de chunks e coordenação dos trabalhos assíncronos.
- `Targeting/`: seleção de blocos, prévia de construção e consultas de ataque corpo a corpo.
- `View/`: malhas, objetos, lotes de sprites e efeitos visuais do terreno.

Cada subpasta tem seu próprio `README.md` com o resumo dos arquivos.

O sistema de fauna em `../Wildlife/` consulta alturas, biomas e disponibilidade dos chunks para ativar entidades temporárias. A prévia de colocação verifica a ocupação física por esses atores.

A cena `src/World/demo.tscn` usa câmera ortográfica alinhada à grade. [Controles padrão](../../../../README.md#controles-padrão)

Por padrão, cada execução sorteia uma seed e mostra o valor na aba Saída do Godot. Para reproduzir o mapa, abra `World Definition` no nó raiz, desative `Randomize Seed` e preencha `Seed`. Com os mesmos recursos e mods, a seed reproduz o terreno, os biomas, as bacias e a colocação de objetos.

## Responsabilidades

| Módulo em `addons/ldk/core/Voxel` | Responsabilidade |
| --- | --- |
| `Data` | Células em chunks de 16³, coordenadas com sinal, snapshots de leitura e alterações esparsas por chunk. |
| `Blocks` | Catálogo de definições compartilhadas, orientação, geometria, colisão, oclusão e agendamento de comportamentos ativos. |
| `Generation` | Contrato de geração por chunk, campos de clima e perfis de relevo por bioma. |
| `Streaming` | Prioridade por distância ao jogador, halo de seis vizinhos solicitado sob demanda, tarefas com cancelamento cooperativo e revisões de malha. |
| `View` | Culling nas fronteiras, greedy meshing de cubos, templates para formas especiais, dois grupos de materiais e reutilização dos nós de apresentação. |

`src/World` contém a cena, o controle do jogador, a configuração dos materiais e as regras da demonstração. Os biomas e o manifesto nativo ficam em `assets/core/`. O gerador combina altura, temperatura e umidade em coordenadas globais, mistura a elevação dos biomas e intercala seus materiais nas transições. `VoxelBiomePlacement` relaciona as âncoras determinísticas a cenas compostas. `VoxelPropView` apresenta essas cenas quando o chunk da célula de apoio fica disponível e atualiza as âncoras atingidas por edições. Uma cena pode ocupar várias células visualmente e definir sua própria colisão. O inventário independente da apresentação fica em `addons/ldk/core/Inventory`, com a bolsa em `src/UI`.

O Data usa o índice `x + 16*z + 256*y` e um byte por ID em chunks mistos. Um chunk uniforme armazena só o ID, sem buffer de células. O Luanti também divide o mundo em blocos 16³ e usa IDs numéricos. O Voxel Tools usa canais com compressão uniforme e diferentes larguras. Aqui uma paleta de dois materiais com bit-packing ocuparia 512 bytes de índices, e uma paleta de até 16 materiais ocuparia 2.048 bytes de índices, mais as respectivas paletas. O byte direto ocupa 4.096 bytes e faz uma leitura indexada no caminho crítico do mesher. IDs de 16 bits ocupariam 8.192 bytes em chunks mistos. [Luanti — MapBlocks](https://api.luanti.org/map-terminology-and-coordinates/) · [Luanti — MapNode](https://github.com/luanti-org/luanti/blob/master/src/mapnode.h) · [Voxel Tools — formato de blocos](https://voxel-tools.readthedocs.io/en/latest/specs/block_format_v4/)

Os workers recebem snapshots e definições preparadas na thread principal. Uma edição em lote troca apenas os snapshots afetados e invalida o chunk e seus vizinhos de face quando alcança uma borda. A revisão impede que tarefas antigas publiquem superfícies depois de uma edição. A thread principal cria as malhas e formas físicas e limita a publicação a dois chunks por quadro por padrão. [Voxel Tools — desempenho e streaming](https://voxel-tools.readthedocs.io/en/latest/performance/) · [Godot — APIs seguras para threads](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html) · [Godot — WorkerThreadPool](https://docs.godotengine.org/en/4.7/classes/class_workerthreadpool.html)

O mesher funde retângulos adjacentes com a mesma combinação de camada, material e presença de colisão. Oclusão visual e física são testadas separadamente. Formas especiais podem ocultar triângulos na fronteira quando a face vizinha tem cobertura total. A superfície opaca e a translúcida usam uma `Texture2DArray` com filtragem Nearest e repetição em unidades de bloco. Cada camada tem amostragem independente. O material do terreno deriva o ângulo e a variante de cada topo pela seed e pelas coordenadas mundiais, mantendo o retângulo resultante do greedy meshing. A demo pinta o topo da grama em `assets/core/textures/grass.png` a partir da referência em `assets/image/grass_top.jpg`. MultiMesh beneficia objetos repetidos e independentes. Para o terreno contíguo, a malha por chunk remove faces internas e permite reconstrução e visibilidade por região. [Voxel Tools — terreno de blocos](https://voxel-tools.readthedocs.io/en/latest/blocky_terrain/) · [Comparação original de algoritmos de meshing](https://0fps.net/2012/06/30/meshing-in-a-minecraft-game/) · [Godot — Texture2DArray](https://docs.godotengine.org/en/4.7/classes/class_texture2darray.html) · [Godot — MultiMesh](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html)

## Configuração do mundo e relevo

O preset `assets/core/Worlds/overworld.tres` combina os recursos de geração, ambiente e física. Crie outro `WorldDefinition` no Inspector para trocar o mundo. `Generation` seleciona os biomas e ajusta o peso e a extensão de cada um, além de controlar água, rocha de fundo, bacias e objetos procedurais. Uma lista vazia usa os biomas do registro. Referências por ID reaproveitam as substituições de mods. `Environment` usa o recurso nativo do Godot para céu, fundo, neblina e luz ambiente, junto às opções de luz direcional e ciclo dia/noite. `Physics` aplica a gravidade ao espaço 3D e configura movimento e pulo. [Godot — Resources](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html) · [Godot — WorldEnvironment](https://docs.godotengine.org/en/stable/classes/class_worldenvironment.html)

O Overworld parte de uma escala climática de 320 blocos, uma faixa de relevo de 64 e uma faixa de materiais de 40. Os tamanhos são aproximados porque as fronteiras seguem o ruído de temperatura e umidade. O relevo usa um campo de ruído próprio, combina perfis com Smoothstep e só então arredonda a altura. O controle de inclinação ajusta as amplitudes e alarga a faixa de elevação conforme necessário. Os materiais se alternam em pequenas manchas com base em outro ruído, mantendo nítidas as texturas dos blocos.

Cada `VoxelBiome` pode ajustar a largura de material. Seu `terrain_relief` reúne altura base, amplitude, frequência, suavidade, limites, largura de transição e inclinação desejada. As definições legadas continuam usando `elevation_offset` e `relief` quando o perfil está ausente. A geração consulta coordenadas globais, preservando a continuidade e a independência da ordem de carregamento. [Godot — FastNoiseLite](https://docs.godotengine.org/en/stable/classes/class_fastnoiselite.html) · [Voxel Tools — Geração procedural](https://voxel-tools.readthedocs.io/en/latest/procedural_generation/)

## Mira e corte de visibilidade

Com uma arma equipada, a demo usa uma mira de combate. `VoxelTargeting` consulta a forma física do arco durante a janela ativa. O terreno e os objetos sólidos podem bloquear o golpe.

A mira da demo acompanha o mouse. `VoxelTargeting` percorre o raio da câmera e usa os triângulos visuais de formas como escadas e meios blocos. O raio físico entre o jogador e o ponto atingido mantém o alcance sujeito às colisões. A face atingida orienta o destaque do alvo e a colocação normal. O recurso `assets/core/Settings/block_targeting.tres` configura a projeção, o alcance e a aparência da prévia. A View reutiliza a malha da peça e um contorno para mostrar a célula de destino. [Godot — Ray casting](https://docs.godotengine.org/en/stable/tutorials/physics/ray-casting.html) · [Voxel Tools — Raycast voxel](https://voxel-tools.readthedocs.io/en/latest/api/VoxelTool/#raycast)

O cutaway procura cobertura até oito células acima da cabeça e acompanha a região coberta até sete células ao redor. Na frente do jogador, corta pilhas sólidas e remove bordas que encobrem o corpo durante a escavação. Uma máscara compartilhada por coluna anima a remoção e a restauração em 0,2 s. Uma malha complementar pequena fecha as faces de cubos reveladas pelo corte. A janela usa os chunks carregados e, durante a transição, a mira atravessa a superfície a partir de metade do efeito. [Project Zomboid — Nightzedding](https://projectzomboid.com/blog/news/2018/12/nightzedding/) · [The Sims 4 — Walls Cutaway View](https://www.ea.com/games/the-sims/the-sims-4/news/update-7-23-2024) · [Dwarf Fortress — Z-axis](https://www.dwarffortresswiki.org/index.php/DF2014%3AZ-axis) · [Hailstone — Isometric Camera](https://github-wiki-see.page/m/projecthailstone/hailstone-client/wiki/Isometric-Camera)

Segure F e clique com o botão direito para construir na célula sob a mira na camada dos pés. O atalho de camada pode ser remapeado em **Controles**. A prévia usa a mesma validação de alcance, ocupação e colisão da colocação. O Resource `Construction` no Inspetor aponta para `assets/core/Settings/block_construction.tres` e configura o plano da mira, o alcance e o corte. Com o corte habilitado, os shaders dos chunks aplicam transparência acima da altura de corte e aos blocos da mesma altura que se projetam na frente do personagem ou da célula marcada. A malha complementar expõe os topos internos que o mesher omitiu. Soltar o atalho restaura a visibilidade normal. [Godot — Plane](https://docs.godotengine.org/en/stable/classes/class_plane.html) · [Godot — Spatial shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)

O recorte contextual e a construção por camada desenham as superfícies afetadas com transparência suave e desfoque na demo. O passe adicional é desativado quando a visibilidade volta ao normal.

## Inventário, fabricação e mineração

Selecione uma flor na barra rápida, mire em uma célula livre com chão sólido e use o botão direito para plantá-la. A entidade mantém sua cor, pode ser colhida de novo e permanece após o recarregamento do chunk ou do mundo salvo.

`src/UI/inventory_settings.tres` define as quantidades de slots da bolsa e da barra rápida. As duas áreas compartilham um `SlotInventory` e usam a mesma operação de mover pilhas. `src/UI/hotbar.tres` configura as ações, o espaçamento e o tema da barra. Os atalhos vêm de `src/Settings/game_settings.tres` e podem ser redefinidos no menu de pausa. [Godot — Control](https://docs.godotengine.org/en/stable/classes/class_control.html) · [Expressobits — Inventory System](https://github.com/expressobits/inventory-system)

Na fabricação à mão, navegue até uma receita para ver seus detalhes e quantos lotes os materiais permitem. Pressione Enter para enfileirar um lote. O planejador reserva materiais, produz intermediários e guarda os resultados até haver espaço na bolsa. Configure as abas com os recursos `CraftingTag` registrados em `ContentPack.crafting_tags`. Cada receita referencia o ID da aba em `tag`. Receitas antigas continuam disponíveis na aba Outras. [Godot — TabContainer](https://docs.godotengine.org/en/stable/classes/class_tabcontainer.html)

`ContentBreakable` define o tempo de quebra à velocidade 1 e `ContentDrops` lista os itens obtidos. Ambos são opcionais e ficam nas definições compartilhadas de blocos e objetos. Água e rocha de fundo deixam `Breakable` vazio. A velocidade em `block_mining.tres` é multiplicada por `InventoryItem.mining_speed_multiplier` do item ativo. O dano usa tempo de física e ocupa memória só nas células e objetos atingidos. Alterar a célula ou descarregar seu chunk limpa o dano. A View mostra as rachaduras configuradas em `block_targeting.tres`. [Vintage Story — Block Behaviors](https://wiki.vintagestory.at/Json:block:behaviors) · [Luanti — Tool Capabilities](https://api.luanti.org/tool-capabilities/)

## Extensão

- Registre um `VoxelBlock` com ID `namespace:nome` no manifesto. Use `SimpleTexture` para um cubo opaco com a mesma textura e oclusão nas seis faces. Com o componente avançado `VoxelGeometry`, informe as texturas de cubos na ordem +X, −X, +Y, −Y, +Z e −Z. Um bloco pode reutilizar os recursos de colisão e oclusão de outros tipos.
- Para uma forma nova, preencha um `VoxelModel` com triângulos em ordem horária, UVs e um ID de textura por triângulo. Marque somente triângulos coplanares a uma fronteira com o índice daquela face e use `-1` nos demais. O modelo de colisão pode ser diferente. A escada da demo combina degraus visuais e uma rampa física. Para conectar vizinhos no mesmo nível, defina um `connection_group` e forneça a extensão voltada para +X em `connection_arm` na geometria, na colisão ou nas duas.
- Para estruturas de blocos, monte um lote de posições e IDs e chame `VoxelWorld.set_blocks()`. A autoridade aceita alterações fora da janela carregada e as reaplica quando o chunk é gerado. Para objetos com arte e colisão próprias, use `VoxelPropView` com um callback que mapeia as células de apoio do chunk para cenas `Node3D`, como fazem as árvores da demo.
- Acrescente um `VoxelBiome` com clima, relevo e materiais próprios ou implemente outro `VoxelGenerator` para volumes, como cavernas. Geradores devem preparar caches antes do streaming e manter os dados compartilhados somente para leitura durante sua execução.
- Para um bloco interativo, componha `VoxelBlockBehavior` com a definição. `interact()` e `advance()` recebem o estado da célula na thread principal. O agendador guarda o estado quando preenchido e usa o retorno para decidir se precisa de outro tick. A suíte inclui um contador como exemplo. Esse contrato permite que comportamentos futuros de máquinas tenham estado próprio e usem o `SlotInventory` existente. [Vintage Story — Block System](https://wiki.vintagestory.at/Modding:Block_System)


### Conteúdo e mods

O [guia de pacotes](../Content/README.md) descreve como registrar definições e componentes, declarar dependências e sobrescrever biomas. A restauração de edições usa IDs de texto e aceita o mapa de índices da demonstração antiga em `restore_block_edits(edits, DemoContent.LEGACY_BLOCKS)`.

## Validação

```sh
godot --headless --editor --path . --import
godot --headless --path . --max-fps 120 --script res://src/World/Checks/voxel_check.gd
```

A suíte verifica seeds em ordens de carregamento diferentes, três biomas, coordenadas negativas e verticais, faces internas sólidas e líquidas, colisões de formas especiais, atualizações de borda, descarte de tarefas e retenção de edições após descarregamento. Verifica também a câmera, o streaming e a colisão das árvores, os limites de empilhamento e a integração da bolsa com a colocação e a coleta de blocos.

### Medição da composição

Godot 4.7.2 em modo headless, mediana de cinco rodadas após aquecimento. A consulta inclui a verificação de resistência e o cálculo da duração. A serialização inclui a exportação dos IDs estáveis e a conversão para bytes. A restauração inclui a leitura dos bytes e a aplicação das edições.

| Ensaio | Antes | Depois |
| --- | ---: | ---: |
| 1 milhão de consultas de resistência | 1,64 s | 1,53 s |
| Serializar 4.096 edições | 10,51 ms | 10,48 ms |
| Restaurar 4.096 edições | 70,79 ms | 69,81 ms |
| Tamanho serializado | 149.704 bytes | 149.704 bytes |
| Buffer de células de 95 chunks residentes | 180 KiB | 180 KiB |
| Memória estática do Godot após carregar o catálogo | 57,30 MiB | 57,29 MiB |
| Resources carregados após preparar o catálogo | 93 | 197 |

As edições restauradas reproduziram os mesmos IDs e geraram bytes idênticos. Um chunk uniforme usa 0 bytes de buffer. Chunks mistos usam 4.096 bytes com IDs de 8 bits ou 16.384 bytes com IDs largos. O buffer mede somente os IDs das células. A amostra de memória estática inclui o engine e o catálogo inicial, antes de carregar chunks. Os novos Resources são compartilhados por definição. A consulta usa o índice por ID já mantido pelo catálogo. [Luanti — MapNode](https://github.com/luanti-org/luanti/blob/master/src/mapnode.h) · [Flecs — Queries](https://www.flecs.dev/flecs/Queries.html)

### Medições da primeira versão do terreno

Godot 4.7.2 em um Core i5-4570, seed 1729, nove chunks superficiais com os mesmos vizinhos. O tempo é a média do preparo da malha e da colisão em CPU, por chunk.

| Modo | Vértices | Triângulos | Superfícies | Tempo médio |
| --- | ---: | ---: | ---: | ---: |
| Culling por face | 17.262 | 8.338 | 13 | 24,94 ms |
| Culling e greedy | 7.422 | 3.418 | 13 | 23,08 ms |

O greedy reduziu em 59% os triângulos dessa amostra. O batching definiu o número de superfícies nas duas variantes. O tempo varia com a proporção de faces que podem ser fundidas.

A janela inicial de 75 chunks ficou pronta em 2,31 s no ensaio headless. Com o halo, havia 140 chunks residentes e 272 KiB de buffers de células. Os 272 KiB excluem metadados, malhas, colisores e edições esparsas. A geração levou 1,44 ms em média e o preparo assíncrono de malhas, 37,37 ms. A publicação na thread principal levou 0,39 ms em média e 1,56 ms no maior envio de um chunk. O intervalo entre quadros durante o carregamento foi de 10,05 ms no p95 e 18,32 ms no maior quadro, limitado a 120 FPS.

No ensaio gráfico a 960×540 em Intel HD 4600 com ANGLE, o Godot registrou 60 draw calls no quadro capturado. A janela ficou pronta em 18,73 s, com p95 de 16,76 ms e um intervalo máximo de 9,74 s na primeira apresentação. Nesse ambiente, o driver usou ANGLE e o Godot reportou que não pôde criar o cache de shaders. A medição inclui esse início a frio e caracteriza apenas a máquina testada.

O mesher é o maior custo de CPU no ensaio. A fronteira de buffers entre worker e View permite reavaliar GDExtension quando a carga real pedir mais vazão.

### Limites da primeira versão

O [sistema de save](../World/README.md#persistência) grava os registros dos chunks sujos, com IDs estáveis para blocos e objetos e espaço para estados de componentes. A água demonstra transparência e ausência de colisão, sem simulação de fluxo. A transparência é ordenada por malha de chunk, e a oclusão de faces parcialmente cobertas é conservadora. O contrato de estruturas multicélula cobre escrita em lote. Regras de suporte, conexões e remoção coordenada ficam a cargo do conteúdo que usar esse contrato.
