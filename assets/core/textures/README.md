# Texturas

Tiles de terreno e construção, sprites de árvores e do jogador, sombra e ícones do inventário. As variantes de grama, terra e pedra têm 16×16 pixels e preservam as bordas dos tiles base. A vegetação e as pedras usam sprites transparentes próprios. O manifesto associa texturas a IDs e registra seus caminhos para abertura sob demanda. Os arquivos `.import` são metadados gerados pelo Godot.

`pickaxe.tres` usa `pickaxe_texture.gd` para compor o sprite provisório com amostras de pedra e madeira. A Hotbar e a mão do Explorer compartilham a mesma textura.

`pixel_pattern_texture.gd` lê as grades de pixels e paletas de `sword.tres`, `sword_trail.tres`, `sword_hit.tres` e `weapon_reticle.tres`. Esses Resources fornecem o sprite da espada, o rastro do golpe, a faísca de contato e a mira de 16×16 pixels com centro transparente.
