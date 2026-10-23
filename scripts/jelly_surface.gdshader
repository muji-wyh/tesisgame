shader_type canvas_item;
render_mode unshaded;

#include "res://scripts/jelly_optics.gdshaderinc"

uniform sampler2D shape_sdf : filter_linear, repeat_disable;
uniform vec2 surface_size = vec2(100.0);

uniform float bend = 0.0;
uniform float beat = 0.0;
uniform float preview_pressure = 0.0;
uniform float preview_sway = 0.0;
uniform float preview_pull = 0.0;
uniform vec4 rim_color : source_color = vec4(0.21, 0.49, 0.44, 1.0);
uniform float rim_strength = 0.0;
uniform float rim_width = 1.0;
uniform float rim_uv = 0.025;
uniform vec2 contact_direction = vec2(0.0);
uniform float contact_strength = 0.0;
uniform bool contact_match = false;
uniform float palette_hue = -1.0;
uniform float completion_strength = 0.0;
uniform float completion_glint = -2.0;
varying vec4 gel_modulate;

vec3 palette(vec3 paint) {
	if (palette_hue < 0.0) { return paint; }
	float high = max(max(paint.r, paint.g), paint.b);
	float low = min(min(paint.r, paint.g), paint.b);
	vec3 hue = clamp(abs(fract(vec3(palette_hue) + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	// Retain every acquired highlight, shaded contour and alpha edge.
	return mix(vec3(low), vec3(high), hue);
}

void vertex() {
	// Pad only the matching light; inverse UV mapping keeps the painted body fixed.
	float glow = smoothstep(0.35, 0.7, completion_strength);
	VERTEX = (VERTEX - surface_size * 0.5) * (1.0 + glow * 0.16) + surface_size * 0.5;
	// Extend the skin mesh, not its UV bounds, so the hanging belly cannot clip.
	// The learning face and input rectangle are separate, stationary controls.
	VERTEX.y *= 1.0 + preview_pull;
	gel_modulate = COLOR;
}

void fragment() {
	float glow = smoothstep(0.35, 0.7, completion_strength);
	vec2 skin_uv = (UV - vec2(0.5)) * (1.0 + glow * 0.16) + vec2(0.5);
	vec2 sample_uv = skin_uv;
	sample_uv.x += sin(skin_uv.y * 3.14159265) * sin(beat + skin_uv.y * 3.14159265) * bend;
	sample_uv.y += sin(skin_uv.x * 3.14159265) * cos(beat + skin_uv.x * 3.14159265) * bend * 0.55;
	// The crown resists while gravity stretches the acquired lower lobe.
	// A pinched shoulder preserves volume as the skin extends downwards.
	float height = clamp((0.890625 - skin_uv.y) / 0.784375, 0.0, 1.0);
	// Keep lateral pressure inside the acquired texture's transparent margin.
	float bulge = sin(height * 3.14159265) * preview_pressure * 0.28;
	sample_uv.x = 0.5 + (sample_uv.x - 0.5) / (1.0 + bulge - preview_pull * smoothstep(0.15, 0.9, height) * 0.42);
	sample_uv.x -= preview_sway * height * height;
	sample_uv.y -= preview_pressure * 0.784375 * pow(height, 1.35);
	vec2 local = skin_uv - vec2(0.5);
	float pressure = exp(-pow(dot(local, vec2(-contact_direction.y, contact_direction.x)) * 4.0, 2.0));
	sample_uv -= contact_direction * pressure * contact_strength * (contact_match ? 0.025 : -0.02);
	vec4 gel = texture(TEXTURE, clamp(sample_uv, vec2(0.0), vec2(1.0)));
	gel.rgb = palette(gel.rgb);
	gel.rgb = jelly_source_light(gel.rgb, shape_sdf, sample_uv, surface_size);
	// A soft sweep lights the acquired paint without moving the learning label.
	float sweep = 1.0 - smoothstep(0.02, 0.18, abs(sample_uv.x * 0.7 + sample_uv.y * 0.3 - completion_glint));
	gel.rgb = mix(gel.rgb, vec3(1.0, 0.995, 0.89), completion_strength * (0.12 + sweep * 0.42));
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
	if (glow > 0.0) {
		// Bloom follows the acquired silhouette and fades within a few screen pixels.
		float distance = max(0.0, (texture(shape_sdf, sample_uv).a - 0.5) * 0.4);
		float bloom = (1.0 - smoothstep(0.0, 0.085, distance)) * 0.5 * glow * (1.0 - gel.a);
		float alpha = gel.a + bloom;
		vec3 light = mix(rim_color.rgb, vec3(1.0, 0.96, 0.72), 0.24);
		gel = vec4((gel.rgb * gel.a + light * bloom) / max(alpha, 0.001), alpha);
	}
	COLOR = gel * gel_modulate;
}
