shader_type spatial;

group_uniforms road_alpha;
uniform sampler2D s_alpha_grad : source_color, filter_nearest;
uniform sampler2D s_v_alpha_grad : source_color, filter_nearest;
uniform sampler2D s_alpha_noise : source_color, filter_nearest;

group_uniforms base;
uniform sampler2D s_base_color : source_color, filter_nearest;
uniform sampler2D s_base_detail : source_color, filter_nearest;

group_uniforms rocks_and_shit;
uniform sampler2D s_ras_base : source_color, filter_nearest;
uniform float ras_base_threshold = 0.8;
uniform float ras_base_blend = 0.6;
uniform sampler2D s_ras_detail : source_color, filter_nearest;

group_uniforms tracks;
uniform sampler2D s_tracks_grad : source_color, filter_nearest;
uniform sampler2D s_tracks_noise : source_color, filter_nearest;
uniform sampler2D s_tracks_treads : source_color, filter_nearest;

void fragment() {
	METALLIC = 0.0;
	SPECULAR = 0.0;
	ROUGHNESS = 1.0;

	vec4 alpha_grad = texture(s_alpha_grad, UV);
	vec4 v_alpha_grad = texture(s_v_alpha_grad, vec2(UV2.y, UV2.x));
	vec4 alpha_noise = texture(s_alpha_noise, UV);
	ALPHA = alpha_grad.r + ((alpha_grad.r - alpha_noise.r)*0.3) - v_alpha_grad.r;


	vec4 base_color = texture(s_base_color, UV+0.5);
	vec4 base_detail = texture(s_base_detail, UV+0.5);

	vec3 color = base_color.rgb * (0.9+(base_detail.r*0.1));


	vec4 ras_base = texture(s_ras_base, UV+0.5);
	vec4 ras_detail = texture(s_ras_detail, UV+0.5);

	float ras_mix = (ras_base.r - ras_base_blend)/(ras_base_threshold-ras_base_blend);
	color = mix(color, ras_detail.rgb, clamp(ras_mix, 0, 1));


	vec4 tracks_grad = texture(s_tracks_grad, UV);
	vec4 tracks_noise = texture(s_tracks_noise, UV+0.5);
	vec4 tracks_treads = texture(s_tracks_treads, UV+0.5);

	color = mix(color, tracks_treads.rgb, (tracks_grad.r - tracks_grad.r*2.0) + tracks_noise.r*tracks_grad.r);


	ALBEDO = color;

}