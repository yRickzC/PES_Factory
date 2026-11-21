render_mode ambient_light_disabled, specular_disabled;
#include "res://addons/ldk/core/Voxel/View/voxel_surface_effects.gdshaderinc"
#include "res://addons/ldk/core/Voxel/View/voxel_top_texture.gdshaderinc"

#ifdef VOXEL_BLUR_PASS
uniform sampler2DArray tile_layers : source_color, filter_linear, repeat_enable;
#else
uniform sampler2DArray tile_layers : source_color, filter_nearest, repeat_enable;
#endif
uniform float wall_brightness : hint_range(0.35, 1.0, 0.01) = 0.84;
uniform float shadow_contrast : hint_range(0.0, 0.5, 0.01) = 0.13;
uniform float elevation_contrast : hint_range(0.0, 0.06, 0.001) = 0.020;
uniform float reference_elevation = 6.0;
uniform float ledge_width : hint_range(0.0, 0.25, 0.005) = 0.085;
uniform float ledge_contrast : hint_range(0.0, 0.5, 0.01) = 0.24;
varying flat float tile_layer;
varying flat int ledge_sides;
varying flat int top_style;
varying float upness;
varying float elevation;

void vertex() {
	vec4 world_position = MODEL_MATRIX * vec4(VERTEX, 1.0);
	tile_layer = UV2.x;
	int markings = int(UV2.y);
	ledge_sides = markings & 63;
	top_style = markings >> 6;
	upness = normalize(MODEL_NORMAL_MATRIX * NORMAL).y;
	elevation = world_position.y;
	voxel_position = (voxel_from_world * world_position).xyz;
	voxel_normal = voxel_normal_from_world * MODEL_NORMAL_MATRIX * NORMAL;
}

float ledge_tone(vec2 uv) {
	if (ledge_sides == 0) {
		return 1.0;
	}
	// The mesher marks exposed X+, X-, Z+, and Z- sides on visible cube tops.
	vec2 tile_position = fract(uv);
	bool ledge = ((ledge_sides & 1) != 0 && tile_position.x > 1.0 - ledge_width)
		|| ((ledge_sides & 2) != 0 && tile_position.x < ledge_width)
		|| ((ledge_sides & 16) != 0 && tile_position.y > 1.0 - ledge_width)
		|| ((ledge_sides & 32) != 0 && tile_position.y < ledge_width);
	return ledge ? 1.0 - ledge_contrast : 1.0;
}

void fragment() {
	vec3 cell = voxel_owner();
#ifdef VOXEL_BLUR_PASS
	float coverage = voxel_coverage(cell, FRAGCOORD.xy);
	if (coverage <= 0.0 || coverage >= 1.0) {
		discard;
	}
	ALPHA = coverage;
#else
	if (!voxel_visible(cell, FRAGCOORD.xy)) {
		discard;
	}
#endif
	vec3 sample_position = voxel_tile_sample(UV, tile_layer, top_style, cell);
	vec3 tile = texture(tile_layers, sample_position).rgb;
#ifdef VOXEL_BLUR_PASS
	tile = voxel_blur_tile(tile_layers, sample_position, tile);
#endif
	float top = smoothstep(0.0, 0.75, upness);
	// Compress brightness at extreme heights while preserving contrast between nearby levels.
	float height_offset = elevation - reference_elevation;
	float elevation_tone = 1.0 + elevation_contrast * height_offset / (1.0 + 0.16 * abs(height_offset));
	float face_tone = mix(wall_brightness, 1.0, top);
	ALBEDO = voxel_highlight(tile * face_tone * elevation_tone * ledge_tone(UV), cell);
	ALBEDO = voxel_mining_effect(ALBEDO, cell, UV);
	EMISSION = ALBEDO * (0.86 - shadow_contrast);
}

void light() {
	float facing = smoothstep(0.0, 0.75, dot(NORMAL, LIGHT));
	DIFFUSE_LIGHT += LIGHT_COLOR * (shadow_contrast / PI) * facing * ATTENUATION;
}
