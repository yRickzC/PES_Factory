# Presets de mundo

`overworld.tres` define o preset padrão do mundo da demo, com geração, ambiente, física e ponto inicial. O gerador resolve os biomas pelo banco de conteúdo carregado na inicialização.

O Resource de física define a corrida em 1,5× a velocidade de caminhada, com aceleração e desaceleração configuráveis.

O ambiente de `overworld.tres` usa uma tonalidade azul-escura durante a noite, com transição gradual ao amanhecer e ao entardecer.

O grupo **Persistência** do Inspetor define o ID estável `core:overworld`, a versão do gerador, o autosave a cada 60 segundos e o salvamento quando um chunk sujo é descarregado.
