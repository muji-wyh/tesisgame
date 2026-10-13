shader_type canvas_item;
render_mode unshaded;

uniform vec2 canvas_size = vec2(108.0, 184.0);
uniform vec2 body_size = vec2(84.0, 44.0);
uniform vec2 body_origin = vec2(12.0, 10.0);
uniform float pull = 0.0;
uniform float max_pull = 116.0;
uniform float sideways = 0.0;
uniform float armed = 0.0;
uniform float focus_light = 0.0;
uniform float shimmer = 0.0;
uniform vec4 light_color : source_color = vec4(1.0, 0.92, 0.65, 1.0);
varying vec4 surface_modulate;

void vertex() {
	surface_modulate = COLOR;
}

void fragment() {
	vec2 point = UV * canvas_size - body_origin;
	float h = max(1.0, body_size.y);
	// Invert y = h * t + pull * t^2. The upper shoulder stays attached while
	// the lower lobe takes the displacement, including the small spring recoil.
	float t = point.y / h;
	if (abs(pull) > 0.01) {
		float discriminant = max(0.0, h * h + 4.0 * pull * point.y);
		t = 2.0 * point.y / max(1.0, h + sqrt(discriminant));
	}
	float tension = clamp(pull / max(1.0, max_pull), 0.0, 1.0);
	float waist = pow(sin(clamp(t, 0.0, 1.0) * 3.14159265), 2.0);
	float width = 1.0 - waist * tension * 0.48;
	width += max(0.0, -pull / h) * 0.35;
	float x = 0.5 + (point.x - body_size.x * 0.5 - sideways * t * t) / (body_size.x * width);
	vec2 source_uv = vec2(mix(0.018, 0.963, x), mix(0.108, 0.892, t));
	float inside = step(0.0, t) * step(t, 1.0) * step(0.0, x) * step(x, 1.0);
	vec4 paint = texture(TEXTURE, clamp(source_uv, vec2(0.0), vec2(1.0))) * inside;
	float lighting = max(armed, focus_light * 0.35);
	float sweep = 1.0 - smoothstep(0.03, 0.19, abs(x * 0.72 + t * 0.28 - shimmer));
	paint.rgb = mix(paint.rgb, light_color.rgb, lighting * (0.17 + sweep * 0.32));
	if (lighting > 0.0) {
		float rim = 0.0;
		for (int i = 0; i < 8; i++) {
			float angle = float(i) * 0.78539816;
			vec2 offset = vec2(cos(angle), sin(angle)) * 0.022;
			rim = max(rim, texture(TEXTURE, source_uv + offset).a * inside);
		}
		rim = max(0.0, rim - paint.a) * lighting;
		float alpha = paint.a + rim;
		paint = vec4((paint.rgb * paint.a + light_color.rgb * rim) / max(alpha, 0.001), alpha);
	}
	COLOR = paint * surface_modulate;
}
