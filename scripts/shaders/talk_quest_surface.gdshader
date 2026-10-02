shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.7, 0.6, 0.5, 1.0);
uniform int surface_kind : hint_range(0, 5) = 1;
uniform float surface_roughness : hint_range(0.15, 1.0) = 0.8;
uniform float detail_scale : hint_range(0.02, 128.0) = 1.0;
uniform bool world_space = false;

varying vec3 surface_position;
varying vec3 surface_normal;

float hash_2d(vec2 point) {
	vec3 value = fract(vec3(point.x, point.y, point.x) * 0.1031);
	value += dot(value, value.yzx + 33.33);
	return fract((value.x + value.y) * value.z);
}

float noise_2d(vec2 point) {
	vec2 cell = floor(point);
	vec2 fraction = fract(point);
	vec2 blend = fraction * fraction * (3.0 - 2.0 * fraction);
	return mix(mix(hash_2d(cell), hash_2d(cell + vec2(1.0, 0.0)), blend.x),
		mix(hash_2d(cell + vec2(0.0, 1.0)), hash_2d(cell + vec2(1.0, 1.0)), blend.x), blend.y);
}

float fine_detail_visibility(vec2 point) {
	float footprint = max(length(dFdx(point)), length(dFdy(point)));
	return 1.0 - smoothstep(0.4, 1.3, footprint);
}

float joints(vec2 grid, float width) {
	vec2 edge = min(fract(grid), 1.0 - fract(grid));
	vec2 antialias = max(fwidth(grid), vec2(0.0001));
	vec2 interior = smoothstep(vec2(width), vec2(width) + antialias, edge);
	// Unresolved distant joints fade into the surface instead of forming a grid.
	float visibility = 1.0 - smoothstep(0.12, 0.5, max(antialias.x, antialias.y));
	return (1.0 - min(interior.x, interior.y)) * visibility;
}

// Return restrained color variation, roughness variation, and joint occlusion.
vec3 surface_sample(vec2 point) {
	if (surface_kind == 0) {
		float board = floor(point.x / 0.24);
		float board_tone = hash_2d(vec2(board, 17.0));
		vec2 grid = vec2(point.x / 0.24, point.y / 1.65 + board_tone * 0.85);
		float seam = joints(grid, 0.006);
		float flow = noise_2d(point * vec2(4.0, 0.7));
		float grain_phase = point.x * 260.0 + flow * 5.0 + sin(point.y * 1.9 + board) * 0.6;
		float grain_visibility = 1.0 - smoothstep(1.0, 4.0, fwidth(grain_phase));
		float grain = sin(grain_phase) * grain_visibility;
		float shade = 0.95 + board_tone * 0.05 + (flow - 0.5) * 0.06 + grain * 0.025;
		return vec3(shade * (1.0 - seam * 0.14), grain * 0.025 + seam * 0.06, 1.0 - seam * 0.08);
	}
	if (surface_kind == 2 || surface_kind == 3) {
		bool tiled = surface_kind == 3;
		vec2 grid = point / (tiled ? vec2(0.34) : vec2(0.62, 0.40));
		if (!tiled) {
			grid.x += mod(floor(grid.y), 2.0) * 0.5;
		}
		float seam = joints(grid, tiled ? 0.012 : 0.018);
		float block = hash_2d(floor(grid));
		float mottling = noise_2d(point * 8.0) - 0.5;
		float shade = 0.97 + block * (tiled ? 0.035 : 0.07) + mottling * (tiled ? 0.025 : 0.07);
		return vec3(shade * (1.0 - seam * 0.13), mottling * 0.04 + seam * 0.1, 1.0 - seam * 0.06);
	}
	if (surface_kind == 4) {
		float settling = noise_2d(point * 2.5) - 0.5;
		vec2 grain_point = point * 105.0;
		float grain = (noise_2d(grain_point) - 0.5) * fine_detail_visibility(grain_point);
		return vec3(1.0 + settling * 0.07 + grain * 0.10, 0.04 + grain * 0.045, 1.0);
	}
	if (surface_kind == 5) {
		vec2 threads = point * 225.0;
		float weave = sin(threads.x) * sin(threads.y) * fine_detail_visibility(threads / 6.283185);
		float cloth = noise_2d(point * 5.0) - 0.5;
		return vec3(1.0 + cloth * 0.05 + weave * 0.025, 0.025 + weave * 0.035, 1.0);
	}
	float plaster = noise_2d(point * 3.5) - 0.5;
	vec2 fine_point = point * 48.0;
	float fine = (noise_2d(fine_point) - 0.5) * fine_detail_visibility(fine_point);
	return vec3(1.0 + plaster * 0.065 + fine * 0.04, plaster * 0.035 + fine * 0.025, 1.0);
}

void vertex() {
	// Local coordinates keep moving props' detail attached to their geometry.
	// World coordinates can be enabled for adjoining architectural pieces.
	surface_position = world_space ? (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz : VERTEX;
	surface_normal = world_space ? normalize(MODEL_NORMAL_MATRIX * NORMAL) : NORMAL;
}

void fragment() {
	vec3 weights = pow(abs(normalize(surface_normal)), vec3(4.0));
	weights /= max(weights.x + weights.y + weights.z, 0.0001);
	vec3 point = surface_position * detail_scale;
	vec3 detail = surface_sample(point.yz) * weights.x
		+ surface_sample(point.xz) * weights.y
		+ surface_sample(point.xy) * weights.z;
	ALBEDO = clamp(base_color.rgb * detail.x, vec3(0.0), vec3(1.0));
	ROUGHNESS = clamp(surface_roughness + detail.y, 0.15, 1.0);
	SPECULAR = surface_kind == 3 ? 0.45 : 0.30;
	METALLIC = 0.0;
	AO = detail.z;
	AO_LIGHT_AFFECT = 0.25;
}
