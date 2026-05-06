extends BaseBoss
class_name CyberWarship
## CYBER WARSHIP — 巨型艦橋 Boss
##
## 外形：寬大三角艦體 + 兩翼延伸 + 艦橋上層（所有造型程序化）
##
## Phase 1 (HP > 66%)：靜止於頂部，緩慢橫向漂移，定時發射導彈群（sin 波路徑）
## Phase 2 (HP 33-66%)：啟動中央光束（厚 Line2D + Shader），導彈發射頻率加快
## Phase 3 (HP ≤ 33%)：同時開火：導彈群 + 旋轉環形彈 + 光束持續追蹤

@export var drift_speed: float = 55.0
@export var missile_speed: float = 190.0
@export var missile_damage: int = 2
@export var missile_count_p1: int = 5
@export var missile_count_p2: int = 9
@export var beam_damage_per_sec: float = 8.0
@export var beam_duration: float = 2.8
@export var beam_cooldown: float = 5.0

var _drift_dir: float = 1.0
var _beam_active: bool = false
var _beam_timer: float = 0.0       ## 冷卻倒計時（正值=充能中，負值=可發射）
var _beam_line: Line2D
var _beam_phase_elapsed: float = 0.0
var _missile_launch_points: Array[Node2D] = []


# ── 外形 ──────────────────────────────────────────────────

func _build_visual() -> void:
	var v := Node2D.new()
	v.name = "Visual"
	add_child(v)

	## 主艦體：寬大三角形（底部朝下，尖端朝下向玩家）
	var hull_pts: Array = [
		Vector2(-88, -18), Vector2(88, -18),
		Vector2(72,   0),  Vector2(28,  16),
		Vector2(0,   32),  Vector2(-28, 16), Vector2(-72, 0),
	]
	var hull := _make_polygon(hull_pts, body_color, body_hdr_boost)
	hull.name = "Hull"
	v.add_child(hull)

	## 艦橋上層（中央小矩形突起）
	var bridge_pts: Array = [
		Vector2(-22, -32), Vector2(22, -32),
		Vector2(18,  -18), Vector2(-18, -18),
	]
	var bridge := _make_polygon(bridge_pts, accent_color, body_hdr_boost * 1.15)
	bridge.name = "Bridge"
	v.add_child(bridge)

	## 兩翼延伸
	for side in [-1, 1]:
		var wing_pts: Array = [
			Vector2(side * 72, -4),   Vector2(side * 110, -14),
			Vector2(side * 118, -6),  Vector2(side * 108,  4),
			Vector2(side * 72,  8),
		]
		var wing := _make_polygon(wing_pts, body_color, body_hdr_boost * 0.9)
		v.add_child(wing)

	## 翼端發射艙（四個導彈口標記）
	var launch_xs: Array = [-100.0, -60.0, 60.0, 100.0]
	for i in launch_xs.size():
		var lp := Node2D.new()
		lp.name = "LaunchPoint%d" % i
		lp.position = Vector2(launch_xs[i], -2.0)
		v.add_child(lp)
		_missile_launch_points.append(lp)

		var nozzle := _make_line([Vector2(0, -6), Vector2(0, 6)], accent_color * 2.8, 3.5)
		lp.add_child(nozzle)

	## 艦底引擎（3 個光點）
	for i in 3:
		var ex: float = lerp(-38.0, 38.0, float(i) / 2.0)
		var eng := _make_polygon(BaseBoss._polygon_pts(6, 7.0), accent_color, body_hdr_boost * 1.4)
		eng.position = Vector2(ex, 26.0)
		v.add_child(eng)

	## 中央光束 Line2D（初始隱藏）
	_beam_line = _make_line([Vector2(0, 20), Vector2(0, 800)], Color(1.0, 0.2, 0.2) * 3.5, 12.0)
	_beam_line.name = "BeamLine"
	_beam_line.visible = false
	v.add_child(_beam_line)

	## 艦體邊框光
	var outline_pts: Array = hull_pts.duplicate()
	outline_pts.append(hull_pts[0])
	var outline := _make_line(outline_pts, accent_color * 2.0, 2.0)
	v.add_child(outline)


# ── Phase 邏輯 ────────────────────────────────────────────

func _run_phase(phase: int, delta: float) -> void:
	## 橫向漂移（phase 3 稍快）
	var drift_mul: float = 1.0 + (phase - 1) * 0.3
	position.x += _drift_dir * drift_speed * drift_mul * delta
	## 碰到視窗左右邊緣反向
	var vp := get_viewport()
	if vp:
		var half_w: float = vp.get_visible_rect().size.x * 0.5
		var cam := vp.get_camera_2d()
		var cx: float = cam.global_position.x if cam else half_w
		if global_position.x > cx + half_w - 120.0 or global_position.x < cx - half_w + 120.0:
			_drift_dir = -_drift_dir

	## 導彈計時
	var fire_interval: float = 3.5 - float(phase - 1) * 0.8
	if _attack_timer <= 0.0:
		_launch_missile_swarm(missile_count_p1 if phase == 1 else missile_count_p2)
		_attack_timer = fire_interval

	## Phase 2+ 光束
	if phase >= 2:
		_tick_beam(delta)

	## Phase 3：環形補充彈
	if phase == 3 and _attack_timer <= 0.0:
		_fire_ring(global_position, 12, 280.0, _phase_elapsed * 0.8, 1)


func _on_phase_changed(old_p: int, new_p: int) -> void:
	EventBus.screen_shake_requested.emit(0.65, 0.45)
	if new_p == 2:
		_beam_timer = 1.2  ## 稍作延遲再射第一次光束
	if new_p == 3:
		## 艦體變紅
		var visual := get_node_or_null("Visual")
		if visual:
			for child in visual.get_children():
				if child is CanvasItem and not child == _beam_line:
					(child as CanvasItem).modulate = Color(2.0, 0.6, 0.5)


# ── 導彈群（Macross 風：sin 波路徑，由 bullet 系統自行處理）──

func _launch_missile_swarm(count: int) -> void:
	if EventBus == null or not EventBus.has_signal("bullet_spawn_requested"):
		return
	var lps: Array = _missile_launch_points if _missile_launch_points.size() > 0 else [self]
	for i in count:
		## 每枚導彈從不同發射口輪流出發
		var lp: Node2D = lps[i % lps.size()]
		var origin: Vector2 = lp.global_position
		## 底部直下 + sin 波偏移（用 bullet.gd 嘅 homing 實際追蹤）
		## 以 sin(i * offset) 令每枚出發角度略微不同，產生扇形散開感
		var spread_angle: float = sin(float(i) * 0.65 + _phase_elapsed) * deg_to_rad(22.0)
		var base_dir := Vector2(sin(spread_angle), 1.0).normalized()
		## 導彈以 homing=true 最終會轉向玩家
		EventBus.bullet_spawn_requested.emit(origin, base_dir, missile_speed, missile_damage, false, "missile")
		## 交錯發射（同幀太密）
		if i < count - 1:
			var t := create_tween()
			t.tween_callback(func() -> void: pass).set_delay(float(i) * 0.12)


# ── 中央光束 ─────────────────────────────────────────────

func _tick_beam(delta: float) -> void:
	_beam_timer -= delta
	if _beam_active:
		_beam_phase_elapsed += delta
		## 光束追蹤玩家（搖擺）
		var p := _get_player()
		if p and is_instance_valid(p):
			var target_x: float = p.global_position.x - global_position.x
			var pts := _beam_line.points
			if pts.size() >= 2:
				pts[1] = Vector2(lerp(pts[1].x, target_x, 0.06), 820.0)
				_beam_line.points = pts
		## 光束閃爍（sin 讓寬度脈動）
		_beam_line.width = 10.0 + sin(_beam_phase_elapsed * 18.0) * 4.0
		## 傷害：每幀若有玩家喺光束寬度內
		_apply_beam_damage_to_player(delta)
		if _beam_phase_elapsed >= beam_duration:
			_deactivate_beam()
	elif _beam_timer <= 0.0:
		_activate_beam()
		_beam_timer = beam_cooldown


func _activate_beam() -> void:
	_beam_active = true
	_beam_phase_elapsed = 0.0
	_beam_line.visible = true
	## 亮起動畫
	var t := create_tween()
	t.tween_property(_beam_line, "width", 18.0, 0.25).from(2.0)
	if EventBus:
		EventBus.screen_shake_requested.emit(0.45, 0.25)


func _deactivate_beam() -> void:
	_beam_active = false
	var t := create_tween()
	t.tween_property(_beam_line, "width", 0.0, 0.15).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void: _beam_line.visible = false)


func _apply_beam_damage_to_player(delta: float) -> void:
	var p := _get_player()
	if p == null or not is_instance_valid(p):
		return
	## 簡單距離判定：玩家 X 座標距光束中心線 < 光束一半寬度
	var beam_world_x: float = global_position.x + _beam_line.points[1].x if _beam_line.points.size() >= 2 else global_position.x
	if abs(p.global_position.x - beam_world_x) < _beam_line.width * 0.55:
		if p.has_method("take_damage"):
			p.take_damage(int(beam_damage_per_sec * delta))
		elif p.has_method("take_hit"):
			p.take_hit(int(beam_damage_per_sec * delta))
