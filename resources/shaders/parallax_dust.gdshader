shader_type canvas_item;
render_mode blend_mix, unshaded;

// ── Nebula ────────────────────────────────────────────────────────────────
uniform float nebula_scale    : hint_range(0.5, 8.0)  = 2.2;
uniform float nebula_speed    : hint_range(0.0, 0.5)  = 0.028;
uniform vec4  nebula_color_a  : source_color          = vec4(0.08, 0.12, 0.45, 0.38);
uniform vec4  nebula_color_b  : source_color          = vec4(0.25, 0.05, 0.38, 0.28);
uniform vec4  nebula_color_c  : source_color          = vec4(0.0,  0.18, 0.35, 0.22);
uniform float nebula_contrast : hint_range(0.5, 3.0)  = 1.45;

// ── Building Silhouette ───────────────────────────────────────────────────
// silhouette_enable: 0=純星雲, 1=城市剪影全顯
uniform float silhouette_enable : hint_range(0.0, 1.0) = 0.82;
// 剪影帶位置（0=頂部,1=底部）
uniform float skyline_y       : hint_range(0.0, 1.0)  = 0.68;
uniform float skyline_height  : hint_range(0.0, 0.5)  = 0.28;
// 建築色（深色剪影）
uniform vec4  building_color  : source_color          = vec4(0.01, 0.02, 0.06, 1.0);
// 窗戶霓虹燈：隨機小點，用色偏暖橙/青
uniform vec4  window_color_a  : source_color          = vec4(1.0,  0.65, 0.1,  1.0);
uniform vec4  window_color_b  : source_color          = vec4(0.1,  0.85, 1.0,  1.0);
uniform float window_density  : hint_range(0.0, 1.0)  = 0.055;  // 窗戶出現機率
uniform float window_hdr      : hint_range(1.0, 5.0)  = 2.6;    // HDR boost（觸發 Bloom）
// 剪影水平漂移（比 camera 慢，0.3 = 遠景感）
uniform float skyline_drift   : hint_range(0.0, 1.0)  = 0.32;
// 每「塊」建築寬度（越小越多棟）
uniform float building_freq   : hint_range(2.0, 30.0) = 7.5;
// 剪影頂部霓虹邊光（Glow edge）
uniform float edge_glow_width : hint_range(0.0, 0.06) = 0.022;
uniform vec4  edge_glow_color : source_color          = vec4(0.3, 0.7, 1.0, 1.0);
uniform float edge_glow_hdr   : hint_range(1.0, 6.0)  = 3.2;

// ── 共用 ──────────────────────────────────────────────────────────────────
uniform vec2  scroll_offset                           = vec2(0.0, 0.0);
uniform vec2  player_offset                           = vec2(0.0, 0.0);
uniform vec2  focus_center                            = vec2(0.5, 0.5);
uniform float focus_inner_radius : hint_range(0.0, 1.0) = 0.0;
uniform float focus_outer_radius : hint_range(0.0, 1.0) = 0.85;

// ─────────────────────────────────────────────────────────────────────────

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash1(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1,0)), f.x),
			   mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.1; a *= 0.5; }
	return v;
}

// 建築高度函數：依 x 座標返回該「棟」嘅屋頂高度（UV y 座標）。
// 高頻雜湊模擬不規則城市天際線。
float building_height(float x) {
	float block = floor(x * building_freq);
	float h = hash1(block) * 0.82 + hash1(block * 3.7 + 13.1) * 0.18;
	// 偶爾出現高塔（10%）
	float tower = step(0.9, hash1(block * 7.3));
	h = mix(h, 1.0, tower * 0.55);
	return h;
}

// ─────────────────────────────────────────────────────────────────────────
void fragment() {
	vec2 nebula_uv = UV + scroll_offset * 0.00022 + player_offset * 0.032;
	// Skyline 水平漂移比 nebula 慢（遠景視差分離感）
	vec2 sky_uv = UV + scroll_offset * 0.00008 + player_offset * 0.018;

	// ── 星雲（FBM 疊加三色）──────────────────────────────────────────
	vec2 nu = nebula_uv * nebula_scale;
	vec2 drift = vec2(TIME * nebula_speed, TIME * nebula_speed * 0.62);
	float n1 = fbm(nu + drift);
	float n2 = fbm(nu * 1.25 - drift * 0.55 + vec2(10.3, 5.7));
	float n3 = fbm(nu * 0.7  + drift * 1.1  + vec2(30.0, 18.4));

	// 對比強化
	n1 = pow(n1, 1.0 / nebula_contrast);
	n2 = pow(n2, 1.0 / nebula_contrast);

	vec4 nebula_col = mix(nebula_color_a, nebula_color_b, n1);
	nebula_col      = mix(nebula_col, nebula_color_c, n2 * 0.55);
	nebula_col.a   *= (0.55 + n3 * 0.45);

	// ── 建築剪影 ─────────────────────────────────────────────────────
	// skyline_y = 剪影帶中心；skyline_height = 剪影帶覆蓋高度
	float bx    = sky_uv.x;
	float bh_n  = building_height(bx); // 0..1（歸一化高度）
	// 轉換到 UV y 座標：建築從 skyline_y 往上延伸 skyline_height * bh_n
	float roof_y = skyline_y - skyline_height * bh_n;
	float in_building = step(roof_y, UV.y) * step(UV.y, skyline_y + 0.02);

	// 窗戶：建築內部格狀隨機亮點
	vec2 win_uv   = sky_uv * vec2(60.0, 30.0);
	float win_h   = hash(floor(win_uv));
	float is_window = step(1.0 - window_density, win_h) * in_building;
	// 窗戶閃爍（心跳感）
	float win_flick = 0.85 + 0.15 * sin(TIME * 2.2 + win_h * 20.0);
	vec4 win_col = mix(window_color_a, window_color_b, step(0.5, hash(floor(win_uv) + 0.5)));
	win_col = vec4(win_col.rgb * window_hdr * win_flick, win_col.a);

	// 建築主體
	vec4 bld_col = mix(vec4(0.0), building_color, in_building * (1.0 - is_window));
	// 加窗戶
	bld_col = mix(bld_col, win_col, is_window);

	// 屋頂邊光（霓虹輪廓）
	float edge_dist = abs(UV.y - roof_y);
	float edge_mask = in_building * smoothstep(edge_glow_width, 0.0, edge_dist);
	vec4 glow_col = vec4(edge_glow_color.rgb * edge_glow_hdr, edge_mask * edge_glow_color.a);

	// ── 合成 ────────────────────────────────────────────────────────
	vec4 col = nebula_col;
	col = mix(col, bld_col, silhouette_enable * bld_col.a);
	col.rgb += glow_col.rgb * silhouette_enable * glow_col.a;
	col.a = max(col.a, silhouette_enable * max(bld_col.a, glow_col.a));

	// Focus 邊緣衰減
	float dist = distance(UV, focus_center);
	float focus = smoothstep(focus_inner_radius, focus_outer_radius, dist);
	col.a *= mix(1.0, 0.3, focus * 0.5);

	COLOR = col;
}
