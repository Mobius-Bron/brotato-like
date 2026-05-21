shader_type canvas_item;

uniform float sway_speed = 0.8;
uniform float sway_amount = 0.15;
uniform float grass_density = 100.0;
uniform float blade_height = 0.04;
uniform vec4 grass_color = vec4(0.22, 0.42, 0.12, 1.0);
uniform vec4 grass_tip_color = vec4(0.35, 0.55, 0.18, 1.0);
uniform vec4 flatten_color = vec4(0.28, 0.48, 0.14, 1.0);

uniform vec2 flatten_positions[20];
uniform float flatten_count = 0.0;
uniform float flatten_radius = 0.06;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void fragment() {
	vec2 uv = UV;
	vec2 grid_uv = uv * grass_density;
	vec2 cell_id = floor(grid_uv);
	vec2 cell_frac = fract(grid_uv);

	float cell_hash = hash(cell_id);
	float angle = (cell_hash - 0.5) * 1.2;
	float sway_noise = noise(cell_id * 0.3 + TIME * sway_speed * 0.2);
	angle += sway_noise * sway_amount;

	if (cell_frac.x < 0.45 || cell_frac.x > 0.55) {
		discard;
	}

	float local_x = (cell_frac.x - 0.5) * 2.0;
	float blade_factor = (1.0 - abs(local_x)) * 2.0;

	float tip_height = blade_height;
	float base_y = cell_frac.y;

	if (base_y > blade_factor * tip_height) {
		discard;
	}

	float height_ratio = base_y / (blade_factor * tip_height);

	float flatten_factor = 0.0;
	for (int i = 0; i < 20; i++) {
		if (float(i) >= flatten_count) break;
		vec2 fp = flatten_positions[i];
		float dist = length(uv - fp);
		flatten_factor += smoothstep(flatten_radius, 0.0, dist);
	}
	flatten_factor = clamp(flatten_factor, 0.0, 1.0);

	float total_angle = angle + flatten_factor * 1.2 * sign(angle + 0.001);
	float sway_offset = sin(total_angle) * local_x * tip_height * (1.0 - height_ratio);

	vec2 blade_uv = uv;
	blade_uv.x += sway_offset;
	blade_uv.y -= abs(sway_offset) * 0.5;

	if (blade_uv.x < cell_id.x / grass_density || blade_uv.x > (cell_id.x + 1.0) / grass_density) {
		discard;
	}

	vec4 col = mix(grass_color, grass_tip_color, height_ratio);
	if (flatten_factor > 0.3) {
		col = mix(col, flatten_color, flatten_factor);
	}
	col.a *= 1.0 - abs(local_x) * 0.5;

	COLOR = col;
}
