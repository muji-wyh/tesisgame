shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

uniform vec2 surface_size = vec2(100.0);
uniform float mesh_scale = 1.0;
varying vec4 body_modulate;

void vertex() {
	// Padded atlas paint keeps the original skin, pivot and learning face fixed.
	VERTEX = (VERTEX - surface_size * 0.5) * mesh_scale + surface_size * 0.5;
	body_modulate = COLOR;
}

void fragment() {
	// Transparent viewport pixels already contain premultiplied source paint.
	vec4 paint = texture(TEXTURE, UV);
	COLOR = vec4(paint.rgb * body_modulate.rgb * body_modulate.a, paint.a * body_modulate.a);
}
