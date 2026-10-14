shader_type canvas_item;
render_mode unshaded;

uniform float aspect = 1.0;
uniform float yaw = 0.0;
uniform float warmth = 0.16;
uniform float light_strength = 0.17;

void fragment() {
	// Project the acquired panorama into its upper hemisphere, with a paused game clock.
	vec2 screen = UV * 2.0 - 1.0;
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
	COLOR = vec4(sky, 1.0);
}
