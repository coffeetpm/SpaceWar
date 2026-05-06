extends Area2D
class_name Bullet
## Single bullet: pooled, neon trail, additive material. Movement in _physics_process.
## Style system: call apply_style(BulletFactory.BulletStyle.*) after setup() for Plasma/Needle/Heavy visuals.

const HitSpark := preload("res://scripts/vfx/hit_spark.gd")

## ── 子彈樣式常數（與 BulletFactory.BulletStyle 對應）──────────
const STYLE_DEFAULT := 0
const STYLE_PLASMA  := 1
const STYLE_NEEDLE  := 2
const STYLE_HEAVY   := 3

## Hit Stop 持續時間（秒）/ 時間縮放
const PLASMA_HITSTOP_DURATION := 0.028
const PLASMA_HITSTOP_SCALE    := 0.08   ## 幾乎全停但留微量運動感
const HEAVY_HITSTOP_DURATION  := 0.055
const HEAVY_HITSTOP_SCALE     := 0.0    ## 真正頓幀

signal returned_to_pool

## 預設 2 秒以節省效能；個別武器可於 setup() 後覆蓋。
@export var lifetime: float = 2.0
@export var trail_length: int = 22
@export var trail_width: float = 8.0
## PointLight2D 預設能量（0 = 停用光源）
@export var light_energy: float = 1.4
## Hit Spark 觸發顏色（None = 使用 modulate；設定後命中 / 消散均採此色）
@export var hit_spark_color: Color = Color(0, 0, 0, 0)

var _direction: Vector2
var _speed: float
var _damage: int
var _is_player: bool
var _timer: float
var _pool: BulletPool  # Set by pool in set_pool()
var _trail_global_points: Array[Vector2] = []
var _dodge_triggered: bool = false
var _is_homing: bool = false
var _homing_straight_until: float = 0.0  # time (sec) after which steering starts — signature straight-then-curve
var _is_refraction_echo: bool = false  # meta unlock: secondary trajectory (fainter, functional)

## ── 樣式系統 ──────────────────────────────────────────────
var _bullet_style: int = STYLE_DEFAULT
var _heavy_mode:   bool = false
## 電漿電弧（惰性建立，pooled 時重用）
var _plasma_arcs: Node2D = null  ## PlasmaArcController instance
## 各樣式的 _visual_core/glow 預設 scale（pool 回收後還原）
var _default_core_scale: Vector2 = Vector2.ONE
var _default_glow_scale: Vector2 = Vector2.ONE
var _default_trail_width_saved: float = 8.0
var _default_trail_length_saved: int  = 22
const HOMING_TURN_SPEED := 4.5  # radians per second for curved trail
const HOMING_STRAIGHT_DURATION := 0.1   # initial straight dash before curve
const REFRACTION_ECHO_ALPHA := 0.48  # readable, clearly secondary; no clutter
const REFRACTION_ECHO_TRAIL_SCALE := 0.6  # shorter/thinner trail for echo

const DODGE_NEAR_RADIUS := 26.0
## Reduce outer glow so bullets stay readable but don't overpower player (no art_direction change).
const BULLET_GLOW_ALPHA_SCALE := 0.72

## Per-weapon trail identity: width, length, curve (0=thin tail, 1=full), stretch (gradient softness).
const TRAIL_STYLES: Dictionary = {
	"spread": {"width": 3.6, "length": 11, "curve": 0.08, "stretch": 0.18},
	"burst": {"width": 8.5, "length": 9, "curve": 0.78, "stretch": 0.68},
	"homing": {"width": 4.8, "length": 18, "curve": 0.18, "stretch": 0.38},
	"rear": {"width": 6.2, "length": 12, "curve": 0.38, "stretch": 0.52},
	"beam": {},
	"drones": {"width": 3.2, "length": 10, "curve": 0.55, "stretch": 0.22},
}

## 效能：Curve / Gradient 資源依「武器 + 陣營」快取，避免 pool 回收每次重建。
## key 格式："weapon_id|player" 或 "weapon_id|enemy"；value 為 {curve: Curve, gradient: Gradient}。
static var _trail_resource_cache: Dictionary = {}
## Trail fallback Curve / Gradient（冇 weapon_id 樣式時用）— 全局共用一份。
static var _default_trail_curve: Curve = null
static var _default_trail_gradient_player: Gradient = null
static var _default_trail_gradient_enemy: Gradient = null

@onready var _trail: Line2D = $Trail
@onready var _visual_glow: Polygon2D = $Visual/Glow
@onready var _visual_core: Polygon2D = $Visual/Core
@onready var _core_light: PointLight2D = get_node_or_null("Visual/CoreLight") as PointLight2D

func set_pool(pool: BulletPool) -> void:
	_pool = pool


func get_damage() -> int:
	return _damage

# Layer/mask set in scene or by setup()
const LAYER_PLAYER_BULLET := 2
const LAYER_ENEMY_BULLET := 4
const MASK_PLAYER_HITS := 4   # enemy
const MASK_ENEMY_HITS := 2    # player


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	## 記錄初始 scale，供 pool 回收後還原
	if _visual_core:
		_default_core_scale = _visual_core.scale
	if _visual_glow:
		_default_glow_scale = _visual_glow.scale


func setup(global_pos: Vector2, direction: Vector2, speed: float, damage: int, is_player: bool, is_homing: bool = false, weapon_id: String = "", is_refraction_echo: bool = false) -> void:
	_reset_style()  ## 清除上次 pool 可能殘留的樣式
	global_position = global_pos
	_direction = direction.normalized()
	_speed = speed
	_damage = damage
	_is_player = is_player
	_is_homing = is_homing and is_player
	_is_refraction_echo = is_refraction_echo and is_player
	if _is_homing:
		_homing_straight_until = Time.get_ticks_msec() * 0.001 + HOMING_STRAIGHT_DURATION
	_timer = lifetime
	rotation = _direction.angle()
	var base_mod := ArtDirection.PLAYER_BULLET if is_player else ArtDirection.ENEMY_BULLET
	modulate = Color(base_mod.r, base_mod.g, base_mod.b, base_mod.a * (REFRACTION_ECHO_ALPHA if _is_refraction_echo else 1.0))
	# Tier 2: bright core + outer glow (glow intensity scaled so bullets don't overpower player)
	if _visual_glow:
		var c := ArtDirection.TIER2_BULLET_GLOW_PLAYER if is_player else ArtDirection.TIER2_BULLET_GLOW_ENEMY
		var alpha_scale := BULLET_GLOW_ALPHA_SCALE * (REFRACTION_ECHO_ALPHA if _is_refraction_echo else 1.0)
		_visual_glow.color = Color(c.r, c.g, c.b, c.a * alpha_scale)
	if _visual_core:
		_visual_core.color = ArtDirection.TIER2_BULLET_CORE_PLAYER if is_player else ArtDirection.TIER2_BULLET_CORE_ENEMY
	## 同步 PointLight2D 顏色與 HDR bullet 核心一致（Forward+ 支援）
	if _core_light:
		var light_c: Color = ArtDirection.TIER2_BULLET_CORE_PLAYER if is_player else ArtDirection.TIER2_BULLET_CORE_ENEMY
		_core_light.color = Color(light_c.r, light_c.g, light_c.b, 1.0)
		_core_light.energy = light_energy * (REFRACTION_ECHO_ALPHA if _is_refraction_echo else 1.0)
		_core_light.enabled = light_energy > 0.0
	_apply_trail_style(weapon_id, is_player)
	if _is_refraction_echo and _trail:
		trail_length = maxi(4, int(float(trail_length) * REFRACTION_ECHO_TRAIL_SCALE))
		trail_width = trail_width * REFRACTION_ECHO_TRAIL_SCALE
	visible = true
	_dodge_triggered = false
	_trail_global_points.clear()
	_update_trail_visual()
	set_physics_process(true)
	set_process(true)
	_collision_setup(is_player)


func _apply_trail_style(weapon_id: String, is_player: bool) -> void:
	var style: Variant = TRAIL_STYLES.get(weapon_id, {})
	if style is Dictionary and style.size() > 0:
		trail_width = float(style.get("width", trail_width))
		trail_length = int(style.get("length", trail_length))
		if _trail:
			var cached: Dictionary = _get_or_create_trail_resources(weapon_id, is_player, style as Dictionary)
			_trail.width_curve = cached["curve"] as Curve
			_trail.gradient = cached["gradient"] as Gradient
			_trail.width = trail_width


## 依 weapon_id + is_player 快取 Curve / Gradient；多粒子彈共用同一份資源（Line2D 讀取引用）。
static func _get_or_create_trail_resources(weapon_id: String, is_player: bool, style: Dictionary) -> Dictionary:
	var key: String = "%s|%s" % [weapon_id, "p" if is_player else "e"]
	if _trail_resource_cache.has(key):
		return _trail_resource_cache[key] as Dictionary
	var curve_val: float = float(style.get("curve", 0.5))
	var stretch: float = float(style.get("stretch", 0.5))
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.08 + curve_val * 0.08))
	curve.add_point(Vector2(0.42, 0.22 + curve_val * 0.22))
	curve.add_point(Vector2(1.0, 0.82))
	var g: Gradient = Gradient.new()
	if is_player:
		g.add_point(0.0, ArtDirection.TIER3_TRAIL_TAIL_PLAYER)
		g.add_point(lerpf(0.25, 0.65, stretch), Color(ArtDirection.TIER3_TRAIL_TAIL_PLAYER.r, ArtDirection.TIER3_TRAIL_TAIL_PLAYER.g, ArtDirection.TIER3_TRAIL_TAIL_PLAYER.b, 0.45))
		g.add_point(1.0, ArtDirection.TIER3_TRAIL_HEAD_PLAYER)
	else:
		g.add_point(0.0, ArtDirection.TIER3_TRAIL_TAIL_ENEMY)
		g.add_point(lerpf(0.3, 0.7, stretch), Color(ArtDirection.TIER3_TRAIL_TAIL_ENEMY.r, ArtDirection.TIER3_TRAIL_TAIL_ENEMY.g, ArtDirection.TIER3_TRAIL_TAIL_ENEMY.b, 0.4))
		g.add_point(1.0, ArtDirection.TIER3_TRAIL_HEAD_ENEMY)
	var entry: Dictionary = {"curve": curve, "gradient": g}
	_trail_resource_cache[key] = entry
	return entry


func _steer_toward_nearest_enemy(delta: float) -> void:
	## 效能：最近敵機查詢成本 O(N_enemies) 對每粒 homing bullet，每幾 frames 才需更新一次。
	## 於 _physics_process 已每 2 幀只呼叫一次；此處再用平方距離 + early exit 減少分支。
	var enemies: Array = get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		return
	var nearest: Node2D = null
	var best_dist: float = INF
	var my_pos: Vector2 = global_position
	for node in enemies:
		if node == null or not is_instance_valid(node):
			continue
		var n: Node2D = node as Node2D
		var d: float = my_pos.distance_squared_to(n.global_position)
		if d < best_dist:
			best_dist = d
			nearest = n
	if nearest:
		var to_enemy: Vector2 = (nearest.global_position - my_pos).normalized()
		_direction = _direction.lerp(to_enemy, clampf(HOMING_TURN_SPEED * delta, 0.0, 1.0)).normalized()
		rotation = _direction.angle()


func _collision_setup(is_player: bool) -> void:
	if is_player:
		collision_layer = 1 << (LAYER_PLAYER_BULLET - 1)
		collision_mask = MASK_PLAYER_HITS
	else:
		collision_layer = 1 << (LAYER_ENEMY_BULLET - 1)
		collision_mask = MASK_ENEMY_HITS


func _physics_process(delta: float) -> void:
	if RunState and RunState.gameplay_frozen:
		return
	if _is_homing and _is_player:
		var now := Time.get_ticks_msec() * 0.001
		if now >= _homing_straight_until:
			if Engine.get_physics_frames() % 2 == 0:
				_steer_toward_nearest_enemy(delta)
	position += _direction * _speed * delta
	_trail_global_points.append(global_position)
	while _trail_global_points.size() > trail_length:
		_trail_global_points.remove_at(0)
	if Engine.get_physics_frames() % 2 == 0:
		_update_trail_visual()
	## modulate 已於 setup() 一次設定，這裡不再每 frame 重寫（效能修正）。
	_timer -= delta
	if _timer <= 0.0:
		## lifetime 消散 / 離開畫面：微弱 hit spark
		_spawn_hit_spark(false)
		_return()
	# Near-miss dodge feedback (enemy bullets only, once per bullet, when moving away)
	if not _is_player and not _dodge_triggered:
		var player: Node2D = PlayerRef.get_player() if PlayerRef else get_tree().get_first_node_in_group("player") as Node2D
		if player and is_instance_valid(player):
			var dist := global_position.distance_to(player.global_position)
			if dist < DODGE_NEAR_RADIUS:
				var to_player := (player.global_position - global_position).normalized()
				if _direction.dot(to_player) < -0.25:
					_dodge_triggered = true
					EventBus.near_dodge_feedback.emit()


func _process(_delta: float) -> void:
	## 效能：flicker 改為每 4 frames 更新一次；對百粒子彈 glow alpha 輕微變化不會被察覺。
	if Engine.get_process_frames() % 4 != 0:
		return
	if _visual_glow == null:
		return
	var base: Color = ArtDirection.TIER2_BULLET_GLOW_PLAYER if _is_player else ArtDirection.TIER2_BULLET_GLOW_ENEMY
	var t_ms: int = Time.get_ticks_msec()
	var flicker: float = 0.88 + 0.12 * sin(t_ms * 0.008)
	var alpha_mult: float = BULLET_GLOW_ALPHA_SCALE * flicker
	# Light Language: homing = curve trails with delayed glow (ramp up after straight phase)
	if _is_homing and _is_player and LightLanguage and LightLanguage.is_delayed_glow_trail("homing"):
		var now: float = t_ms * 0.001
		var ramp_sec: float = LightLanguage.get_delayed_glow_ramp_sec("homing")
		var initial: float = LightLanguage.get_delayed_glow_initial_alpha("homing")
		var glow_t: float = 0.0 if ramp_sec <= 0.0 else clampf((now - _homing_straight_until) / ramp_sec, 0.0, 1.0)
		alpha_mult *= lerpf(initial, 1.0, glow_t)
	# Weapon evolution Tier 2: experimental — slightly unstable glow (faster, subtle wobble)
	if _is_player and SynergyManager and SynergyManager.get_evolution_tier() >= 2:
		var unstable: float = 0.97 + 0.06 * sin(t_ms * 0.022)
		alpha_mult *= unstable
	_visual_glow.color = Color(base.r, base.g, base.b, base.a * alpha_mult)


func _on_body_entered(body: Node2D) -> void:
	if _is_player and body.is_in_group("enemy"):
		if body.has_method("take_damage"):
			body.take_damage(_damage)
		if EventBus.has_signal("player_projectile_impact"):
			EventBus.player_projectile_impact.emit(global_position, _damage)
		_spawn_hit_spark(true)
		_return()
	elif not _is_player and body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(_damage, self)
		_spawn_hit_spark(true)
		_return()


func _on_area_entered(area: Area2D) -> void:
	if _is_player:
		var boss: Node = null
		if area.is_in_group("boss") and area.has_method("take_damage"):
			boss = area
		else:
			var p: Node = area.get_parent()
			while p and not (p.is_in_group("boss") and p.has_method("take_damage")):
				p = p.get_parent()
			boss = p
		if boss:
			boss.take_damage(_damage)
			if EventBus.has_signal("player_projectile_impact"):
				EventBus.player_projectile_impact.emit(global_position, _damage)
			_spawn_hit_spark(true)
			_return()


## 生成 Hit Spark 粒子。is_impact = true 為命中（較強烈）；false 為 lifetime 消散（較微弱）。
func _spawn_hit_spark(is_impact: bool) -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var c: Color = hit_spark_color
	if c.a <= 0.0:
		c = _style_spark_color()
	var amt: int = 14 if is_impact else 6

	## 樣式增幅：Plasma / Heavy 命中時 spark 更多
	if is_impact:
		match _bullet_style:
			STYLE_PLASMA: amt = 22
			STYLE_HEAVY:  amt = 30
	HitSpark.spawn(tree.current_scene, global_position, c, amt)

	## ── Hit Stop + 樣式特效（僅玩家子彈命中時觸發）─────────────
	if is_impact and _is_player:
		match _bullet_style:
			STYLE_PLASMA:
				EventBus.hitstop_requested.emit(PLASMA_HITSTOP_DURATION, PLASMA_HITSTOP_SCALE)
			STYLE_HEAVY:
				EventBus.hitstop_requested.emit(HEAVY_HITSTOP_DURATION, HEAVY_HITSTOP_SCALE)
				## 衝擊波環
				var scene := tree.current_scene
				if scene:
					var impact_color := _style_spark_color()
					HeavyImpact.spawn(scene, global_position, impact_color, 1.0 + float(_damage) * 0.04)


## 依目前樣式回傳合適的 HDR Spark 顏色
func _style_spark_color() -> Color:
	if not (hit_spark_color.a <= 0.0):
		return hit_spark_color
	match _bullet_style:
		STYLE_PLASMA:
			return Color(0.3, 2.2, 3.8, 1.0) if _is_player else Color(2.5, 0.3, 2.8, 1.0)
		STYLE_NEEDLE:
			return Color(3.2, 3.2, 1.0, 1.0) if _is_player else Color(1.2, 3.2, 0.5, 1.0)
		STYLE_HEAVY:
			return Color(4.2, 1.8, 0.2, 1.0) if _is_player else Color(3.5, 0.6, 0.1, 1.0)
		_:
			return Color(0.4, 1.8, 3.0, 1.0) if _is_player else Color(3.0, 0.5, 0.9, 1.0)


func _update_trail_visual() -> void:
	if not _trail:
		return
	## 性能：用 set_points 一次替換整條軌跡，避免 clear + N 次 add_point 的多次 bounds 重算。
	var n: int = _trail_global_points.size()
	if n == 0:
		_trail.clear_points()
	else:
		var local_points: PackedVector2Array = PackedVector2Array()
		local_points.resize(n)
		var xform_inv: Transform2D = global_transform.affine_inverse()
		for i in n:
			local_points[i] = xform_inv * _trail_global_points[i]
		_trail.points = local_points
	# Thick head, thin tail; palette gradient — 全局共用 fallback 資源，避免每 frame 新建。
	if _trail.get_point_count() > 1:
		if _trail.gradient == null:
			_trail.gradient = _get_default_trail_gradient(_is_player)
		if _trail.width_curve == null:
			_trail.width_curve = _get_default_trail_curve()
	_trail.width = trail_width


static func _get_default_trail_curve() -> Curve:
	if _default_trail_curve:
		return _default_trail_curve
	_default_trail_curve = Curve.new()
	_default_trail_curve.add_point(Vector2(0.0, 0.14))
	_default_trail_curve.add_point(Vector2(0.5, 0.42))
	_default_trail_curve.add_point(Vector2(1.0, 0.8))
	return _default_trail_curve


static func _get_default_trail_gradient(is_player: bool) -> Gradient:
	if is_player:
		if _default_trail_gradient_player:
			return _default_trail_gradient_player
		_default_trail_gradient_player = Gradient.new()
		_default_trail_gradient_player.add_point(0.0, Color(ArtDirection.TIER3_TRAIL_TAIL_PLAYER.r, ArtDirection.TIER3_TRAIL_TAIL_PLAYER.g, ArtDirection.TIER3_TRAIL_TAIL_PLAYER.b, 0.0))
		_default_trail_gradient_player.add_point(0.58, Color(ArtDirection.TIER3_TRAIL_TAIL_PLAYER.r, ArtDirection.TIER3_TRAIL_TAIL_PLAYER.g, ArtDirection.TIER3_TRAIL_TAIL_PLAYER.b, 0.2))
		_default_trail_gradient_player.add_point(1.0, ArtDirection.TIER3_TRAIL_HEAD_PLAYER)
		return _default_trail_gradient_player
	if _default_trail_gradient_enemy:
		return _default_trail_gradient_enemy
	_default_trail_gradient_enemy = Gradient.new()
	_default_trail_gradient_enemy.add_point(0.0, Color(ArtDirection.TIER3_TRAIL_TAIL_ENEMY.r, ArtDirection.TIER3_TRAIL_TAIL_ENEMY.g, ArtDirection.TIER3_TRAIL_TAIL_ENEMY.b, 0.0))
	_default_trail_gradient_enemy.add_point(0.58, Color(ArtDirection.TIER3_TRAIL_TAIL_ENEMY.r, ArtDirection.TIER3_TRAIL_TAIL_ENEMY.g, ArtDirection.TIER3_TRAIL_TAIL_ENEMY.b, 0.18))
	_default_trail_gradient_enemy.add_point(1.0, ArtDirection.TIER3_TRAIL_HEAD_ENEMY)
	return _default_trail_gradient_enemy


func _return() -> void:
	_reset_style()
	_trail_global_points.clear()
	if _trail:
		_trail.clear_points()
	set_physics_process(false)
	set_process(false)
	if _pool:
		_pool.return_bullet(self)
	else:
		visible = false
	returned_to_pool.emit()


# ═══════════════════════════════════════════════════════════════
# 子彈樣式系統（BulletFactory 呼叫）
# ═══════════════════════════════════════════════════════════════

## 套用視覺樣式；在 setup() 之後呼叫。
func apply_style(style_id: int, damage: int, is_player_bullet: bool) -> void:
	_reset_style()
	_bullet_style = style_id
	match style_id:
		STYLE_PLASMA: _apply_plasma(damage, is_player_bullet)
		STYLE_NEEDLE: _apply_needle(damage, is_player_bullet)
		STYLE_HEAVY:  _apply_heavy(damage, is_player_bullet)


## Pool 回收 / 新 setup 前：復位所有樣式改動
func _reset_style() -> void:
	_bullet_style = STYLE_DEFAULT
	_heavy_mode   = false
	## 隱藏電弧（不 free，下次複用）
	if _plasma_arcs != null and is_instance_valid(_plasma_arcs):
		(_plasma_arcs as Node2D).visible = false
		if _plasma_arcs.has_method("reset"):
			_plasma_arcs.reset()
	## 還原 visual scale
	if _visual_core and _default_core_scale != Vector2.ZERO:
		_visual_core.scale = _default_core_scale
	if _visual_glow and _default_glow_scale != Vector2.ZERO:
		_visual_glow.scale = _default_glow_scale
	## 還原 PointLight
	if _core_light:
		_core_light.texture_scale = 0.18
	## 還原 trail（export 預設值）
	trail_length = _default_trail_length_saved if _default_trail_length_saved > 0 else 22
	trail_width  = _default_trail_width_saved  if _default_trail_width_saved  > 0.0 else 8.0


# ── Plasma 樣式 ─────────────────────────────────────────────

func _apply_plasma(damage: int, is_p: bool) -> void:
	var c: Color = Color(0.25, 2.2, 3.8, 1.0) if is_p else Color(2.8, 0.35, 2.6, 1.0)
	## 大而明亮的圓形核心
	if _visual_core:
		_visual_core.scale = Vector2(2.6, 2.6)
		_visual_core.color = c
	## 寬柔光暈
	if _visual_glow:
		_visual_glow.scale = Vector2(3.2, 3.2)
		_visual_glow.color = Color(c.r * 0.55, c.g * 0.55, c.b * 0.55, 0.50)
	## 較強 PointLight
	if _core_light:
		_core_light.color        = c
		_core_light.energy       = 3.2
		_core_light.texture_scale = 0.34
	## 稍短拖尾
	_default_trail_length_saved = trail_length
	_default_trail_width_saved  = trail_width
	trail_length = 16
	trail_width  = 14.0
	## 電弧控制器（惰性建立）
	var mat: Material = _load_additive_mat_cached()
	if _plasma_arcs == null or not is_instance_valid(_plasma_arcs):
		_plasma_arcs = Node2D.new()
		_plasma_arcs.set_script(preload("res://scripts/vfx/plasma_arc_controller.gd"))
		add_child(_plasma_arcs)
	else:
		_plasma_arcs.visible = true
	if _plasma_arcs.has_method("setup"):
		_plasma_arcs.call("setup", c, mat)


# ── Needle 樣式 ─────────────────────────────────────────────

func _apply_needle(_damage: int, is_p: bool) -> void:
	var c: Color = Color(3.2, 3.2, 1.2, 1.0) if is_p else Color(1.2, 3.2, 0.4, 1.0)
	## 極細長（Y 拉伸模擬針形）
	if _visual_core:
		_visual_core.scale = Vector2(0.18, 6.5)
		_visual_core.color = c
	## 幾乎不可見的外暈，保留中心高光感
	if _visual_glow:
		_visual_glow.scale = Vector2(0.4, 4.0)
		_visual_glow.color = Color(c.r * 0.6, c.g * 0.6, c.b * 0.6, 0.30)
	## 小燈光（只點亮尖端區域）
	if _core_light:
		_core_light.color        = c
		_core_light.energy       = 1.6
		_core_light.texture_scale = 0.09
	## 超長細尾
	_default_trail_length_saved = trail_length
	_default_trail_width_saved  = trail_width
	trail_length = 30
	trail_width  = 1.7


# ── Heavy 樣式 ──────────────────────────────────────────────

func _apply_heavy(_damage: int, is_p: bool) -> void:
	var c: Color = Color(4.0, 1.8, 0.15, 1.0) if is_p else Color(3.5, 0.5, 0.1, 1.0)
	_heavy_mode = true
	## 巨大核心 + 大光暈
	if _visual_core:
		_visual_core.scale = Vector2(3.8, 3.8)
		_visual_core.color = c
	if _visual_glow:
		_visual_glow.scale = Vector2(5.2, 5.2)
		_visual_glow.color = Color(c.r * 0.42, c.g * 0.42, c.b * 0.42, 0.58)
	## 極強燈光（橘紅 PointLight，大範圍照亮周圍）
	if _core_light:
		_core_light.color        = c
		_core_light.energy       = 5.0
		_core_light.texture_scale = 0.46
	## 短粗尾巴
	_default_trail_length_saved = trail_length
	_default_trail_width_saved  = trail_width
	trail_length = 10
	trail_width  = 22.0


## 共用：取得 additive Material（避免每次 load）
static var _cached_additive_mat: Material = null
static func _load_additive_mat_cached() -> Material:
	if _cached_additive_mat != null and is_instance_valid(_cached_additive_mat):
		return _cached_additive_mat
	const PATH := "res://resources/materials/additive_material.tres"
	if ResourceLoader.exists(PATH):
		_cached_additive_mat = load(PATH) as Material
	return _cached_additive_mat
