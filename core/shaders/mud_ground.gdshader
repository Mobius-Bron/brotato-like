shader_type canvas_item;

uniform float time_scale = 0.5;
uniform vec3 color_dark = vec3(0.18, 0.12, 0.05);
uniform vec3 color_mid = vec3(0.28, 0.18, 0.08);
uniform vec3 color_light = vec3(0.35, 0.22, 0.10);

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

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;
	for (int i = 0; i < 4; i++) {
		value += amplitude * noise(p * frequency);
		frequency *= 2.0;
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 uv = UV;
	float n1 = fbm(uv * 8.0 + TIME * 0.01);
	float n2 = fbm(uv * 16.0 + vec2(TIME * 0.02, 0.0));
	float n3 = hash(uv * 50.0);

	float combined = n1 * 0.6 + n2 * 0.3 + n3 * 0.1;
	vec3 col = mix(color_dark, color_mid, smoothstep(0.3, 0.5, combined));
	col = mix(col, color_light, smoothstep(0.55, 0.7, combined));

	float puddle = smoothstep(0.65, 0.72, n2);
	col = mix(col, vec3(0.22, 0.16, 0.06), puddle * 0.5);

	COLOR = vec4(col, 1.0);
}
