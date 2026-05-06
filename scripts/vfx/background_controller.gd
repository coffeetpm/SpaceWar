extends ParallaxBackground
class_name BackgroundController
## 賽博龐克三層視差背景控制器
## 掛載在 ParallaxBackground 節點上。
##
## 負責：
##   1. 依相機位置更新 scroll_offset → 驅動三層視差滾動（Layer 1=最慢, Layer 3=最快）
##   2. 依玩家 velocity.x 計算水平偏移（player_offset）→ 注入三層 Shader
##   3. 玩家高速時更新前景條紋長度（speed_factor）→ 超速視覺感
##   4. 為 GPUParticles2D 碎片層動態建立 8×8 霓虹方塊材質

# ── Parallax speed per layer ───────────────────────────────────────────────
## motion_scale 直接在 ParallaxLayer 節點設定，此處做同步（編輯器亦可覆蓋）。
@export_group("Layer Motion Scale")
@export var ms_layer1: float = 0.05   ## Deep Grid（最遠，幾乎不動）
@export var ms_layer2: float = 0.25   ## Nebula / City（中景）
@export var ms_layer3: float = 1.20   ## Foreground Debris（超過玩家，「近鏡」感）

# ── Player-tracking offset ──────────────────────────────────────────────────
@export_group("Player Offset")
## 偏移強度倍率（數值越大，左右移動時背景偏移越明顯）
@export var player_offset_scale_l1: float = 0.008
@export var player_offset_scale_l2: float = 0.022
@export var player_offset_scale_l3: float = 0.072
## 平滑阻尼（越大越即時，越小越「飄」）
@export var offset_smooth: float = 5.5

# ── Speed streaks ───────────────────────────────────────────────────────────
@export_group("Speed Streaks")
## 玩家速度超過此值才啟用速度條紋延伸
@export var speed_threshold: float = 55.0
## speed_factor 上限
@export var speed_factor_max: float = 0.88

# ── Debris particles ───────────────────────────────────────────────────────
@export_group("Debris Particles")
## 碎片粒子顏色 A / B（交替）
@export var debris_color_a: Color = Color(0.3, 1.8, 3.5, 1.0)  ## 電青
@export var debris_color_b: Color = Color(1.8, 0.4, 3.2, 1.0)  ## 紫粉
@export var debris_second_color: Color = Color(0.15, 0.9, 1.6, 0.0)  ## 粒子尾部（透明）

# ── Node path overrides（若場景內命名不同可調整）────────────────────────────
@export_group("Node Paths")
@export var layer1_rect_path: NodePath = NodePath("Layer1_DeepGrid/GridRect")
@export var layer2_rect_path: NodePath = NodePath("Layer2_Nebula/NebulaRect")
@export var layer3_rect_path: NodePath = NodePath("Layer3_Debris/FogRect")
@export var debris_path:      NodePath = NodePath("Layer3_Debris/DebrisParticles")
@export var layer1_backdrop_path: NodePath = NodePath("Layer1_DeepGrid/SpaceBackdropFar")
@export var layer2_backdrop_path: NodePath = NodePath("Layer2_Nebula/SpaceBackdropMid")
@export var layer2_glow_backdrop_path: NodePath = NodePath("Layer2_Nebula/SpaceBackdropGlow")

@export_group("Backdrop Fit")
@export var backdrop_cover_bleed: float = 1.35

# ── Internal refs ──────────────────────────────────────────────────────────
var _mat_grid:   ShaderMaterial = null
var _mat_nebula: ShaderMaterial = null
var _mat_fog:    ShaderMaterial = null
var _debris:     GPUParticles2D = null
var _camera:     Camera2D       = null
var _player:     Node2D         = null
var _layer1_backdrop: Sprite2D = null
var _layer2_backdrop: Sprite2D = null
var _layer2_glow_backdrop: Sprite2D = null

var _current_offset: Vector2 = Vector2.ZERO
var _target_offset:  Vector2 = Vector2.ZERO
var _current_speed_f: float  = 0.0
var _target_speed_f:  float  = 0.0
var _last_viewport_size: Vector2 = Vector2.ZERO

## 上次相機位置（smooth delta calc）
var _last_cam_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	_cache_shader_materials()
	_cache_backdrops()
	_setup_debris_texture()
	_sync_motion_scales()
	_fit_backdrops_to_viewport()
	_camera = get_viewport().get_camera_2d()
	if not Engine.is_editor_hint():
		_player = _find_player()
	## 監聽 ThemeManager（可選）
	if ThemeManager and ThemeManager.has_signal("theme_changed"):
		ThemeManager.theme_changed.connect(_on_theme_changed)


func _process(delta: float) -> void:
	_fit_backdrops_to_viewport_if_needed()
	## 每隔一幀才更新（背景輕量化）
	if Engine.get_process_frames() % 2 != 0:
		return

	_refresh_camera_player_refs()
	var cam_pos: Vector2 = _camera.global_position if _camera else Vector2.ZERO
	var player_vel: Vector2 = _get_player_vel()

	## ── 1. scroll_offset：驅動 ParallaxBackground 位移 ──────────────────
	## Godot ParallaxBackground 以 scroll_offset 為基礎，
	## 乘以各 ParallaxLayer.motion_scale 後得到每層實際偏移。
	## 將相機座標傳入讓場景保持「固定在世界空間」感。
	scroll_offset = cam_pos

	## ── 2. 玩家水平偏移（阻尼 lerp）────────────────────────────────
	_target_offset.x = -player_vel.x * 0.0024
	_target_offset.y = -player_vel.y * 0.0008
	_current_offset = _current_offset.lerp(
		_target_offset, 1.0 - exp(-offset_smooth * delta)
	)

	## ── 3. speed_factor（前景條紋延伸）────────────────────────────
	var spd_x: float = absf(player_vel.x)
	_target_speed_f = clampf(
		(spd_x - speed_threshold) / maxf(1.0, speed_threshold),
		0.0, speed_factor_max
	)
	_current_speed_f = lerpf(_current_speed_f, _target_speed_f, 1.0 - exp(-5.5 * delta))
	var player_speed_x_norm: float = clampf(player_vel.x / 300.0, -1.0, 1.0)

	## ── 4. 寫入 Shader 參數 ──────────────────────────────────────────
	## scroll_offset 給 Shader 用（細粒度 UV 偏移，比 ParallaxLayer 更細膩）
	var shader_scroll := cam_pos * 0.001

	if _mat_grid:
		_mat_grid.set_shader_parameter("scroll_offset", shader_scroll * ms_layer1)
		_mat_grid.set_shader_parameter("player_offset",
			_current_offset * player_offset_scale_l1 * 40.0)

	if _mat_nebula:
		_mat_nebula.set_shader_parameter("scroll_offset", shader_scroll * ms_layer2)
		_mat_nebula.set_shader_parameter("player_offset",
			_current_offset * player_offset_scale_l2 * 40.0)

	if _mat_fog:
		_mat_fog.set_shader_parameter("scroll_offset", shader_scroll * ms_layer3)
		_mat_fog.set_shader_parameter("player_offset",
			_current_offset * player_offset_scale_l3 * 40.0)
		_mat_fog.set_shader_parameter("speed_factor",  _current_speed_f)
		_mat_fog.set_shader_parameter("player_speed_x", player_speed_x_norm)


# ── 初始化 ──────────────────────────────────────────────────────────────────

func _cache_shader_materials() -> void:
	var r1 := get_node_or_null(layer1_rect_path) as CanvasItem
	var r2 := get_node_or_null(layer2_rect_path) as CanvasItem
	var r3 := get_node_or_null(layer3_rect_path) as CanvasItem
	if r1 and r1.material is ShaderMaterial:
		_mat_grid   = r1.material as ShaderMaterial
	if r2 and r2.material is ShaderMaterial:
		_mat_nebula = r2.material as ShaderMaterial
	if r3 and r3.material is ShaderMaterial:
		_mat_fog    = r3.material as ShaderMaterial
	_debris = get_node_or_null(debris_path) as GPUParticles2D


func _cache_backdrops() -> void:
	_layer1_backdrop = get_node_or_null(layer1_backdrop_path) as Sprite2D
	_layer2_backdrop = get_node_or_null(layer2_backdrop_path) as Sprite2D
	_layer2_glow_backdrop = get_node_or_null(layer2_glow_backdrop_path) as Sprite2D


func _fit_backdrops_to_viewport_if_needed() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size if get_viewport() else Vector2.ZERO
	if vp_size == _last_viewport_size:
		return
	_fit_backdrops_to_viewport()


func _fit_backdrops_to_viewport() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size if get_viewport() else Vector2.ZERO
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return
	_last_viewport_size = vp_size
	_fit_single_backdrop(_layer1_backdrop, vp_size, 1.0)
	_fit_single_backdrop(_layer2_backdrop, vp_size, 1.0)
	_fit_single_backdrop(_layer2_glow_backdrop, vp_size, 1.05)


func _fit_single_backdrop(sprite: Sprite2D, vp_size: Vector2, extra_scale: float) -> void:
	if sprite == null or sprite.texture == null:
		return
	var tex_size: Vector2 = sprite.texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var target_w: float = vp_size.x * backdrop_cover_bleed
	var target_h: float = vp_size.y * backdrop_cover_bleed
	var cover_scale: float = maxf(target_w / tex_size.x, target_h / tex_size.y) * extra_scale
	sprite.centered = false
	sprite.position = Vector2.ZERO
	sprite.scale = Vector2.ONE * cover_scale


## 程序化建立 8×8 霓虹方塊材質並注入到 GPUParticles2D。
## 粒子以 blend_add 混合，配合 WorldEnvironment Bloom 自動發光。
func _setup_debris_texture() -> void:
	if _debris == null:
		return
	## 建立 8×8 純白影像（方形像素，by code 無需外部資源）
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	_debris.texture = tex

	## CanvasItemMaterial: Additive Blend（使粒子發光）
	var cmat := CanvasItemMaterial.new()
	cmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_debris.material = cmat

	## 設定 ParticleProcessMaterial 粒子色（色彩 A）
	var pm := _debris.process_material as ParticleProcessMaterial
	if pm:
		pm.color = debris_color_a
		## Gradient：頭部 A 色, 尾部 B 色（漸消）
		var cg := Gradient.new()
		cg.add_point(0.0, debris_color_a)
		cg.add_point(0.55, debris_color_b)
		cg.add_point(1.0, debris_second_color)
		var cgt := GradientTexture1D.new()
		cgt.gradient = cg
		pm.color_ramp = cgt


## 將 GDScript export 的 motion_scale 同步到 ParallaxLayer 節點。
## 若 ParallaxLayer 在 Inspector 已設定，此處以 export 值為準（可在 Inspector 微調）。
func _sync_motion_scales() -> void:
	_set_layer_motion_scale("Layer1_DeepGrid", Vector2(ms_layer1, ms_layer1))
	_set_layer_motion_scale("Layer2_Nebula",   Vector2(ms_layer2, ms_layer2))
	_set_layer_motion_scale("Layer3_Debris",   Vector2(ms_layer3, ms_layer3))


func _set_layer_motion_scale(layer_name: String, scale: Vector2) -> void:
	var n := get_node_or_null(layer_name) as ParallaxLayer
	if n:
		n.motion_scale = scale


# ── Theme 整合 ─────────────────────────────────────────────────────────────

func _on_theme_changed(theme_id: int, duration: float) -> void:
	if not ThemeManager:
		return
	var t := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	## Grid 色跟隨主題（深空=藍, 霓虹核心=洋紅）
	var star_c: Color = ThemeManager.get_star_color()
	var grid_c := Color(star_c.r * 0.4, star_c.g * 0.65 + 0.1, star_c.b * 0.85 + 0.12, 1.0)
	if _mat_grid:
		var cur: Variant = _mat_grid.get_shader_parameter("grid_color")
		var cur_c: Color = cur if cur is Color else Color(0.18, 0.55, 1.0, 1.0)
		t.parallel().tween_method(Callable(self, "_set_grid_color"), cur_c, grid_c, duration)
	## 星雲色
	if _mat_nebula:
		var nebula_c: Color = ThemeManager.get_dust_color()
		var cur: Variant = _mat_nebula.get_shader_parameter("nebula_color_a")
		var cur_c: Color = cur if cur is Color else Color(0.08, 0.12, 0.45, 0.38)
		t.parallel().tween_method(
			Callable(self, "_set_nebula_color_a"),
			cur_c,
			Color(nebula_c.r, nebula_c.g, nebula_c.b, 0.38),
			duration
		)
	## 前景條紋色
	if _mat_fog:
		var fog_c: Color = ThemeManager.get_fog_color()
		var cur: Variant = _mat_fog.get_shader_parameter("streak_color_a")
		var cur_c: Color = cur if cur is Color else Color(0.2, 0.8, 1.0, 1.0)
		t.parallel().tween_method(Callable(self, "_set_fog_streak_color"), cur_c, fog_c, duration)


# ── 輔助函數 ───────────────────────────────────────────────────────────────

func _refresh_camera_player_refs() -> void:
	if not _camera or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_2d()
	if not _player or not is_instance_valid(_player):
		_player = _find_player()


func _set_grid_color(c: Color) -> void:
	if _mat_grid:
		_mat_grid.set_shader_parameter("grid_color", c)


func _set_nebula_color_a(c: Color) -> void:
	if _mat_nebula:
		_mat_nebula.set_shader_parameter("nebula_color_a", Color(c.r, c.g, c.b, 0.38))


func _set_fog_streak_color(c: Color) -> void:
	if _mat_fog:
		_mat_fog.set_shader_parameter("streak_color_a", c)
		_mat_fog.set_shader_parameter("streak_color_b", Color(c.b, c.r * 0.5, c.g, 1.0))


func _set_grid_glow_boost_value(v: float) -> void:
	if _mat_grid:
		_mat_grid.set_shader_parameter("grid_glow_boost", v)


func _find_player() -> Node2D:
	if PlayerRef and PlayerRef.has_method("get_player"):
		return PlayerRef.get_player() as Node2D
	return get_tree().get_first_node_in_group("player") as Node2D


func _get_player_vel() -> Vector2:
	if _player == null or not is_instance_valid(_player):
		return Vector2.ZERO
	if _player is CharacterBody2D:
		return (_player as CharacterBody2D).velocity
	return Vector2.ZERO


## 公開 API：可由其他系統（Boss 警報等）暫時強化 Glow 參數。
func set_grid_glow_boost(boost: float, duration: float = 0.5) -> void:
	if not _mat_grid:
		return
	var cur: Variant = _mat_grid.get_shader_parameter("grid_glow_boost")
	var cur_f: float = cur if cur is float else 2.8
	var t := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_method(Callable(self, "_set_grid_glow_boost_value"), boost, cur_f, duration)


## Debug（F9）
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and ke.keycode == KEY_F9:
			_debug_dump()


func _debug_dump() -> void:
	print("[BG] grid=%s | nebula=%s | fog=%s | speed_f=%.2f | offset=%s | scroll=%s" % [
		"OK" if _mat_grid   else "MISS",
		"OK" if _mat_nebula else "MISS",
		"OK" if _mat_fog    else "MISS",
		_current_speed_f,
		str(_current_offset),
		str(scroll_offset),
	])
