shader_type canvas_item;
render_mode unshaded;

uniform float star_density : hint_range(1.0, 50.0) = 18.0;
uniform float twinkle_speed : hint_range(0.0, 3.0) = 0.5;
uniform vec4 star_color : source_color = vec4(0.5, 0.6, 0.85, 0.7);
uniform vec4 dim_color : source_color = vec4(0.15, 0.18, 0.28, 0.4);
uniform vec2 scroll_offset = vec2(0.0, 0.0);
uniform vec2 focus_center = vec2(0.5, 0.5);
uniform float focus_inner_radius : hint_range(0.0, 1.0) = 0.2;
uniform float focus_outer_radius : hint_range(0.0, 1.0) = 0.55;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV + scroll_offset * 0.0003;
	float n = hash(floor(uv * star_density));
	float twinkle = 0.7 + 0.3 * sin(TIME * twinkle_speed + n * 6.28);
	vec4 col = mix(dim_color, star_color, step(0.97, n) * twinkle);
	float d = distance(UV, focus_center);
	float focus = smoothstep(focus_inner_radius, focus_outer_radius, d);
	col.a *= focus;
	COLOR = col;
}
