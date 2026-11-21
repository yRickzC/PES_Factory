# Verificações do mundo

`voxel_check.gd` reúne verificações do terreno, inventário, crafting e interação, incluindo as seis faces de construção, a estabilidade nas bordas e a seleção por camada. `landmark_blocks.gd`, `landmark_generator.gd` e `landmark_placement.gd` preparam terreno fixo e marcos para os cenários de integração. O cabeçalho do script indica o comando de execução manual.

A verificação da mira em terreno plano cobre o centro, as quatro bordas com vizinhos sólidos e uma lateral livre na mesma altura. A verificação de faces também cobre impactos diretos próximos à borda vertical de uma lateral.

As verificações de alcance cobrem o alvo visível fora do alcance, a volta ao alcance, o raio sem impacto e o destino distante na construção por camada.

A verificação do inventário usa a ação de atalho para abrir a bolsa e ativa os slots de origem e destino. Ela confere as quantidades exibidas na bolsa e na barra rápida após transferir e consumir itens.

A verificação de mineração da árvore confere a recompensa de quatro a oito troncos e a preservação do bloco de suporte mesmo após manter o golpe. As verificações de flores cobrem o vínculo entre a entidade e o item de cada cor, o replantio na mesma célula, a retenção após descarregar o chunk e a rejeição de ações duplicadas.

A verificação da picareta cobre equipar pela Hotbar, interromper o balanço ao trocar de slot, aplicar dano uma vez no impacto e retornar a Walk e Idle.

As verificações integram os módulos do LDK com a cena da demonstração. Os PCKs temporários exercitam dependências, conflito, versão, escopo de montagem, compatibilidade de IDs e o compartilhamento de biomas, receitas e componentes.

`save_check.gd` valida mineração, construção, plantio, inventário, Hotbar, equipamento, HP, posição e retomada do crafting em processos separados. Também cobre a gravação ao descarregar um chunk, o autosave, a ausência de fauna temporária no save, estados esparsos de componentes, recuperação de uma revisão interrompida e migração de `state.dat`.

Execute na raiz com Godot disponível no PATH. O teste usa uma pasta separada em `.godot/`.

```powershell
$env:APPDATA = Join-Path $PWD '.godot/save-check-home'
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
foreach ($phase in @('write', 'read', 'recover', 'legacy')) {
    godot --headless --path . --max-fps 120 --script res://src/World/Checks/save_check.gd -- $phase
    if ($LASTEXITCODE -ne 0) { break }
}
```
