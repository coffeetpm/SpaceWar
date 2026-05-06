extends Node2D
class_name BaseBoss
## 所有 Boss 嘅共用基類。
## 子類負責：
##   _build_visual()   — 用 Polygon2D / Line2D 建立自身外形
##   _run_phase(p, dt) — 依 phase 執行攻擊邏輯
##   _on_phase_changed(old_p, new_p) — phase 切換動畫（optional）
##
## 外部只需 call take_damage(amount)。死亡由本類統一處理並發 EventBus.boss_defeated。

signal phase_changed(phase: int)

## ── Inspector ──────────────────────────────────────────────
@export var boss_name: String = "BOSS"
@export var max_health: int = 600
## phase 切換閾值（每個元素 = 該 phase 需超過此 HP 百分比才維持；由高到低）
## 例：[0.66, 0.33] → phase1 HP>66%, phase2 HP>33%, phase3 HP≤33%
@export var phase_thresholds: Array[float] = [0.66, 0.33]

@export_group("Visual")
@export var body_color: Color = Color(0.5, 1.0, 0.9)
@export var accent_color: Color = Color(1.0, 0.3, 0.7)
@export var body_hdr_boost: float = 2.4

@export_group("Flash")
## 受擊白光持續時間（秒）
@export var hit_flash_duration: float = 0.12
## flash_boost 會傳入 boss_flash_white.gdshader；> 1.0 = HDR 白光
@export var hit_flash_boost: float = 2.8

## ── State ──────────────────────────────────────────────────
enum BossState { IDLE, ATTACK, STUNNED, DEATH }
var boss_state: BossState = BossState.IDLE

var current_health: int = 0
var current_phase: int = 1
var _total_phases: int = 1

var _player: Node2D
var _origin: Vector2
var _stopped: bool = false
var _death_started: bool = false
var _phase_elapsed: float = 0.0
var _attack_timer: float = 0.0

## 所有 Polygon2D / Line2D visual 子節點的 ShaderMaterial（快取，受擊時 uniform 一次改晒）
var _flash_materials: Array[ShaderMaterial] = []
static var _shared_additive_mat: Material = null
static var _shared_flash_shader: Shader = null


func _ready() -> void:
	add_to_group("boss")
	current_health = max_health
	_total_phases = phase_thresholds.size() + 1
	_origin = global_position
	_player = _resolve_player()

	_ensure_shared_resources()
	_build_visual()
	_collect_flash_materials()
	_setup_hitbox()

	if EventBus:
		EventBus.boss_hp_changed.emit(current_health, max_health)
		EventBus.boss_phase_changed.emit(current_phase)
	phase_changed.emit(current_phase)
	boss_state = BossState.ATTACK


func _physics_process(delta: float) -> void:
	if _stopped or _death_started:
		return
	if RunState and RunState.gameplay_frozen:
		return
	if boss_state == BossState.STUNNED:
		return
	_phase_elapsed += delta
	_attack_timer -= delta
	_run_phase(current_phase, delta)


# ── 公開 API ──────────────────────────────────────────────

func take_damage(amount: int) -> void:
	if _death_started:
		return
	var dmg: int = maxi(1, amount)
	current_health -= dmg
	current_health = maxi(0, current_health)
	if EventBus:
		EventBus.boss_hp_changed.emit(current_health, max_health)
	_trigger_hit_flash()
	_check_phase_transition()
	if current_health <= 0:
		_start_death()


func stop_all_attacks() -> void:
	_stopped = true
	boss_state = BossState.IDLE


func play_collapse_inward(duration: float) -> void:
	## 由 StageManager._run_boss_clear_sequence() 呼叫；子類可 override 加自己嘅死亡動畫。
	var visual := get_node_or_null("Visual") as Node2D
	if visual == null:
		await get_tree().create_timer(duration).timeout
		return
	var t := create_tween().set_parallel(true)
	t.tween_property(visual, "scale", Vector2.ZERO, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	t.tween_property(visual, "modulate:a", 0.0, duration * 0.85)
	await t.finished


# ── Override points ────────────────────────────────────────

## 子類 MUST override：建立自身視覺（Polygon2D / Line2D）。
func _build_visual() -> void:
	pass


## 子類 MUST override：依 phase 執行移動 + 攻擊。
func _run_phase(_phase: int, _delta: float) -> void:
	pass


## 子類 MAY override：phase 改變時做特效（閃光、速度加快等）。
func _on_phase_changed(_old_phase: int, _new_phase: int) -> void:
	pass


# ── Helpers（子類可用）─────────────────────────────────────

## 取得玩家（快取 + fallback）。
func _resolve_player() -> Node2D:
	if PlayerRef and PlayerRef.has_method("get_player"):
		var p: Node2D = PlayerRef.get_player()
		if p and is_instance_valid(p):
			return p
	return get_tree().get_first_node_in_group("player") as Node2D


## 取得或更新玩家 ref（每幀 call 前建議先 call 本函數）。
func _get_player() -> Node2D:
	if _player == null or not is_instance_valid(_player):
		_player = _resolve_player()
	return _player


## 取方向至玩家（若玩家無效則向下）。
func _dir_to_player() -> Vector2:
	var p := _get_player()
	if p == null:
		return Vector2.DOWN
	var d := (p.global_position - global_position)
	if d.length_squared() < 0.01:
		return Vector2.DOWN
	return d.normalized()


## 用 sin/cos 射出環形子彈。
## origin：發射位置；count：顆數；speed：速度；start_angle：起始弧度；damage：傷害。
func _fire_ring(origin: Vector2, count: int, speed: float, start_angle: float = 0.0, damage: int = 1) -> void:
	if EventBus == null or not EventBus.has_signal("bullet_spawn_requested"):
		return
	for i in count:
		var a: float = start_angle + TAU * float(i) / float(count)
		var dir := Vector2(cos(a), sin(a))
		EventBus.bullet_spawn_requested.emit(origin, dir, speed, damage, false, "")


## 射出弧線子彈（sin/cos 波動路徑需由 bullet 自身支援，此處提供 offset angle）。
func _fire_arc_burst(origin: Vector2, center_dir: Vector2, spread_rad: float, count: int, speed: float, damage: int = 1) -> void:
	if EventBus == null or not EventBus.has_signal("bullet_spawn_requested"):
		return
	var base_angle: float = center_dir.angle()
	for i in count:
		var t: float = float(i) / maxf(float(count) - 1.0, 1.0)
		var a: float = base_angle + (t - 0.5) * spread_rad
		var dir := Vector2(cos(a), sin(a))
		EventBus.bullet_spawn_requested.emit(origin, dir, speed, damage, false, "")


## 建立 Polygon2D（自動套 flash shader + additive material）。
func _make_polygon(pts: Array, color: Color, boost: float = 1.0) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array(pts)
	poly.color = Color(color.r * boost, color.g * boost, color.b * boost, color.a)
	var mat := _make_flash_material()
	poly.material = mat
	_flash_materials.append(mat)
	return poly


## 建立 Line2D（自動套 additive material，唔套 flash shader 因 Line2D 係裝飾層）。
func _make_line(pts: Array, color: Color, width: float = 3.0) -> Line2D:
	var line := Line2D.new()
	line.points = PackedVector2Array(pts)
	line.default_color = color
	line.width = width
	if _shared_additive_mat:
		line.material = _shared_additive_mat
	return line


## 建立以 n 個頂點定義的正多邊形頂點陣列（半徑 r，起始角度 offset）。
static func _polygon_pts(n: int, r: float, offset: float = 0.0) -> Array:
	var pts: Array = []
	for i in n:
		var a: float = offset + TAU * float(i) / float(n)
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	return pts


## 簡易 Area2D hitbox（矩形）；子類可 override _setup_hitbox 換成任何形狀。
func _setup_hitbox() -> void:
	var area := Area2D.new()
	area.name = "Hitbox"
	area.collision_layer = 4   # layer 3 = enemy
	area.collision_mask  = 2   # layer 2 = player bullet
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(80, 80)
	shape.shape = rect
	area.add_child(shape)
	add_child(area)
	area.area_entered.connect(_on_hitbox_area_entered)


func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.has_method("get_damage"):
		take_damage(area.get_damage())
	elif area.has_meta("damage"):
		take_damage(int(area.get_meta("damage")))


# ── 受擊閃白光 ─────────────────────────────────────────────

func _trigger_hit_flash() -> void:
	if _flash_materials.is_empty():
		return
	for mat in _flash_materials:
		if mat and is_instance_valid(mat):
			mat.set_shader_parameter("flash_modifier", 1.0)
			mat.set_shader_parameter("flash_boost", hit_flash_boost)
	var t := create_tween()
	t.tween_method(_set_flash_all, 1.0, 0.0, hit_flash_duration)


func _set_flash_all(v: float) -> void:
	for mat in _flash_materials:
		if mat and is_instance_valid(mat):
			mat.set_shader_parameter("flash_modifier", v)


func _make_flash_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shared_flash_shader
	mat.set_shader_parameter("flash_modifier", 0.0)
	mat.set_shader_parameter("flash_boost", body_hdr_boost)
	return mat


## 收集所有 Visual 子孫已有 ShaderMaterial 嘅節點（若子類自己建立了 flash 材質）。
func _collect_flash_materials() -> void:
	var visual := get_node_or_null("Visual")
	if visual == null:
		return
	for child in visual.get_children():
		var mat := (child as CanvasItem).material as ShaderMaterial if child is CanvasItem else null
		if mat and mat.shader == _shared_flash_shader and not _flash_materials.has(mat):
			_flash_materials.append(mat)


# ── Phase 管理 ─────────────────────────────────────────────

func _check_phase_transition() -> void:
	var hp_pct: float = float(current_health) / float(max_health)
	var new_phase: int = _total_phases
	for i in phase_thresholds.size():
		if hp_pct > phase_thresholds[i]:
			new_phase = i + 1
			break
	if new_phase != current_phase:
		var old: int = current_phase
		current_phase = new_phase
		_phase_elapsed = 0.0
		_attack_timer = 0.0
		_on_phase_changed(old, new_phase)
		phase_changed.emit(current_phase)
		if EventBus:
			EventBus.boss_phase_changed.emit(current_phase)
			EventBus.screen_shake_requested.emit(0.55, 0.35)


# ── 死亡 ───────────────────────────────────────────────────

func _start_death() -> void:
	if _death_started:
		return
	_death_started = true
	boss_state = BossState.DEATH
	_stopped = true
	collision_layer = 0
	collision_mask  = 0
	if EventBus:
		EventBus.boss_defeated.emit()


# ── 靜態共用資源 ───────────────────────────────────────────

static func _ensure_shared_resources() -> void:
	if _shared_additive_mat == null:
		if ResourceLoader.exists("res://resources/materials/additive_material.tres"):
			_shared_additive_mat = load("res://resources/materials/additive_material.tres") as Material
	if _shared_flash_shader == null:
		if ResourceLoader.exists("res://resources/shaders/boss_flash_white.gdshader"):
			_shared_flash_shader = load("res://resources/shaders/boss_flash_white.gdshader") as Shader
