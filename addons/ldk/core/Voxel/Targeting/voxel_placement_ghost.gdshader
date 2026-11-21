shader_type spatial;
render_mode unshaded, blend_mix, shadows_disabled;

uniform sampler2DArray tile_layers : source_color, filter_nearest, repeat_enable;
uniform float opacity = 0.48;
varying flat float tile_layer;

void vertex() {
	tile_layer = UV2.x;
}

void fragment() {
	ALBEDO = texture(tile_layers, vec3(UV, tile_layer)).rgb;
	ALPHA = opacity;
}
