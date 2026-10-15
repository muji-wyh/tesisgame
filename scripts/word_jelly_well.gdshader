shader_type canvas_item;
render_mode unshaded;

uniform vec2 region_size = vec2(300.0, 500.0);
uniform float corner_radius = 16.0;

void fragment() {
	// Recolor the acquired Kenney cloud pattern; keep its original silhouettes.
	float cloud = texture(TEXTURE, UV * region_size / 240.0).r;
	vec3 sky = mix(vec3(0.89, 0.92, 0.97), vec3(0.90, 0.95, 0.91), UV.y);
	vec3 paper = mix(sky, vec3(0.98, 0.99, 0.97), cloud * 0.76);
	vec2 q = abs((UV - 0.5) * region_size) - (region_size * 0.5 - vec2(corner_radius));
	float rim = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner_radius;
	COLOR = vec4(paper, 1.0 - smoothstep(-0.6, 0.6, rim));
}
