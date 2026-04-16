shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform float drift_speed : hint_range(0.0, 0.5) = 0.04;
uniform vec3 tint_a : source_color = vec3(0.12, 0.14, 0.28);
uniform vec3 tint_b : source_color = vec3(0.08, 0.18, 0.35);
uniform vec3 tint_c : source_color = vec3(0.2, 0.12, 0.3);
uniform float scale : hint_range(0.5, 4.0) = 1.4;
uniform float opacity : hint_range(0.0, 0.5) = 0.22;
uniform float breath_speed : hint_range(0.0, 1.0) = 0.22;
uniform vec2 focus_center = vec2(0.5, 0.5);
uniform float focus_inner_radius : hint_range(0.0, 1.0) = 0.2;
uniform float focus_outer_radius : hint_range(0.0, 1.0) = 0.55;

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
	float v = 0.0;
	float a = 0.5;
	p *= scale;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	vec2 drift = vec2(TIME * drift_speed, TIME * drift_speed * 0.7);
	float n1 = fbm(uv + drift);
	float n2 = fbm(uv * 1.3 - drift * 0.5 + 10.0);
	float n3 = fbm(uv * 0.8 + drift * 1.2 + 30.0);
	vec3 col = mix(tint_a, tint_b, n1);
	col = mix(col, tint_c, n2 * 0.5);
	col = mix(col, tint_a, smoothstep(0.3, 0.6, n3));
	float breath = 0.92 + 0.08 * sin(TIME * breath_speed);
	float d = distance(UV, focus_center);
	float focus = smoothstep(focus_inner_radius, focus_outer_radius, d);
	COLOR = vec4(col, opacity * breath * focus);
}
