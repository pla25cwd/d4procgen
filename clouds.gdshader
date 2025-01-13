shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler3D i_noise : source_color, filter_nearest;
uniform sampler2D i_alpha : source_color, filter_nearest;

void fragment() {
	ALBEDO = vec3(1.0);
	vec4 noise = texture(i_noise, vec3(UV, 0));
	vec4 alpha = texture(i_alpha, UV);
	ALPHA = noise.r * alpha.r;
}