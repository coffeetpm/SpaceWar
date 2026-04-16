shader_type canvas_item;

uniform float vignette_strength : hint_range(0.0, 1.0) = 0.65;

void fragment() {
	vec2 uv = UV;
	float d = length(uv - 0.5) * 2.0;
	float v = 1.0 - smoothstep(0.2, 1.0, d) * vignette_strength;
	COLOR *= v;
}
