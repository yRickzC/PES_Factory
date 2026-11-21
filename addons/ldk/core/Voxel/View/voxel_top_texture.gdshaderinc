uniform sampler2D voxel_top_styles : filter_nearest, repeat_disable;
uniform int voxel_texture_seed = 0;

uvec3 voxel_texture_hash(ivec3 cell) {
	// Mix the signed cell coordinates as unsigned bits, including negative chunks.
	uvec3 bits = uvec3(cell) * 1664525u + uvec3(uint(voxel_texture_seed) + 1013904223u);
	bits += bits.yzx * bits.zxy;
	bits = bits ^ (bits >> 16u);
	bits += bits.yzx * bits.zxy;
	return bits ^ (bits >> 16u);
}

vec3 voxel_top_texel(int index) {
	return floor(texelFetch(voxel_top_styles, ivec2(index & 255, index >> 8), 0).rgb * 255.0 + 0.5);
}

vec3 voxel_tile_sample(vec2 uv, float layer, int style, vec3 cell) {
	if (style == 0) {
		return vec3(uv, layer);
	}
	vec3 settings = voxel_top_texel(style);
	if (settings.z < 1.0) {
		return vec3(uv, layer);
	}
	uvec3 random_bits = voxel_texture_hash(ivec3(cell));
	vec2 p = fract(uv);
	int rank = int(random_bits.x % uint(settings.z));
	int turn = (int(settings.x) >> (rank * 2)) & 3;
	if (turn == 1) {
		p = vec2(p.y, 1.0 - p.x);
	} else if (turn == 2) {
		p = vec2(1.0) - p;
	} else if (turn == 3) {
		p = vec2(1.0 - p.y, p.x);
	}
	if (settings.y > 0.0) {
		int variant = int(random_bits.z % (uint(settings.y) + 1u));
		layer = voxel_top_texel(style + 1 + variant).x;
	}
	return vec3(min(p, vec2(0.999999)), layer);
}
