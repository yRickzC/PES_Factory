shader_type spatial;
render_mode blend_mix, diffuse_lambert, specular_disabled, shadows_disabled;

uniform sampler2DArray tile_layers : source_color, filter_nearest, repeat_enable;
uniform float opacity : hint_range(0.0, 1.0) = 0.72;
varying flat float tile_layer;

void vertex() {
	tile_layer = UV2.x;
}

void fragment() {
	ALBEDO = texture(tile_layers, vec3(UV, tile_layer)).rgb;
	ALPHA = opacity;
	ROUGHNESS = 1.0;
}
