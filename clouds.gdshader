shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler3D noise : source_color, filter_nearest;
uniform sampler2D alpha : source_color, filter_nearest;

void vertex() {
	vec4 noise_v = texture(noise, vec3(UV, 0));
	VERTEX.y = noise_v.r*10.0;
}

void fragment() {
	ALBEDO = vec3(1, 1, 1);
	vec4 noise_v = texture(noise, vec3(UV, 0));
	vec4 alpha_v = texture(alpha, UV);
	ALPHA = noise_v.r * alpha_v.r;
}