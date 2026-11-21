// Locate individual cells even on a single quad spanning multiple blocks.
uniform mat4 voxel_from_world;
uniform mat3 voxel_normal_from_world;
varying vec3 voxel_position;
varying vec3 voxel_normal;

uniform bool cutaway_enabled = false;
uniform bool cutaway_soft_blur = false;
uniform sampler2D cutaway_columns : filter_nearest, repeat_disable;
uniform ivec2 cutaway_origin;
uniform bool cutaway_cap_pass = false;
const float CUTAWAY_TRANSPARENCY = 0.9;
const int CONSTRUCTION_SOFT_BLUR = 2;

uniform bool construction_enabled = false;
uniform float construction_layer;
uniform float construction_cut;
uniform float construction_opacity = 0.1;
uniform int construction_style = 0;
uniform bool construction_reveal_front = true;
uniform vec2 construction_slope;
uniform vec2 construction_player;
uniform vec3 construction_destination;

uniform bool target_enabled = false;
uniform vec3 target_cell;
uniform vec3 target_normal;
uniform float target_plane;
uniform bool target_whole_block = false;
uniform vec4 target_color : source_color = vec4(1.0);
uniform vec3 target_settings = vec3(0.85, 0.16, 0.075);
uniform int target_style = 2;
uniform vec3 mining_cell;
uniform float mining_progress = 0.0;
uniform vec4 mining_color : source_color = vec4(0.24, 0.17, 0.19, 1.0);
uniform vec4 mining_edge_color : source_color = vec4(1.0, 0.9, 0.71, 0.65);
uniform float mining_opacity = 0.86;

vec3 voxel_owner() {
	return floor(voxel_position - normalize(voxel_normal) * 0.002);
}

float voxel_hidden(vec3 cell) {
	ivec2 coord = ivec2(cell.xz) - cutaway_origin;
	ivec2 dimensions = textureSize(cutaway_columns, 0);
	if (any(lessThan(coord, ivec2(0))) || any(greaterThanEqual(coord, dimensions))) {
		return 0.0;
	}
	vec4 column = texelFetch(cutaway_columns, coord, 0);
	return CUTAWAY_TRANSPARENCY * mix(step(column.r, cell.y), step(column.g, cell.y), column.b);
}

float voxel_bayer2(vec2 bit) {
	return bit.y + 2.0 * mod(bit.x + bit.y, 2.0);
}

float voxel_dither(vec2 fragment) {
	// Screen-door transparency keeps the chunk material in the opaque depth pipeline.
	vec2 p = mod(floor(fragment), 8.0);
	vec2 low = mod(p, 2.0);
	vec2 middle = mod(floor(p * 0.5), 2.0);
	vec2 high = floor(p * 0.25);
	return (16.0 * voxel_bayer2(low) + 4.0 * voxel_bayer2(middle) + voxel_bayer2(high) + 0.5) / 64.0;
}

bool construction_blocks_view(vec2 cell, vec2 focus) {
	vec2 delta = cell - focus;
	if (all(equal(delta, vec2(0.0)))) {
		return false;
	}
	// Sweep the focused cell towards the camera over one layer. A lateral neighbor
	// whose silhouette merely touches the sweep must stay opaque.
	vec2 directed = delta * mix(vec2(-1.0), vec2(1.0), step(vec2(0.0), construction_slope));
	vec2 speed = max(abs(construction_slope), vec2(0.0001));
	vec2 first = (directed - 0.9999) / speed;
	vec2 last = (directed + 0.9999) / speed;
	return max(0.0, max(first.x, first.y)) < min(1.0, min(last.x, last.y));
}

bool construction_fades(vec3 cell) {
	if (cell.y > construction_cut) {
		return true;
	}
	if (!construction_reveal_front || cell.y != construction_layer
		|| (construction_destination.z > 0.0 && all(equal(cell.xz, construction_destination.xy)))) {
		return false;
	}
	return construction_blocks_view(cell.xz, construction_player)
		|| (construction_destination.z > 0.0 && construction_blocks_view(cell.xz, construction_destination.xy));
}

bool voxel_uses_soft_blur() {
	return cutaway_soft_blur && (!construction_enabled || construction_style == CONSTRUCTION_SOFT_BLUR);
}

float voxel_coverage(vec3 cell, vec2 fragment) {
	float opacity;
	if (construction_enabled) {
		if (!construction_fades(cell)) {
			return 1.0;
		}
		opacity = construction_opacity;
	} else {
		if (!cutaway_enabled) {
			return 1.0;
		}
		opacity = 1.0 - voxel_hidden(cell);
	}
	if (voxel_uses_soft_blur() || opacity == 0.0 || opacity == 1.0) {
		return opacity;
	}
	float threshold = construction_enabled && construction_style == 1
		? fract(52.9829189 * fract(dot(floor(fragment), vec2(0.06711056, 0.00583715))))
		: voxel_dither(fragment);
	return step(threshold, opacity);
}

bool voxel_visible(vec3 cell, vec2 fragment) {
	if (voxel_coverage(cell, fragment) < 1.0) {
		return false;
	}
	return !cutaway_cap_pass ||
		voxel_coverage(cell + round(normalize(voxel_normal)), fragment) < 1.0;
}

vec3 voxel_blur_tile(sampler2DArray layers, vec3 sample_position, vec3 center) {
	vec2 texel = 1.5 / vec2(textureSize(layers, 0).xy);
	vec3 dx = vec3(texel.x, 0.0, 0.0);
	vec3 dy = vec3(0.0, texel.y, 0.0);
	return (4.0 * center + texture(layers, sample_position + dx).rgb
		+ texture(layers, sample_position - dx).rgb + texture(layers, sample_position + dy).rgb
		+ texture(layers, sample_position - dy).rgb) / 8.0;
}

vec3 voxel_highlight(vec3 color, vec3 cell) {
	if (!target_enabled || any(notEqual(cell, target_cell))) {
		return color;
	}
	if (target_whole_block) {
		float fill = target_style == 0 ? 0.25 : target_settings.y;
		return mix(color, target_color.rgb, fill * target_settings.x * target_color.a);
	}
	vec3 normal = normalize(voxel_normal);
	vec3 p = clamp(voxel_position - cell, vec3(0.0), vec3(1.0));
	float alignment = dot(normal, target_normal);
	bool same_face = alignment > 0.96 && abs(dot(p, target_normal) - target_plane) < 0.035;
	if (!same_face) {
		return color;
	}
	vec3 edge = min(p, 1.0 - p) + step(vec3(0.5), abs(normal));
	float width = min(min(edge.x, edge.y), edge.z);
	float amount = 0.0;
	if (target_style != 1 && width < target_settings.z) {
		amount = target_settings.x;
	} else if (target_style != 0) {
		amount = target_settings.y * target_settings.x;
	}
	return mix(color, target_color.rgb, amount * target_color.a);
}

bool voxel_mining_crack(vec2 p) {
	float spine = 7.0 + mod(floor(p.y * 0.5), 2.0);
	float reach = 1.0 + mining_progress * 7.0;
	float left = 7.0 - p.y;
	float right = p.y - 9.0;
	return (abs(p.y - 7.0) <= reach && p.x == spine)
		|| (left > 0.0 && left <= max(0.0, mining_progress - 0.25) * 8.0 && p.x == 8.0 - left)
		|| (right > 0.0 && right <= max(0.0, mining_progress - 0.5) * 10.0 && p.x == 7.0 + right);
}

vec3 voxel_mining_effect(vec3 color, vec3 cell, vec2 uv) {
	if (mining_progress <= 0.0 || any(notEqual(cell, mining_cell))) {
		return color;
	}
	// Tile-local pixel pattern works on both merged quads and custom shapes.
	vec2 p = floor(fract(uv) * 16.0);
	if (voxel_mining_crack(p)) {
		return mix(color, mining_color.rgb, mining_opacity * mining_color.a);
	}
	if (voxel_mining_crack(p - vec2(1.0, 0.0))) {
		return mix(color, mining_edge_color.rgb, mining_opacity * mining_edge_color.a);
	}
	// Keep progress visible on narrow surfaces that sample only part of the tile.
	return mix(color, mining_color.rgb, mining_progress * mining_opacity * mining_color.a * 0.2);
}
