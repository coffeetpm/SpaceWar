@tool
extends CharacterBody2D
class_name NeonEntity
## 霓虹實體基礎類別（Cyberpunk Neon Base）。
## 特性：自動生成雙側 Shader 光翼，所有視覺參數可在 Inspector 調整。
## 子類別可覆寫 _entity_process(delta) 與 _entity_physics_process(delta) 來加入行為。

const _WING_SHADER_PATH := "res://resources/shaders/neon_wing.gdshader"

# -----------------------------------------------------------------------------
# Inspector
# -----------------------------------------------------------------------------

@export_group("Neon Wings")
## 光翼霓虹主色。
@export var neon_color: Color = Color(0.35, 0.9, 1.0, 1.0):
	set(v):
		neon_color = v
		_update_wing_shader()
## 光翼脈動頻率（每秒週期數）。值越高閃爍越快。
@export_range(0.0, 20.0, 0.1) var wing_frequency: float = 4.0:
	set(v):
		wing_frequency = v
		_update_wing_shader()
## 整體亮度倍率（超過 1 會觸發 HDR glow）。
@export_range(0.0, 6.0, 0.05) var wing_intensity: float = 1.85:
	set(v):
		wing_intensity = v
		_update_wing_shader()
## 沿翼長流動的能量條紋速度。負值反向。
@export_range(-4.0, 4.0, 0.05) var wing_flow_speed: float = 1.6:
	set(v):
		wing_flow_speed = v
		_update_wing_shader()
## 光翼外緣柔邊（0 = 硬邊；大值 = 羽化擴散）。
@export_range(0.005, 0.5, 0.005) var wing_softness: float = 0.12:
	set(v):
		wing_softness = v
		_update_wing_shader()
## 條紋密度（單翼可見條紋數）。
@export_range(1.0, 40.0, 0.5) var wing_streak_density: float = 14.0:
	set(v):
		wing_streak_density = v
		_update_wing_shader()

@export_group("Wing Shape")
## 從身體中心向外的光翼長度（px）。
@export var wing_length: float = 56.0:
	set(v):
		wing_length = maxf(1.0, v)
		_rebuild_wings()
## 根部寬度（px）。
@export var wing_span: float = 28.0:
	set(v):
		wing_span = maxf(1.0, v)
		_rebuild_wings()
## 光翼錨點位移（相對實體中心，通常微微上移讓翼像從「肩部」伸出）。
@export var wing_anchor_offset: Vector2 = Vector2(0, -2):
	set(v):
		wing_anchor_offset = v
		if _wing_root:
			_wing_root.position = wing_anchor_offset
## 啟用 / 停用光翼。
@export var enable_wings: bool = true:
	set(v):
		enable_wings = v
		if _wing_root:
			_wing_root.visible = v

# -----------------------------------------------------------------------------
# 內部狀態
# -----------------------------------------------------------------------------

var _wing_root: Node2D
var _wing_left: Polygon2D
var _wing_right: Polygon2D
var _wing_material: ShaderMaterial
var _wing_built: bool = false


func _ready() -> void:
	_build_wings_if_missing()


func _build_wings_if_missing() -> void:
	if _wing_built and _wing_root and is_instance_valid(_wing_root):
		return
	## 若子類別已在場景中放置同名節點則重用，避免重複生成
	var existing: Node = get_node_or_null("NeonWings")
	if existing is Node2D:
		_wing_root = existing as Node2D
		_wing_left = _wing_root.get_node_or_null("WingL") as Polygon2D
		_wing_right = _wing_root.get_node_or_null("WingR") as Polygon2D
	else:
		_wing_root = Node2D.new()
		_wing_root.name = "NeonWings"
		_wing_root.z_index = -1
		add_child(_wing_root)
	_wing_root.position = wing_anchor_offset
	_ensure_shared_material()
	if _wing_left == null or not is_instance_valid(_wing_left):
		_wing_left = _make_wing_polygon_node("WingL")
		_wing_root.add_child(_wing_left)
	else:
		_wing_left.material = _wing_material
	if _wing_right == null or not is_instance_valid(_wing_right):
		_wing_right = _make_wing_polygon_node("WingR")
		_wing_root.add_child(_wing_right)
	else:
		_wing_right.material = _wing_material
	_rebuild_wings()
	_wing_root.visible = enable_wings
	_wing_built = true


func _ensure_shared_material() -> void:
	if _wing_material:
		return
	_wing_material = ShaderMaterial.new()
	var shader := load(_WING_SHADER_PATH) as Shader
	if shader:
		_wing_material.shader = shader
	_update_wing_shader()


func _make_wing_polygon_node(node_name: String) -> Polygon2D:
	var p := Polygon2D.new()
	p.name = node_name
	p.material = _wing_material
	return p


func _rebuild_wings() -> void:
	if not _wing_built and not (_wing_root and is_instance_valid(_wing_root)):
		return
	if _wing_left and is_instance_valid(_wing_left):
		_wing_left.polygon = _make_wing_polygon_points(false)
		_wing_left.uv = _make_wing_uv()
	if _wing_right and is_instance_valid(_wing_right):
		_wing_right.polygon = _make_wing_polygon_points(true)
		_wing_right.uv = _make_wing_uv()


## 生成單側光翼的多邊形（5 頂點：根上 → 翼中上 → 翼尖 → 翼中下 → 根下）。
## mirror=true 為右側（朝 +x），false 為左側（朝 -x）。
func _make_wing_polygon_points(mirror: bool) -> PackedVector2Array:
	var s: float = 1.0 if mirror else -1.0
	var half: float = wing_span * 0.5
	return PackedVector2Array([
		Vector2(0, -half),
		Vector2(s * wing_length * 0.6, -half * 0.38),
		Vector2(s * wing_length * 1.08, 0),
		Vector2(s * wing_length * 0.6, half * 0.38),
		Vector2(0, half),
	])


## UV 對應：x = 沿翼長 0→1；y = 翼寬 0→1。
func _make_wing_uv() -> PackedVector2Array:
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
# 子類別覆寫點
# -----------------------------------------------------------------------------

## 子類別覆寫此處做自訂邏輯（避免覆寫 _process 影響光翼更新）。
func _entity_process(_delta: float) -> void:
	pass


## 子類別覆寫此處做移動／AI（_physics_process）。
func _entity_physics_process(_delta: float) -> void:
	pass


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_entity_process(delta)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_entity_physics_process(delta)


# -----------------------------------------------------------------------------
# 公用 API
# -----------------------------------------------------------------------------

## 執行期快速切換霓虹配色（含顏色動畫）。
func set_neon_color(c: Color, transition_duration: float = 0.0) -> void:
	if transition_duration <= 0.0:
		neon_color = c
		return
	var start: Color = neon_color
	var t := create_tween()
	t.tween_method(Callable(self, "_set_neon_color_value"), start, c, transition_duration)


func _set_neon_color_value(v: Color) -> void:
	neon_color = v


## 震擊效果：短暫強化脈動（用於受擊、進入狂暴階段等）。
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
