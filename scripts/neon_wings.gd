@tool
extends Node2D
class_name NeonWings
## 玩家專用程序化霓虹翼：Polygon2D + HDR Shader + 速度 Roll。
##
## 結構：
##   [Self (Node2D)]
##   ├─ GlowL / GlowR  （大輪廓，柔外發光）
##   └─ CoreL / CoreR  （小輪廓，銳利 HDR 核心 + rim）
##
## 所有幾何由 wing_span + sweep_angle + wing_depth 程序化生成；
## 無需在場景中手畫 polygon。掛到 CharacterBody2D 之下即自動 Roll。

const _SHADER_PATH := "res://resources/shaders/neon_wing_sharp.gdshader"

# -----------------------------------------------------------------------------
# Inspector：形狀
# -----------------------------------------------------------------------------

@export_group("Procedural Shape")
## 翼展（從機身根部到翼尖的距離，單位：px）
@export_range(10.0, 240.0, 0.5) var wing_span: float = 58.0:
	set(v):
		wing_span = maxf(4.0, v)
		_rebuild_geometry()

## 後掠角（度）：0 = 水平外伸；+ = 向後掠；- = 向前掃
@export_range(-60.0, 75.0, 0.5) var sweep_angle: float = 32.0:
	set(v):
		sweep_angle = clampf(v, -80.0, 80.0)
		_rebuild_geometry()

## 翼根厚度（上下距離）
@export_range(2.0, 80.0, 0.5) var wing_depth: float = 18.0:
	set(v):
		wing_depth = maxf(1.0, v)
		_rebuild_geometry()

## 內側凹陷量（0 = 平直三角；高值 = 尖銳 jag 切角，更 cyberpunk）
@export_range(0.0, 1.0, 0.01) var jag_amount: float = 0.45:
	set(v):
		jag_amount = clampf(v, 0.0, 1.0)
		_rebuild_geometry()

## 外發光層擴張量（越大發光範圍越廣）
@export_range(0.0, 40.0, 0.5) var glow_padding: float = 10.0:
	set(v):
		glow_padding = maxf(0.0, v)
		_rebuild_geometry()

## 翼根掛載位置（相對 Parent 原點，Player 朝 -y 時 y>0 = 尾端）
@export var anchor_offset: Vector2 = Vector2(0, 12):
	set(v):
		anchor_offset = v
		position = v

# -----------------------------------------------------------------------------
# Inspector：霓虹 Shader
# -----------------------------------------------------------------------------

@export_group("Neon (HDR)")
## HDR 霓虹色；RGB 可 > 1.0 配合 WorldEnvironment Glow/Bloom
@export var neon_color: Color = Color(0.42, 2.50, 3.00, 1.0):
	set(v):
		neon_color = v
		_push_shader_params()

@export_range(0.5, 12.0, 0.05) var pulse_speed: float = 3.2:
	set(v):
		pulse_speed = v
		_push_shader_params()

@export_range(0.0, 1.0, 0.01) var pulse_strength: float = 0.35:
	set(v):
		pulse_strength = v
		_push_shader_params()

@export_range(0.0, 6.0, 0.05) var core_brightness: float = 2.4:
	set(v):
		core_brightness = v
		_push_shader_params()

@export_range(0.05, 1.5, 0.01) var glow_softness: float = 0.55:
	set(v):
		glow_softness = v
		_push_shader_params()

@export_range(0.005, 0.5, 0.005) var edge_sharpness: float = 0.06:
	set(v):
		edge_sharpness = v
		_push_shader_params()

@export_range(0.0, 4.0, 0.05) var tip_boost: float = 1.6:
	set(v):
		tip_boost = v
		_push_shader_params()

# -----------------------------------------------------------------------------
# Inspector：移動 Roll
# -----------------------------------------------------------------------------

@export_group("Movement Roll")
## 依父節點速度自動 Roll（父必須有 velocity 屬性，例如 CharacterBody2D）
@export var auto_roll_from_parent: bool = true
## 最大 Roll 角度（弧度）
@export_range(0.0, 1.2, 0.01) var roll_amount: float = 0.28
## Roll 平滑速度
@export_range(1.0, 30.0, 0.5) var roll_smoothness: float = 9.0
## 速度正規化參照（超過此值視為滿 Roll）；若父有 MAX_SPEED 則優先使用
@export var velocity_reference: float = 420.0

# -----------------------------------------------------------------------------
# Internal
# -----------------------------------------------------------------------------

var _core_mat: ShaderMaterial
var _glow_mat: ShaderMaterial
var _core_left: Polygon2D
var _core_right: Polygon2D
var _glow_left: Polygon2D
var _glow_right: Polygon2D
var _built: bool = false

var _parent_body: Node2D
var _current_roll: float = 0.0


func _ready() -> void:
	position = anchor_offset
	_build()
	_rebuild_geometry()
	_push_shader_params()
	if not Engine.is_editor_hint():
		var p := get_parent()
		if p is Node2D:
			_parent_body = p as Node2D


# -----------------------------------------------------------------------------
# 建構
# -----------------------------------------------------------------------------

func _build() -> void:
	if _built:
		return
	_ensure_materials()
	_glow_left = _make_layer("GlowL", _glow_mat, -3)
	_glow_right = _make_layer("GlowR", _glow_mat, -3)
	_core_left = _make_layer("CoreL", _core_mat, -2)
	_core_right = _make_layer("CoreR", _core_mat, -2)
	add_child(_glow_left)
	add_child(_glow_right)
	add_child(_core_left)
	add_child(_core_right)
	_built = true


func _ensure_materials() -> void:
	var shader := load(_SHADER_PATH) as Shader
	if _core_mat == null:
		_core_mat = ShaderMaterial.new()
		_core_mat.shader = shader
		_core_mat.set_shader_parameter("is_core", true)
	if _glow_mat == null:
		_glow_mat = ShaderMaterial.new()
		_glow_mat.shader = shader
		_glow_mat.set_shader_parameter("is_core", false)


func _make_layer(n: String, mat: Material, zi: int) -> Polygon2D:
	var p := Polygon2D.new()
	p.name = n
	p.material = mat
	p.z_as_relative = true
	p.z_index = zi
	return p


# -----------------------------------------------------------------------------
# 程序化幾何
# -----------------------------------------------------------------------------

## 5 點銳利 cyberpunk 翼輪廓（s = +1 右翼；-1 左翼）。
## padding > 0 用於外發光層外擴。
func _compute_wing_polygon(right: bool, padding: float) -> PackedVector2Array:
	var s: float = 1.0 if right else -1.0
	var sweep_rad: float = deg_to_rad(sweep_angle)
	var span_eff: float = wing_span + padding
	var depth_eff: float = wing_depth + padding * 0.6

	var tip_x: float = cos(sweep_rad) * span_eff
	var tip_y: float = sin(sweep_rad) * span_eff
	var jag: float = jag_amount

	## 沿「尖端方向」的法線（垂直於 sweep 方向）
	var forward := Vector2(cos(sweep_rad), sin(sweep_rad)) * s
	var normal := Vector2(-forward.y, forward.x)

	## 根部：上、下
	var p0: Vector2 = normal * (-depth_eff * 0.5)
	var p4: Vector2 = normal * (depth_eff * 0.5)

	## 翼尖（上緣）：射向外側，略靠上
	var p1: Vector2 = Vector2(s * tip_x, tip_y) + normal * (-depth_eff * 0.15)

	## 翼尖（尖銳前端）：比 p1 再向前推 + 往下偏
	var p2: Vector2 = Vector2(s * tip_x, tip_y) + forward * (depth_eff * 0.05) + normal * (depth_eff * 0.35)

	## 內切口（jag）：在翼尖與翼根之間，向內凹陷形成鋸齒感
	var mid := Vector2(s * tip_x * (0.42 + 0.1 * (1.0 - jag)), tip_y * (0.6 - 0.25 * jag))
	var p3: Vector2 = mid + normal * (depth_eff * (0.75 + 0.25 * jag))

	return PackedVector2Array([p0, p1, p2, p3, p4])


## UV 對應上面 5 點：u 沿翼根→翼尖；v 上緣→下緣。
func _wing_uv() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.00, 0.00), # p0 root top
		Vector2(1.00, 0.10), # p1 upper tip
		Vector2(0.95, 0.50), # p2 sharp forward tip
		Vector2(0.55, 0.85), # p3 jag notch
		Vector2(0.00, 1.00), # p4 root bottom
	])


func _rebuild_geometry() -> void:
	if not _built:
		return
	var uvs := _wing_uv()
	_core_left.polygon = _compute_wing_polygon(false, 0.0)
	_core_right.polygon = _compute_wing_polygon(true, 0.0)
	_glow_left.polygon = _compute_wing_polygon(false, glow_padding)
	_glow_right.polygon = _compute_wing_polygon(true, glow_padding)
	_core_left.uv = uvs
	_core_right.uv = uvs
	_glow_left.uv = uvs
	_glow_right.uv = uvs


# -----------------------------------------------------------------------------
# Shader 參數同步
# -----------------------------------------------------------------------------

func _push_shader_params() -> void:
	var mats: Array = [_core_mat, _glow_mat]
	for m in mats:
		if m == null:
			continue
		m.set_shader_parameter("neon_color", neon_color)
		m.set_shader_parameter("pulse_speed", pulse_speed)
		m.set_shader_parameter("pulse_strength", pulse_strength)
		m.set_shader_parameter("core_brightness", core_brightness)
		m.set_shader_parameter("glow_softness", glow_softness)
		m.set_shader_parameter("edge_sharpness", edge_sharpness)
		m.set_shader_parameter("tip_boost", tip_boost)


# -----------------------------------------------------------------------------
# 移動 Roll
# -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not auto_roll_from_parent or _parent_body == null:
		return
	if not is_instance_valid(_parent_body):
		return
	var vx: float = 0.0
	if "velocity" in _parent_body:
		vx = (_parent_body.velocity as Vector2).x
	var ref: float = velocity_reference
	if "MAX_SPEED" in _parent_body:
		ref = float(_parent_body.MAX_SPEED)
	var t: float = clampf(vx / maxf(1.0, ref), -1.0, 1.0)
	## Player 朝 -y 飛行 → 向右移（vx>0）應令右翼下沉 = 正 rotation
	var target_roll: float = t * roll_amount
	_current_roll = lerp_angle(_current_roll, target_roll, clampf(delta * roll_smoothness, 0.0, 1.0))
	rotation = _current_roll


# -----------------------------------------------------------------------------
# 運行期 API
# -----------------------------------------------------------------------------

## 受擊 / 狂暴等狀態短暫變色（0 duration = 永久）
func flash_color(c: Color, duration: float = 0.25) -> void:
	var orig := neon_color
	neon_color = c
	if duration <= 0.0:
		return
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		if not is_instance_valid(self):
			return
		neon_color = orig
	)


## 翼尖位置（local，相對 NeonWings 原點）。right = true 為右翼，false 為左翼。
func get_wing_tip_local(right: bool) -> Vector2:
	var s: float = 1.0 if right else -1.0
	var sweep_rad: float = deg_to_rad(sweep_angle)
	return Vector2(s * cos(sweep_rad), sin(sweep_rad)) * wing_span


## 翼尖位置（global）。
func get_wing_tip_global(right: bool) -> Vector2:
	return to_global(get_wing_tip_local(right))


## 強力脈衝（例如 Dash / 強化技觸發）
func boost_pulse(intensity_mul: float = 1.8, duration: float = 0.4) -> void:
	var orig_core: float = core_brightness
	var orig_pulse: float = pulse_strength
	core_brightness = orig_core * intensity_mul
	pulse_strength = clampf(orig_pulse * 2.5, 0.0, 1.0)
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		if not is_instance_valid(self):
			return
		core_brightness = orig_core
		pulse_strength = orig_pulse
	)
