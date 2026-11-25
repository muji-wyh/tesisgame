shader_type canvas_item;
render_mode unshaded;

uniform vec4 paper_tint : source_color = vec4(0.985, 0.973, 0.941, 1.0);
uniform vec4 top_wash : source_color = vec4(0.93, 0.96, 0.92, 1.0);
uniform float wash_strength = 0.28;
uniform float grain_strength = 0.018;
uniform float vignette_strength = 0.035;

float paper_hash(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

void fragment() {
	// Subtle storybook warm paper wash with gentle top daylight tint and organic grain.
	float wash = (1.0 - smoothstep(0.0, 0.52, UV.y)) * wash_strength;
	vec3 base = mix(paper_tint.rgb, top_wash.rgb, wash);
	// Low-contrast paper fiber grain in screen-consistent pixel grid.
	vec2 grain_uv = floor(FRAGCOORD.xy * 0.5);
	float n = paper_hash(grain_uv) - 0.5;
	base += vec3(n * grain_strength);
	// Soft warm vignette around outer frame edges without dimming central text.
	vec2 centered = UV * 2.0 - 1.0;
	float edge = smoothstep(0.55, 1.35, length(centered * vec2(0.85, 1.0)));
	base = mix(base, base * vec3(0.965, 0.955, 0.925), edge * vignette_strength * 4.0);
	COLOR = vec4(base, paper_tint.a);
}
