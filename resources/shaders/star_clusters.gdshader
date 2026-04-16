shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform float cluster_scale : hint_range(5.0, 40.0) = 18.0;
uniform float drift_speed : hint_range(0.0, 0.3) = 0.02;
uniform float softness : hint_range(0.01, 0.5) = 0.12;
uniform vec4 cluster_color : source_color = vec4(0.45, 0.5, 0.7, 0.18);
uniform vec4 dim_color : source_color = vec4(0.2, 0.22, 0.35, 0.06);
uniform float breath_speed : hint_range(0.0, 0.5) = 0.18;
uniform vec2 focus_center = vec2(0.5, 0.5);
uniform float focus_inner_radius : hint_range(0.0, 1.0) = 0.2;
uniform float focus_outer_radius : hint_range(0.0, 1.0) = 0.55;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV + vec2(TIME * drift_speed, TIME * drift_speed * 0.6);
	vec2 id = floor(uv * cluster_scale);
	vec2 gv = fract(uv * cluster_scale) - 0.5;
	float r = hash(id);
	float size = 0.08 + 0.15 * r;
	float d = length(gv);
	float star = 1.0 - smoothstep(size - softness, size + softness, d);
	star *= step(0.92, r);
	vec4 col = mix(dim_color, cluster_color, star);
	float twinkle = 0.85 + 0.15 * sin(TIME * 0.3 + r * 6.28);
	col.a *= twinkle;
	float breath = 0.94 + 0.06 * sin(TIME * breath_speed);
	col.a *= breath;
	float focus_d = distance(UV, focus_center);
	float focus = smoothstep(focus_inner_radius, focus_outer_radius, focus_d);
	col.a *= focus;
	COLOR = col;
}
