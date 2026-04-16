shader_type canvas_item;

uniform vec4 dark_color : source_color = vec4(0.06, 0.055, 0.1, 1.0);
uniform vec4 mid_color : source_color = vec4(0.09, 0.08, 0.14, 1.0);
uniform float noise_scale : hint_range(1.0, 50.0) = 14.0;
uniform float noise_strength : hint_range(0.0, 0.3) = 0.1;
uniform float time_scale : hint_range(0.0, 2.0) = 0.12;

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

void fragment() {
	vec2 uv = UV;
	float n = noise(uv * noise_scale + TIME * time_scale);
	n += 0.5 * noise(uv * noise_scale * 0.5 - TIME * time_scale * 0.7);
	n = n / 1.5;
	vec4 col = mix(dark_color, mid_color, uv.y + n * noise_strength);
	COLOR = col;
}
