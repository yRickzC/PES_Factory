# Menu

`startup.tscn` e `startup.gd` mostram as etapas e a contagem do carregamento. Ao publicar o banco, a cena abre `main_menu.tscn`, que mostra avisos de conteúdo quando presentes. `world_selection.tscn` e `world_selection.gd` usam o armazenamento de mundos do LDK para listar, criar e abrir mundos. `create_world_form.*` implementa o formulário. `menu_backdrop.*` e `pixel_menu_theme.tres` fornecem aparência compartilhada.

`pause_menu.gd` pausa a simulação, informa ao mundo quando o menu abre ou fecha e conecta o comando de salvar e sair. `controls_view.gd` organiza ações por categoria e oferece busca, captura de teclas e botões do mouse e restauração de atalhos. `settings_view.gd` aplica opções de áudio, vídeo e gameplay. `pixel_menu_theme.tres` compartilha o estilo desses painéis. Os menus aceitam mouse, navegação por foco com **Tab** e **setas** e confirmação com **Enter**.

O atalho de pausa também funciona enquanto o comando de corrida estiver pressionado.
