extends Node2D
class_name PlasmaArcController
## 電漿子彈的電弧 VFX：N 條從中心向外爆射的隨機鋸齒線，模擬電磁放電。
## 由 Bullet.apply_style() 惰性建立並附加為子節點；pool 回收時 reset() 隱藏。

@export var arc_count:     int   = 5
@export var arc_min_len:   float = 5.0
@export var arc_max_len:   float = 11.0
@export var arc_width:     float = 1.4
@export var spin_speed:    float = 3.2   ## 主要旋轉速度（rad/s）
@export var flicker_speed: float = 14.0  ## 高頻閃爍
@export var jag_amount:    float = 0.35  ## 鋸齒偏移量（0=直線, 1=很彎）

var hdr_color: Color = Color(0.3, 2.0, 3.8, 1.0)

var _arcs:        Array[Line2D] = []
var _angles:      Array[float]  = []
var _lengths:     Array[float]  = []
var _jag_phases:  Array[float]  = []
var _mat:         Material      = null
var _time:        float         = 0.0
var _initialized: bool          = false


func setup(color: Color, mat: Material) -> void:
	hdr_color = color
	_mat      = mat
	_time     = 0.0
	visible   = true
	if not _initialized:
		_build_arcs()
		_initialized = true
	else:
		_randomize_arcs()


## 第一次建立 arc Line2D 節點
func _build_arcs() -> void:
	for i in arc_count:
		var arc := Line2D.new()
		arc.width = arc_width
		arc.default_color = hdr_color
		arc.begin_cap_mode = Line2D.LINE_CAP_ROUND
		arc.end_cap_mode  = Line2D.LINE_CAP_ROUND
		if _mat:
			arc.material = _mat
		add_child(arc)
		_arcs.append(arc)
		_angles.append(TAU * float(i) / float(arc_count))
		_lengths.append(randf_range(arc_min_len, arc_max_len))
		_jag_phases.append(randf() * TAU)


func _randomize_arcs() -> void:
	for i in _arcs.size():
		_lengths[i]    = randf_range(arc_min_len, arc_max_len)
		_jag_phases[i] = randf() * TAU


func reset() -> void:
	visible = false
	for arc in _arcs:
		if is_instance_valid(arc):
			arc.points = PackedVector2Array()
	_time = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	for i in _arcs.size():
		var arc: Line2D = _arcs[i]
		if not is_instance_valid(arc):
			continue
		## 主角度緩慢旋轉 + 各弧獨立偏移
		_angles[i] += delta * (spin_speed + sin(_time * 1.1 + float(i)) * 1.4)
		var base_a: float = _angles[i]
		var length: float = _lengths[i]

		## 3 段鋸齒：起點（bullet 中心附近）→ 中段偏折 → 尖端
		var inner_r: float = 2.4
		var mid_r: float   = length * 0.52
		var outer_r: float = length + sin(_time * flicker_speed * 0.7 + float(i) * 1.9) * 2.0

		## 各段加入隨機側偏，製造鋸齒感
		var jag1: float = sin(_time * flicker_speed + _jag_phases[i]) * jag_amount
		var jag2: float = sin(_time * flicker_speed * 1.3 + _jag_phases[i] + 1.1) * jag_amount * 0.7

		var a1: float = base_a
		var a_mid: float  = base_a + jag1
		var a_tip: float  = base_a + jag2

		arc.points = PackedVector2Array([
			Vector2(cos(a1) * inner_r,  sin(a1) * inner_r),
			Vector2(cos(a_mid) * mid_r, sin(a_mid) * mid_r),
			Vector2(cos(a_tip) * outer_r, sin(a_tip) * outer_r),
		])

		## 閃爍 alpha（高頻）
		var flicker: float = 0.55 + 0.45 * abs(sin(_time * flicker_speed + float(i) * 2.3))
		arc.default_color = Color(hdr_color.r, hdr_color.g, hdr_color.b, flicker)
