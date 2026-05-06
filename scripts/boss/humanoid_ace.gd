extends BaseBoss
class_name HumanoidAce
## HUMANOID ACE — 敏捷人形 Boss
##
## 外形：修長人形剪影（頭 + 軀幹 + 雙臂 + 雙腿，全程序化 Polygon2D）
##
## Phase 1 (HP > 66%)：
##   快速 Dash 到玩家附近 → 劍斬弧（寬角度弧形彈幕）→ 冷卻退後
## Phase 2 (HP 33-66%)：
##   Dash 頻率加快 + 近距散彈爆（shotgun burst 以 sin/cos 散射）
## Phase 3 (HP ≤ 33%)：
##   狂暴：Dash→斬→Dash→散彈 循環，部分子彈以 cos 路徑蛇行

@export var dash_speed: float = 580.0
@export var dash_cooldown: float = 1.8
@export var slash_spread_deg: float = 80.0
@export var slash_bullet_count: int = 7
@export var slash_bullet_speed: float = 320.0
@export var slash_damage: int = 2
@export var shotgun_count: int = 9
@export var shotgun_spread_deg: float = 55.0
@export var shotgun_speed: float = 380.0
@export var shotgun_damage: int = 1
## 在玩家多近距離才用散彈代替劍斬
@export var shotgun_range: float = 130.0

enum AceState { HOVER, DASH_TELEGRAPH, DASH, SLASH, SHOTGUN, RETREAT }
var _ace_state: AceState = AceState.HOVER
var _ace_timer: float = 0.8
var _dash_dir: Vector2 = Vector2.ZERO
var _retreat_dir: Vector2 = Vector2.ZERO
var _body_lean: float = 0.0           ## 左右傾斜（視覺 roll）
var _arm_swing: float = 0.0           ## 揮臂角度（攻擊時）
var _left_arm: Node2D
var _right_arm: Node2D


# ── 外形 ──────────────────────────────────────────────────

func _build_visual() -> void:
	var v := Node2D.new()
	v.name = "Visual"
	add_child(v)

	## 頭部：小橢圓（8 頂點）
	var head_pts: Array = []
	for i in 8:
		var a := TAU * float(i) / 8.0
		head_pts.append(Vector2(cos(a) * 9.0, sin(a) * 11.0 - 36.0))
	var head := _make_polygon(head_pts, accent_color, body_hdr_boost * 1.3)
	head.name = "Head"
	v.add_child(head)

	## 頭部光圈
	var halo := _make_line(
		_ring_pts(14.0, -36.0), accent_color * 3.0, 2.5)
	v.add_child(halo)

	## 軀幹：窄梯形
	var torso_pts: Array = [
		Vector2(-11, -26), Vector2(11, -26),
		Vector2(14,  10),  Vector2(-14, 10),
	]
	var torso := _make_polygon(torso_pts, body_color, body_hdr_boost)
	torso.name = "Torso"
	v.add_child(torso)

	## 腰部能量帶
	var belt := _make_line([Vector2(-15, 8), Vector2(15, 8)], accent_color * 2.5, 3.0)
	v.add_child(belt)

	## 雙腿（兩條 Line2D）
	for side in [-1, 1]:
		var leg := _make_line([
			Vector2(side * 6, 10), Vector2(side * 9, 26), Vector2(side * 7, 44)
		], body_color * Color(1.4, 1.4, 1.4), 4.5)
		v.add_child(leg)

	## 左右臂（獨立 Node2D 便於旋轉揮動）
	for side in [-1, 1]:
		var arm_root := Node2D.new()
		arm_root.name = "ArmL" if side == -1 else "ArmR"
		arm_root.position = Vector2(side * 14.0, -18.0)
		v.add_child(arm_root)

		var blade_pts: Array = [
			Vector2(0, 0), Vector2(side * 8.0, -6.0),
			Vector2(side * 12.0, -22.0), Vector2(side * 6.0, -26.0),
			Vector2(0, -18.0),
		]
		var blade := _make_polygon(blade_pts, accent_color, body_hdr_boost * 1.5)
		blade.name = "Blade"
		arm_root.add_child(blade)

		## 刀刃發光邊
		var edge := _make_line([Vector2(0, 0), Vector2(side * 12.0, -24.0)], accent_color * 3.5, 2.0)
		arm_root.add_child(edge)

		if side == -1:
			_left_arm = arm_root
		else:
			_right_arm = arm_root


func _ring_pts(r: float, cy: float) -> Array:
	var pts: Array = []
	for i in 17:
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a) * r, sin(a) * r + cy))
	return pts


# ── Phase 邏輯 ────────────────────────────────────────────

func _run_phase(phase: int, delta: float) -> void:
	var speed_mul := 1.0 + (phase - 1) * 0.3
	_ace_timer -= delta

	## 更新視覺傾斜 / 揮臂
	var lean_target: float = -_dash_dir.x * 0.4 if _ace_state == AceState.DASH else 0.0
	_body_lean = lerp(_body_lean, lean_target, 8.0 * delta)
	rotation = _body_lean
	_animate_arms(delta)

	match _ace_state:
		AceState.HOVER:
			## 懸停：以 sin/cos 繞小圓移動（有機感）
			var t := _phase_elapsed
			var hover_r: float = 40.0 + sin(t * 0.8) * 15.0
			var p := _get_player()
			if p and is_instance_valid(p):
				var orbit := p.global_position + Vector2(cos(t * 1.1) * hover_r, sin(t * 0.9) * hover_r - 80.0)
				position = position.lerp(orbit, 3.5 * delta)
			if _ace_timer <= 0.0:
				_enter_state(AceState.DASH_TELEGRAPH, 0.35)

		AceState.DASH_TELEGRAPH:
			var p := _get_player()
			if p and is_instance_valid(p):
				_dash_dir = (p.global_position - global_position).normalized()
			if _ace_timer <= 0.0:
				_enter_state(AceState.DASH, 0.0)
				EventBus.screen_shake_requested.emit(0.22, 0.08)

		AceState.DASH:
			position += _dash_dir * dash_speed * speed_mul * delta
			var p2 := _get_player()
			## 接近到攻擊距離 or 計時器完結
			if _ace_timer <= 0.0 or (p2 and global_position.distance_to(p2.global_position) < shotgun_range):
				var use_shotgun: bool = (p2 != null and global_position.distance_to(p2.global_position) < shotgun_range) or phase >= 2
				_enter_state(AceState.SHOTGUN if use_shotgun else AceState.SLASH, 0.22)

		AceState.SLASH:
			if _ace_timer <= 0.0:
				_perform_slash(phase)
				_enter_state(AceState.RETREAT, 0.6 / speed_mul)

		AceState.SHOTGUN:
			if _ace_timer <= 0.0:
				_perform_shotgun(phase)
				_enter_state(AceState.RETREAT, 0.5 / speed_mul)

		AceState.RETREAT:
			## 退回稍遠距離
			var p3 := _get_player()
			if p3 and is_instance_valid(p3):
				_retreat_dir = (global_position - p3.global_position).normalized()
			position += _retreat_dir * 280.0 * delta
			if _ace_timer <= 0.0:
				var hover_cd: float = dash_cooldown * (1.0 - float(phase - 1) * 0.18)
				_enter_state(AceState.HOVER, hover_cd)


func _enter_state(s: AceState, duration: float) -> void:
	_ace_state = s
	_ace_timer = duration


func _on_phase_changed(old_p: int, new_p: int) -> void:
	EventBus.screen_shake_requested.emit(0.6, 0.4)
	## Phase 3：刀刃變紅
	if new_p == 3:
		for arm in [_left_arm, _right_arm]:
			if arm:
				arm.modulate = Color(2.2, 0.5, 0.5)
	## Phase 2：整體加速，Dash 距離更長
	if new_p >= 2:
		dash_cooldown *= 0.75


# ── 攻擊 ─────────────────────────────────────────────────

func _perform_slash(phase: int) -> void:
	## 劍斬弧：以 sin/cos 計算子彈方向，以 _dir_to_player 為中心展開
	var count: int = slash_bullet_count + (phase - 1) * 3
	var half: float = deg_to_rad(slash_spread_deg * 0.5)
	var center_angle: float = _dir_to_player().angle()
	for i in count:
		## sin 分佈令中間密、兩端稀疏（仿弧形劍氣）
		var t: float = float(i) / float(count - 1) if count > 1 else 0.5
		var a: float = center_angle + sin((t - 0.5) * PI) * half
		var dir := Vector2(cos(a), sin(a))
		EventBus.bullet_spawn_requested.emit(global_position, dir, slash_bullet_speed, slash_damage, false, "")
	## 揮臂視覺
	_swing_arms(0.28)
	EventBus.screen_shake_requested.emit(0.32, 0.18)


func _perform_shotgun(phase: int) -> void:
	## 近距散彈：以 cos 曲線計算間距（中間偏密）
	var count: int = shotgun_count + (phase - 1) * 3
	var center_angle: float = _dir_to_player().angle()
	var half: float = deg_to_rad(shotgun_spread_deg * 0.5)
	for i in count:
		var t: float = float(i) / float(count - 1) if count > 1 else 0.5
		## cos 對稱分佈：邊緣密中間稀（散彈感）
		var a: float = center_angle + (1.0 - cos(t * PI)) * (half * 2.0 * sign(t - 0.5))
		var dir := Vector2(cos(a), sin(a))
		var speed_var: float = shotgun_speed * randf_range(0.82, 1.18)
		EventBus.bullet_spawn_requested.emit(global_position, dir, speed_var, shotgun_damage, false, "")
	_swing_arms(0.18)
	EventBus.screen_shake_requested.emit(0.28, 0.15)


# ── 揮臂動畫 ─────────────────────────────────────────────

var _arm_swing_time: float = 0.0
var _arm_swinging: bool = false

func _swing_arms(duration: float) -> void:
	_arm_swinging = true
	_arm_swing_time = duration


func _animate_arms(delta: float) -> void:
	if _arm_swinging:
		_arm_swing_time -= delta
		var progress: float = 1.0 - clampf(_arm_swing_time / 0.28, 0.0, 1.0)
		var swing: float = sin(progress * PI) * 0.9
		if _left_arm:
			_left_arm.rotation = -swing
		if _right_arm:
			_right_arm.rotation = swing
		if _arm_swing_time <= 0.0:
			_arm_swinging = false
	else:
		## 懸停時臂膀輕微呼吸
		var idle: float = sin(_phase_elapsed * 2.2) * 0.08
		if _left_arm:
			_left_arm.rotation = lerp(_left_arm.rotation, idle, 6.0 * delta)
		if _right_arm:
			_right_arm.rotation = lerp(_right_arm.rotation, -idle, 6.0 * delta)
