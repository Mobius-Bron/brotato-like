shader_type canvas_item;

uniform float sway_speed = 0.4;
uniform vec4 blade_color = vec4(0.20, 0.48, 0.13, 1.0);
uniform vec4 bend_color = vec4(0.15, 0.35, 0.10, 1.0);

uniform vec2 flatten_positions[20];
uniform float flatten_count = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;

	float cell_size = 0.022;
	vec2 cell_uv = uv / cell_size;
	vec2 cell_id = floor(cell_uv);
	vec2 cell_frac = fract(cell_uv);

	float density_hash = hash(cell_id);
	if (density_hash < 0.32) {
		discard;
	}

	float offset_x = (hash(cell_id + 1.0) - 0.5) * 0.25;
	vec2 local_uv = cell_frac + vec2(offset_x, 0.0);

	if (local_uv.x < 0.20 || local_uv.x > 0.80) {
		discard;
	}

	float blade_height = 0.25 + hash(cell_id + 2.0) * 0.55;
	float height_ratio = local_uv.y / blade_height;
	if (local_uv.y > blade_height || local_uv.y < 0.0) {
		discard;
	}

	float phase = hash(cell_id) * 6.28;
	float sway = sin(TIME * sway_speed + phase) * 0.03 * height_ratio;

	float flatten = 0.0;
	for (int i = 0; i < 20; i++) {
		if (float(i) >= flatten_count) break;
		vec2 fp = flatten_positions[i];
		float dist = length(uv - fp);
		float factor = clamp(1.0 - dist / 0.08, 0.0, 1.0);
		flatten = max(flatten, factor);
	}

	float bend = flatten * 1.2;
	sway -= bend * (1.0 - height_ratio);

	vec2 sample_uv = uv;
	sample_uv.x += sway * cell_size * 0.8;
	sample_uv.y -= abs(sway) * cell_size * 0.5;

	if (sample_uv.x < cell_id.x * cell_size || sample_uv.x > (cell_id.x + 1.0) * cell_size) {
		discard;
	}

	if (sample_uv.y < cell_id.y * cell_size || sample_uv.y > (cell_id.y + blade_height) * cell_size) {
		discard;
	}

	float alpha = 1.0;
	if (flatten > 0.1) {
		alpha = mix(1.0, 0.5, flatten);
	}

	vec4 col = blade_color;
	if (flatten > 0.15) {
		col = mix(col, bend_color, flatten);
	}
	col.a *= alpha;

	COLOR = col;
}
