# Editor de conteúdo

Na aba **LDK**, o ícone **Configurações** abre as preferências do contexto. Use **Adicionar pasta…** nas abas **Pastas de leitura** e **Pastas ignoradas** para escolher diretórios do projeto (`res://`) ou dos dados do usuário (`user://`). Cada tag mostra o nome da pasta e exibe o caminho completo ao passar o mouse. O botão **×** pede confirmação para retirar a pasta da lista e preserva os arquivos no disco.

A leitura inclui subpastas e descobre manifestos `ContentPack` e outros Resources `.tres` e `.res`. As pastas ignoradas prevalecem sobre as de leitura. Se um Resource ou manifesto depender de um arquivo ignorado, o editor informa o caminho em **Avisos** e deixa o dependente fora do catálogo.

O **Namespace** começa em `core` e é usado para Resources sem namespace no manifesto da pasta ou na própria definição. Para um mod `technology` que dependa de `core`, inclua `res://mods/technology` e `res://assets/core` nas pastas de leitura e escolha `technology` como namespace padrão do contexto.

**Salvar** grava as preferências daquele contexto em `user://ldk/content_editor/`. O contexto **Nativo** recebe as pastas iniciais de `ldk/content_editor/native_directories` nas Configurações do Projeto. **Mods** aceita `ldk/content_editor/mod_directories` e começa sem pastas neste projeto. A edição de mods usa os Resources em pasta. A instalação de PCK é feita pela inicialização do jogo.

A aba **Voxel** reúne **Blocos**, **Biomas** e **Mundos** em uma árvore. As subpastas abaixo da pasta da categoria são preservadas. Por exemplo, `block/stones/granite.tres` aparece em **Blocos > stones > granite**. Sem uma pasta reconhecida para a categoria, a árvore usa o caminho relativo ao pacote ou à pasta de leitura. As fontes compartilham a mesma árvore, com namespace e caminho no tooltip de cada Resource. Em caso de nomes iguais no mesmo ramo, a linha mostra o namespace e, se necessário, o caminho de origem.

Para biomas e mundos, o painel direito mostra o tipo, a origem e as propriedades do Resource e dá acesso ao Inspetor do Godot. Arraste o divisor para ajustar os painéis. A faixa acima dos painéis aparece quando há avisos ou faltam pastas de leitura. O ícone **Atualizar**, ao lado de **Configurações**, relê as fontes do contexto selecionado. Cada contexto mantém a última leitura em memória e altera a árvore quando troca de contexto, salva novas pastas ou regras de exclusão, muda o namespace padrão ou solicita uma atualização.

## Editor visual de blocos

Selecione um bloco na árvore para ver seu ID e o grafo. Use a barra do canvas para o zoom e arraste os nós para organizá-los. **Adicionar componente** abre o seletor com os tipos registrados no contexto, incluindo os dos mods carregados. Pesquise por nome, categoria ou descrição. Passe o mouse para ver a finalidade de um tipo. Clique em um resultado ou pressione Enter para criar um rascunho com os valores padrão. Também é possível arrastar um Resource compatível do painel **Sistema de Arquivos** para o canvas. Use os botões do cabeçalho para duplicar ou remover os componentes selecionados.

Para um cubo opaco com a mesma textura nas seis faces, adicione **SimpleTexture**, escolha a textura do catálogo e conecte à porta **Visual** de **BlockDefinition**. O preset configura forma, UVs e oclusão. Use **Texture** nessa porta para modelos ou faces personalizadas. **Collision**, **Breakable**, **Interactable** e **Occlusion** têm portas próprias. Conecte **Drops** à entrada do **Breakable** ativo. Para desconectar, arraste o fio pela sua porta de entrada e solte no canvas. Desconecte **Drops** antes de desligar seu **Breakable**. Os avisos de referência consultam itens e texturas do catálogo do contexto.

As propriedades são editadas nos próprios nós. Campos de texto são confirmados com Enter ou ao perder o foco. Separe as seis texturas por vírgulas na ordem indicada. Em **Drops**, use pares como `core:stone=2, core:clay=1`. Uma edição válida em um componente conectado é salva no próprio arquivo do bloco. Se o componente veio de um Resource compartilhado, a edição cria uma cópia para aquele bloco.

**Desfazer** e **Refazer** operam por bloco sobre edições, conexões e movimentos. Rascunhos e histórico ficam em memória até trocar de contexto, atualizar o catálogo ou fechar o editor. As posições da definição e dos componentes ativos ficam em `user://ldk/content_editor/graphs/`. Os fios são reconstruídos a partir dos campos do bloco.

## Extensão

- Instancie `content_editor.tscn` e adicione-o à árvore do editor. Depois de `ready`, registre cada contexto com `register_context(context)`. Crie os objetos pelo script `content_editor_context.gd` e forneça um ID estável, título e pastas iniciais.
- Registre uma categoria com `register_category(id, title, panel, refresh)`. O painel é um `Control` próprio, sem pai. O callback opcional `refresh(context)` recebe o contexto quando a aba visível precisa exibir um novo catálogo.
- `content_editor_context.gd` mantém as preferências e a leitura obtida pela `ContentLibrary`. `content_editor.gd` alterna as abas e atualiza o painel ativo conforme a revisão do contexto.
- `voxel_editor_catalog.gd` prepara a hierarquia virtual. `voxel_editor_panel.tscn` encaminha blocos ao `block_graph_editor.tscn` e os outros Resources à prévia genérica `content_resource_panel.tscn`.

- `resource_graph_canvas.gd` monta nós, portas e fios e recebe Resources por arraste. `block_graph_editor.gd` adapta campos e ligações do bloco ao canvas. `block_graph_document.gd` valida, grava o Resource de origem e mantém o histórico e a disposição dos nós.
- `component_picker.tscn` recebe descritores do editor que o instancia e emite o ID escolhido. A pesquisa filtra as linhas existentes. O grafo voxel monta a lista a partir do registro de componentes do contexto.
- `content_editor_settings` implementa o formulário. `directory_tag_selector.tscn` e seu script compartilham a edição em tags, o seletor de diretórios e a confirmação entre as duas listas. `settings.svg` e `refresh-cw.svg` são os ícones do cabeçalho.

[Godot — EditorPlugin](https://docs.godotengine.org/en/stable/tutorials/plugins/editor/making_plugins.html) · [Tree](https://docs.godotengine.org/en/stable/classes/class_tree.html) · [HSplitContainer](https://docs.godotengine.org/en/stable/classes/class_hsplitcontainer.html)
