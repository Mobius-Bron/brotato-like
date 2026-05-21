shader_type canvas_item;

uniform vec3 color_dark = vec3(0.16, 0.10, 0.04);
uniform vec3 color_mid = vec3(0.26, 0.17, 0.07);
uniform vec3 color_light = vec3(0.33, 0.22, 0.10);
uniform vec3 color_puddle = vec3(0.18, 0.12, 0.05);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p, int octaves) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;
	float lacunarity = 2.1;
	float gain = 0.55;
	for (int i = 0; i < 6; i++) {
		if (i >= octaves) break;
		value += amplitude * noise(p * frequency);
		frequency *= lacunarity;
		amplitude *= gain;
	}
	return value;
}

void fragment() {
	vec2 uv = UV;

	float n1 = fbm(uv * 4.0 + TIME * 0.015, 6);
	float n2 = fbm(uv * 10.0 + vec2(TIME * 0.025, TIME * 0.01), 4);
	float n3 = fbm(uv * 25.0 + vec2(0.0, TIME * 0.04), 2);
	float n4 = noise(uv * 60.0);

	float combined = n1 * 0.45 + n2 * 0.3 + n3 * 0.15 + n4 * 0.1;
	combined = combined * 0.6 + 0.2;

	float t1 = smoothstep(0.32, 0.44, combined);
	float t2 = smoothstep(0.46, 0.58, combined);
	vec3 col = mix(color_dark, color_mid, t1);
	col = mix(col, color_light, t2);

	float wetness = smoothstep(0.62, 0.72, n2 * 0.8 + n3 * 0.2);
	col = mix(col, color_puddle, wetness * 0.6);

	float detail = n4 * 0.04;
	col += detail;

	COLOR = vec4(col, 1.0);
}
