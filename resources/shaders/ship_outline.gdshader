shader_type canvas_item;
render_mode blend_add, unshaded;
// blend_add：邊框直接加算到畫面，配合 WorldEnvironment Bloom 自動產生 HDR 光暈。

// ── 流動邊框 ─────────────────────────────────────────────────────────────
// 光流速度（UV 沿形狀邊緣走動）
uniform float flow_speed      : hint_range(-8.0, 8.0)  = 2.8;
// 邊框厚度（UV 空間，越大越粗）
uniform float outline_width   : hint_range(0.0, 0.15)  = 0.04;
// 邊框主色（HDR；配合 Bloom）
uniform vec4  outline_color   : source_color            = vec4(0.2, 0.8, 1.0, 1.0);
uniform float hdr_boost       : hint_range(1.0, 8.0)   = 3.2;
// 第二諧波：疊加更高頻率的光點掃過感
uniform float shimmer_freq    : hint_range(0.0, 40.0)  = 18.0;
uniform float shimmer_amp     : hint_range(0.0, 1.0)   = 0.45;
// 整體 alpha 控制（用 Tween 控制閃白/升級特效）
uniform float master_alpha    : hint_range(0.0, 1.0)   = 0.72;
// 受擊 flash（0=正常, 1=純白 HDR）
uniform float flash_modifier  : hint_range(0.0, 1.0)   = 0.0;
uniform float flash_boost     : hint_range(1.0, 6.0)   = 2.8;

// ── 引擎噴焰連動（由 GDScript 寫入）───────────────────────────────────────
// 引擎亮度倍率（速度快時提升）
uniform float engine_boost    : hint_range(0.0, 2.0)   = 0.0;
// 引擎亮點位置（機尾 UV 附近，由腳本寫入）
uniform vec2  engine_pos      : hint_range(0.0, 1.0)   = vec2(0.5, 0.85);
uniform float engine_radius   : hint_range(0.0, 0.5)   = 0.22;

// ─────────────────────────────────────────────────────────────────────────
void fragment() {
	// 取得原始顏色（Polygon2D vertex color × texture）
	vec4 base = COLOR * texture(TEXTURE, UV);

	// ── 流動邊框：用 UV 距邊緣的距離模擬 outline ─────────────────────
	// 以 UV 距 0/1 邊界的最小值估算「邊緣距離」
	float edge_x = min(UV.x, 1.0 - UV.x);
	float edge_y = min(UV.y, 1.0 - UV.y);
	float edge_dist = min(edge_x, edge_y);
	float outline_mask = smoothstep(0.0, outline_width, edge_dist);
	outline_mask = 1.0 - outline_mask;  // 1=邊框, 0=內部

	// 流動光：沿 UV 周長方向走動
	float perimeter = UV.x + UV.y;  // 簡化周長參數（沿 UV 對角線走動）
	float flow = sin(perimeter * shimmer_freq - TIME * flow_speed) * 0.5 + 0.5;
	float shimmer = 1.0 - shimmer_amp + shimmer_amp * flow;

	// 引擎熱點：機尾附近額外亮起
	float eng_dist = distance(UV, engine_pos);
	float eng_glow = smoothstep(engine_radius, 0.0, eng_dist) * engine_boost;

	// 最終邊框色（HDR）
	vec4 edge_col = vec4(outline_color.rgb * hdr_boost * shimmer, outline_color.a);
	edge_col.rgb += outline_color.rgb * eng_glow * 2.0;

	// ── 受擊白閃 ────────────────────────────────────────────────────
	vec4 flash_col = vec4(vec3(flash_boost), base.a);
	edge_col = mix(edge_col, flash_col, flash_modifier);

	// 只在邊框區域輸出；內部透明（避免遮住機身紋理）
	float final_alpha = outline_mask * master_alpha * (1.0 + engine_boost * 0.35);
	COLOR = vec4(edge_col.rgb, clamp(final_alpha, 0.0, 1.0));
}
