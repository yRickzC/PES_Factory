shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled;

uniform vec4 outline_color : source_color;
uniform float outline_width;

void fragment() {
	vec2 edge = min(UV, vec2(1.0) - UV);
	if (min(edge.x, edge.y) > outline_width) {
		discard;
	}
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
