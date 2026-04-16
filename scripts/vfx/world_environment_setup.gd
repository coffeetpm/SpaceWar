extends WorldEnvironment
## 執行時配置 Environment：深邃背景 + 強 HDR Glow（賽博龐克霓虹）。
## 會 duplicate 現有 Environment，避免直接改寫磁碟上的 .tres 資源。

@export var deep_black: Color = Color(0.003, 0.004, 0.01, 1.0)
@export var glow_intensity: float = 1.42
@export var glow_strength: float = 1.88
@export var glow_bloom: float = 0.48
@export var glow_hdr_threshold: float = 0.68
@export var glow_hdr_scale: float = 2.15
@export var glow_mix: float = 0.94
@export var tonemap_exposure: float = 1.05
@export var tonemap_white: float = 1.35
@export var apply_in_editor: bool = false


func _ready() -> void:
	if not apply_in_editor and Engine.is_editor_hint():
		return
	_apply_neon_environment()


func _apply_neon_environment() -> void:
	var env: Environment
	if environment:
		env = environment.duplicate(true) as Environment
	else:
		env = Environment.new()
	environment = env
	env.background_mode = Environment.BG_COLOR
	env.background_color = deep_black
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.glow_enabled = true
	env.glow_normalized = true
	env.glow_intensity = glow_intensity
	env.glow_strength = glow_strength
	env.glow_mix = glow_mix
	env.glow_bloom = glow_bloom
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = glow_hdr_threshold
	env.glow_hdr_scale = glow_hdr_scale
	env.glow_hdr_luminance_cap = 14.0
	var rm: String = String(ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus"))
	if rm != "gl_compatibility":
		env.set_glow_level(1, 0.78)
		env.set_glow_level(2, 0.98)
		env.set_glow_level(3, 0.62)
		env.set_glow_level(4, 0.32)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = tonemap_exposure
	env.tonemap_white = tonemap_white
