shader_type spatial;
render_mode unshaded, blend_mix;
#include "res://addons/ldk/core/Voxel/View/voxel_surface_effects.gdshaderinc"

uniform sampler2DArray tile_layers : source_color, filter_nearest, repeat_enable;
varying flat float tile_layer;

void vertex() {
	tile_layer = UV2.x;
	voxel_position = (voxel_from_world * MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	voxel_normal = voxel_normal_from_world * MODEL_NORMAL_MATRIX * NORMAL;
}

void fragment() {
	vec3 cell = voxel_owner();
	float coverage = voxel_coverage(cell, FRAGCOORD.xy);
	if (coverage <= 0.0) {
		discard;
	}
	vec3 sample_position = vec3(UV, tile_layer);
	vec3 tile = texture(tile_layers, sample_position).rgb;
	if (coverage < 1.0) {
		tile = voxel_blur_tile(tile_layers, sample_position, tile);
	}
	ALBEDO = voxel_highlight(tile, cell);
	ALBEDO = voxel_mining_effect(ALBEDO, cell, UV);
	ALPHA = 0.86 * coverage;
}
