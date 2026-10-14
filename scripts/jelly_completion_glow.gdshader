shader_type canvas_item;
render_mode unshaded;
varying vec4 light_tint;

void vertex() {
	light_tint = COLOR;
}

void fragment() {
	vec4 light = texture(TEXTURE, UV);
	// Lift the acquired portal's faint wisps so they read on the pale garden.
	// Retain the authored falloff and its transparent edge, without a hard ring.
	light.a = pow(light.a, 0.45) * smoothstep(0.0, 0.025, light.a);
	COLOR = light * light_tint;
}
