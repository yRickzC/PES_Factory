# Streaming voxel

`voxel_world.gd` coordena chunks visíveis, alterações e publicação das malhas. Também expõe as definições por célula, exporta edições de blocos por ID estável, valida o apoio de objetos plantados e sinaliza à View o plantio e a destruição. `voxel_chunk_job.gd` executa trabalho assíncrono por chunk. `voxel_cancellation.gd` permite cancelar tarefas obsoletas.

As edições exportadas usam `namespace:nome`. A restauração aceita referências legadas e mantém o ID original de conteúdo ausente para uma futura reabertura.

`VoxelWorld` exporta e restaura registros de bloco, objeto e componente por chunk. Emite `persistence_changed` após alterações persistentes e `chunk_unloaded` ao descarregar o chunk. O sistema de save usa esses sinais para acompanhar alterações sem consultar a View.

Use `set_persistent_component_state(cell, id, state)` para guardar um estado individual e `persistent_component_states(cell)` para consultá-lo. O ID usa o namespace da definição que possui o estado. Guarde apenas valores simples. Passe `null` para remover o estado. Substituir o bloco ou remover o objeto também remove o estado correspondente.
