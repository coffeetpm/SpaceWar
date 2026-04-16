shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float glow_strength : hint_range(0.5, 3.0) = 1.2;
uniform float hue_speed : hint_range(-2.0, 2.0) = 0.3;
uniform vec4 base_color : source_color = vec4(0.4, 0.7, 1.0, 0.95);
uniform float alpha : hint_range(0.0, 1.0) = 0.95;

// Hue shift in RGB via rotation in color space (simplified)
vec3 hue_shift(vec3 c, float h) {
	vec3 k = vec3(0.57735, 0.57735, 0.57735);
	float cos_h = cos(h);
	float sin_h = sin(h);
	return c * cos_h + cross(k, c) * sin_h + k * dot(k, c) * (1.0 - cos_h);
}

void fragment() {
	vec4 col = COLOR;
	if (col.a < 0.01) {
		discard;
	}
	// Blend base_color with vertex/rect color for tint
	vec3 rgb = mix(base_color.rgb, col.rgb, 0.6);
	float hue_offset = TIME * hue_speed;
	rgb = hue_shift(rgb, hue_offset);
	// Layer 3 light wrap: soft bloom around silhouette (bright center, fade at edges)
	vec2 center = UV * 2.0 - 1.0;
	float edge = 1.0 - smoothstep(0.2, 1.25, length(center));
	edge = mix(0.35, 1.0, edge);
	float out_alpha = col.a * alpha * edge * glow_strength;
	COLOR = vec4(rgb, out_alpha);
}
