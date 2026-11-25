shader_type canvas_item;
render_mode unshaded;

uniform float aspect = 1.0;
uniform float yaw = 0.0;
uniform float warmth = 0.16;
uniform float light_strength = 0.17;
uniform float mote_time = 0.0;
uniform float mote_strength = 0.0;
uniform vec4 mote_color : source_color = vec4(1.0, 0.96, 0.84, 1.0);
uniform float impact_glow = 0.0;
uniform vec4 impact_color : source_color = vec4(1.0, 0.92, 0.62, 1.0);
uniform float impact_zoom = 0.0;
uniform vec2 impact_shift = vec2(0.0, 0.0);

void fragment() {
	// Project the acquired panorama into its upper hemisphere, with a paused game clock.
	vec2 shifted_uv = (UV - vec2(0.5)) / (1.0 + clamp(impact_zoom, 0.0, 0.06)) + vec2(0.5) - impact_shift;
	vec2 screen = shifted_uv * 2.0 - 1.0;
	float field_of_view = mix(0.94, 0.78, smoothstep(0.5, 1.8, aspect));
	vec3 view_ray = normalize(vec3(screen.x * field_of_view * aspect, -screen.y * field_of_view, 1.0));
	float pitch = 0.34;
	vec3 ray = vec3(view_ray.x, view_ray.y * cos(pitch) + view_ray.z * sin(pitch),
		view_ray.z * cos(pitch) - view_ray.y * sin(pitch));
	float heading = mix(0.878, 0.84, smoothstep(0.5, 1.8, aspect));
	vec2 panorama_uv = vec2(fract(atan(ray.x, ray.z) / (2.0 * PI) + heading + yaw / (2.0 * PI)),
		acos(clamp(ray.y, -1.0, 1.0)) / PI);
	vec3 sky = texture(TEXTURE, panorama_uv).rgb;
	float luminance = dot(sky, vec3(0.2126, 0.7152, 0.0722));
	sky = mix(vec3(luminance), sky, 0.84);
	sky = mix(sky, vec3(0.94, 0.97, 0.98), 0.20);
	sky = mix(sky, sky * vec3(1.07, 1.025, 0.93), warmth);
	// Atmospheric light follows the sun already painted into the source panorama.
	vec2 sun_delta = vec2((panorama_uv.x - 0.917) * 2.0, panorama_uv.y - 0.228);
	float sunlight = exp(-dot(sun_delta, sun_delta) * 90.0) * light_strength;
	sky = mix(sky, vec3(1.0, 0.965, 0.86), sunlight);
	float horizon_haze = smoothstep(0.46, 1.0, UV.y);
	sky = mix(sky, vec3(0.89, 0.94, 0.89), horizon_haze * 0.58);
	// Soft sunlit atmospheric motes drifting slowly through the outer sky (0 when reduced motion).
	if (mote_strength > 0.001) {
		float motes = 0.0;
		for (int i = 0; i < 8; i++) {
			float fi = float(i);
			float seed_x = fract(sin(fi * 78.233 + 12.9898) * 43758.5453);
			float seed_y = fract(sin(fi * 39.425 + 91.713) * 24634.6345);
			float drift_x = fract(seed_x + mote_time * (0.006 + 0.003 * fract(fi * 0.37)) + sin(mote_time * 0.35 + fi * 1.9) * 0.018);
			float drift_y = fract(seed_y - mote_time * (0.009 + 0.004 * fract(fi * 0.53)));
			vec2 delta = (UV - vec2(drift_x, drift_y)) * vec2(aspect, 1.0);
			float radius = mix(0.0045, 0.0095, fract(fi * 0.618));
			float dot_glow = exp(-dot(delta, delta) / (radius * radius));
			float twinkle = 0.55 + 0.45 * sin(mote_time * (0.9 + fract(fi * 0.29) * 0.8) + fi * 2.7);
			// Keep motes gentle near the top and periphery so central board contrast stays untouched.
			float mask = smoothstep(0.95, 0.15, UV.y);
			motes += dot_glow * twinkle * mask;
		}
		sky = mix(sky, mote_color.rgb, clamp(motes * mote_strength * 0.34, 0.0, 0.36));
	}
	if (impact_glow > 0.001) {
		// Luminous radial aura framing the board during heavy merges/pops & Boss finishers
		// (pure light pulse with zero displacement during ordinary play).
		vec2 radial = (UV - vec2(0.5, 0.46)) * vec2(aspect * 0.85, 1.0);
		float halo = exp(-dot(radial, radial) * 2.6);
		float edge_aura = smoothstep(0.18, 0.95, length(radial));
		float boost = clamp(impact_glow, 0.0, 1.0);
		sky = mix(sky, impact_color.rgb, clamp((halo * 0.24 + edge_aura * 0.20) * boost, 0.0, 0.42));
		sky += impact_color.rgb * (halo * 0.14 * boost);
	}
	COLOR = vec4(sky, 1.0);
}
