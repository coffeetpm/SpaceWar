extends BaseBoss
class_name NeonTank
## NEON TANK — 重裝甲 Boss
##
## 外形：方塊車體 + 旋轉砲塔（所有造型由 Polygon2D / Line2D 程序化生成）
##
## Phase 1 (HP > 66%)：緩慢靠近玩家，砲塔持續旋轉，定時射出 Bounce Shell
##   Bounce Shell 碰到視窗邊緣後反彈（最多 3 次），之後 queue_free
## Phase 2 (HP 33-66%)：移速提升，同時射出雙排平行 Bounce Shell
## Phase 3 (HP ≤ 33%)：Enrage — 瘋狂旋轉砲塔 + 三排扇形彈 + 加速衝向玩家

## ── exports ──────────────────────────────────────────────
@export var move_speed: float = 52.0
@export var turret_rpm: float = 45.0         ## Phase1 砲塔轉速（°/s）
@export var fire_interval: float = 1.8       ## Phase1 射擊間隔
@export var bounce_shell_speed: float = 220.0
@export var bounce_shell_damage: int = 2
@export var bounce_max: int = 3              ## 最多反彈次數

var _turret: Node2D
var _turret_angle: float = 0.0
var _vp_rect: Rect2 = Rect2(0, 0, 1152, 648)
## 追蹤所有存活 BounceShell 節點
var _shells: Array[Node2D] = []


# ── 外形 ──────────────────────────────────────────────────

func _build_visual() -> void:
	var v := Node2D.new()
	v.name = "Visual"
	add_child(v)

	## 車體：粗曠方塊形（6 頂點矩形 + 前端缺角凸顯砲管方向）
	var body_pts: Array = [
		Vector2(-36, -22), Vector2(-28, -30), Vector2(28, -30),
		Vector2(36, -22),  Vector2(36,  26),  Vector2(-36,  26),
	]
	var body := _make_polygon(body_pts, body_color, body_hdr_boost)
	body.name = "Body"
	v.add_child(body)

	## 裝甲側板（左右各一條 Line2D）
	for side in [-1, 1]:
		var armor := _make_line([
			Vector2(side * 38, -18),
			Vector2(side * 42, -10),
			Vector2(side * 42, 20),
			Vector2(side * 38, 26),
		], accent_color * 2.2, 3.5)
		v.add_child(armor)

	## 前臉：橫向掃描線（2 條，讓坦克感覺「有眼睛」）
	for yy in [-8.0, 4.0]:
		var scanline := _make_line([Vector2(-28, yy), Vector2(28, yy)], accent_color * 1.8, 2.0)
		v.add_child(scanline)

	## 底部履帶
	for side in [-1, 1]:
		var track_pts: Array = []
		for i in 8:
			var t: float = float(i) / 7.0
			track_pts.append(Vector2(lerp(-36.0, 36.0, t), side * 30.0))
		var track := _make_line(track_pts, Color(body_color.r * 0.7, body_color.g * 0.7, body_color.b * 0.7), 5.0)
		v.add_child(track)

	## 砲塔（獨立 Node2D 方便旋轉）
	_turret = Node2D.new()
	_turret.name = "Turret"
	v.add_child(_turret)

	## 砲台底座（小八邊形）
	var turret_base_pts := BaseBoss._polygon_pts(8, 18.0, PI / 8.0)
	var turret_base := _make_polygon(turret_base_pts, accent_color, body_hdr_boost * 1.2)
	turret_base.name = "TurretBase"
	_turret.add_child(turret_base)

	## 砲管（長矩形指向上方）
	var barrel_pts: Array = [
		Vector2(-5, -44), Vector2(5, -44), Vector2(7, 0), Vector2(-7, 0)
	]
	var barrel := _make_polygon(barrel_pts, body_color, body_hdr_boost)
	barrel.name = "Barrel"
	_turret.add_child(barrel)

	## 砲管光（發光邊線）
	var barrel_glow := _make_line([Vector2(0, -44), Vector2(0, -6)], accent_color * 3.0, 2.5)
	_turret.add_child(barrel_glow)


# ── Phase 邏輯 ────────────────────────────────────────────

func _run_phase(phase: int, delta: float) -> void:
	var speed_mul: float = 1.0 + (phase - 1) * 0.35
	var rpm_mul: float   = 1.0 + (phase - 1) * 0.55
	var fire_mul: float  = 1.0 - (phase - 1) * 0.22

	## 移動：緩慢朝玩家前進
	var dir := _dir_to_player()
	if global_position.distance_to(_get_player().global_position if _get_player() else global_position) > 180.0:
		position += dir * move_speed * speed_mul * delta

	## 砲塔追蹤玩家（旋轉插值）
	var turret_rpm_now := turret_rpm * rpm_mul
	if phase == 3:
		turret_rpm_now = turret_rpm * 3.5  ## Enrage：快速旋轉
		_turret_angle += deg_to_rad(turret_rpm_now) * delta
	else:
		var target_angle: float = _dir_to_player().angle() + PI * 0.5
		var diff: float = wrapf(target_angle - _turret_angle, -PI, PI)
		_turret_angle += clampf(diff, -deg_to_rad(turret_rpm_now) * delta, deg_to_rad(turret_rpm_now) * delta)
	_turret.rotation = _turret_angle

	## 射擊
	if _attack_timer <= 0.0:
		_fire_for_phase(phase)
		_attack_timer = fire_interval * fire_mul

	## 更新 bounce shells
	_tick_bounce_shells(delta)


func _fire_for_phase(phase: int) -> void:
	match phase:
		1:
			_spawn_bounce_shell(global_position, _dir_to_player())
		2:
			var perp := _dir_to_player().rotated(PI * 0.5)
			_spawn_bounce_shell(global_position + perp * 18.0, _dir_to_player())
			_spawn_bounce_shell(global_position - perp * 18.0, _dir_to_player())
		3:
			## 扇形三發 + 兩條側邊 Bounce Shell
			_fire_arc_burst(global_position, _dir_to_player(), deg_to_rad(60), 3, bounce_shell_speed + 80.0, bounce_shell_damage)
			var perp := _dir_to_player().rotated(PI * 0.5)
			_spawn_bounce_shell(global_position + perp * 25.0, _dir_to_player().rotated(deg_to_rad(20)))
			_spawn_bounce_shell(global_position - perp * 25.0, _dir_to_player().rotated(deg_to_rad(-20)))


func _on_phase_changed(old_p: int, new_p: int) -> void:
	## 相變：強震 + 砲塔顏色變紅
	EventBus.screen_shake_requested.emit(0.6, 0.4)
	var new_color := Color(1.0, 0.3, 0.2) if new_p == 3 else accent_color
	if _turret:
		for child in _turret.get_children():
			if child is CanvasItem:
				(child as CanvasItem).modulate = Color(new_color.r * 2.2, new_color.g * 2.2, new_color.b * 2.2)


# ── Bounce Shell ─────────────────────────────────────────

func _spawn_bounce_shell(origin: Vector2, dir: Vector2) -> void:
	## 用普通 Area2D 自行管理反彈，唔走 EventBus（需要自訂反彈邏輯）
	var shell := _BounceShell.new()
	shell.init(origin, dir.normalized(), bounce_shell_speed, bounce_shell_damage, bounce_max, _vp_rect)
	get_parent().add_child(shell)
	_shells.append(shell)


func _tick_bounce_shells(_delta: float) -> void:
	## 清理已 queue_free 嘅 shell 引用
	_shells = _shells.filter(func(s: Node2D) -> bool:
		return s != null and is_instance_valid(s)
	)


func _ready() -> void:
	## 嘗試讀取當前 viewport 大小（若 Camera2D 唔在，用預設 1152×648）
	super._ready()
	var vp := get_viewport()
	if vp:
		_vp_rect = Rect2(Vector2.ZERO, vp.get_visible_rect().size)
	_attack_timer = 0.6  ## 首發稍快


# ── Bounce Shell 內部類 ───────────────────────────────────
## 使用 inner class 封裝反彈邏輯，避免額外檔案。
class _BounceShell extends Area2D:
	var _vel: Vector2
	var _damage: int
	var _bounces_left: int
	var _vp: Rect2
	var _life: float = 0.0
	const MAX_LIFE := 5.0

	## 視覺
	var _poly: Polygon2D

	func init(pos: Vector2, dir: Vector2, speed: float, dmg: int, max_bounces: int, vp_rect: Rect2) -> void:
		global_position = pos
		_vel = dir * speed
		_damage = dmg
		_bounces_left = max_bounces
		_vp = vp_rect
		collision_layer = 4
		collision_mask  = 2

		## 外形：小菱形 + 拖尾 Line2D
		_poly = Polygon2D.new()
		_poly.polygon = PackedVector2Array([Vector2(0,-9), Vector2(-7,0), Vector2(0,9), Vector2(7,0)])
		_poly.color = Color(1.0, 0.55, 0.1, 1.0) * 2.6
		add_child(_poly)

		var shape := CollisionShape2D.new()
		var cs := CircleShape2D.new()
		cs.radius = 7.0
		shape.shape = cs
		add_child(shape)

		body_entered.connect(_on_body_entered)

	func _physics_process(delta: float) -> void:
		_life += delta
		if _life > MAX_LIFE:
			queue_free()
			return
		global_position += _vel * delta
		_poly.rotation += delta * 4.0
		_handle_bounce()

	func _handle_bounce() -> void:
		var pos := global_position
		var bounced := false
		if pos.x < _vp.position.x + 16.0 or pos.x > _vp.position.x + _vp.size.x - 16.0:
			_vel.x = -_vel.x
			bounced = true
		if pos.y < _vp.position.y + 16.0 or pos.y > _vp.position.y + _vp.size.y - 16.0:
			_vel.y = -_vel.y
			bounced = true
		if bounced:
			_bounces_left -= 1
			if _bounces_left < 0:
				queue_free()

	func _on_body_entered(body: Node) -> void:
		if body.has_method("take_damage"):
			body.take_damage(_damage)
		elif body.is_in_group("player"):
			if body.has_method("take_hit"):
				body.take_hit(_damage)
		queue_free()

	func get_damage() -> int:
		return _damage
