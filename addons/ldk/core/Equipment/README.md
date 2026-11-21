# Equipamento de mão

`HandEquipment` reúne os Resources `EquipmentAction` e `HandEquipmentVisual`. A ação configura duração, ponto de impacto, intervalo entre ataques, movimento e repetição. A aparência configura a textura, o ponto de empunhadura e a pose da mão. `VoxelMiningTool` define o trabalho de mineração por impacto. `MeleeWeapon` define dano, alcance, arco, janela ativa, tolerância a cliques antecipados e máscara física dos alvos.

`ActorStateMachine` mantém o estado e o tempo por ator. No jogador, Idle, Walk e Run são escolhidos pela movimentação e pelo comando de corrida. Attack continua registrando a locomoção solicitada para retomá-la na saída. `impacted` sinaliza o primeiro impacto e `impact_window` informa o trecho ativo percorrido no tick. A fauna reutiliza o relógio e as transições para Idle, Wander, Forage, Flee e Dead. O hitstop suspende localmente o avanço do estado e do cooldown.

`MeleeEffects` configura as texturas, cores, dimensões e duração dos efeitos. `MeleeEffectView` usa o relógio do ataque para desenhar o rastro e mantém o tempo das faíscas durante o hitstop. `MeleeWeapon.hit_feedback` configura a pausa, o recuo e o tremor do atacante em contatos confirmados.

Para cadastrar outro equipamento, associe um `HandEquipment` a um `InventoryItem` e registre o item no manifesto. Outra arma corpo a corpo pode usar `MeleeWeapon` com seus próprios valores e aparência.
