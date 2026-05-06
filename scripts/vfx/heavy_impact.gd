extends Node2D
class_name HeavyImpact
## 重型子彈命中效果：快速擴張的圓形衝擊波環 + 中心閃光。
## 自我管理生命週期（tween 結束後 queue_free）。

## 靜態工廠：直接 spawn 到 parent，無需預先場景引用。
static func spawn(parent: Node, pos: Vector2, color: Color, scale_mul: float = 1.0) -> void:
	if parent == null:
		return
	var vfx := HeavyImpact.new()
	parent.add_child(vfx)
	vfx.global_position = pos
	vfx._start(color, scale_mul)


## ─ 配置常數 ────────────────────────────────────────────────
const RING_RADIUS_START  := 5.0
const RING_RADIUS_END    := 38.0
const RING_DURATION      := 0.22
const FLASH_DURATION     := 0.12
const RING_SEGS          := 20
const RING_WIDTH_START   := 4.5
const RING_WIDTH_END     := 1.0
const INNER_RING_SCALE   := 0.55
const INNER_RING_ALPHA   := 0.30


var _ring_outer : Line2D    = null
var _ring_inner : Line2D    = null
var _fill       : Polygon2D = null
var _flash      : Polygon2D = null
var _mat        : Material  = null

## 動畫狀態（供 _process 輪詢，避免 lambda 內多行捕捉問題）
var _animating  : bool  = false
var _elapsed    : float = 0.0
var _scale_mul  : float = 1.0
var _color      : Color = Color.WHITE
var _end_r      : float = 0.0
var _start_r    : float = 0.0


func _start(color: Color, scale_mul: float) -> void:
	_mat = _load_additive_mat()
	_color     = color
	_scale_mul = scale_mul
	_start_r   = RING_RADIUS_START * scale_mul
	_end_r     = RING_RADIUS_END   * scale_mul

	## 核心爆閃
	_flash = _make_polygon(_start_r * 1.6)
	_flash.color = Color(color.r, color.g, color.b, 0.92)
	if _mat:
		_flash.material = _mat
	add_child(_flash)

	## 外層衝擊環
	_ring_outer = _make_ring(_start_r)
	_ring_outer.width         = RING_WIDTH_START * scale_mul
	_ring_outer.default_color = Color(color.r, color.g, color.b, 1.0)
	if _mat:
		_ring_outer.material = _mat
	add_child(_ring_outer)

	## 內層補充環
	_ring_inner = _make_ring(_start_r * 0.45)
	_ring_inner.width         = (RING_WIDTH_START - 1.5) * scale_mul
	_ring_inner.default_color = Color(color.r * 0.7, color.g * 0.7, color.b * 0.7, INNER_RING_ALPHA)
	if _mat:
		_ring_inner.material = _mat
	add_child(_ring_inner)

	## 半透明填充
	_fill = _make_polygon(_start_r * 0.8)
	_fill.color = Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 0.28)
	if _mat:
		_fill.material = _mat
	add_child(_fill)

	_animating = true


func _process(delta: float) -> void:
	if not _animating:
		return
	_elapsed += delta

	var outer_t : float = clampf(_elapsed / RING_DURATION, 0.0, 1.0)
	var inner_t : float = clampf(_elapsed / (RING_DURATION * 0.75), 0.0, 1.0)
	var flash_t : float = clampf(_elapsed / FLASH_DURATION, 0.0, 1.0)

	## 外環
	if is_instance_valid(_ring_outer):
		var r_outer := lerpf(_start_r, _end_r, _ease_out_circ(outer_t))
		_ring_outer.points       = _ring_pts(r_outer, true)
		_ring_outer.default_color = Color(
			_color.r, _color.g, _color.b,
			lerpf(1.0, 0.0, outer_t)
		)
		_ring_outer.width = lerpf(RING_WIDTH_START * _scale_mul, RING_WIDTH_END, outer_t)

	## 填充圓
	if is_instance_valid(_fill):
		var fill_r := _start_r * 0.8 * (1.0 - outer_t * 0.6)
		_fill.polygon = _circle_pts(fill_r)
		_fill.color   = Color(
			_color.r * 0.5, _color.g * 0.5, _color.b * 0.5,
			lerpf(0.28, 0.0, minf(outer_t * 1.4, 1.0))
		)

	## 內環
	if is_instance_valid(_ring_inner):
		var r_inner := lerpf(_start_r * 0.45, _end_r * 0.6, _ease_out_expo(inner_t))
		_ring_inner.points       = _ring_pts(r_inner, true)
		_ring_inner.default_color = Color(
			_color.r * 0.7, _color.g * 0.7, _color.b * 0.7,
			lerpf(INNER_RING_ALPHA, 0.0, minf(inner_t * 1.5, 1.0))
		)

	## 核心閃光消散
	if is_instance_valid(_flash):
		_flash.color = Color(_color.r, _color.g, _color.b, lerpf(0.92, 0.0, _ease_in_quad(flash_t)))

	## 動畫結束
	if _elapsed >= RING_DURATION:
		_animating = false
		queue_free()


## ─ 緩動函數 ────────────────────────────────────────────────

func _ease_out_circ(t: float) -> float:
	return sqrt(1.0 - pow(t - 1.0, 2.0))


func _ease_out_expo(t: float) -> float:
	if t <= 0.0:
		return 0.0
	if t >= 1.0:
		return 1.0
	return 1.0 - pow(2.0, -10.0 * t)


func _ease_in_quad(t: float) -> float:
	return t * t


## ─ 幾何輔助 ────────────────────────────────────────────────

func _make_ring(r: float) -> Line2D:
	var line          := Line2D.new()
	line.points       = _ring_pts(r, true)
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode   = Line2D.LINE_CAP_ROUND
	return line


func _make_polygon(r: float) -> Polygon2D:
	var poly    := Polygon2D.new()
	poly.polygon = _circle_pts(r)
	return poly


func _ring_pts(r: float, closed: bool) -> PackedVector2Array:
	var pts   := PackedVector2Array()
	var steps : int = RING_SEGS + (1 if closed else 0)
	for i in steps:
		var a := TAU * float(i % RING_SEGS) / float(RING_SEGS)
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	return pts


func _circle_pts(r: float) -> PackedVector2Array:
	return _ring_pts(r, false)


static func _load_additive_mat() -> Material:
	const PATH := "res://resources/materials/additive_material.tres"
	if ResourceLoader.exists(PATH):
		return load(PATH) as Material
	return null
