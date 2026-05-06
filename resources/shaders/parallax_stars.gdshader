shader_type canvas_item;
render_mode blend_mix, unshaded;

// ── Stars ─────────────────────────────────────────────────────────────────
uniform float star_density    : hint_range(1.0, 80.0)  = 28.0;
uniform float twinkle_speed   : hint_range(0.0, 4.0)   = 0.55;
uniform vec4  star_color      : source_color           = vec4(0.55, 0.65, 1.0,  0.85);
uniform vec4  dim_color       : source_color           = vec4(0.12, 0.14, 0.22, 0.35);
// 第二層小星（增加深度）
uniform float star_density_b  : hint_range(1.0, 120.0) = 72.0;
uniform vec4  star_color_b    : source_color           = vec4(0.3,  0.35, 0.55, 0.45);

// ── Neon Grid ─────────────────────────────────────────────────────────────
// grid_enable: 0=純星空, 1=純Grid, 0.5=混合
uniform float grid_enable     : hint_range(0.0, 1.0)   = 0.72;
uniform float grid_scale      : hint_range(2.0, 60.0)  = 14.0;  // 每格大小（UV 單位）
uniform vec4  grid_color      : source_color           = vec4(0.18, 0.55, 1.0,  1.0);
uniform float grid_line_width : hint_range(0.0, 0.06)  = 0.018; // 線條粗細（UV 比例）
uniform float grid_glow_boost : hint_range(1.0, 6.0)   = 2.8;   // HDR 提升（配合 Bloom）
// 透視感：越接近底部線條越密（vanishing point 收縮）
uniform float perspective_skew: hint_range(0.0, 1.5)   = 0.65;
// Grid 緩慢縱向滾動（產生「往前飛行」感）
uniform float grid_scroll_y   : hint_range(0.0, 2.0)   = 0.28;
// Grid 水平掃光（sin 波掃過格線，增加電子感）
uniform float grid_pulse_speed: hint_range(0.0, 4.0)   = 1.2;
uniform float grid_pulse_amp  : hint_range(0.0, 1.0)   = 0.35;

// ── 共用 ──────────────────────────────────────────────────────────────────
uniform vec2  scroll_offset                            = vec2(0.0, 0.0);
uniform vec2  player_offset                            = vec2(0.0, 0.0); // 玩家移動偏移（controller 寫入）
// Focus: 中心清晰，邊緣大氣感衰減
uniform vec2  focus_center                             = vec2(0.5, 0.5);
uniform float focus_inner_radius : hint_range(0.0, 1.0) = 0.0;
uniform float focus_outer_radius : hint_range(0.0, 1.0) = 0.72;

// ─────────────────────────────────────────────────────────────────────────

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// ─────────────────────────────────────────────────────────────────────────
void fragment() {
	// 各層獨立 scroll（player_offset 最慢，scroll_offset 跟 camera）
	vec2 base_uv = UV + scroll_offset * 0.00028 + player_offset * 0.012;

	// ── 遠景大星 ────────────────────────────────────────────────────────
	float n_a = hash(floor(base_uv * star_density));
	float twinkle_a = 0.65 + 0.35 * sin(TIME * twinkle_speed + n_a * 6.2832);
	float star_a = step(0.974, n_a) * twinkle_a;

	// ── 近景小星（密度更高，更暗）──────────────────────────────────────
	float n_b = hash(floor(base_uv * star_density_b + vec2(17.3, 93.1)));
	float twinkle_b = 0.5 + 0.5 * sin(TIME * twinkle_speed * 1.4 + n_b * 9.42);
	float star_b = step(0.981, n_b) * twinkle_b;

	vec4 star_col = mix(dim_color,
						mix(star_color_b, star_color, star_a),
						max(star_a, star_b * 0.55));

	// ── Neon Grid ───────────────────────────────────────────────────────
	// 透視感：y 越大（畫面底部）越壓縮
	vec2 grid_uv = base_uv;
	float persp = 1.0 + (grid_uv.y - 0.5) * perspective_skew;
	grid_uv.y = grid_uv.y * persp * 0.5;
	// 縱向滾動（往下飛行感）
	grid_uv.y += TIME * grid_scroll_y * 0.015;

	vec2 g = grid_uv * grid_scale;
	vec2 grid_frac = abs(fract(g - 0.5) - 0.5); // 距格線的距離（0=中心,0.5=格線）
	// 用 smoothstep 繪製帶軟邊嘅格線（比 fwidth 在 canvas_item 更穩定）
	float lx = smoothstep(0.5 - grid_line_width, 0.5, grid_frac.x);
	float ly = smoothstep(0.5 - grid_line_width, 0.5, grid_frac.y);
	float grid_mask = max(lx, ly);

	// 掃光效果：sin 波沿 x 方向掃過（電子感脈衝）
	float pulse = 1.0 - grid_pulse_amp + grid_pulse_amp * sin(grid_uv.x * 3.0 + TIME * grid_pulse_speed);
	// 縱向衰減：頂部幾乎不可見，底部最亮（配合透視）
	float v_fade = smoothstep(0.0, 0.6, grid_uv.y + 0.1);

	vec4 neon_grid = vec4(grid_color.rgb * grid_glow_boost, grid_mask * grid_color.a * pulse * v_fade);

	// ── 合成 ────────────────────────────────────────────────────────────
	vec4 col = mix(star_col, neon_grid, grid_enable * neon_grid.a);
	col.a = max(star_col.a * (1.0 - grid_enable * 0.4), neon_grid.a * grid_enable);

	// Focus 邊緣衰減
	float dist = distance(UV, focus_center);
	float focus = smoothstep(focus_inner_radius, focus_outer_radius, dist);
	col.a = mix(col.a, col.a * 0.25, focus * 0.4);

	COLOR = col;
}
