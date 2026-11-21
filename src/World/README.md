# Demonstração do mundo

`demo.tscn` e `demo_world.gd` conectam a sessão, o terreno, a interface e o jogador ao banco de conteúdo. A mineração lê resistência e recompensas das definições registradas. `demo_player.gd` controla o movimento e os estados do personagem. `player_sprite_view.gd` renderiza cabeça, corpo, mãos e equipamento a partir da direção e do tempo de estado. `player_sprite_profile.gd` define os recortes do atlas, posições das mãos, ritmo dos passos e tremor da corrida. `demo_generator.gd` gera o terreno e `demo_materials.gd` configura seus materiais. As verificações ficam em `Checks/` e a cena visual da árvore fica no pacote nativo.

A cena usa os scripts de mundo e a mira do LDK. A visualização aplica o destaque de mineração tanto às entidades em cena quanto aos detalhes em lote. A coleta sorteia recompensas entre os limites definidos quando o objeto é destruído.

Segure **Shift** enquanto se move para correr. A máquina de estados alterna entre Idle, Walk e Run e retoma a locomoção solicitada ao sair de Attack. A física usa aceleração e desaceleração do preset do mundo. A apresentação usa o mesmo relógio de Run para os passos rápidos, o balanço alternado dos braços e o tremor discreto da câmera a cada passada no chão.

A mira acompanha o mouse. O **botão esquerdo** minera ou coleta, o **direito** coloca e **F + botão direito** constrói na camada dos pés com a visibilidade normal do terreno. Corrida e construção por camada são remapeáveis em **Controles**. A colocação usa a posição do cursor no momento do clique. Depois de quebrar uma entidade, solte o botão e pressione de novo para minerar o terreno.

O cursor do sistema fica oculto durante a exploração com destaque de terreno. Equipar uma arma corpo a corpo exibe a mira pixelada no cursor. A bolsa, a pausa e a saída do mundo restauram a seta normal.

O contorno da mira fica vermelho no bloco apontado fora do alcance e continua visível à noite. Ao voltar ao alcance, a mira retoma a cor normal.

O slot ativo equipa o item na mão. A picareta aparece no sétimo slot de mundos novos com a Hotbar padrão e pode ser fabricada em mundos salvos. O ataque aplica mineração no impacto do balanço se a mira ainda alcançar o alvo do início do golpe. Soltar o comando de mineração encerra a repetição após o balanço atual. Trocar o equipamento, abrir a bolsa ou o menu de pausa, iniciar a construção por camada, mudar o foco para fora da janela ou reaparecer interrompe o ataque.

A espada aparece no oitavo slot de mundos novos com a Hotbar padrão e também pode ser fabricada. O botão esquerdo inicia o arco na direção clicada. `demo_world.gd` resolve os contatos da janela de impacto com `VoxelTargeting` e aplica dano uma vez por alvo a cada golpe. `demo_player.gd` usa a mesma máquina de estados da picareta para conduzir a pose e o rastro do golpe. Quando um alvo aceita o dano, a faísca aparece, o avatar recua visualmente e a câmera aplica um tremor em pixels. O hitstop mantém a pose do golpe por alguns frames antes de retomar a janela ativa.

As flores coletadas podem ser selecionadas na barra rápida e plantadas com o **botão direito** em terreno sólido livre. A prévia usa o sprite da entidade definida pelo item, e o plantio confirmado consome uma unidade.

`demo_materials.gd` compartilha a seed e a tabela de variantes dos topos entre o terreno e o passe de desfoque. `demo_world.gd` conecta o recorte à apresentação do terreno e dos sprites de objetos em cena.

Ao abrir um mundo pelo seletor, `demo_world.gd` aplica as edições persistentes antes do streaming e restaura posição, direção, HP, bolsa, slot ativo e fila de crafting. O equipamento na mão é resolvido a partir do item no slot ativo. A sessão agenda autosaves conforme o preset e confirma o save final ao voltar ao menu ou fechar a janela. A cena aberta diretamente pelo editor cria um mundo no seletor na primeira saída normal.

`demo.tscn` contém o nó de população que `demo_world.gd` conecta ao jogador, ao streaming e ao registro de entidades. A sessão simula a fauna próxima em memória e inclui sua camada física nas checagens de colocação de blocos.
