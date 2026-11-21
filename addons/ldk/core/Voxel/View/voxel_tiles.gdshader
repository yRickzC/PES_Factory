shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2DArray tile_layers : source_color, filter_nearest, repeat_enable;
varying flat float tile_layer;

void vertex() {
	tile_layer = UV2.x;
}

void fragment() {
	ALBEDO = texture(tile_layers, vec3(UV, tile_layer)).rgb;
	ROUGHNESS = 1.0;
}
