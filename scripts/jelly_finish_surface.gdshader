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
uniform float pixel_unit = 1.0;
uniform vec4 light_color : source_color = vec4(1.0, 0.92, 0.65, 1.0);
varying vec4 surface_modulate;

void vertex() {
	surface_modulate = COLOR;
}

vec2 skin_uv(vec2 point) {
	float h = max(1.0, body_size.y);
	// Preserve the broad crown and the painted lower lobe. Only the clear
	// middle of the acquired skin carries the long elastic bridge.
	float cap = 0.20;
	float split = 0.42;
	float body_stretch = h * 0.65 * (1.0 - exp(-max(0.0, pull) / (h * 0.8)));
	float bridge_pull = pull - body_stretch;
	float bridge = h * (split - cap);
	float t = point.y / h;
	if (pull < 0.0) {
		t = point.y / max(1.0, h + pull);
	} else if (point.y >= h * split + bridge_pull) {
		t = split + (point.y - h * split - bridge_pull) / (h + body_stretch / (1.0 - split));
	} else if (point.y > h * cap) {
		// Invert an ease-in/out quadratic exactly, keeping both bridge ends
		// tangent to the unstretched cap instead of stretching its rounded tip.
		float y = point.y - h * cap;
		float extent = bridge + bridge_pull;
		float distance = min(y, extent - y);
		float u = 2.0 * distance / (bridge + sqrt(bridge * bridge + 8.0 * bridge_pull * distance));
		if (y > extent * 0.5) {
			u = 1.0 - u;
		}
		t = mix(cap, split, u);
	}
	float tension = clamp(pull / max(1.0, max_pull), 0.0, 1.0);
	// Shape the waist along the displayed length so the compressed paint
	// regions cannot turn the neck-to-belly transition into an angular shelf.
	float length_t = point.y / max(1.0, h + pull);
	float waist = sin(clamp((length_t - 0.10) / 0.75, 0.0, 1.0) * 3.14159265);
	float width = 1.0 - tension * (0.34 * waist * waist + 0.04 * smoothstep(0.20, 0.65, t));
	width += max(0.0, -pull / h) * 0.35;
	float travel = smoothstep(cap, split, t);
	float x = 0.5 + (point.x - body_size.x * 0.5 - sideways * travel) / (body_size.x * width);
	return vec2(mix(0.018, 0.963, x), mix(0.108, 0.892, t));
}

void fragment() {
	vec2 point = UV * canvas_size - body_origin;
	vec2 source_uv = skin_uv(point);
	float inside = step(0.0, source_uv.x) * step(source_uv.x, 1.0) * step(0.0, source_uv.y) * step(source_uv.y, 1.0);
	vec4 paint = texture(TEXTURE, clamp(source_uv, vec2(0.0), vec2(1.0))) * inside;
	float lighting = max(armed, focus_light * 0.35);
	float sweep = 1.0 - smoothstep(0.03, 0.19, abs(source_uv.x * 0.72 + source_uv.y * 0.28 - shimmer));
	paint.rgb = mix(paint.rgb, light_color.rgb, lighting * (0.17 + sweep * 0.32));
	if (lighting > 0.0) {
		float rim = 0.0;
		for (int i = 0; i < 8; i++) {
			float angle = float(i) * 0.78539816;
			// Sample in screen pixels and keep the source's transparent padding.
			// The rim stays even around the rounded foot at every pull distance.
			vec2 offset = vec2(cos(angle), sin(angle)) * 1.5 * pixel_unit;
			vec2 rim_uv = skin_uv(point + offset);
			float rim_inside = step(0.0, rim_uv.x) * step(rim_uv.x, 1.0) * step(0.0, rim_uv.y) * step(rim_uv.y, 1.0);
			rim = max(rim, texture(TEXTURE, clamp(rim_uv, vec2(0.0), vec2(1.0))).a * rim_inside);
		}
		rim = max(0.0, rim - paint.a) * lighting;
		float alpha = paint.a + rim;
		paint = vec4((paint.rgb * paint.a + light_color.rgb * rim) / max(alpha, 0.001), alpha);
	}
	COLOR = paint * surface_modulate;
}
