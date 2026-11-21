# Instruções do projeto

## Resumos das pastas

- Mantenha um `README.md` em cada pasta de conteúdo do projeto, explicando sua função e resumindo os arquivos e subpastas relevantes.
- Sempre que criar, remover, renomear ou alterar um arquivo de uma pasta, atualize o `README.md` dessa mesma pasta para refletir o estado atual. Se a mudança alterar a estrutura ou a responsabilidade de uma pasta, atualize também os resumos das pastas ancestrais afetadas.
- Em mudanças que atinjam várias pastas, revise o `README.md` de cada pasta atingida. Uma atualização do próprio `README.md` não exige uma segunda atualização dele.
- Não liste arquivos auxiliares gerados pelo Godot (`.uid` e `.import`) individualmente; explique esses metadados em conjunto quando forem relevantes.
- `.godot/` e `graphify-out/` são saídas geradas e ficam fora desta regra de documentação.

## Graphify

- Em trabalhos com código, confirme a raiz e a atualização do grafo, consulte as relações relevantes antes de alterar e confirme os resultados nos arquivos-fonte.
- Após mudanças de código, atualize o grafo por AST local, sem chamadas a modelos ou serviços externos.
- A autorização para usar Graphify não autoriza executar o jogo, builds ou testes.
