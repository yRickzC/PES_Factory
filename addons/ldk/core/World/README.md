# Mundo

`world_definition.gd` reúne seed, geração, ambiente, física, ponto inicial e configurações de persistência. Os arquivos `world_environment_*`, `world_physics_config.gd` e `projected_ground_shadow.gd` configuram a apresentação e as regras do mundo. `world_save_store.gd` cria, lista e abre saves em `user://worlds`. `world_save.gd` representa os metadados de cada mundo e lê o antigo `state.dat`. `world_session.gd` passa o contexto do save à cena de jogo.

A sessão e a persistência compartilham a definição de mundo e os tipos do próprio LDK.

`WorldPhysicsConfig` define a velocidade de caminhada, o multiplicador de corrida e a aceleração e desaceleração horizontais usadas pelo jogador.

`WorldEnvironmentConfig` permite definir uma tonalidade noturna para a cena 3D. A View aplica a cor também a superfícies e sprites sem iluminação e interpola o efeito com o ciclo de dia e noite. A interface é desenhada por cima.

O catálogo **Mundos** do editor LDK abre os presets `WorldDefinition` e seus Resources de configuração no Inspetor.

## Persistência

- `save_manager.gd` captura o estado do jogador e os chunks sujos na thread principal. Um único worker grava a transação; edições novas ficam pendentes para a próxima. Uma falha devolve os chunks ao conjunto sujo. A saída aguarda a gravação final.
- `chunk_save_codec.gd` codifica deltas por índice local com uma paleta de IDs `namespace:nome`. A partir de 256 edições, compara os bytes da representação esparsa com os de um vetor de índices de paleta comprimido com Zstandard. Usa o vetor quando ele ocupa menos bytes. O índice reservado para uma célula procedural é distinto de `core:air`, que registra uma remoção.
- `world_save_files.gd` grava regiões de 4×4×4 chunks e alterna dois manifestos de commit. Cada manifesto tem a versão do formato, a identidade do mundo e do gerador, os dados do jogador e as referências das regiões. Objetos persistentes e estados de componentes ocupam mapas esparsos próprios nos registros dos chunks. O terreno intacto é regenerado pela seed.

O worker publica cada região alterada por arquivo temporário e renomeação. Só publica o manifesto após concluir as regiões, vinculando suas alterações ao mesmo estado de inventário e crafting. A abertura verifica os checksums SHA-256 do manifesto e das regiões com edições, então carrega os deltas em memória. Se a revisão mais recente estiver incompleta ou corrompida, tenta a anterior. Uma versão incompatível exige migração. Uma interrupção pode deixar arquivos de região sem referência. A recuperação depende dos arquivos que o sistema operacional conseguiu gravar.

O formato de regiões usa apenas APIs nativas do Godot. SQLite com WAL permitiria escritas transacionais e consultas pontuais, mas exigiria integrar e distribuir uma extensão nativa. O formato escolhido regrava apenas as regiões tocadas e mantém duas revisões recuperáveis. [Luanti — formato de mundo](https://github.com/luanti-org/luanti/blob/master/doc/world_format.md) · [Vintage Story — Chunk Data Storage](https://wiki.vintagestory.at/Chunk_Data_Storage) · [SQLite — WAL](https://www.sqlite.org/wal.html) · [Godot — FileAccess](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html)

Em **Persistência** no preset, defina um ID estável, a versão do gerador, o intervalo de autosave e a gravação no descarregamento de chunks sujos. O formato antigo migra na primeira gravação bem-sucedida. Mantenha o ID do preset ao mover o arquivo e atualize a versão do gerador quando uma alteração incompatível mudar a base procedural.
