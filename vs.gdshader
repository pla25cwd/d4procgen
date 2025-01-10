shader_type spatial;
render_mode world_vertex_coords;

uniform float n = 5;

void vertex() {
	VERTEX = trunc(VERTEX*n)/n;
}