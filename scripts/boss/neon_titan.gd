extends Node2D
class_name NeonTitan
## 賽博龐克 Boss - NEON TITAN
## 架構：血量驅動的三階段 AI + 三個可破壞弱點核心。
## Phase 1 (HP 100% -> 66%)：普通彈幕（放射 + 追蹤點爆）
## Phase 2 (HP  66% -> 33%)：旋轉激光（雙臂繞圈掃射 + 補位點射）
## Phase 3 (HP  33% ->   0%)：狂暴衝撞（高速 Dash + 衝擊波）

signal phase_changed(phase: int)
signal weak_point_destroyed(index: int)

const DISPLAY_NAME := "NEON TITAN"

## 核心總血量（弱點額外加成，見 weak_points_hp）
@export var max_hp: int = 900
## 未破壞弱點時的主體傷害減免 (0.0 = 無減免，0.75 = 受到 25% 傷害)
@export var armored_damage_reduction: float = 0.65
## 每個弱點的血量
@export var weak_point_hp: int = 120
## 弱點被破壞後，主體傷害倍率（>1.0 = 鼓勵先打弱點）
@export var exposed_damage_multiplier: float = 1.35
## 階段觸發血量百分比
@export var phase2_threshold: float = 0.66
@export var phase3_threshold: float = 0.33
## 移動 / 位置
@export var base_move_speed: float = 60.0
@export var hover_radius: float = 90.0

var current_hp: int
var current_phase: int = 1

var _hitbox_shape: CollisionShape2D
var _weak_points: Array[Area2D] = []
var _weak_points_hp: Array[int] = []
var _weak_points_destroyed: int = 0
var _weak_points_container: Node2D

var _player: Node2D
var _origin: Vector2
var _hover_angle: float = 0.0
var _phase_elapsed: float = 0.0
var _attack_timer: float = 0.0
var _is_stunned: bool = false
var _stopped: bool = false
## Phase 3 狀態機
enum ChargeState { IDLE, TELEGRAPH, DASH, RECOVER }
var _charge_state: int = ChargeState.IDLE
var _charge_timer: float = 0.0
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_speed: float = 760.0
var _shockwave_pellet_timer: float = 0.0

const _BULLET_SPEED_P1: float = 260.0
const _BULLET_SPEED_P3_WAVE: float = 360.0
const _RING_COUNT_P1: int = 14
const _AIM_BURST_COUNT: int = 3


func _ready() -> void:
	add_to_group("boss")
	current_hp = max_hp
	_origin = global_position
	_player = PlayerRef.get_player() if PlayerRef else get_tree().get_first_node_in_group("player") as Node2D
	_ensure_visual()
	_setup_hitbox()
	_build_weak_points()
	if EventBus:
		EventBus.boss_hp_changed.emit(current_hp, _total_effective_hp())
		EventBus.boss_phase_changed.emit(current_phase)
	phase_changed.emit(current_phase)


func _total_effective_hp() -> int:
	var wp_sum: int = 0
	for hp in _weak_points_hp:
		wp_sum += maxi(0, hp)
	return max_hp + wp_sum


func _ensure_visual() -> void:
	## 若場景未提供 Visual，建立簡易霓虹核心（菱形核心 + 光環）
	if get_node_or_null("Visual"):
		return
	var v := Node2D.new()
	v.name = "Visual"
	add_child(v)
	var ring := Line2D.new()
	ring.name = "OuterRing"
	ring.width = 4.0
	ring.default_color = Color(0.7, 0.95, 1.0, 0.85)
	var mat := load("res://resources/materials/additive_material.tres") as Material
	if mat:
		ring.material = mat
	for i in 17:
		var a := TAU * float(i) / 16.0
		ring.add_point(Vector2(cos(a), sin(a)) * 54.0)
	v.add_child(ring)
	var core := Polygon2D.new()
	core.name = "CorePoly"
	core.color = Color(1.0, 0.45, 0.9, 0.98)
	core.polygon = PackedVector2Array([
		Vector2(0, -24), Vector2(-24, 0), Vector2(0, 24), Vector2(24, 0)
	])
	if mat:
		core.material = mat
	v.add_child(core)


func _setup_hitbox() -> void:
	## bullet.gd._on_area_entered: area.is_in_group("boss") 或 fallback 到 area.get_parent()。
	## Hitbox 不進入 "boss" group（避免沒有 take_damage），由 parent NeonTitan 承接。
	var area: Area2D = get_node_or_null("Hitbox") as Area2D
	if not area:
		area = Area2D.new()
		area.name = "Hitbox"
		area.collision_layer = 4
		area.collision_mask = 2
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 44.0
		shape.shape = circle
		area.add_child(shape)
		add_child(area)
		_hitbox_shape = shape
	else:
		_hitbox_shape = area.get_node_or_null("CollisionShape2D") as CollisionShape2D


func _build_weak_points() -> void:
	## 建立 3 個弱點節點（若場景已提供 WeakPoints/Container，使用之；否則自動生成）。
	_weak_points_container = get_node_or_null("WeakPoints") as Node2D
	if not _weak_points_container:
		_weak_points_container = Node2D.new()
		_weak_points_container.name = "WeakPoints"
		add_child(_weak_points_container)
	var existing: Array = _weak_points_container.get_children()
	if existing.is_empty():
		for i in 3:
			var angle := TAU * float(i) / 3.0
			var offset := Vector2.from_angle(angle - PI * 0.5) * 82.0
			_weak_points_container.add_child(_make_weak_point(i, offset))
	for child in _weak_points_container.get_children():
		if child is Area2D:
			var a := child as Area2D
			_weak_points.append(a)
			_weak_points_hp.append(weak_point_hp)
			a.set_meta("weak_point_index", _weak_points.size() - 1)
			if not a.is_in_group("boss_weak_point"):
				a.add_to_group("boss_weak_point")
			if not a.is_in_group("boss"):
				a.add_to_group("boss")


func _make_weak_point(index: int, offset: Vector2) -> Area2D:
	var wp_script := load("res://scripts/boss/neon_titan_weak_point.gd") as Script
	var a: Area2D
	if wp_script:
		a = wp_script.new() as Area2D
	else:
		a = Area2D.new()
	a.name = "WeakPoint%d" % index
	a.position = offset
	a.collision_layer = 4
	a.collision_mask = 2
	a.set("weak_point_index", index)
	a.add_to_group("boss")
	a.add_to_group("boss_weak_point")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16.0
	shape.shape = circle
	a.add_child(shape)
	var mat := load("res://resources/materials/additive_material.tres") as Material
	var ring := Line2D.new()
	ring.name = "Ring"
	ring.width = 2.6
	ring.default_color = Color(1.0, 0.85, 0.35, 0.95)
	if mat:
		ring.material = mat
	for i in 13:
		var ang := TAU * float(i) / 12.0
		ring.add_point(Vector2(cos(ang), sin(ang)) * 14.0)
	a.add_child(ring)
	var core := Polygon2D.new()
	core.name = "Core"
	core.color = Color(1.0, 0.72, 0.35, 1.0)
	core.polygon = PackedVector2Array([
		Vector2(-6, -6), Vector2(6, -6), Vector2(6, 6), Vector2(-6, 6)
	])
	if mat:
		core.material = mat
	a.add_child(core)
	return a


## Bullet 命中主體 hitbox（RefractionCore 相同 API）。
func take_damage(amount: int) -> void:
	if _stopped or amount <= 0:
		return
	var dealt: int = amount
	## 依弱點狀態調整主體傷害：全弱點未破 = 裝甲折扣；每破 1 個弱點 = 加倍傷害
	if _weak_points_destroyed < _weak_points.size():
		dealt = int(ceil(float(amount) * (1.0 - armored_damage_reduction)))
	else:
		dealt = int(ceil(float(amount) * exposed_damage_multiplier))
	current_hp = maxi(0, current_hp - maxi(1, dealt))
	if EventBus:
		EventBus.boss_hp_changed.emit(current_hp + _remaining_weak_hp(), _total_effective_hp())
		EventBus.hitstop_requested.emit(0.05, 0.18)
		EventBus.screen_shake_requested.emit(0.12, 0.08)
	_check_phase_transition()
	if current_hp <= 0:
		_stopped = true
		if EventBus and EventBus.has_signal("boss_defeated"):
			EventBus.boss_defeated.emit()


## 子彈可直接呼叫弱點上的 take_damage(amount, node) 嗎？
## bullet.gd 的 _on_area_entered 會讀 area（或其 parent）是否 in_group("boss")。
## 我們讓弱點 Area 本身具 take_damage，並覆寫到主體的 weak_point API。
## -> 由 _on_child_area_hit 處理。
func _unhandled_input(_event: InputEvent) -> void:
	pass


func _remaining_weak_hp() -> int:
	var s: int = 0
	for hp in _weak_points_hp:
		s += maxi(0, hp)
	return s


## 對弱點造成傷害（由 bullet.gd 透過 area_entered → boss.take_weak_point_damage 呼叫）。
func damage_weak_point(index: int, amount: int) -> void:
	if index < 0 or index >= _weak_points_hp.size():
		return
	if _weak_points_hp[index] <= 0 or _stopped:
		return
	_weak_points_hp[index] = maxi(0, _weak_points_hp[index] - amount)
	if EventBus:
		EventBus.boss_hp_changed.emit(current_hp + _remaining_weak_hp(), _total_effective_hp())
		EventBus.hitstop_requested.emit(0.05, 0.15)
		EventBus.screen_shake_requested.emit(0.16, 0.1)
	if _weak_points_hp[index] == 0:
		_on_weak_point_destroyed(index)


func _on_weak_point_destroyed(index: int) -> void:
	_weak_points_destroyed += 1
	weak_point_destroyed.emit(index)
	var wp: Area2D = _weak_points[index]
	if not is_instance_valid(wp):
		return
	wp.set_deferred("monitoring", false)
	wp.set_deferred("monitorable", false)
	var ring: Line2D = wp.get_node_or_null("Ring") as Line2D
	var core: Polygon2D = wp.get_node_or_null("Core") as Polygon2D
	if core:
		core.color = Color(0.25, 0.25, 0.3, 0.6)
	if ring:
		ring.default_color = Color(0.4, 0.4, 0.45, 0.5)
	if EventBus:
		EventBus.explosion_requested.emit(wp.global_position, 0.85, Color(1.0, 0.7, 0.3, 1.0))
		EventBus.hitstop_requested.emit(0.09, 0.1)
		EventBus.screen_shake_requested.emit(0.35, 0.22)
	## 視覺回饋：短暫昏迷（給玩家進攻空檔）
	_is_stunned = true
	_attack_timer = 0.9
	get_tree().create_timer(0.9).timeout.connect(func() -> void: _is_stunned = false)


## 依血量推進階段（取代舊的計時階段）。
func _check_phase_transition() -> void:
	var pct: float = float(current_hp) / float(maxi(1, max_hp))
	var new_phase := current_phase
	if pct <= phase3_threshold:
		new_phase = 3
	elif pct <= phase2_threshold:
		new_phase = 2
	else:
		new_phase = 1
	if new_phase != current_phase:
		current_phase = new_phase
		_attack_timer = 0.4
		_phase_elapsed = 0.0
		_charge_state = ChargeState.IDLE
		phase_changed.emit(current_phase)
		if EventBus:
			EventBus.boss_phase_changed.emit(current_phase)
			EventBus.screen_shake_requested.emit(0.6, 0.35)
			EventBus.hitstop_requested.emit(0.12, 0.08)


func _process(delta: float) -> void:
	if _stopped:
		return
	if RunState and RunState.gameplay_frozen:
		return
	_phase_elapsed += delta
	_update_weak_point_orbit(delta)
	if _is_stunned:
		return
	match current_phase:
		1: _phase1_process(delta)
		2: _phase2_process(delta)
		3: _phase3_process(delta)


func _physics_process(delta: float) -> void:
	if _stopped or _is_stunned:
		return
	if RunState and RunState.gameplay_frozen:
		return
	if current_phase == 3 and _charge_state == ChargeState.DASH:
		global_position += _charge_dir * _charge_speed * delta
		return
	## 懸停：環繞原點小幅漂移，保持可讀攻擊軌跡
	_hover_angle += delta * 0.6
	var target := _origin + Vector2(cos(_hover_angle), sin(_hover_angle * 0.8)) * hover_radius * 0.25
	global_position = global_position.lerp(target, clampf(base_move_speed * delta / 80.0, 0.0, 1.0))


func _update_weak_point_orbit(delta: float) -> void:
	if _weak_points_container:
		_weak_points_container.rotation += delta * (0.6 + 0.3 * float(current_phase - 1))


# =============================================================================
# PHASE 1 — 普通彈幕
# =============================================================================

func _phase1_process(delta: float) -> void:
	_attack_timer -= delta
	if _attack_timer > 0.0:
		return
	## 輪流：放射環 → 追蹤點爆 → 放射環
	var cycle := int(_phase_elapsed / 2.2) % 3
	if cycle == 1:
		_fire_aimed_burst(_AIM_BURST_COUNT)
		_attack_timer = 1.4
	else:
		_fire_radial_ring(_RING_COUNT_P1, _BULLET_SPEED_P1, 0.0)
		_attack_timer = 2.2


func _fire_radial_ring(count: int, speed: float, angle_offset: float) -> void:
	if EventBus == null or not EventBus.has_signal("bullet_spawn_requested"):
		return
	for i in count:
		var a := TAU * float(i) / float(count) + angle_offset
		var dir := Vector2.from_angle(a)
		EventBus.bullet_spawn_requested.emit(global_position, dir, speed, 1, false, "")


func _fire_aimed_burst(count: int) -> void:
	if EventBus == null or not EventBus.has_signal("bullet_spawn_requested"):
		return
	_player = _player if is_instance_valid(_player) else (PlayerRef.get_player() if PlayerRef else null)
	if not _player:
		return
	var to_player := (_player.global_position - global_position).normalized()
	for i in count:
		var spread := (float(i) - (count - 1) * 0.5) * deg_to_rad(10.0)
		var dir := to_player.rotated(spread)
		EventBus.bullet_spawn_requested.emit(global_position, dir, _BULLET_SPEED_P1 * 1.05, 1, false, "")


# =============================================================================
# PHASE 2 — 旋轉激光
# =============================================================================

var _rot_beam_angle: float = 0.0
var _rot_beam_speed: float = deg_to_rad(55.0)
var _rot_beam_burst_timer: float = 2.2

func _phase2_process(delta: float) -> void:
	_rot_beam_angle += delta * _rot_beam_speed
	_attack_timer -= delta
	_rot_beam_burst_timer -= delta
	## 從核心發 2 條相對激光（旋轉）作為「光流」：以高頻子彈模擬掃射軌跡。
	if _attack_timer <= 0.0:
		_emit_rotating_spokes()
		_attack_timer = 0.065  ## 高密度 -> 形成旋轉激光「光軌」
	## 每 3.8 秒打一次補位點射，逼玩家離開固定位置
	if _rot_beam_burst_timer <= 0.0:
		_rot_beam_burst_timer = 3.8
		_fire_aimed_burst(2)


func _emit_rotating_spokes() -> void:
	if EventBus == null:
		return
	for i in 2:
		var a := _rot_beam_angle + PI * float(i)
		var dir := Vector2.from_angle(a)
		EventBus.bullet_spawn_requested.emit(global_position, dir, 340.0, 1, false, "")


# =============================================================================
# PHASE 3 — 狂暴衝撞
# =============================================================================

const _CHARGE_TELEGRAPH_SEC: float = 0.55
const _CHARGE_RECOVER_SEC: float = 0.9
const _CHARGE_MAX_TIME: float = 1.1

func _phase3_process(delta: float) -> void:
	match _charge_state:
		ChargeState.IDLE:
			_attack_timer -= delta
			if _attack_timer <= 0.0:
				_begin_charge_telegraph()
		ChargeState.TELEGRAPH:
			_charge_timer -= delta
			if _charge_timer <= 0.0:
				_begin_charge_dash()
		ChargeState.DASH:
			_charge_timer -= delta
			_shockwave_pellet_timer -= delta
			if _shockwave_pellet_timer <= 0.0:
				_shockwave_pellet_timer = 0.085
				_drop_shockwave_pellets()
			if _charge_timer <= 0.0 or _hit_edge():
				_begin_charge_recover()
		ChargeState.RECOVER:
			_charge_timer -= delta
			if _charge_timer <= 0.0:
				_charge_state = ChargeState.IDLE
				_attack_timer = 0.55


func _begin_charge_telegraph() -> void:
	_charge_state = ChargeState.TELEGRAPH
	_charge_timer = _CHARGE_TELEGRAPH_SEC
	_player = _player if is_instance_valid(_player) else (PlayerRef.get_player() if PlayerRef else null)
	if _player:
		_charge_dir = (_player.global_position - global_position).normalized()
	else:
		_charge_dir = Vector2.from_angle(_hover_angle)
	if EventBus:
		EventBus.muzzle_flash_requested.emit(global_position, "boss_charge")


func _begin_charge_dash() -> void:
	_charge_state = ChargeState.DASH
	_charge_timer = _CHARGE_MAX_TIME
	if EventBus:
		EventBus.screen_shake_requested.emit(0.35, 0.18)
	_fire_radial_ring(10, _BULLET_SPEED_P3_WAVE * 0.85, 0.0)


func _begin_charge_recover() -> void:
	_charge_state = ChargeState.RECOVER
	_charge_timer = _CHARGE_RECOVER_SEC
	## 衝撞結束：四方爆震波
	_fire_radial_ring(16, _BULLET_SPEED_P3_WAVE, PI / 16.0)
	if EventBus:
		EventBus.screen_shake_requested.emit(0.6, 0.25)


func _hit_edge() -> bool:
	var vp := get_viewport_rect() if get_viewport() else Rect2(Vector2.ZERO, Vector2(1920, 1080))
	var margin := 90.0
	return (
		global_position.x < vp.position.x + margin
		or global_position.x > vp.position.x + vp.size.x - margin
		or global_position.y < vp.position.y + margin
		or global_position.y > vp.position.y + vp.size.y - margin
	)


func _drop_shockwave_pellets() -> void:
	if EventBus == null:
		return
	var perp := Vector2(-_charge_dir.y, _charge_dir.x)
	EventBus.bullet_spawn_requested.emit(global_position + perp * 18.0, perp, 180.0, 1, false, "")
	EventBus.bullet_spawn_requested.emit(global_position - perp * 18.0, -perp, 180.0, 1, false, "")


# =============================================================================
# StageManager 相容 API
# =============================================================================

func stop_all_attacks() -> void:
	_stopped = true


func play_collapse_inward(duration: float) -> void:
	var vis: Node2D = get_node_or_null("Visual")
	if not vis:
		await get_tree().create_timer(duration).timeout
		return
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(vis, "scale", Vector2.ZERO, duration)
	if _weak_points_container:
		tween.parallel().tween_property(_weak_points_container, "modulate:a", 0.0, duration)
	await tween.finished
