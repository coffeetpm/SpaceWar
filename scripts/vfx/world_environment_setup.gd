extends WorldEnvironment
class_name WorldEnvironmentSetup
## 執行時配置 Environment：純黑背景 + ACES Tonemap + 強 HDR Additive Glow（賽博龐克霓虹）。
##
## 使用方式：
##   1) 將本腳本掛到 main.tscn 的 WorldEnvironment 節點。
##   2) Inspector 可微調 glow / tonemap；預設值已為高端霓虹調校。
##   3) 其他節點可用 `WorldEnvironmentSetup.to_neon_color(c)` 或
##      `WorldEnvironmentSetup.apply_neon(node, c)` 將顏色/節點 modulate 推入 HDR 空間，
##      令 Bloom 自動 pick up 並產生霓虹光暈。
##
## 注意：Forward+ 渲染器先至支援 HDR Glow 多 level mipmaps；GL Compatibility 退化為單層。

## 純黑背景（0,0,0,1），令 Bloom 對比最大化。
@export var background_color: Color = Color(0.0, 0.0, 0.0, 1.0)

@export_group("Glow")
## Additive Blend：霓虹色直接加到畫面；比 SCREEN / SOFTLIGHT 更烈。
@export var glow_blend_mode: Environment.GlowBlendMode = Environment.GLOW_BLEND_MODE_ADDITIVE
@export var glow_intensity: float = 1.5
@export var glow_strength: float = 1.25
@export var glow_bloom: float = 0.35
@export var glow_mix: float = 0.88
## HDR 門檻：只處理 brightness > threshold 嘅像素。低 = 更多位置發光。
@export var glow_hdr_threshold: float = 0.72
@export var glow_hdr_scale: float = 2.2
@export var glow_hdr_luminance_cap: float = 14.0

@export_group("Tonemap")
## ACES 係最接近電影級 HDR 壓縮曲線，保留霓虹飽和而唔過曝。
@export var tonemap_mode: Environment.ToneMapper = Environment.TONE_MAPPER_ACES
@export var tonemap_exposure: float = 1.05
@export var tonemap_white: float = 1.35

@export_group("Editor")
@export var apply_in_editor: bool = false


func _ready() -> void:
	if not apply_in_editor and Engine.is_editor_hint():
		return
	_apply_neon_environment()


func _apply_neon_environment() -> void:
	## 複製現有 environment 以免改寫磁碟資源；若無則新建。
	var env: Environment
	if environment:
		env = environment.duplicate(true) as Environment
	else:
		env = Environment.new()
	environment = env

	## 背景：純黑
	env.background_mode = Environment.BG_COLOR
	env.background_color = background_color
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED

	## Glow：ACES + Additive + HDR
	env.glow_enabled = true
	env.glow_normalized = true
	env.glow_intensity = glow_intensity
	env.glow_strength = glow_strength
	env.glow_bloom = glow_bloom
	env.glow_mix = glow_mix
	env.glow_blend_mode = glow_blend_mode
	env.glow_hdr_threshold = glow_hdr_threshold
	env.glow_hdr_scale = glow_hdr_scale
	env.glow_hdr_luminance_cap = glow_hdr_luminance_cap

	## 多層 Glow：Forward+ 專享；GL Compatibility 降級用單層預設。
	var rm: String = String(ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus"))
	if rm != "gl_compatibility":
		env.set_glow_level(1, 0.78)
		env.set_glow_level(2, 0.98)
		env.set_glow_level(3, 0.62)
		env.set_glow_level(4, 0.32)
		env.set_glow_level(5, 0.15)

	## Tonemap：ACES 壓縮曲線
	env.tonemap_mode = tonemap_mode
	env.tonemap_exposure = tonemap_exposure
	env.tonemap_white = tonemap_white


# =============================================================================
# HDR Neon Color Helpers（靜態，任何地方可直接呼叫）
# =============================================================================

## 將任意 Color 轉換為 HDR 霓虹色：RGB 分量乘以 boost（> 1 即進入 HDR 空間）。
## boost 預設 2.4：配合 glow_hdr_threshold 0.72，確保飽和色（r/g/b=1）必定觸發 Bloom。
## 典型值：
##   1.5  — 輕微發光（一般 UI 高亮）
##   2.4  — 霓虹標準（敵機/子彈/光翼）
##   3.5  — 高強度爆光（爆炸核心、Boss 弱點）
##   5.0+ — 刺眼（Boss 狂暴殺招／結算畫面）
static func to_neon_color(base: Color, boost: float = 2.4) -> Color:
	## 保留 alpha；只對 RGB 做 boost。Godot 4 支援 > 1.0 分量值，由 Glow pipeline 處理。
	return Color(base.r * boost, base.g * boost, base.b * boost, base.a)


## 將 CanvasItem 嘅 modulate 設為 HDR 霓虹色。
## 支援所有 CanvasItem 子類：Sprite2D / Polygon2D / Line2D / Label / TextureRect...
## 若傳入 Control，亦會同時更新 self_modulate 以疊加色彩（可選）。
static func apply_neon(item: CanvasItem, base_color: Color, boost: float = 2.4) -> void:
	if item == null or not is_instance_valid(item):
		return
	item.modulate = to_neon_color(base_color, boost)


## 進階：同時設定 self_modulate（獨立於 parent modulate 嘅 tint，疊加後仍為 HDR）。
## 適合霓虹光暈圖層（GlowL / GlowR）希望保留 parent 動畫縮放而自身發光。
static func apply_neon_self(item: CanvasItem, base_color: Color, boost: float = 2.4) -> void:
	if item == null or not is_instance_valid(item):
		return
	item.self_modulate = to_neon_color(base_color, boost)


## Shader uniform 輔助：寫入 hdr_color 係常用做法（如 neon_bullet.gdshader）。
## 會自動 skip 無 ShaderMaterial 嘅節點。
static func apply_neon_shader_param(
		item: CanvasItem,
		base_color: Color,
		boost: float = 2.4,
		param_name: String = "hdr_color"
	) -> void:
	if item == null or not is_instance_valid(item):
		return
	var mat := item.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter(param_name, to_neon_color(base_color, boost))
