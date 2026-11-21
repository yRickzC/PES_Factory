shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

uniform sampler2D sprite_texture : source_color, filter_linear, repeat_disable;
instance uniform float cut_strength = 0.0;
instance uniform vec4 uv_bounds = vec4(0.0, 0.0, 1.0, 1.0);

vec4 premultiply(vec4 sample_color) {
	return vec4(sample_color.rgb * sample_color.a, sample_color.a);
}

vec4 sample_sprite(vec2 uv, vec2 texel) {
	if (any(lessThan(uv, uv_bounds.xy)) || any(greaterThanEqual(uv, uv_bounds.zw))) {
		return vec4(0.0);
	}
	vec2 center_uv = clamp(uv, uv_bounds.xy + texel * 0.5, uv_bounds.zw - texel * 0.5);
	return premultiply(texture(sprite_texture, center_uv));
}

void fragment() {
	ivec2 dimensions = textureSize(sprite_texture, 0);
	vec2 texel = 1.0 / vec2(dimensions);
	ivec2 pixel = clamp(ivec2(floor(UV * vec2(dimensions))), ivec2(0), dimensions - ivec2(1));
	vec4 sharp = premultiply(texelFetch(sprite_texture, pixel, 0));
	vec2 offset = texel * 2.0;
	vec4 blurred = sample_sprite(UV, texel) * 0.25;
	blurred += sample_sprite(UV + vec2(offset.x, 0.0), texel) * 0.125;
	blurred += sample_sprite(UV - vec2(offset.x, 0.0), texel) * 0.125;
	blurred += sample_sprite(UV + vec2(0.0, offset.y), texel) * 0.125;
	blurred += sample_sprite(UV - vec2(0.0, offset.y), texel) * 0.125;
	blurred += sample_sprite(UV + offset, texel) * 0.0625;
	blurred += sample_sprite(UV - offset, texel) * 0.0625;
	blurred += sample_sprite(UV + vec2(offset.x, -offset.y), texel) * 0.0625;
	blurred += sample_sprite(UV + vec2(-offset.x, offset.y), texel) * 0.0625;
	vec4 result = mix(sharp, blurred, smoothstep(0.0, 0.6, cut_strength));
	ALBEDO = result.rgb / max(result.a, 0.0001) * COLOR.rgb;
	ALPHA = result.a * (1.0 - cut_strength) * COLOR.a;
}
