shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform float intensity : hint_range(0.0, 0.5) = 0.0;

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float edge = 1.0 - smoothstep(0.35, 1.0, d);
	COLOR = vec4(0.0, 0.0, 0.0, intensity * edge);
}
