extends Node2D
class_name ShipVisualController
## 主角機完整視覺控制器（替換舊 thruster_fx.gd）
##
## 負責：
##   1. 引擎噴焰 GPUParticles2D — 速度自適應長度 / 亮度 / 粒子數
##   2. Roll 傾斜動畫 — 基於玩家水平速度的平滑 rotation.z 傾斜
##   3. 模組化零件系統 — 三個掛載點（左翼 / 右翼 / 機頭），升級時顯示對應零件
##   4. 霓虹邊框 Shader — 流動光框 + 受擊白閃 + 引擎連動

## ── Roll ──────────────────────────────────────────────────
@export var roll_max_angle: float    = 0.30   ## 最大傾斜弧度（~17°）
@export var roll_smoothness: float   = 10.0   ## 插值速度（越大越即時）
@export var roll_speed_ref: float    = 300.0  ## 參考速度（達到此速度 = 滿傾斜）

## ── 引擎噴焰 ───────────────────────────────────────────────
@export var thruster_path: NodePath  = NodePath("Thruster")
## 噴焰 GPUParticles2D 節點路徑（可多個，以逗號分隔擴充）
@export var gpu_thruster_path: NodePath = NodePath("ThrusterGPU")
## 靜止速度倍率（速度=0 時噴焰長度）
@export var thruster_idle_scale: float  = 0.55
## 全速時噴焰長度倍率
@export var thruster_full_scale: float  = 1.65
## 速度對應 lifetime 縮放（快=長尾）
@export var thruster_lifetime_min: float = 0.08
@export var thruster_lifetime_max: float = 0.32
## 全速時粒子發射速率倍率
@export var thruster_amount_idle: int    = 12
@export var thruster_amount_full: int    = 42

## ── 霓虹邊框 ───────────────────────────────────────────────
@export var outline_node_path: NodePath = NodePath("ShipOutline")
## 引擎連動 boost（全速時邊框機尾區亮起）
@export var outline_engine_boost_max: float = 1.2

## ── 模組零件 ───────────────────────────────────────────────
## 三個掛載點：upgrade_mount_left / upgrade_mount_right / upgrade_mount_nose
## 每個點下可用代碼動態 add_child，亦可場景預置 visible=false
@export var mount_left_path:  NodePath = NodePath("MountLeft")
@export var mount_right_path: NodePath = NodePath("MountRight")
@export var mount_nose_path:  NodePath = NodePath("MountNose")

## 可選：場景預置嘅零件節點名稱（若有則升級時顯示，否則程序化建立）
@export var part_scene_cannon:  PackedScene = null   ## 副砲
@export var part_scene_fin:     PackedScene = null   ## 導流翼
@export var part_scene_shield:  PackedScene = null   ## 護盾環

# ── 快取 ──────────────────────────────────────────────────
var _thruster_poly: Polygon2D
var _gpu_thruster: GPUParticles2D
var _outline_node: CanvasItem
var _outline_poly: Polygon2D
var _outline_mat: ShaderMaterial
var _mount_left: Node2D
var _mount_right: Node2D
var _mount_nose: Node2D
var _player_body: CharacterBody2D
var _evolution_root: Node2D
var _orbit_sentinels: Array[Node2D] = []

# 內部狀態
var _current_roll: float  = 0.0
var _current_speed_factor: float = 0.0  ## 0=靜止, 1=全速
# beat pulse
var _pulse_until: float = 0.0
var _dodge_brighten_until: float = 0.0
# 零件狀態
var _cannon_spawned: bool = false
var _fin_spawned:    bool = false
var _shield_spawned: bool = false
var _visual_level:   int  = 1

const BEAT_PULSE_DURATION  := 0.12
const SHOT_PULSE_DURATION  := 0.07
const DODGE_BRIGHTEN_DURATION := 0.2
const ORBIT_SENTINEL_COUNT := 3
const ORBIT_SENTINEL_RADIUS := 22.0


func _ready() -> void:
	## 向上找 CharacterBody2D 父節點（Player）
	_player_body = get_parent() as CharacterBody2D

	_thruster_poly = get_node_or_null(thruster_path) as Polygon2D
	_gpu_thruster  = get_node_or_null(gpu_thruster_path) as GPUParticles2D
	_outline_node  = get_node_or_null(outline_node_path) as CanvasItem
	_outline_poly  = _outline_node as Polygon2D
	_mount_left    = get_node_or_null(mount_left_path)   as Node2D
	_mount_right   = get_node_or_null(mount_right_path)  as Node2D
	_mount_nose    = get_node_or_null(mount_nose_path)   as Node2D

	if _outline_node and _outline_node.material is ShaderMaterial:
		_outline_mat = _outline_node.material as ShaderMaterial

	## 舊有 Cockpit / TopEdge / BodyOutline 顏色應用（向後兼容）
	_apply_art_direction_colors()

	## 信號連接
	var bc := get_node_or_null("/root/BeatConductor")
	if bc and bc.has_signal("beat_pulse"):
		bc.beat_pulse.connect(_on_beat_pulse)
	EventBus.near_dodge_feedback.connect(_on_near_dodge)
	if not EventBus.bullet_spawn_requested.is_connected(_on_shot):
		EventBus.bullet_spawn_requested.connect(_on_shot)
	## 升級觸發模組零件
	EventBus.upgrade_picked.connect(_on_upgrade_picked)
	EventBus.level_up.connect(_on_level_up)
	EventBus.upgrade_effect_damage.connect(_check_cannon_unlock)
	EventBus.upgrade_effect_move_speed.connect(_check_fin_unlock)
	EventBus.upgrade_effect_max_hp.connect(_check_shield_unlock)
	_ensure_evolution_root()
	_apply_streamlined_outline()
	_refresh_visual_progression()


func _process(delta: float) -> void:
	var vel: Vector2 = _player_body.velocity if _player_body else Vector2.ZERO
	var spd: float = vel.length()
	_current_speed_factor = clampf(spd / maxf(1.0, _player_body.MAX_SPEED if _player_body else 420.0), 0.0, 1.0)

	_update_roll(vel, delta)
	_update_thruster(_current_speed_factor)
	_update_outline(_current_speed_factor)
	_update_cockpit_pulse()
	_update_orbit_sentinels(delta)


# ── Roll 傾斜 ─────────────────────────────────────────────

func _update_roll(vel: Vector2, delta: float) -> void:
	## 傾斜依玩家水平速度（右移 = 右傾，左移 = 左傾）
	var target_roll: float = clampf(-vel.x / maxf(1.0, roll_speed_ref), -1.0, 1.0) * roll_max_angle
	_current_roll = lerp(_current_roll, target_roll, 1.0 - exp(-roll_smoothness * delta))
	rotation = _current_roll


# ── 引擎噴焰 ─────────────────────────────────────────────

func _update_thruster(spd_f: float) -> void:
	## 通知程序化戰機更新引擎亮度
	var fighter: Node2D = get_node_or_null("Fighter") as Node2D
	if fighter and fighter.has_method("set_engine_intensity"):
		fighter.call("set_engine_intensity", spd_f)

	var now := Time.get_ticks_msec() * 0.001
	var pulse_ratio: float = 0.0
	if now < _pulse_until:
		pulse_ratio = clampf((_pulse_until - now) / BEAT_PULSE_DURATION, 0.0, 1.0)

	## 舊 Polygon2D 噴焰（向後兼容）
	if _thruster_poly:
		var s: float = lerpf(thruster_idle_scale, thruster_full_scale, spd_f) + pulse_ratio * 0.25
		_thruster_poly.scale.y = s
		var a: float = lerpf(0.55, 0.95, spd_f) + pulse_ratio * 0.18
		_thruster_poly.modulate.a = clampf(a, 0.0, 1.0)

	## GPUParticles2D 噴焰（新）
	if _gpu_thruster:
		var pm := _gpu_thruster.process_material as ParticleProcessMaterial
		if pm:
			## lifetime 控制噴焰長度（速度快 → 拖尾更長）
			_gpu_thruster.lifetime = lerpf(thruster_lifetime_min, thruster_lifetime_max, spd_f)
			## 粒子發射量
			_gpu_thruster.amount = int(lerpf(float(thruster_amount_idle), float(thruster_amount_full), spd_f))
			## 初速（快速時更有力）
			pm.initial_velocity_min = lerpf(60.0, 200.0, spd_f)
			pm.initial_velocity_max = lerpf(120.0, 380.0, spd_f)
			## 速度快時粒子更亮（color scale）
			var brightness: float = lerpf(0.6, 1.8, spd_f) + pulse_ratio * 0.4
			pm.color = Color(
				ArtDirection.PARTICLE_THRUSTER.r * brightness,
				ArtDirection.PARTICLE_THRUSTER.g * brightness,
				ArtDirection.PARTICLE_THRUSTER.b * brightness,
				lerpf(0.35, 0.85, spd_f)
			)
			## Beat pulse：短暫爆發
			if pulse_ratio > 0.0:
				pm.initial_velocity_max = lerpf(120.0, 380.0, spd_f) * (1.0 + pulse_ratio * 0.5)


# ── 霓虹邊框 ─────────────────────────────────────────────

func _update_outline(spd_f: float) -> void:
	if not _outline_mat:
		return
	## 引擎熱點隨速度亮起
	_outline_mat.set_shader_parameter("engine_boost", spd_f * outline_engine_boost_max)


## 受擊白閃（由 PlayerController 呼叫）
func flash_hit(duration: float = 0.1) -> void:
	if not _outline_mat:
		return
	_outline_mat.set_shader_parameter("flash_modifier", 1.0)
	var t := create_tween()
	t.tween_method(Callable(self, "_set_outline_flash_modifier_safe"), 1.0, 0.0, duration)


# ── Cockpit / Pulse ───────────────────────────────────────

func _update_cockpit_pulse() -> void:
	var now := Time.get_ticks_msec() * 0.001
	var boost := 0.0
	if now < _pulse_until:
		boost += 0.08 * clampf((_pulse_until - now) / BEAT_PULSE_DURATION, 0.0, 1.0)
	if now < _dodge_brighten_until:
		boost += 0.14
	var mod := Color(1.0 + boost, 1.0 + boost, 1.0 + boost, 1.0)
	var cockpit: Polygon2D = get_node_or_null("Cockpit") as Polygon2D
	var cockpit_glow: Polygon2D = get_node_or_null("CockpitGlow") as Polygon2D
	if cockpit:       cockpit.modulate = mod
	if cockpit_glow:  cockpit_glow.modulate = mod


func _apply_art_direction_colors() -> void:
	var cockpit: Polygon2D = get_node_or_null("Cockpit") as Polygon2D
	var cockpit_glow: Polygon2D = get_node_or_null("CockpitGlow") as Polygon2D
	var top_edge: Line2D = get_node_or_null("TopEdge") as Line2D
	var body_outline: Line2D = get_node_or_null("BodyOutline") as Line2D
	if cockpit:       cockpit.color = ArtDirection.TIER1_PLAYER_CORE
	if cockpit_glow:  cockpit_glow.color = Color(ArtDirection.TIER1_COCKPIT_GLOW.r, ArtDirection.TIER1_COCKPIT_GLOW.g, ArtDirection.TIER1_COCKPIT_GLOW.b, 0.62)
	if top_edge:      top_edge.default_color = Color(ArtDirection.TIER1_COCKPIT_GLOW.r, ArtDirection.TIER1_COCKPIT_GLOW.g, ArtDirection.TIER1_COCKPIT_GLOW.b, 0.88)
	if body_outline:  body_outline.default_color = Color(0.45, 0.85, 1.2, 0.9)
	var old_parts: CPUParticles2D = get_node_or_null("ThrusterParticles") as CPUParticles2D
	if old_parts:     old_parts.color = ArtDirection.PARTICLE_THRUSTER


func _apply_streamlined_outline() -> void:
	if not _outline_poly:
		return
	_outline_poly.polygon = PackedVector2Array([
		Vector2(0, -22),
		Vector2(-12, -6),
		Vector2(-15, 10),
		Vector2(-7, 22),
		Vector2(0, 18),
		Vector2(7, 22),
		Vector2(15, 10),
		Vector2(12, -6),
	])


# ── 模組化零件 ─────────────────────────────────────────────

## 公開：手動為指定掛載點附加零件節點。
## mount: "left" / "right" / "nose"
## part_node: 任何 Node2D（腳本預置、程序化均可）
func attach_part(mount: String, part_node: Node2D) -> void:
	var mp := _get_mount(mount)
	if mp == null:
		push_warning("ShipVisualController: mount '%s' not found" % mount)
		return
	## 清除舊零件
	for c in mp.get_children():
		c.queue_free()
	mp.visible = true
	mp.add_child(part_node)
	_show_mount_enter_effect(mp)


## 公開：移除指定掛載點的所有零件。
func detach_part(mount: String) -> void:
	var mp := _get_mount(mount)
	if mp:
		for c in mp.get_children():
			c.queue_free()


func _get_mount(mount: String) -> Node2D:
	match mount:
		"left":  return _mount_left
		"right": return _mount_right
		"nose":  return _mount_nose
	return null


## 零件附加入場特效：scale 0→1 + 短暫閃光
func _show_mount_enter_effect(mp: Node2D) -> void:
	if mp.get_child_count() == 0:
		return
	var child: Node2D = mp.get_child(0) as Node2D
	if child == null:
		return
	child.scale = Vector2.ZERO
	var t := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(child, "scale", Vector2.ONE, 0.32)
	## 邊框閃一下
	if _outline_mat:
		_outline_mat.set_shader_parameter("flash_modifier", 0.7)
		var ft := create_tween()
		ft.tween_method(Callable(self, "_set_outline_flash_modifier_if_present"), 0.7, 0.0, 0.25)


func _set_outline_flash_modifier_safe(v: float) -> void:
	if is_instance_valid(self) and _outline_mat:
		_outline_mat.set_shader_parameter("flash_modifier", v)


func _set_outline_flash_modifier_if_present(v: float) -> void:
	if _outline_mat:
		_outline_mat.set_shader_parameter("flash_modifier", v)


# ── 程序化零件生成 ─────────────────────────────────────────

## 副砲（左右翼各一個小炮管 + 砲口光）
func _build_cannon_part(is_right: bool) -> Node2D:
	var root := Node2D.new()
	root.name = "Cannon"
	## is_right 保留供將來微調炮管偏移，目前兩側形狀對稱
	@warning_ignore("unused_variable")
	var _side: float = 1.0 if is_right else -1.0
	var mat: Material = null
	if ResourceLoader.exists("res://resources/materials/additive_material.tres"):
		mat = load("res://resources/materials/additive_material.tres") as Material

	## 炮管（長矩形）
	var barrel := Polygon2D.new()
	barrel.polygon = PackedVector2Array([
		Vector2(-2.0, -12.0), Vector2(2.0, -12.0), Vector2(2.5, 4.0), Vector2(-2.5, 4.0)
	])
	barrel.color = Color(0.4, 0.9, 1.2, 0.95)
	if mat: barrel.material = mat
	root.add_child(barrel)

	## 炮口光點
	var muzzle := Polygon2D.new()
	muzzle.polygon = _hex_pts(4.5)
	muzzle.color = Color(0.5, 1.0, 1.5, 0.9)
	muzzle.position = Vector2(0, -14)
	if mat: muzzle.material = mat
	root.add_child(muzzle)

	## 炮口光暈（更大、更透明）
	var halo := Polygon2D.new()
	halo.polygon = _hex_pts(8.0)
	halo.color = Color(0.3, 0.7, 1.0, 0.35)
	halo.position = Vector2(0, -14)
	if mat: halo.material = mat
	root.add_child(halo)

	## 動態脈衝（跟隨玩家射擊節奏）
	var tween_ref: Array[Tween] = []
	EventBus.bullet_spawn_requested.connect(func(_p, _d, _s, _dmg, is_p, _id) -> void:
		if not is_p or not is_instance_valid(muzzle): return
		if tween_ref.size() > 0 and is_instance_valid(tween_ref[0]):
			tween_ref[0].kill()
		var tt := muzzle.create_tween()
		tween_ref.clear()
		tween_ref.append(tt)
		tt.tween_property(muzzle, "scale", Vector2(1.8, 1.8), 0.04).from(Vector2.ONE)
		tt.tween_property(muzzle, "scale", Vector2.ONE, 0.1)
	)
	return root


## 導流翼（三角形尖翼延伸）
func _build_fin_part(is_right: bool) -> Node2D:
	var root := Node2D.new()
	root.name = "Fin"
	var side: float = 1.0 if is_right else -1.0
	var mat: Material = null
	if ResourceLoader.exists("res://resources/materials/additive_material.tres"):
		mat = load("res://resources/materials/additive_material.tres") as Material

	var fin := Polygon2D.new()
	fin.polygon = PackedVector2Array([
		Vector2(0, 2.0),
		Vector2(side * 18.0, 8.0),
		Vector2(side * 22.0, 2.0),
		Vector2(side * 14.0, -6.0),
	])
	fin.color = Color(0.2, 0.7, 1.0, 0.88)
	if mat: fin.material = mat
	root.add_child(fin)

	## 導流線
	var edge := Line2D.new()
	edge.points = PackedVector2Array([
		Vector2(0, 2.0),
		Vector2(side * 22.0, 2.0),
		Vector2(side * 14.0, -6.0),
	])
	edge.default_color = Color(0.5, 1.0, 1.6, 0.9)
	edge.width = 2.0
	if mat: edge.material = mat
	root.add_child(edge)
	return root


## 護盾環（六邊形旋轉圈）
func _build_shield_part() -> Node2D:
	var root := Node2D.new()
	root.name = "ShieldOrb"
	var mat: Material = null
	if ResourceLoader.exists("res://resources/materials/additive_material.tres"):
		mat = load("res://resources/materials/additive_material.tres") as Material

	## 外圈
	var ring := Line2D.new()
	var ring_pts: PackedVector2Array = PackedVector2Array()
	for i in 13:
		var a := TAU * float(i) / 12.0
		ring_pts.append(Vector2(cos(a), sin(a)) * 26.0)
	ring.points = ring_pts
	ring.default_color = Color(0.4, 0.9, 1.2, 0.7)
	ring.width = 2.5
	if mat: ring.material = mat
	root.add_child(ring)

	## 六邊形菱格
	var hex := Polygon2D.new()
	hex.polygon = PackedVector2Array(_hex_pts(20.0))
	hex.color = Color(0.15, 0.5, 0.85, 0.22)
	if mat: hex.material = mat
	root.add_child(hex)

	## 自動旋轉
	var rot_script := GDScript.new()
	rot_script.source_code = "extends Node2D\nfunc _process(d):\n\trotation += d * 1.2\n"
	rot_script.reload()
	root.set_script(rot_script)
	return root


func _build_orbit_sentinel(index: int) -> Node2D:
	var root := Node2D.new()
	root.name = "OrbitSentinel%d" % index
	var mat: Material = null
	if ResourceLoader.exists("res://resources/materials/additive_material.tres"):
		mat = load("res://resources/materials/additive_material.tres") as Material

	var chassis := Polygon2D.new()
	chassis.polygon = PackedVector2Array([
		Vector2(0, -7),
		Vector2(5, -1),
		Vector2(3, 6),
		Vector2(-3, 6),
		Vector2(-5, -1),
	])
	chassis.color = Color(0.20, 0.74, 1.10, 0.95)
	if mat:
		chassis.material = mat
	root.add_child(chassis)

	var core := Polygon2D.new()
	core.polygon = _hex_pts(3.0)
	core.position = Vector2(0, -1)
	core.color = Color(0.95, 1.75, 2.50, 0.82)
	if mat:
		core.material = mat
	root.add_child(core)

	var rails := Line2D.new()
	rails.points = PackedVector2Array([
		Vector2(-4, 3),
		Vector2(0, -5),
		Vector2(4, 3),
	])
	rails.width = 1.5
	rails.default_color = Color(0.45, 1.05, 1.70, 0.90)
	if mat:
		rails.material = mat
	root.add_child(rails)
	return root


func _hex_pts(r: float) -> Array:
	var pts: Array = []
	for i in 6:
		var a := TAU * float(i) / 6.0 + PI / 6.0
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	return pts


# ── 升級觸發 ─────────────────────────────────────────────

func _on_upgrade_picked() -> void:
	## upgrade_picked 發出後，各 effect signal 已處理完；此處做通用刷新
	_refresh_visual_progression()


func _on_level_up(level: int) -> void:
	_visual_level = maxi(_visual_level, level)
	_refresh_visual_progression(level)


func _refresh_visual_progression(level_override: int = -1) -> void:
	var level_now: int = level_override if level_override > 0 else _resolve_player_level()
	_visual_level = maxi(_visual_level, level_now)
	var fighter := get_node_or_null("Fighter")
	if fighter and fighter.has_method("set_visual_tier"):
		var tier := 1
		if _visual_level >= 6:
			tier = 4
		elif _visual_level >= 4:
			tier = 3
		elif _visual_level >= 2:
			tier = 2
		fighter.call("set_visual_tier", tier)
	_update_orbit_sentinel_state()


func _resolve_player_level() -> int:
	if _player_body and "level" in _player_body:
		return int(_player_body.level)
	return 1


func _ensure_evolution_root() -> void:
	if _evolution_root and is_instance_valid(_evolution_root):
		return
	_evolution_root = Node2D.new()
	_evolution_root.name = "EvolutionDecor"
	add_child(_evolution_root)


func _update_orbit_sentinel_state() -> void:
	_ensure_evolution_root()
	var wanted: int = ORBIT_SENTINEL_COUNT if _visual_level >= 4 else 0
	while _orbit_sentinels.size() > wanted:
		var n: Node2D = _orbit_sentinels.pop_back()
		if is_instance_valid(n):
			n.queue_free()
	while _orbit_sentinels.size() < wanted:
		var sentinel: Node2D = _build_orbit_sentinel(_orbit_sentinels.size())
		sentinel.scale = Vector2.ZERO
		_evolution_root.add_child(sentinel)
		_orbit_sentinels.append(sentinel)
		var t: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(sentinel, "scale", Vector2.ONE, 0.28)


func _update_orbit_sentinels(_delta: float) -> void:
	if _orbit_sentinels.is_empty():
		return
	var t: float = Time.get_ticks_msec() * 0.001
	for i in _orbit_sentinels.size():
		var node: Node2D = _orbit_sentinels[i]
		if not is_instance_valid(node):
			continue
		var ang: float = t * (1.25 + 0.08 * i) + TAU * float(i) / float(_orbit_sentinels.size())
		var radius: float = ORBIT_SENTINEL_RADIUS + sin(t * 1.9 + float(i)) * 2.0
		node.position = Vector2(cos(ang), sin(ang) * 0.55) * radius
		node.rotation = ang + PI * 0.5


func _check_cannon_unlock(_val: int) -> void:
	if _cannon_spawned:
		return
	_cannon_spawned = true
	var left_part := part_scene_cannon.instantiate() as Node2D if part_scene_cannon else _build_cannon_part(false)
	var right_part := part_scene_cannon.instantiate() as Node2D if part_scene_cannon else _build_cannon_part(true)
	attach_part("left",  left_part)
	attach_part("right", right_part)


func _check_fin_unlock(_val: float) -> void:
	if _fin_spawned:
		return
	_fin_spawned = true
	var left_fin  := part_scene_fin.instantiate() as Node2D if part_scene_fin else _build_fin_part(false)
	var right_fin := part_scene_fin.instantiate() as Node2D if part_scene_fin else _build_fin_part(true)
	attach_part("left",  left_fin)
	attach_part("right", right_fin)


func _check_shield_unlock(_val: int) -> void:
	if _shield_spawned:
		return
	_shield_spawned = true
	var shield_part := part_scene_shield.instantiate() as Node2D if part_scene_shield else _build_shield_part()
	attach_part("nose", shield_part)


# ── Beat / Shot 信號 ────────────────────────────────────────

func _on_beat_pulse() -> void:
	_pulse_until = maxf(_pulse_until, Time.get_ticks_msec() * 0.001 + BEAT_PULSE_DURATION)


func _on_shot(_pos: Vector2, _dir: Vector2, _speed: float, _dmg: int, is_player: bool, _id: String) -> void:
	if not is_player: return
	_pulse_until = maxf(_pulse_until, Time.get_ticks_msec() * 0.001 + SHOT_PULSE_DURATION)


func _on_near_dodge() -> void:
	_dodge_brighten_until = Time.get_ticks_msec() * 0.001 + DODGE_BRIGHTEN_DURATION
