extends Node
## 三層視差背景控制器（全程序化 Shader）
##
## Layer 1 – Stars  (parallax_stars_material)   : 深空星場 + 霓虹 Grid，最遠最慢
## Layer 2 – Dust   (parallax_dust_material)    : 星雲 + 程序化城市剪影，中景
## Layer 3 – Fog    (parallax_fog_material)     : 高速前景條紋 + 漂浮粒子，最近最快
##
## 動態感：
##   - 玩家左右移動 → 各層 player_offset 水平偏移（Layer 3 最強）
##   - 玩家速度大小 → Layer 3 speed_factor 控制條紋長度
##   - ThemeManager → 各層顏色平滑過渡

@export var layer_stars_path: NodePath = NodePath("ParallaxLayer/Stars")
@export var layer_dust_path:  NodePath = NodePath("ParallaxLayer/Dust")
@export var layer_fog_path:   NodePath = NodePath("ParallaxLayer/Fog")

## 各層 scroll_offset 對 camera 位置的係數（越小 = 越遠）
@export var motion_scale_stars: float = 0.08
@export var motion_scale_dust:  float = 0.22
@export var motion_scale_fog:   float = 0.58

## 玩家橫向移動偏移係數（左右移動影響幅度；Layer 3 最大）
@export var player_offset_scale_stars: float = 0.008
@export var player_offset_scale_dust:  float = 0.022
@export var player_offset_scale_fog:   float = 0.068

## 偏移追蹤阻尼（值越小越平滑，值越大越即時響應）
@export var offset_smooth: float = 4.5

## 速度閾值：玩家 X 速度超過此值才計算 speed_factor
@export var speed_threshold: float = 60.0
## speed_factor 最大值（對應最長條紋）
@export var speed_factor_max: float = 0.85

var _camera: Camera2D
var _mat_stars: ShaderMaterial
var _mat_dust:  ShaderMaterial
var _mat_fog:   ShaderMaterial

var _player: Node2D
## 目標偏移（平滑到 _current_offset）
var _target_offset: Vector2  = Vector2.ZERO
var _current_offset: Vector2 = Vector2.ZERO
## 目標 speed_factor（玩家高速時拉長條紋）
var _target_speed_factor: float = 0.0
var _current_speed_factor: float = 0.0


func _ready() -> void:
	_camera = get_viewport().get_camera_2d()
	_player = _resolve_player()

	var stars: CanvasItem = get_node_or_null(layer_stars_path) as CanvasItem
	var dust:  CanvasItem = get_node_or_null(layer_dust_path)  as CanvasItem
	var fog:   CanvasItem = get_node_or_null(layer_fog_path)   as CanvasItem

	if stars and stars.material is ShaderMaterial:
		_mat_stars = stars.material as ShaderMaterial
	if dust and dust.material is ShaderMaterial:
		_mat_dust = dust.material as ShaderMaterial
	if fog and fog.material is ShaderMaterial:
		_mat_fog = fog.material as ShaderMaterial

	if EventBus:
		if EventBus.has_signal("wave_cleared"):
			EventBus.wave_cleared.connect(_on_stage_progression)
		if EventBus.has_signal("stage_cleared"):
			EventBus.stage_cleared.connect(_on_stage_progression)

	if ThemeManager:
		if not ThemeManager.theme_changed.is_connected(_on_theme_changed):
			ThemeManager.theme_changed.connect(_on_theme_changed)
		_apply_theme_colors(ThemeManager.current_theme)


func _process(delta: float) -> void:
	## Camera 驅動
	if not _camera or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_2d()
	var cam_pos: Vector2 = _camera.global_position if _camera else Vector2.ZERO

	## 玩家速度驅動
	if not _player or not is_instance_valid(_player):
		_player = _resolve_player()
	var player_vel := _get_player_velocity()

	## 目標水平偏移（玩家 X 方向移動）
	_target_offset.x = -player_vel.x * 0.001 * 0.5   ## 反向偏移製造「慣性」感
	_target_offset.y = -player_vel.y * 0.0003
	## 平滑阻尼
	_current_offset = _current_offset.lerp(_target_offset, 1.0 - exp(-offset_smooth * delta))

	## speed_factor：玩家 X 速度超閾值時拉長前景條紋
	var spd_x: float = abs(player_vel.x)
	_target_speed_factor = clampf((spd_x - speed_threshold) / maxf(1.0, speed_threshold), 0.0, speed_factor_max)
	_current_speed_factor = lerp(_current_speed_factor, _target_speed_factor, 1.0 - exp(-5.0 * delta))

	## 正規化玩家 X 速度（-1..1），寫給 Layer3 橫向曳尾
	var player_speed_x_norm: float = clampf(player_vel.x / 300.0, -1.0, 1.0)

	## ── Layer 1: Stars + Neon Grid ──────────────────────────────────
	if _mat_stars:
		_mat_stars.set_shader_parameter("scroll_offset", cam_pos * motion_scale_stars)
		_mat_stars.set_shader_parameter("player_offset", _current_offset * player_offset_scale_stars * 40.0)

	## ── Layer 2: Nebula + City Silhouette ───────────────────────────
	if _mat_dust:
		_mat_dust.set_shader_parameter("scroll_offset", cam_pos * motion_scale_dust)
		_mat_dust.set_shader_parameter("player_offset", _current_offset * player_offset_scale_dust * 40.0)

	## ── Layer 3: Speed Streaks + Particles ──────────────────────────
	if _mat_fog:
		_mat_fog.set_shader_parameter("scroll_offset", cam_pos * motion_scale_fog)
		_mat_fog.set_shader_parameter("player_offset", _current_offset * player_offset_scale_fog * 40.0)
		_mat_fog.set_shader_parameter("speed_factor",  _current_speed_factor)
		_mat_fog.set_shader_parameter("player_speed_x", player_speed_x_norm)

	## Focus（VisualLayers 提供中心清晰感）
	if VisualLayers:
		var center: Vector2 = VisualLayers.get_focus_center()
		var inner:  float   = VisualLayers.get_focus_inner_radius()
		var outer:  float   = VisualLayers.get_focus_outer_radius()
		for mat in [_mat_stars, _mat_dust]:
			if mat:
				mat.set_shader_parameter("focus_center", center)
				mat.set_shader_parameter("focus_inner_radius", inner)
				mat.set_shader_parameter("focus_outer_radius", outer)


# ── Theme 顏色過渡 ─────────────────────────────────────────

func _on_theme_changed(theme_id: int, transition_duration: float) -> void:
	if not ThemeManager:
		return
	var tween := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_method(_set_star_color,  _get_star_color(),  ThemeManager.get_star_color(),  transition_duration)
	tween.parallel().tween_method(_set_dust_color,  _get_dust_color(),  ThemeManager.get_dust_color(),  transition_duration)
	tween.parallel().tween_method(_set_fog_color,   _get_fog_color(),   ThemeManager.get_fog_color(),   transition_duration)
	## Grid 顏色也跟 theme 變化（e.g. 深空主題 → 藍色 Grid，霓虹核心 → 洋紅 Grid）
	tween.parallel().tween_method(_set_grid_color, _get_grid_color(), _theme_to_grid_color(theme_id), transition_duration)


func _theme_to_grid_color(theme_id: int) -> Color:
	## 依主題 ID 返回對應 grid 顏色（配合 ThemeManager 定義，此處保守 fallback）
	if not ThemeManager:
		return Color(0.18, 0.55, 1.0, 1.0)
	var star_c: Color = ThemeManager.get_star_color()
	## 從星星色推導 Grid 色：飽和度拉高 + 亮度拉低
	return Color(star_c.r * 0.4, star_c.g * 0.6 + 0.2, star_c.b * 0.8 + 0.15, 1.0)


func _apply_theme_colors(theme_id: int) -> void:
	if not ThemeManager:
		return
	_set_star_color(ThemeManager.get_star_color())
	_set_dust_color(ThemeManager.get_dust_color())
	_set_fog_color(ThemeManager.get_fog_color())
	_set_grid_color(_theme_to_grid_color(theme_id))


func _get_star_color() -> Color:
	if _mat_stars:
		var v: Variant = _mat_stars.get_shader_parameter("star_color")
		if v is Color: return v
	return Color(0.55, 0.65, 1.0, 0.85)

func _set_star_color(c: Color) -> void:
	if _mat_stars: _mat_stars.set_shader_parameter("star_color", c)

func _get_grid_color() -> Color:
	if _mat_stars:
		var v: Variant = _mat_stars.get_shader_parameter("grid_color")
		if v is Color: return v
	return Color(0.18, 0.55, 1.0, 1.0)

func _set_grid_color(c: Color) -> void:
	if _mat_stars: _mat_stars.set_shader_parameter("grid_color", c)

func _get_dust_color() -> Color:
	if _mat_dust:
		var v: Variant = _mat_dust.get_shader_parameter("nebula_color_a")
		if v is Color: return v
	return Color(0.08, 0.12, 0.45, 0.38)

func _set_dust_color(c: Color) -> void:
	if _mat_dust:
		_mat_dust.set_shader_parameter("nebula_color_a", Color(c.r, c.g, c.b, 0.38))
		_mat_dust.set_shader_parameter("nebula_color_b", Color(c.r * 1.1, c.g * 0.4, c.b * 0.85, 0.28))

func _get_fog_color() -> Color:
	if _mat_fog:
		var v: Variant = _mat_fog.get_shader_parameter("streak_color_a")
		if v is Color: return v
	return Color(0.2, 0.8, 1.0, 1.0)

func _set_fog_color(c: Color) -> void:
	if _mat_fog:
		_mat_fog.set_shader_parameter("streak_color_a", Color(c.r, c.g, c.b, 1.0))
		_mat_fog.set_shader_parameter("streak_color_b", Color(c.b, c.r * 0.5, c.g, 1.0))


# ── 輔助 ──────────────────────────────────────────────────

func _resolve_player() -> Node2D:
	if PlayerRef and PlayerRef.has_method("get_player"):
		return PlayerRef.get_player()
	return get_tree().get_first_node_in_group("player") as Node2D


func _get_player_velocity() -> Vector2:
	if _player == null or not is_instance_valid(_player):
		return Vector2.ZERO
	if _player is CharacterBody2D:
		return (_player as CharacterBody2D).velocity
	return Vector2.ZERO


func _on_stage_progression(_arg: int = 0) -> void:
	## 波次推進：輕微亮度脈衝（通過 VisualLayers 處理，避免重複邏輯）
	if not VisualLayers:
		return
	VisualLayers.set_stage_progression_multiplier(1.06)
	var t := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_method(VisualLayers.set_stage_progression_multiplier, 1.06, 1.0, 1.4)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and ke.keycode == KEY_F10:
			_debug_print_status()


func _debug_print_status() -> void:
	print("[ParallaxCtrl] Stars: %s | Dust: %s | Fog: %s | speed_factor=%.2f | offset=%s" % [
		"OK" if _mat_stars else "NO_MAT",
		"OK" if _mat_dust  else "NO_MAT",
		"OK" if _mat_fog   else "NO_MAT",
		_current_speed_factor,
		str(_current_offset),
	])
