shader_type spatial;

uniform bool enable_x;
uniform bool enable_y;

void fragment() {
	ALBEDO = vec3(UV.y);
}