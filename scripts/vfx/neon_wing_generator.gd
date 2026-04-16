@tool
extends Node2D
class_name NeonWingGenerator
## 可重用元件：在任何 Node2D 上附加霓虹光翼。
## 用法：將此節點加為實體子節點 → Inspector 調色即可；或設 auto_color_from_parent = true 依父節點名稱自動配色。
## 不依賴 NeonEntity；任何 CharacterBody2D / RigidBody2D / Node2D 皆可掛載。

const _WING_SHADER_PATH := "res://resources/shaders/neon_wing.gdshader"

## 名稱關鍵字 → 霓虹色 的自動對應表。
## 偵測規則：對父節點名稱做 to_lower() 後，檢查是否包含下列任一關鍵字（由上往下）。
const NAME_COLOR_MAP: Array = [
	{"key": "bomber",   "color": Color(1.00, 0.28, 0.30, 1.0)},  # 紅
	{"key": "scout",    "color": Color(0.40, 1.00, 0.55, 1.0)},  # 綠
	{"key": "dasher",   "color": Color(1.00, 0.55, 0.20, 1.0)},  # 橙
	{"key": "shooter",  "color": Color(1.00, 0.35, 0.80, 1.0)},  # 品紅
	{"key": "tank",     "color": Color(0.55, 0.45, 1.00, 1.0)},  # 紫
	{"key": "sniper",   "color": Color(1.00, 0.88, 0.25, 1.0)},  # 黃
	{"key": "elite",    "color": Color(0.95, 0.20, 0.95, 1.0)},  # 亮紫
	{"key": "drone",    "color": Color(0.30, 0.95, 1.00, 1.0)},  # 青
	{"key": "basic",    "color": Color(0.40, 0.90, 1.00, 1.0)},  # 淡青
	{"key": "fighter",  "color": Color(1.00, 0.42, 0.42, 1.0)},  # 血橙
	{"key": "boss",     "color": Color(1.00, 0.50, 0.90, 1.0)},  # 霓紅
	{"key": "titan",    "color": Color(0.70, 0.40, 1.00, 1.0)},  # 深紫
	{"key": "player",   "color": Color(0.35, 0.85, 1.00, 1.0)},  # 玩家藍
]
const FALLBACK_COLOR := Color(0.35, 0.90, 1.00, 1.0)

# -----------------------------------------------------------------------------
# Inspector
# -----------------------------------------------------------------------------

@export_group("Auto Color")
## 啟用後會在 _ready 依據父節點名稱匹配 NAME_COLOR_MAP 自動設定 neon_color。
@export var auto_color_from_parent: bool = true:
	set(v):
		auto_color_from_parent = v
		if is_inside_tree():
			_apply_auto_color()
			_update_wing_shader()

@export_group("Neon Wings")
@export var neon_color: Color = FALLBACK_COLOR:
	set(v):
		neon_color = v
		_update_wing_shader()
@export_range(0.0, 20.0, 0.1) var wing_frequency: float = 4.0:
	set(v):
		wing_frequency = v
		_update_wing_shader()
@export_range(0.0, 6.0, 0.05) var wing_intensity: float = 1.85:
	set(v):
		wing_intensity = v
		_update_wing_shader()
@export_range(-4.0, 4.0, 0.05) var wing_flow_speed: float = 1.6:
	set(v):
		wing_flow_speed = v
		_update_wing_shader()
@export_range(0.005, 0.5, 0.005) var wing_softness: float = 0.12:
	set(v):
		wing_softness = v
		_update_wing_shader()
@export_range(1.0, 40.0, 0.5) var wing_streak_density: float = 14.0:
	set(v):
		wing_streak_density = v
		_update_wing_shader()

@export_group("Wing Shape")
@export var wing_length: float = 22.0:
	set(v):
		wing_length = maxf(1.0, v)
		_rebuild_wings()
@export var wing_span: float = 14.0:
	set(v):
		wing_span = maxf(1.0, v)
		_rebuild_wings()
@export var enable_wings: bool = true:
	set(v):
		enable_wings = v
		if is_inside_tree():
			visible = v

# -----------------------------------------------------------------------------
# Internal
# -----------------------------------------------------------------------------

var _wing_left: Polygon2D
var _wing_right: Polygon2D
var _wing_material: ShaderMaterial
var _built: bool = false


func _ready() -> void:
	z_as_relative = true
	z_index = -1
	if auto_color_from_parent:
		_apply_auto_color()
	_build()


func _build() -> void:
	if _built:
		return
	_ensure_material()
	_wing_left = _make_wing("WingL")
	_wing_right = _make_wing("WingR")
	add_child(_wing_left)
	add_child(_wing_right)
	_rebuild_wings()
	visible = enable_wings
	_built = true


func _ensure_material() -> void:
	if _wing_material:
		return
	_wing_material = ShaderMaterial.new()
	var shader := load(_WING_SHADER_PATH) as Shader
	if shader:
		_wing_material.shader = shader
	_update_wing_shader()


func _make_wing(node_name: String) -> Polygon2D:
	var p := Polygon2D.new()
	p.name = node_name
	p.material = _wing_material
	return p


func _rebuild_wings() -> void:
	if _wing_left and is_instance_valid(_wing_left):
		_wing_left.polygon = _wing_points(false)
		_wing_left.uv = _wing_uv()
	if _wing_right and is_instance_valid(_wing_right):
		_wing_right.polygon = _wing_points(true)
		_wing_right.uv = _wing_uv()


func _wing_points(mirror: bool) -> PackedVector2Array:
	var s: float = 1.0 if mirror else -1.0
	var half: float = wing_span * 0.5
	return PackedVector2Array([
		Vector2(0, -half),
		Vector2(s * wing_length * 0.6, -half * 0.38),
		Vector2(s * wing_length * 1.08, 0),
		Vector2(s * wing_length * 0.6, half * 0.38),
		Vector2(0, half),
	])


func _wing_uv() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(0.62, 0.26),
		Vector2(1.0, 0.5),
		Vector2(0.62, 0.74),
		Vector2(0.0, 1.0),
	])


func _update_wing_shader() -> void:
	if _wing_material == null:
		return
	_wing_material.set_shader_parameter("neon_color", neon_color)
	_wing_material.set_shader_parameter("frequency", wing_frequency)
	_wing_material.set_shader_parameter("intensity", wing_intensity)
	_wing_material.set_shader_parameter("flow_speed", wing_flow_speed)
	_wing_material.set_shader_parameter("wing_softness", wing_softness)
	_wing_material.set_shader_parameter("streak_density", wing_streak_density)


# -----------------------------------------------------------------------------
# 自動配色
# -----------------------------------------------------------------------------

func _apply_auto_color() -> void:
	var c := resolve_color_for_name(_get_parent_name())
	neon_color = c


func _get_parent_name() -> String:
	var p := get_parent()
	if p == null:
		return ""
	return str(p.name)


## 依名稱關鍵字解析霓虹色；查無匹配回傳 FALLBACK_COLOR。
static func resolve_color_for_name(entity_name: String) -> Color:
	var lower := entity_name.to_lower()
	for entry in NAME_COLOR_MAP:
		if lower.contains(String(entry["key"])):
			return entry["color"]
	return FALLBACK_COLOR


# -----------------------------------------------------------------------------
# 運行期 API
# -----------------------------------------------------------------------------

func set_neon_color(c: Color, transition_duration: float = 0.0) -> void:
	if transition_duration <= 0.0:
		neon_color = c
		return
	var start: Color = neon_color
	var t := create_tween()
	t.tween_method(func(v: Color) -> void:
		neon_color = v
	, start, c, transition_duration)


func pulse_flash(intensity_mul: float = 1.8, frequency_mul: float = 3.0, duration: float = 0.35) -> void:
	var orig_i: float = wing_intensity
	var orig_f: float = wing_frequency
	wing_intensity = orig_i * intensity_mul
	wing_frequency = orig_f * frequency_mul
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		if not is_instance_valid(self):
			return
		wing_intensity = orig_i
		wing_frequency = orig_f
	)
