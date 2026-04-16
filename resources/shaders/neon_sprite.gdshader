shader_type canvas_item;
render_mode blend_add, unshaded;

/// Cyberpunk 霓虹：邊緣加亮 + 色相微漂移 + 亮度隨時間脈動（與 WorldEnvironment Glow 搭配）
uniform float glow_strength : hint_range(0.5, 4.0) = 1.4;
uniform float hue_speed : hint_range(-2.5, 2.5) = 0.35;
uniform float pulse_speed : hint_range(0.0, 14.0) = 2.0;
uniform float pulse_amount : hint_range(0.0, 0.45) = 0.14;
uniform float edge_rim_power : hint_range(0.2, 5.0) = 2.4;
uniform vec4 edge_color : source_color = vec4(0.35, 1.0, 1.0, 1.0);
uniform vec4 base_color : source_color = vec4(0.4, 0.75, 1.0, 0.95);
uniform float alpha : hint_range(0.0, 1.0) = 0.95;

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
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	float flicker = 1.0 + pulse_amount * sin(TIME * pulse_speed);
	float micro = 1.0 + pulse_amount * 0.35 * sin(TIME * pulse_speed * 2.37 + r * 6.0);
	float pulse = flicker * micro;
	float rim = pow(smoothstep(0.12, 1.0, r), edge_rim_power);
	vec3 rgb = mix(base_color.rgb, col.rgb, 0.58);
	float hue_offset = TIME * hue_speed + sin(TIME * pulse_speed * 0.65) * 0.09;
	rgb = hue_shift(rgb, hue_offset);
	vec3 rim_rgb = mix(rgb, edge_color.rgb, 0.55);
	rgb = mix(rgb, rim_rgb + edge_color.rgb * 0.85, rim);
	rgb *= glow_strength * pulse;
	float core = 1.0 - smoothstep(0.0, 0.92, r);
	float out_alpha = col.a * alpha * mix(0.5, 1.0, core + rim * 0.45) * pulse;
	COLOR = vec4(rgb, out_alpha);
}
