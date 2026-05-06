extends Node2D
@tool
class_name ProceduralFighter
## 程序化科幻戰機——Ace Combat 風格，全部以 Polygon2D / Line2D 在代碼裏繪製。
## 無任何外部貼圖依賴；HDR 霓虹色配合 WorldEnvironment Bloom 自動發光。
##
## 架構：
##   BaseLayer  — 深色填充（機身、機翼、引擎艙）
##   GlowLayer  — additive 混合（邊緣光、機首、引擎噴焰）
##   DetailLayer— additive 混合（面板線、脊線、細節）
##
## 整合：加入 player.tscn > Visual 作為子節點即可。
## ShipVisualController 透過 set_engine_intensity() 傳遞速度資訊。

# ── Inspector ──────────────────────────────────────────────────────────────
@export_group("Edge / Outline")
@export var col_edge_main:   Color = Color(0.32, 2.10, 3.80, 1.0)  ## 主邊框（HDR 青）
@export var col_edge_soft:   Color = Color(0.18, 1.20, 3.20, 0.6)  ## 次邊框（柔青）
@export var col_accent:      Color = Color(1.60, 0.45, 3.10, 0.7)  ## 強調線（紫粉）
@export var edge_width:      float = 1.5
@export var glow_width:      float = 3.2

@export_group("Cockpit")
@export var col_cockpit_core: Color = Color(0.55, 2.00, 3.50, 1.0) ## 駕駛艙核心
@export var col_cockpit_rim:  Color = Color(0.30, 1.50, 2.80, 0.8) ## 駕駛艙邊框

@export_group("Engine")
@export var col_engine_hot:   Color = Color(4.50, 2.20, 0.20, 1.0) ## 噴嘴中心（熾白橙）
@export var col_engine_warm:  Color = Color(3.20, 1.40, 0.35, 0.8) ## 噴嘴外圍
@export var col_engine_plume: Color = Color(1.80, 0.70, 0.20, 0.5) ## 噴焰尾跡

@export_group("Base Fills")
@export var col_fuselage:  Color = Color(0.048, 0.090, 0.200, 0.97)
@export var col_wing:      Color = Color(0.036, 0.068, 0.158, 0.95)
@export var col_engine_pod:Color = Color(0.055, 0.080, 0.175, 0.97)
@export var col_intake:    Color = Color(0.015, 0.025, 0.060, 0.99)

@export_group("Animation")
@export var engine_pulse_speed:   float = 2.60
@export var cockpit_flicker_speed:float = 4.80
@export var scan_line_speed:      float = 0.90
@export var edge_shimmer_speed:   float = 7.20


# ── Animated nodes ─────────────────────────────────────────────────────────
var _cockpit_core: Polygon2D      = null
var _cockpit_rim:  Line2D         = null
var _engine_L_hot: Polygon2D      = null
var _engine_R_hot: Polygon2D      = null
var _engine_L_warm: Polygon2D     = null
var _engine_R_warm: Polygon2D     = null
var _engine_plume_L: Line2D       = null
var _engine_plume_R: Line2D       = null
var _edge_lines:   Array[Line2D]  = []
var _scan_line:    Line2D         = null

# ── State ──────────────────────────────────────────────────────────────────
var _time:              float = 0.0
var _shot_flash:        float = 0.0
var _engine_intensity:  float = 0.75  ## 0=靜止, 1=全速（由 ShipVisualController 注入）
var _mat_add:           Material = null
var _built:             bool = false


# ── Public API ──────────────────────────────────────────────────────────────

## 由 ShipVisualController 每 frame 呼叫，傳遞速度係數 (0..1)
func set_engine_intensity(v: float) -> void:
	_engine_intensity = clampf(v, 0.0, 1.0)


func _ready() -> void:
	_mat_add = _load_additive_mat()
	_build()
	if not Engine.is_editor_hint():
		_connect_signals()


func _process(delta: float) -> void:
	if not _built:
		return
	_time      += delta
	_shot_flash  = maxf(0.0, _shot_flash - delta * 9.0)
	_animate()


# ═══════════════════════════════════════════════════════════════════════════
# BUILD — 一次性建立所有幾何節點
# ═══════════════════════════════════════════════════════════════════════════

func _build() -> void:
	## 三個渲染層 —————————————————
	var base_layer   := _add_layer("_BaseLayer",   false)
	var glow_layer   := _add_layer("_GlowLayer",   true)
	var detail_layer := _add_layer("_DetailLayer", true)

	## ── Layer 1：深色填充 ────────────────────────────────
	_poly(base_layer, _wing_pts(false),  col_wing)       ## 左機翼
	_poly(base_layer, _wing_pts(true),   col_wing)       ## 右機翼
	_poly(base_layer, _canard_pts(false),col_wing)       ## 左鴨翼
	_poly(base_layer, _canard_pts(true), col_wing)       ## 右鴨翼
	_poly(base_layer, _tail_fin_pts(false), col_wing)    ## 左垂尾
	_poly(base_layer, _tail_fin_pts(true),  col_wing)    ## 右垂尾
	_poly(base_layer, _engine_pod_pts(false), col_engine_pod) ## 左引擎艙
	_poly(base_layer, _engine_pod_pts(true),  col_engine_pod) ## 右引擎艙
	_poly(base_layer, _intake_pts(false), col_intake)    ## 左進氣道
	_poly(base_layer, _intake_pts(true),  col_intake)    ## 右進氣道
	_poly(base_layer, _fuselage_pts(),   col_fuselage)   ## 機身（最後蓋住翼根）

	## 前緣光帶（Polygon2D 沿翼前緣，薄長條，additive）
	_poly(glow_layer, _wing_leading_pts(false), Color(col_edge_main.r, col_edge_main.g, col_edge_main.b, 0.22))
	_poly(glow_layer, _wing_leading_pts(true),  Color(col_edge_main.r, col_edge_main.g, col_edge_main.b, 0.22))
	_poly(glow_layer, _canard_leading_pts(false), Color(col_edge_main.r, col_edge_main.g, col_edge_main.b, 0.20))
	_poly(glow_layer, _canard_leading_pts(true),  Color(col_edge_main.r, col_edge_main.g, col_edge_main.b, 0.20))

	## ── Layer 2：Glow 邊框線（additive）───────────────────
	## 機身主輪廓
	var fuselage_edge := _line(glow_layer, _fuselage_edge_pts(), col_edge_main, glow_width)
	fuselage_edge.z_index = 1
	_edge_lines.append(fuselage_edge)
	var fuselage_edge2 := _line(glow_layer, _fuselage_edge_pts(), col_edge_main, edge_width)
	_edge_lines.append(fuselage_edge2)

	## 左右機翼邊框
	for side in [false, true]:
		var wl := _line(glow_layer, _wing_edge_pts(side), col_edge_main, glow_width)
		var wl2 := _line(glow_layer, _wing_edge_pts(side), col_edge_main, edge_width)
		_edge_lines.append(wl)
		_edge_lines.append(wl2)
		var cl  := _line(glow_layer, _canard_edge_pts(side), col_edge_main, glow_width * 0.75)
		var cl2 := _line(glow_layer, _canard_edge_pts(side), col_edge_main, edge_width)
		_edge_lines.append(cl)
		_edge_lines.append(cl2)
		var tl  := _line(glow_layer, _tail_fin_edge_pts(side), col_edge_soft, glow_width * 0.65)
		_edge_lines.append(tl)
		var el  := _line(glow_layer, _engine_nozzle_pts(side), col_edge_soft, glow_width * 0.55)
		_edge_lines.append(el)

	## ── Layer 3：細節線（additive）───────────────────────
	## 機身脊線（中軸）
	_line(detail_layer, PackedVector2Array([Vector2(0,-22), Vector2(0,19)]),
		Color(col_edge_main.r, col_edge_main.g, col_edge_main.b, 0.6), edge_width * 0.65)

	## 翼面面板線（對稱斜線）
	for side in [false, true]:
		var sx: float = -1.0 if not side else 1.0
		## 前緣分割線
		_line(detail_layer, PackedVector2Array([
			Vector2(sx * 6.5, 0), Vector2(sx * 18.0, 6.5)]),
			col_accent, edge_width * 0.55)
		## 後緣收束線
		_line(detail_layer, PackedVector2Array([
			Vector2(sx * 16.0, 10.5), Vector2(sx * 22.5, 16.5)]),
			Color(col_edge_soft.r, col_edge_soft.g, col_edge_soft.b, 0.5), edge_width * 0.45)
		## 機翼前緣延伸高亮
		_line(detail_layer, PackedVector2Array([
			Vector2(sx * 6.5, 0), Vector2(sx * 28.5, 10.0)]),
			Color(col_edge_main.r, col_edge_main.g, col_edge_main.b, 0.35), edge_width * 0.40)
		## 鴨翼面板線
		_line(detail_layer, PackedVector2Array([
			Vector2(sx * 4.0, -12.5), Vector2(sx * 10.0, -9.0)]),
			col_accent, edge_width * 0.50)

	## 引擎艙蓋線（橫截面）
	for side in [false, true]:
		var sx: float = -1.0 if not side else 1.0
		_line(detail_layer, PackedVector2Array([
			Vector2(sx * 2.5, 16.0), Vector2(sx * 5.8, 14.5)]),
			col_accent, edge_width * 0.55)
		_line(detail_layer, PackedVector2Array([
			Vector2(sx * 2.5, 19.5), Vector2(sx * 5.8, 18.0)]),
			Color(col_edge_soft.r, col_edge_soft.g, col_edge_soft.b, 0.5), edge_width * 0.45)

	## 橫向雙道強調線（科幻感）
	for y_off in [-4.0, 6.0]:
		_line(detail_layer, PackedVector2Array([
			Vector2(-7.5, y_off), Vector2(7.5, y_off)]),
			Color(col_accent.r, col_accent.g, col_accent.b, 0.35), edge_width * 0.40)

	## 掃光條（scan line，橫向移動）
	_scan_line = _line(detail_layer, PackedVector2Array([
		Vector2(-32, 0), Vector2(32, 0)]),
		Color(col_edge_main.r, col_edge_main.g, col_edge_main.b, 0.0), edge_width * 0.5)

	## ── 駕駛艙（additive）────────────────────────────────
	_cockpit_core = _poly(glow_layer, _cockpit_pts(), col_cockpit_core)
	_cockpit_core.z_index = 3
	_cockpit_rim  = _line(glow_layer, _cockpit_rim_pts(), col_cockpit_rim, glow_width)
	_cockpit_rim.z_index  = 4
	## 高亮白核心（極小、純白 HDR）
	_poly(glow_layer, _cockpit_inner_pts(), Color(1.8, 2.2, 2.8, 0.9))

	## ── 引擎噴嘴光（additive）───────────────────────────
	_engine_L_hot  = _poly(glow_layer, _nozzle_inner_pts(false), col_engine_hot)
	_engine_R_hot  = _poly(glow_layer, _nozzle_inner_pts(true),  col_engine_hot)
	_engine_L_warm = _poly(glow_layer, _nozzle_outer_pts(false), col_engine_warm)
	_engine_R_warm = _poly(glow_layer, _nozzle_outer_pts(true),  col_engine_warm)
	## 噴焰尾跡（Line2D，向後延伸）
	_engine_plume_L = _line(glow_layer, _plume_pts(false), col_engine_plume, glow_width * 0.9)
	_engine_plume_R = _line(glow_layer, _plume_pts(true),  col_engine_plume, glow_width * 0.9)

	_built = true


# ═══════════════════════════════════════════════════════════════════════════
# ANIMATE — 每 frame 更新可動效果
# ═══════════════════════════════════════════════════════════════════════════

func _animate() -> void:
	## 引擎脈衝（速度越快越亮）
	var eng_base: float = lerpf(0.35, 1.0, _engine_intensity)
	var eng_sin: float  = 0.5 + 0.5 * sin(_time * engine_pulse_speed)
	var eng_t: float    = eng_base + eng_sin * lerpf(0.12, 0.32, _engine_intensity) + _shot_flash * 0.4
	eng_t = clampf(eng_t, 0.0, 2.0)

	if _engine_L_hot:
		var c := col_engine_hot
		_engine_L_hot.color = Color(c.r * eng_t, c.g * eng_t, c.b * eng_t, clampf(eng_t * 0.9, 0, 1))
	if _engine_R_hot:
		var c := col_engine_hot
		_engine_R_hot.color = Color(c.r * eng_t, c.g * eng_t, c.b * eng_t, clampf(eng_t * 0.9, 0, 1))
	if _engine_L_warm:
		var cw := col_engine_warm
		var wt := eng_t * 0.72
		_engine_L_warm.color = Color(cw.r * wt, cw.g * wt, cw.b * wt, clampf(wt * 0.85, 0, 1))
	if _engine_R_warm:
		var cw := col_engine_warm
		var wt := eng_t * 0.72
		_engine_R_warm.color = Color(cw.r * wt, cw.g * wt, cw.b * wt, clampf(wt * 0.85, 0, 1))

	## 噴焰尾跡長度隨速度縮放
	var plume_scale: float = lerpf(0.3, 1.0, _engine_intensity) * (0.8 + 0.2 * eng_sin)
	if _engine_plume_L:
		var cp := col_engine_plume
		_engine_plume_L.color = Color(cp.r, cp.g, cp.b, cp.a * plume_scale)
	if _engine_plume_R:
		var cp := col_engine_plume
		_engine_plume_R.color = Color(cp.r, cp.g, cp.b, cp.a * plume_scale)

	## 駕駛艙閃爍（高頻，微妙）
	var ck_t: float = 0.72 + 0.28 * (0.5 + 0.5 * sin(_time * cockpit_flicker_speed))
	ck_t += _shot_flash * 0.55
	if _cockpit_core:
		var cc := col_cockpit_core
		_cockpit_core.color = Color(cc.r * ck_t, cc.g * ck_t, cc.b * ck_t, clampf(ck_t, 0, 1))
	if _cockpit_rim:
		var cr := col_cockpit_rim
		_cockpit_rim.default_color = Color(cr.r * ck_t, cr.g * ck_t, cr.b * ck_t, clampf(ck_t * 0.9, 0, 1))

	## 邊框整體亮度脈衝（射擊 flash + 低頻呼吸）
	var edge_breath: float = 0.88 + 0.12 * sin(_time * edge_shimmer_speed * 0.25)
	var edge_t: float = edge_breath + _shot_flash * 0.35
	for l in _edge_lines:
		if is_instance_valid(l):
			var base := col_edge_main if l.width >= glow_width * 0.7 else col_edge_soft
			l.default_color = Color(base.r, base.g, base.b,
				clampf(base.a * edge_t, 0.0, 1.0))

	## 掃光線（每隔一段時間橫掃機身一次）
	if _scan_line:
		var scan_cycle: float = fmod(_time * scan_line_speed, 4.0)  ## 4秒一個週期
		if scan_cycle < 1.2:
			var prog: float = scan_cycle / 1.2
			var y_pos: float = lerpf(-24.0, 28.0, prog)
			var alpha: float = sin(prog * PI) * 0.55
			_scan_line.position = Vector2(0, y_pos)
			_scan_line.default_color = Color(col_edge_main.r, col_edge_main.g, col_edge_main.b, alpha)
		else:
			_scan_line.default_color.a = 0.0


# ═══════════════════════════════════════════════════════════════════════════
# 幾何定義 — 每個函數回傳該部件的 PackedVector2Array
# ═══════════════════════════════════════════════════════════════════════════
# 座標系：Y 軸向下（Godot 標準）；機鼻在 -Y，引擎在 +Y。
# 機身中心為原點，左 = -X，右 = +X。

## 機身（飛梭形主體）
func _fuselage_pts() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2( 0.0, -22.0),   ## 機鼻尖
		Vector2( 1.8, -18.5),   ## 機鼻右
		Vector2( 3.8, -13.5),   ## 前機身右
		Vector2( 5.2,  -7.0),   ## 駕駛艙右
		Vector2( 6.8,   0.5),   ## 最寬處右
		Vector2( 6.5,   8.5),   ## 中段右
		Vector2( 5.8,  15.0),   ## 後機身右
		Vector2( 4.5,  20.5),   ## 引擎接頸右
		## 尾部（兩引擎之間）
		Vector2( 2.2,  22.5),
		Vector2( 0.0,  20.8),
		Vector2(-2.2,  22.5),
		## 左側鏡像
		Vector2(-4.5,  20.5),
		Vector2(-5.8,  15.0),
		Vector2(-6.5,   8.5),
		Vector2(-6.8,   0.5),
		Vector2(-5.2,  -7.0),
		Vector2(-3.8, -13.5),
		Vector2(-1.8, -18.5),
	])


## 機身輪廓線（用於 Line2D 邊框）
func _fuselage_edge_pts() -> PackedVector2Array:
	var pts := _fuselage_pts()
	## 閉合
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	return closed


## 主翼（大後掠三角翼，仿 F-22 / 空戰奇兵 ADF-01）
## left=false 則左翼，left=true 則右翼（X 取反）
func _wing_pts(right: bool) -> PackedVector2Array:
	var s: float = -1.0 if not right else 1.0
	return PackedVector2Array([
		Vector2(s *  6.2,  -1.0),  ## 翼根前緣
		Vector2(s * 30.0,  10.0),  ## 翼尖
		Vector2(s * 26.5,  20.5),  ## 翼尖後緣
		Vector2(s *  5.5,  17.5),  ## 翼根後緣
	])


func _wing_edge_pts(right: bool) -> PackedVector2Array:
	var pts := _wing_pts(right)
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	return closed


## 翼前緣薄光帶（additive 疊加製造前緣光效）
func _wing_leading_pts(right: bool) -> PackedVector2Array:
	var s: float = -1.0 if not right else 1.0
	## 沿前緣做 2px 寬薄帶（平行偏移）
	return PackedVector2Array([
		Vector2(s *  6.2,  -1.0),
		Vector2(s * 30.0,  10.0),
		Vector2(s * 28.8,  11.2),  ## 往內縮 ~1.5px
		Vector2(s *  6.8,   0.2),
	])


## 鴨翼（前置三角小翼，仿 Eurofighter / Gripen）
func _canard_pts(right: bool) -> PackedVector2Array:
	var s: float = -1.0 if not right else 1.0
	return PackedVector2Array([
		Vector2(s *  3.5, -13.5),  ## 翼根前
		Vector2(s * 16.0,  -9.5),  ## 翼尖
		Vector2(s * 13.5,  -4.5),  ## 翼尖後
		Vector2(s *  4.0,  -7.5),  ## 翼根後
	])


func _canard_edge_pts(right: bool) -> PackedVector2Array:
	var pts := _canard_pts(right)
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	return closed


func _canard_leading_pts(right: bool) -> PackedVector2Array:
	var s: float = -1.0 if not right else 1.0
	return PackedVector2Array([
		Vector2(s *  3.5, -13.5),
		Vector2(s * 16.0,  -9.5),
		Vector2(s * 15.2,  -8.8),
		Vector2(s *  4.0, -12.8),
	])


## 垂尾（後掠式小型穩定翼，從上方看為薄菱形）
func _tail_fin_pts(right: bool) -> PackedVector2Array:
	var s: float = -1.0 if not right else 1.0
	return PackedVector2Array([
		Vector2(s *  4.0,  13.5),  ## 根部前
		Vector2(s * 11.5,  10.5),  ## 尖端
		Vector2(s * 10.5,  19.5),  ## 尖端後
		Vector2(s *  4.0,  20.5),  ## 根部後
	])


func _tail_fin_edge_pts(right: bool) -> PackedVector2Array:
	var pts := _tail_fin_pts(right)
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	return closed


## 引擎艙（獨立艙體，帶噴嘴開口）
func _engine_pod_pts(right: bool) -> PackedVector2Array:
	var s: float = -1.0 if not right else 1.0
	return PackedVector2Array([
		Vector2(s *  2.0,  16.5),  ## 內側前
		Vector2(s *  5.5,  14.5),  ## 外側前
		Vector2(s *  6.8,  24.0),  ## 外側後
		Vector2(s *  6.2,  27.5),  ## 噴嘴外唇
		Vector2(s *  3.8,  27.5),  ## 噴嘴內唇
		Vector2(s *  2.5,  24.0),  ## 內側後
	])


func _engine_nozzle_pts(right: bool) -> PackedVector2Array:
	var s: float = -1.0 if not right else 1.0
	## 噴嘴開口橢圓形輪廓（5 個頂點弧線）
	return PackedVector2Array([
		Vector2(s * 3.8, 27.5),
		Vector2(s * 4.5, 28.2),
		Vector2(s * 5.0, 27.8),
		Vector2(s * 6.2, 27.5),
	])


## 進氣道（深黑矩形，位於機翼根部）
func _intake_pts(right: bool) -> PackedVector2Array:
	var s: float = -1.0 if not right else 1.0
	return PackedVector2Array([
		Vector2(s *  4.8,  -6.5),  ## 進氣口前
		Vector2(s *  7.8,  -3.0),  ## 外前
		Vector2(s *  7.5,   6.5),  ## 外後
		Vector2(s *  5.5,   5.5),  ## 內後
	])


## 駕駛艙（淚滴形，機鼻偏後）
func _cockpit_pts() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2( 0.0, -19.5),  ## 前尖
		Vector2( 2.8, -14.5),  ## 右前
		Vector2( 3.0,  -9.5),  ## 右後
		Vector2( 0.0,  -7.5),  ## 後中
		Vector2(-3.0,  -9.5),  ## 左後
		Vector2(-2.8, -14.5),  ## 左前
	])


func _cockpit_rim_pts() -> PackedVector2Array:
	var pts := _cockpit_pts()
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	return closed


## 駕駛艙高光（極小內核，模擬玻璃反光）
func _cockpit_inner_pts() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2( 0.0, -18.5),
		Vector2( 1.5, -14.5),
		Vector2( 0.0, -12.5),
		Vector2(-1.5, -14.5),
	])


## 引擎噴嘴熾白內核
func _nozzle_inner_pts(right: bool) -> PackedVector2Array:
	var s: float = -1.0 if not right else 1.0
	var cx: float = s * 5.0
	var cy: float = 27.2
	var r: float  = 1.4
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * float(i) / 8.0
		pts.append(Vector2(cx + cos(a) * r, cy + sin(a) * r * 0.6))
	return pts


## 引擎外暈（橢圓）
func _nozzle_outer_pts(right: bool) -> PackedVector2Array:
	var s: float = -1.0 if not right else 1.0
	var cx: float = s * 5.0
	var cy: float = 27.3
	var rx: float = 2.6
	var ry: float = 1.1
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		pts.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	return pts


## 噴焰尾跡（向後延伸的錐形 Line2D）
func _plume_pts(right: bool) -> PackedVector2Array:
	var s: float = -1.0 if not right else 1.0
	return PackedVector2Array([
		Vector2(s * 5.0, 27.5),
		Vector2(s * 5.0, 34.0),
	])


# ═══════════════════════════════════════════════════════════════════════════
# 節點建立輔助
# ═══════════════════════════════════════════════════════════════════════════

func _add_layer(layer_name: String, additive: bool) -> Node2D:
	var n := Node2D.new()
	n.name = layer_name
	if additive and _mat_add:
		n.material = _mat_add
	add_child(n)
	return n


func _poly(parent: Node2D, pts: PackedVector2Array, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = pts
	p.color   = color
	parent.add_child(p)
	return p


func _line(parent: Node2D, pts: PackedVector2Array, color: Color, width: float) -> Line2D:
	var l := Line2D.new()
	l.points       = pts
	l.default_color = color
	l.width        = width
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode   = Line2D.LINE_CAP_ROUND
	l.joint_mode     = Line2D.LINE_JOINT_ROUND
	l.antialiased    = true
	parent.add_child(l)
	return l


static func _load_additive_mat() -> Material:
	const PATH := "res://resources/materials/additive_material.tres"
	if ResourceLoader.exists(PATH):
		return load(PATH) as Material
	return null


# ═══════════════════════════════════════════════════════════════════════════
# 信號整合（非 Editor 模式）
# ═══════════════════════════════════════════════════════════════════════════

func _connect_signals() -> void:
	if not EventBus:
		return
	if EventBus.has_signal("bullet_spawn_requested"):
		EventBus.bullet_spawn_requested.connect(_on_shot)
	if EventBus.has_signal("near_dodge_feedback"):
		EventBus.near_dodge_feedback.connect(_on_dodge)


func _on_shot(_p, _d, _s, _dmg, is_player: bool, _id) -> void:
	if is_player:
		_shot_flash = maxf(_shot_flash, 0.65)


func _on_dodge() -> void:
	_shot_flash = maxf(_shot_flash, 1.0)
