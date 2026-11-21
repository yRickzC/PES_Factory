shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never;

uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform bool masked = false;
uniform sampler2D mask_texture : source_color, filter_nearest, repeat_disable;
uniform float alpha_cutoff = 0.0;
uniform int billboard_mode = 0;

void vertex() {
	if (billboard_mode == 1) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			MAIN_CAM_INV_VIEW_MATRIX[0], MAIN_CAM_INV_VIEW_MATRIX[1],
			MAIN_CAM_INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	} else if (billboard_mode == 2) {
		vec3 up = vec3(0.0, 1.0, 0.0);
		vec3 right = normalize(cross(up, MAIN_CAM_INV_VIEW_MATRIX[2].xyz));
		vec3 forward = normalize(cross(MAIN_CAM_INV_VIEW_MATRIX[0].xyz, up));
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(right, 0.0), vec4(up, 0.0), vec4(forward, 0.0), MODEL_MATRIX[3]);
	}
	// Keep the overlay just in front of the same surface while testing against the scene.
	vec4 view_position = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view_position.z += 0.001;
	POSITION = PROJECTION_MATRIX * view_position;
}

void fragment() {
	float opacity = 1.0;
	if (masked) {
		opacity = texture(mask_texture, UV).a * COLOR.a;
		if (opacity <= 0.0 || opacity < alpha_cutoff) {
			discard;
		}
		if (alpha_cutoff > 0.0) {
			opacity = 1.0;
		}
	}
	ALBEDO = vec3(1.0);
	ALPHA = opacity * strength;
}
