shader_type canvas_item;
render_mode blend_add, unshaded;

// 玩家霓虹翼專用 Shader：雙層繪製（is_core = true 尖銳核心；false 外發光）。
// 以 UV 作座標：u 沿翼根→翼尖，v 0=上緣 / 1=下緣（0.5 = 中線）。
// 設計為 HDR 輸出以配合 WorldEnvironment Glow 做 Bloom。

uniform vec4 neon_color : source_color = vec4(0.42, 2.50, 3.00, 1.0);
uniform float pulse_speed : hint_range(0.5, 12.0) = 3.2;
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.35;
uniform float core_brightness : hint_range(0.0, 6.0) = 2.4;
uniform float glow_softness : hint_range(0.05, 1.5) = 0.55;
uniform float edge_sharpness : hint_range(0.005, 0.5) = 0.06;
uniform float tip_boost : hint_range(0.0, 4.0) = 1.6;
uniform bool is_core = true;

void fragment() {
	float u = UV.x;
	float y_dist = abs(UV.y - 0.5) * 2.0; // 0 = 中線, 1 = 邊界

	// 主呼吸脈動（低頻）+ 細節閃爍（高頻，微量）
	float pulse = 1.0 + pulse_strength * sin(TIME * pulse_speed);
	float flicker = 1.0 + 0.06 * sin(TIME * pulse_speed * 4.3 + u * 6.2831);

	vec3 rgb = neon_color.rgb * pulse * flicker;
	float alpha = 0.0;

	if (is_core) {
		// 銳利硬邊核心：翼體內部均勻高亮，邊界驟然收斂。
		float core_mask = 1.0 - smoothstep(1.0 - edge_sharpness, 1.0, y_dist);
		// 邊緣 rim（模擬金屬反光亮邊）
		float rim = smoothstep(1.0 - edge_sharpness * 3.5, 1.0 - edge_sharpness, y_dist);
		rgb *= core_brightness;
		rgb += neon_color.rgb * rim * tip_boost;
		alpha = core_mask * (0.55 + 0.45 * u);
	} else {
		// 柔性外發光：從中線到邊界平滑衰減。
		float glow = 1.0 - smoothstep(0.0, glow_softness, y_dist);
		// 向翼尖增強（尖端霓虹拖影）
		alpha = glow * (0.35 + 0.55 * u);
		rgb *= 0.8;
	}

	if (alpha < 0.002) {
		discard;
	}
	COLOR = vec4(rgb, clamp(alpha, 0.0, 1.0));
}
