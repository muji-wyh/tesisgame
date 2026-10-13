shader_type canvas_item;
render_mode unshaded;

uniform sampler2D light_texture : filter_linear, repeat_disable;
uniform sampler2D glint_texture : filter_linear, repeat_disable;
uniform vec2 region_size = vec2(400.0, 600.0);
uniform vec2 frame_half = vec2(170.0, 270.0);
uniform float corner_radius = 18.0;
uniform float urgency = 0.0;
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
	// Keep the warning close to the rim, leaving the learning faces clear.
	if (distance_to_rim < -5.0 || distance_to_rim > 26.0) {
		discard;
	}
	float perimeter = 4.0 * (straight.x + straight.y + radius * 1.57079633);
	float along = rim_position(p, straight, radius) / perimeter;
	float offset = (fract((along - travel) * 2.0 + 0.5) - 0.5) * perimeter * 0.5;
	float streak_length = mix(72.0, 112.0, urgency);
	vec2 streak_uv = vec2(offset / streak_length + 0.5, (distance_to_rim - 1.5) / mix(12.0, 18.0, urgency) + 0.5);
	float glint = texture(glint_texture, clamp(streak_uv, vec2(0.0), vec2(1.0))).a;
	// The acquired soft light breaks up the halo without adding loose particles.
	vec2 light_uv = vec2(fract(along * 4.0 - travel), clamp(distance_to_rim / 100.0 + 0.5, 0.0, 1.0));
	float light = texture(light_texture, light_uv).a;
	float inner_mask = smoothstep(-5.0, -0.5, distance_to_rim);
	float outer_mask = 1.0 - smoothstep(14.0, 26.0, distance_to_rim);
	float core = exp(-abs(distance_to_rim) / mix(1.15, 1.65, urgency));
	float halo = exp(-abs(distance_to_rim) / mix(6.0, 10.0, urgency));
	float breath = mix(0.08, 1.0, pulse);
	float moving_glint = moving ? glint : 0.0;
	float energy = core * (0.08 + 0.48 * breath) + halo * (0.10 + 0.09 * urgency) * breath * (0.75 + light * 0.30);
	energy += moving_glint * (0.26 + 0.10 * urgency) * (0.25 + 0.75 * pulse);
	// A restrained light ripple follows the existing countdown beat.
	// The late echo still raises urgency without spreading a red wash.
	float wave_distance = mix(18.0, 3.0, pulse);
	float wave = exp(-pow((distance_to_rim - wave_distance) / 4.0, 2.0));
	energy += moving ? wave * pulse * (0.025 + urgency * 0.035) * (0.5 + light) : 0.0;
	vec3 warm = mix(vec3(0.90, 0.66, 0.34), vec3(0.88, 0.40, 0.35), urgency);
	vec3 highlight = mix(vec3(1.0, 0.92, 0.76), vec3(1.0, 0.86, 0.77), urgency);
	vec3 tint = mix(warm, highlight, clamp(core * pulse * 0.32 + moving_glint * 0.65, 0.0, 1.0));
	COLOR = vec4(tint, clamp(energy, 0.0, 0.78) * inner_mask * outer_mask);
}
