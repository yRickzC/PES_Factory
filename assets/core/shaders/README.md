# Shaders de assets

`terrain.gdshader` desenha o terreno com filtragem Nearest. `terrain_blur.gdshader` desenha os blocos afetados pelo recorte em um passe translúcido, com desfoque restrito à textura de cada bloco. Ambos compartilham iluminação, atlas, rotações e variantes em `terrain_surface.gdshaderinc`.

`water.gdshader` define a aparência da água e aplica o desfoque no próprio passe translúcido. Os três shaders usam os efeitos de superfície do LDK.
