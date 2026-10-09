shader_type canvas_item;
render_mode unshaded;

uniform float bend = 0.0;
uniform float beat = 0.0;
uniform vec4 rim_color : source_color = vec4(0.21, 0.49, 0.44, 1.0);
uniform float rim_strength = 0.0;
uniform float rim_width = 1.0;
uniform float rim_uv = 0.025;
uniform vec2 contact_direction = vec2(0.0);
uniform float contact_strength = 0.0;
uniform bool contact_match = false;
varying vec4 gel_modulate;

void vertex() {
	gel_modulate = COLOR;
}

void fragment() {
	vec2 sample_uv = UV;
	sample_uv.x += sin(UV.y * 3.14159265) * sin(beat + UV.y * 3.14159265) * bend;
	sample_uv.y += sin(UV.x * 3.14159265) * cos(beat + UV.x * 3.14159265) * bend * 0.55;
	vec2 local = UV - vec2(0.5);
	float pressure = exp(-pow(dot(local, vec2(-contact_direction.y, contact_direction.x)) * 4.0, 2.0));
	sample_uv -= contact_direction * pressure * contact_strength * (contact_match ? 0.025 : -0.02);
	vec4 gel = texture(TEXTURE, clamp(sample_uv, vec2(0.0), vec2(1.0)));
	float gleam = exp(-pow((local.x + 0.22) * 13.0, 2.0) - pow((local.y + 0.14) * 5.0, 2.0));
	gel.rgb = mix(gel.rgb, vec3(1.0, 0.995, 0.95), gleam * contact_strength * 0.28);
	if (rim_strength > 0.0) {
		// Both edges follow the acquired artwork and deform with its gel surface.
		float outer = 0.0;
		float keyline = 0.0;
		for (int i = 0; i < 8; i++) {
			float angle = float(i) * 0.78539816;
			vec2 offset = vec2(cos(angle), sin(angle)) * rim_uv * rim_width;
			outer = max(outer, texture(TEXTURE, sample_uv + offset).a);
			keyline = max(keyline, texture(TEXTURE, sample_uv + offset * 0.36).a);
		}
		float rim = max(0.0, outer - gel.a) * rim_strength;
		float light = max(0.0, keyline - gel.a) * rim_strength;
		float alpha = gel.a + rim;
		vec3 ink = mix(rim_color.rgb, vec3(1.0, 0.99, 0.94), clamp(light / max(rim, 0.001), 0.0, 1.0));
		gel = vec4((gel.rgb * gel.a + ink * rim) / max(alpha, 0.001), alpha);
	}
	COLOR = gel * gel_modulate;
}
