shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform vec4 fog_color : source_color = vec4(0.08, 0.1, 0.18, 0.35);
uniform float softness : hint_range(0.0, 1.0) = 0.7;
uniform vec2 scroll_offset = vec2(0.0, 0.0);
uniform vec2 focus_center = vec2(0.5, 0.5);
uniform float focus_inner_radius : hint_range(0.0, 1.0) = 0.2;
uniform float focus_outer_radius : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	vec2 uv = UV + scroll_offset * 0.0002;
	float edge = smoothstep(0.0, softness, uv.y) * smoothstep(1.0, 1.0 - softness, uv.y);
	edge *= smoothstep(0.0, 0.3, uv.x) * smoothstep(1.0, 0.7, uv.x);
	vec4 col = fog_color * (0.5 + 0.5 * edge);
	float d = distance(UV, focus_center);
	float focus = smoothstep(focus_inner_radius, focus_outer_radius, d);
	col.a *= focus;
	COLOR = col;
}
