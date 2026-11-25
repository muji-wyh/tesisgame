shader_type canvas_item;
render_mode unshaded;

uniform vec2 region_size = vec2(300.0, 500.0);
uniform float corner_radius = 16.0;
uniform vec4 chapter_tint : source_color = vec4(0.90, 0.94, 0.94, 1.0);
uniform float warmth = 0.16;
uniform float rim_pulse = 0.0;
uniform vec4 rim_color : source_color = vec4(1.0, 0.87, 0.48, 1.0);

float well_grain(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.5);
	return fract(p.x * p.y);
}

void fragment() {
	// Recolor the acquired Kenney cloud pattern; keep its original silhouettes.
	float cloud = texture(TEXTURE, UV * region_size / 240.0).r;
	vec3 sky_top = mix(vec3(0.89, 0.92, 0.97), chapter_tint.rgb, 0.24);
	vec3 sky_bottom = mix(vec3(0.90, 0.95, 0.91), chapter_tint.rgb * vec3(1.02, 1.01, 0.98), 0.20);
	vec3 sky = mix(sky_top, sky_bottom, UV.y);
	sky = mix(sky, sky * vec3(1.03, 1.01, 0.96), clamp(warmth, 0.0, 0.45) * 0.45);
	vec3 paper = mix(sky, vec3(0.985, 0.99, 0.97), cloud * 0.76);
	// Subtle tactile paper tooth (~1.2% contrast) without competing with word labels.
	float grain = (well_grain(floor(FRAGCOORD.xy * 0.5)) - 0.5) * 0.012;
	paper += vec3(grain);
	vec2 q = abs((UV - 0.5) * region_size) - (region_size * 0.5 - vec2(corner_radius));
	float rim = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner_radius;
	// Soft inner bevel along the glass/paper well perimeter + dynamic impact rim pulse.
	float inner_edge = 1.0 - smoothstep(-10.0, 0.0, rim);
	float rim_band = smoothstep(-7.0, -0.5, rim) * (1.0 - smoothstep(-0.5, 0.8, rim));
	paper = mix(paper, vec3(1.0, 0.995, 0.98), (1.0 - inner_edge) * 0.08 * (1.0 - UV.y));
	paper = mix(paper, rim_color.rgb, rim_band * clamp(rim_pulse, 0.0, 1.0) * 0.75);
	COLOR = vec4(paper, 1.0 - smoothstep(-0.6, 0.6, rim));
}
