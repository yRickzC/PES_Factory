# Fauna temporária

- `wildlife_profile.gd` define HP, velocidades, pesos de comportamento, intervalos, terrenos, biomas, limites de spawn e o perfil opcional de feedback de dano no Resource `WildlifeProfile`. A chave do bioma controla a chance por região horizontal de 16 × 16 células.
- `wildlife_population.gd` consulta entidades registradas com um perfil de fauna. A seed determina as tentativas de formar grupos em regiões próximas. Amostras de altura, células carregadas, o bloco de apoio e a consulta física determinam quais posições podem receber o grupo.
- `wildlife_actor.gd` mantém HP, destino e grupo em memória. A `ActorStateMachine` fornece Idle, Wander, Forage, Flee e Dead. O ator procura solo para fuçar e margens próximas para se refrescar e mantém proximidade com o grupo. Quando `take_damage(amount, source_position)` reduz o HP, dispara o feedback. O empurrão usa o colisor do animal e precede a retomada da fuga ou da animação de morte. A distância ou a perda do chunk encerra a simulação da instância.
- `wildlife_view.gd` aplica direção, passada, movimento do focinho e pose de morte à cena visual a partir do estado e do tempo do ator. A cena configura as poses e os ritmos no inspetor.

Para registrar outra espécie passiva, associe `WildlifeProfile`, `ContentSceneCollision` e uma cena visual ao `ContentScene` e adicione a definição a `ContentPack.entities`. A população usa o mesmo registro de conteúdo da sessão, com ciclo de vida em memória. Uma região pode receber um grupo novo quando voltar ao alcance depois de ser esquecida.
