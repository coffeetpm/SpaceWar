shader_type canvas_item;
render_mode blend_add, unshaded;

// Neon Bullet Shader — HDR 霓虹子彈（配合 Forward+ Bloom）
// 用於 Polygon2D 八邊形 Core / Glow 兩層。UV 已由 Polygon2D 預設為中心 0.5。

uniform vec4 hdr_color : source_color = vec4(0.30, 1.80, 3.00, 1.0); // HDR Electric Blue
uniform float glow_intensity : hint_range(0.1, 5.0) = 1.8;
uniform float flicker_speed : hint_range(0.0, 40.0) = 12.0;
uniform float flicker_strength : hint_range(0.0, 1.0) = 0.18;
uniform float core_radius : hint_range(0.05, 1.0) = 0.38;   // 中心實心範圍
uniform float rim_power : hint_range(0.5, 6.0) = 2.6;        // 邊緣 rim 銳度
uniform bool is_core_layer = true;                           // core = 實心銳；false = 外發光柔邊

void fragment() {
	// UV 假設八邊形約 0..1 居中，轉為 -1..1
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);

	// 低頻呼吸 + 高頻閃爍（flicker）
	float breath = 1.0 + flicker_strength * sin(TIME * flicker_speed * 0.4);
	float fast = 1.0 + flicker_strength * 0.55 * sin(TIME * flicker_speed + r * 5.7);
	float flicker = breath * fast;

	vec3 rgb = hdr_color.rgb;
	float alpha;

	if (is_core_layer) {
		// 實心銳利核心：中心最亮，邊緣快速收斂。
		float core_mask = 1.0 - smoothstep(core_radius, core_radius + 0.06, r);
		float rim = pow(smoothstep(0.0, 1.0, r), rim_power);
		rgb *= glow_intensity * flicker * (1.4 + rim * 0.8);
		alpha = COLOR.a * (core_mask + rim * 0.25);
	} else {
		// 柔性外發光：半徑衰減式光暈。
		float glow = 1.0 - smoothstep(0.0, 1.0, r);
		glow = pow(glow, 1.6);
		rgb *= glow_intensity * flicker * 0.75;
		alpha = COLOR.a * glow;
	}

	if (alpha < 0.002) discard;
	COLOR = vec4(rgb, clamp(alpha, 0.0, 1.0));
}
