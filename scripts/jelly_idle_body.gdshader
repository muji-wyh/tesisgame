shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

varying vec4 body_modulate;

void vertex() {
	body_modulate = COLOR;
}

void fragment() {
	// Transparent viewport pixels already contain premultiplied source paint.
	vec4 paint = texture(TEXTURE, UV);
	COLOR = vec4(paint.rgb * body_modulate.rgb * body_modulate.a, paint.a * body_modulate.a);
}
