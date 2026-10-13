shader_type canvas_item;
render_mode unshaded;

uniform sampler2D spectrum : source_color, filter_linear;
uniform vec2 rect_size = vec2(200.0, 14.0);
uniform float fraction : hint_range(0.0, 1.0) = 0.0;
uniform vec4 track_color : source_color = vec4(0.89, 0.91, 0.85, 1.0);

float rounded_box(vec2 point, vec2 half_size, float radius) {
	vec2 distance_to_edge = abs(point) - half_size + radius;
	return length(max(distance_to_edge, vec2(0.0))) + min(max(distance_to_edge.x, distance_to_edge.y), 0.0) - radius;
}

void fragment() {
	vec2 extent = max(rect_size, vec2(1.0));
	vec2 point = UV * extent;
	float track = 1.0 - smoothstep(-0.65, 0.65, rounded_box(point - extent * 0.5, extent * 0.5, extent.y * 0.5));
	float fill_width = extent.x * fraction;
	vec2 fill_extent = vec2(fill_width, extent.y);
	float radius = min(extent.y, fill_width) * 0.5;
	float fill = (1.0 - smoothstep(-0.65, 0.65, rounded_box(point - fill_extent * 0.5, fill_extent * 0.5, radius))) * step(0.001, fraction);
	vec3 rainbow = texture(spectrum, vec2(clamp(UV.x / max(fraction, 0.001), 0.0, 1.0), 0.5)).rgb;
	COLOR *= vec4(mix(track_color.rgb, rainbow, fill), track);
}
