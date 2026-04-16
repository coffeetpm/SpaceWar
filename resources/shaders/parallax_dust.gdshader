shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform float scale : hint_range(1.0, 30.0) = 8.0;
uniform float time_scale : hint_range(0.0, 1.0) = 0.05;
uniform vec4 dust_color : source_color = vec4(0.2, 0.22, 0.35, 0.25);
uniform vec4 nebula_mid : source_color = vec4(0.12, 0.15, 0.28, 0.15);
uniform vec2 scroll_offset = vec2(0.0, 0.0);
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

void fragment() {
	vec2 uv = UV + scroll_offset * 0.00025;
	float n = noise(uv * scale + TIME * time_scale);
	n += 0.5 * noise(uv * scale * 0.6 - TIME * time_scale * 0.7);
	n = n / 1.5;
	vec4 col = mix(nebula_mid, dust_color, n * 0.6 + uv.y * 0.2);
	float d = distance(UV, focus_center);
	float focus = smoothstep(focus_inner_radius, focus_outer_radius, d);
	col.a *= focus;
	COLOR = col;
}
