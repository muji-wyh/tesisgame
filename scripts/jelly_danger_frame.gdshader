shader_type canvas_item;
render_mode unshaded;

uniform sampler2D light_texture : filter_linear, repeat_disable;
uniform sampler2D glint_texture : filter_linear, repeat_disable;
uniform vec2 region_size = vec2(400.0, 600.0);
uniform vec2 frame_half = vec2(170.0, 270.0);
uniform float corner_radius = 18.0;
uniform float urgency = 0.0;
uniform float glow_extent = 12.0;
uniform float travel_speed = 0.07;
uniform float pulse = 0.0;
uniform float travel = 0.0;
uniform bool moving = true;

// Distance along the rounded rim, clockwise from its top midpoint.
float rim_position(vec2 p, vec2 straight, float radius) {
	vec2 a = abs(p);
	float arc = radius * 1.57079633;
	float quarter = straight.x + straight.y + arc;
	float segment;
	if (a.x <= straight.x) {
		segment = a.x;
	} else if (a.y <= straight.y) {
		segment = straight.x + arc + straight.y - a.y;
	} else {
		segment = straight.x + radius * atan(a.x - straight.x, a.y - straight.y);
	}
	if (p.x >= 0.0) {
		return p.y < 0.0 ? segment : 2.0 * quarter - segment;
	}
	return p.y >= 0.0 ? 2.0 * quarter + segment : 4.0 * quarter - segment;
}

void fragment() {
	vec2 p = (UV - 0.5) * region_size;
	float radius = min(corner_radius, min(frame_half.x, frame_half.y));
	vec2 straight = frame_half - vec2(radius);
	vec2 q = abs(p) - straight;
	float distance_to_rim = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	// Radiate outward; the learning faces and interaction geometry stay clear.
	if (distance_to_rim < -5.0 || distance_to_rim > glow_extent) {
		discard;
	}
	float perimeter = 4.0 * (straight.x + straight.y + radius * 1.57079633);
	float along = rim_position(p, straight, radius) / perimeter;
	float offset = (fract((along - travel) * 2.0 + 0.5) - 0.5) * perimeter * 0.5;
	float flow = clamp((travel_speed - 0.07) / 0.65, 0.0, 1.0);
	float streak_length = mix(90.0, 230.0, flow);
	vec2 streak_uv = vec2(offset / streak_length + 0.5, distance_to_rim / mix(16.0, 30.0, urgency) + 0.5);
	float glint = texture(glint_texture, clamp(streak_uv, vec2(0.0), vec2(1.0))).a;
	// The acquired soft light gives the growing corona a painted falloff.
	vec2 light_uv = vec2(fract(along * 4.0 - travel), clamp(distance_to_rim / (glow_extent * 2.0) + 0.5, 0.0, 1.0));
	float light = texture(light_texture, light_uv).a;
	float inner_mask = smoothstep(-5.0, -0.5, distance_to_rim);
	float outer_mask = 1.0 - smoothstep(glow_extent * 0.55, glow_extent, distance_to_rim);
	float core = exp(-abs(distance_to_rim) / mix(1.35, 2.6, urgency));
	float halo = exp(-max(distance_to_rim, 0.0) / mix(4.0, 29.0, urgency));
	float breath = mix(0.10, 1.0, pulse);
	float moving_glint = moving ? glint : 0.0;
	float tail_distance = fract((travel - along) * 2.0) * perimeter * 0.5;
	float tail = exp(-tail_distance / mix(28.0, 155.0, flow));
	float stream = moving ? tail * exp(-abs(distance_to_rim) / mix(2.5, 5.0, urgency)) : 0.0;
	float energy = core * (0.10 + 0.52 * breath);
	energy += halo * mix(0.19, 0.65, urgency) * breath * (0.72 + light * 0.40);
	energy += moving_glint * (0.50 + 0.28 * urgency) + stream * (0.20 + 0.24 * urgency);
	// Each existing countdown beat sends a soft wave away from the rim.
	float wave_distance = mix(glow_extent * 0.82, 3.0, pulse);
	float wave = exp(-pow((distance_to_rim - wave_distance) / mix(3.0, 10.0, urgency), 2.0));
	energy += moving ? wave * pulse * mix(0.03, 0.15, urgency) * (0.5 + light) : 0.0;
	vec3 warm = mix(vec3(1.0, 0.67, 0.12), vec3(1.0, 0.30, 0.07), smoothstep(0.0, 0.58, urgency));
	warm = mix(warm, vec3(0.98, 0.075, 0.16), smoothstep(0.48, 1.0, urgency));
	vec3 highlight = mix(vec3(1.0, 0.96, 0.68), vec3(1.0, 0.82, 0.63), urgency);
	vec3 tint = mix(warm, highlight, clamp(moving_glint * 0.92 + stream * 0.28, 0.0, 1.0));
	COLOR = vec4(tint, clamp(energy, 0.0, 0.96) * inner_mask * outer_mask);
}
