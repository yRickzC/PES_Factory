# Preferências e atalhos

`game_settings.gd` define os padrões de controle, áudio, vídeo e gameplay. `game_action_definition.gd` descreve cada ação, sua categoria e seus eventos iniciais. `game_preferences.gd` aplica os atalhos ao `InputMap`, detecta conflitos, restaura padrões e persiste as alterações em um `ConfigFile`. Escape permanece disponível como atalho de emergência para a ação de pausa. Pacotes de conteúdo podem registrar ações adicionais sem editar a interface.

`pressed_with_held_modifiers()` permite combinar um atalho com modificadores de ações mantidas, como corrida e construção por camada. Combinações atribuídas explicitamente têm prioridade.
