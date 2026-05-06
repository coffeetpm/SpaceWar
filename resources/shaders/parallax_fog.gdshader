shader_type canvas_item;
render_mode blend_add, unshaded;
// blend_add：前景條紋直接加算到畫面，配合 Bloom 產生速度光暈。

// ── Speed Streaks ─────────────────────────────────────────────────────────
uniform float streak_speed    : hint_range(1.0, 40.0)  = 18.0;   // 條紋縱向速度倍率
uniform float streak_density  : hint_range(4.0, 60.0)  = 22.0;   // 同時存在的條紋數
uniform float streak_length   : hint_range(0.005, 0.35) = 0.12;  // 條紋長度（UV）
uniform float streak_width    : hint_range(0.001, 0.02) = 0.004; // 條紋橫向寬度（UV）
uniform vec4  streak_color_a  : source_color            = vec4(0.2, 0.8, 1.0, 1.0);  // 青色
uniform vec4  streak_color_b  : source_color            = vec4(0.8, 0.2, 1.0, 1.0);  // 洋紅
uniform float streak_hdr      : hint_range(1.0, 8.0)   = 3.5;    // HDR boost（觸發 Bloom）
// 玩家加速時條紋變長（由 controller 設定 0..1）
uniform float speed_factor    : hint_range(0.0, 1.0)   = 0.0;

// ── Floating Neon Particles ───────────────────────────────────────────────
uniform float particle_density: hint_range(10.0, 120.0) = 48.0;
uniform float particle_speed  : hint_range(0.2, 5.0)   = 1.2;   // 粒子縱向漂移速度
uniform float particle_size   : hint_range(0.002, 0.04) = 0.012;
uniform vec4  particle_color  : source_color            = vec4(0.4, 1.0, 0.6, 1.0);
uniform float particle_hdr    : hint_range(1.0, 6.0)   = 2.4;
// 粒子橫向漂移（玩家移動時偏移）
uniform float particle_h_drift: hint_range(0.0, 0.8)   = 0.28;

// ── 共用 ──────────────────────────────────────────────────────────────────
uniform vec2  scroll_offset                             = vec2(0.0, 0.0);
// 玩家速度偏移（Layer 3 最重，產生視差感）
uniform vec2  player_offset                             = vec2(0.0, 0.0);
uniform float player_speed_x  : hint_range(-1.0, 1.0)  = 0.0;   // 玩家 X 速度（正規化）

// ─────────────────────────────────────────────────────────────────────────

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash1(float x) {
	return fract(sin(x * 311.7) * 43758.5453);
}

// ─────────────────────────────────────────────────────────────────────────
void fragment() {
	// 前景 UV（最強視差：player_offset 用最大係數）
	vec2 uv = UV + scroll_offset * 0.00048 + player_offset * 0.072;

	vec3 out_col = vec3(0.0);
	float out_a  = 0.0;

	// ── Speed Streaks ────────────────────────────────────────────────
	// 每條條紋：x 座標由 hash 決定，y 方向以 TIME 持續下移
	float eff_length = streak_length * (1.0 + speed_factor * 1.8);
	float eff_density = streak_density;

	for (int i = 0; i < 24; i++) {
		if (float(i) >= eff_density) break;
		float fi = float(i);
		float sx = hash1(fi * 0.137 + 3.7);         // 固定 x 位置
		float sy_seed = hash1(fi * 0.293 + 17.1);   // 初始 y 偏移
		float spd = streak_speed * (0.5 + hash1(fi * 0.512) * 0.8);

		// 條紋 y 隨時間向下飄（wrapping）
		float sy = fract(sy_seed + TIME * spd * 0.003 + uv.y * 0.0);
		// 判斷目前 UV 是否落在條紋上
		float dx = abs(uv.x - sx);
		float streak_top = sy;
		float streak_bot = fract(sy + eff_length);
		// 處理 wrap-around
		float in_streak_y: float;
		if (streak_top < streak_bot) {
			in_streak_y = step(streak_top, uv.y) * step(uv.y, streak_bot);
		} else {
			in_streak_y = max(step(streak_top, uv.y), step(uv.y, streak_bot));
		}

		float in_streak_x = smoothstep(streak_width, 0.0, dx);
		// 條紋尾部漸漸消失（頭亮尾暗）
		float tail_fade: float;
		if (streak_top < streak_bot) {
			tail_fade = smoothstep(streak_top, streak_bot, uv.y);
		} else {
			tail_fade = 1.0 - step(streak_bot, uv.y) * (1.0 - step(streak_top, uv.y));
		}
		float streak_mask = in_streak_x * in_streak_y * (1.0 - tail_fade * 0.7);

		// 條紋色（交替 A/B）
		vec4 scol = mix(streak_color_a, streak_color_b, step(0.5, hash1(fi * 0.71)));
		out_col += scol.rgb * streak_hdr * streak_mask;
		out_a   = max(out_a, scol.a * streak_mask);
	}

	// ── 玩家移動時橫向曳尾（speed_factor 驅動）────────────────────
	// 水平條紋：玩家快速移動時在 x 方向產生動態殘影
	float h_streak = 0.0;
	if (abs(player_speed_x) > 0.05) {
		float hsuv_x = uv.x + player_speed_x * 0.08 * sin(uv.y * 80.0 + TIME * 3.0);
		vec2 hsuv = vec2(hsuv_x, uv.y);
		float hsd = hash(floor(hsuv * vec2(1.0, 40.0)));
		float h_mask = smoothstep(0.02, 0.0, abs(fract(hsuv.y * 40.0) - 0.5));
		h_mask *= smoothstep(0.0, 0.5, step(0.92, hsd));
		h_streak = h_mask * abs(player_speed_x);
	}
	vec4 h_col = mix(streak_color_a, streak_color_b, 0.5);
	out_col += h_col.rgb * streak_hdr * 0.6 * h_streak;
	out_a    = max(out_a, h_streak * 0.45);

	// ── Floating Neon Particles ──────────────────────────────────────
	for (int j = 0; j < 16; j++) {
		float fj = float(j);
		float px = hash1(fj * 0.193 + 5.2);
		float py_seed = hash1(fj * 0.381 + 27.0);
		float pspd = particle_speed * (0.6 + hash1(fj * 0.721) * 0.8);
		// 粒子向下漂移 + 橫向擺動（sin 波，玩家移動時偏移）
		float py = fract(py_seed + TIME * pspd * 0.002);
		float px_drift = px + sin(TIME * 0.8 + fj * 2.1) * particle_h_drift * 0.04
						   + player_speed_x * particle_h_drift * 0.06;
		float pdx = abs(uv.x - fract(px_drift));
		float pdy = abs(uv.y - py);
		float dist = length(vec2(pdx, pdy));
		float pmask = smoothstep(particle_size, 0.0, dist);
		float pflick = 0.7 + 0.3 * sin(TIME * 3.5 + fj * 5.1);

		out_col += particle_color.rgb * particle_hdr * pmask * pflick;
		out_a    = max(out_a, particle_color.a * pmask * pflick);
	}

	COLOR = vec4(out_col, clamp(out_a, 0.0, 1.0));
}
