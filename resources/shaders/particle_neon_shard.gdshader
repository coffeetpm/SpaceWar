shader_type canvas_item;
render_mode blend_add, unshaded;

/// GPUParticles2D 方塊碎片：不依賴紋理採樣，UV 即為方形粒子
uniform vec4 neon : source_color = vec4(0.25, 0.95, 1.0, 1.0);
uniform float edge_boost : hint_range(0.5, 16.0) = 7.0;

void fragment() {
	vec2 u = abs(UV - vec2(0.5)) * 2.0;
	float d = max(u.x, u.y);
	float body = 1.0 - smoothstep(0.66, 1.0, d);
	float rim = smoothstep(0.42, 0.94, d) * (1.0 - smoothstep(0.9, 1.0, d));
	vec3 c = neon.rgb * COLOR.rgb * (0.5 + body * 1.25 + rim * edge_boost * 0.065);
	float a = neon.a * COLOR.a * (body * 0.94 + rim * 1.28);
	COLOR = vec4(c, clamp(a, 0.0, 1.0));
}
