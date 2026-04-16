shader_type canvas_item;
render_mode blend_add, unshaded;

/// NeonEntity 光翼 shader：
///  - UV.x: 沿光翼長度（0 = 根部；1 = 翼尖）
///  - UV.y: 光翼寬度方向（0 上 / 0.5 中線 / 1 下）
/// 效果：從根部往翼尖推進的能量流條紋 + 整體脈動 + 邊緣輪廓發光。
uniform vec4 neon_color : source_color = vec4(0.35, 0.9, 1.0, 1.0);
uniform float frequency : hint_range(0.0, 20.0) = 4.0;
uniform float intensity : hint_range(0.0, 6.0) = 1.85;
uniform float wing_softness : hint_range(0.005, 0.5) = 0.12;
uniform float flow_speed : hint_range(-4.0, 4.0) = 1.6;
uniform float streak_density : hint_range(1.0, 40.0) = 14.0;
uniform float alpha : hint_range(0.0, 1.0) = 0.95;

void fragment() {
	vec2 uv = UV;
	float x = clamp(uv.x, 0.0, 1.0);          // 0 = 根；1 = 翼尖
	float y = uv.y - 0.5;                      // -0.5..0.5 橫向
	/// 翼型剖面：從根（寬）漸細至翼尖（細），頂點略呈弧形
	float taper = sqrt(max(0.0, 1.0 - x));     // 根部 1.0 → 翼尖 0
	float half_width = taper * 0.5;
	float dist = abs(y);
	/// 內部（實體）遮罩（在邊界以內）
	float inside = smoothstep(half_width, max(0.0, half_width - wing_softness), dist);
	if (inside <= 0.0025) {
		discard;
	}
	/// 邊緣輪廓（靠近 silhouette 的一圈）→ 霓虹 rim
	float rim = 1.0 - smoothstep(0.0, wing_softness * 1.6, half_width - dist);
	/// 沿翼長流動的能量條紋
	float flow = sin((x * streak_density) - TIME * flow_speed * 3.14159) * 0.5 + 0.5;
	/// 全翼脈動
	float pulse = 0.55 + 0.45 * sin(TIME * frequency);
	/// 翼尖閃爍（比整體快）
	float tip_flicker = 1.0 + 0.25 * sin(TIME * frequency * 2.3 + x * 8.0);
	/// 核心亮線：在翼中線附近最亮
	float core = 1.0 - smoothstep(0.0, half_width * 0.55, dist);
	vec3 rgb = neon_color.rgb;
	rgb *= (0.42 + pulse * 0.38 + rim * 1.25 + flow * 0.45 + core * 0.7);
	rgb *= intensity * tip_flicker;
	float a = alpha * inside * (0.55 + flow * 0.22 + rim * 0.45 + core * 0.35) * pulse;
	COLOR = vec4(rgb, clamp(a, 0.0, 1.0));
}
