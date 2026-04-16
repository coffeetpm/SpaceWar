extends Area2D
class_name Bullet
## Single bullet: pooled, neon trail, additive material. Movement in _physics_process.

const HitSpark := preload("res://scripts/vfx/hit_spark.gd")

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
const HOMING_TURN_SPEED := 4.5  # radians per second for curved trail
const HOMING_STRAIGHT_DURATION := 0.1   # initial straight dash before curve
const REFRACTION_ECHO_ALPHA := 0.48  # readable, clearly secondary; no clutter
const REFRACTION_ECHO_TRAIL_SCALE := 0.6  # shorter/thinner trail for echo

const DODGE_NEAR_RADIUS := 26.0
## Reduce outer glow so bullets stay readable but don't overpower player (no art_direction change).
const BULLET_GLOW_ALPHA_SCALE := 0.72

## Per-weapon trail identity: width, length, curve (0=thin tail, 1=full), stretch (gradient softness).
const TRAIL_STYLES: Dictionary = {
	"spread": {"width": 5.5, "length": 20, "curve": 0.15, "stretch": 0.4},
	"burst": {"width": 11.0, "length": 12, "curve": 0.95, "stretch": 0.85},
	"homing": {"width": 6.0, "length": 30, "curve": 0.25, "stretch": 0.55},
	"rear": {"width": 8.0, "length": 18, "curve": 0.55, "stretch": 0.7},
	"beam": {},
	"drones": {"width": 4.0, "length": 14, "curve": 0.7, "stretch": 0.3},
}

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


func setup(global_pos: Vector2, direction: Vector2, speed: float, damage: int, is_player: bool, is_homing: bool = false, weapon_id: String = "", is_refraction_echo: bool = false) -> void:
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
		var curve_val: float = float(style.get("curve", 0.5))
		var stretch: float = float(style.get("stretch", 0.5))
		if _trail:
			var curve := Curve.new()
			curve.add_point(Vector2(0.0, 0.03 + curve_val * 0.12))
			curve.add_point(Vector2(0.4, 0.25 + curve_val * 0.35))
			curve.add_point(Vector2(1.0, 1.0))
			_trail.width_curve = curve
			var g := Gradient.new()
			if is_player:
				g.add_point(0.0, ArtDirection.TIER3_TRAIL_TAIL_PLAYER)
				g.add_point(lerpf(0.25, 0.65, stretch), Color(ArtDirection.TIER3_TRAIL_TAIL_PLAYER.r, ArtDirection.TIER3_TRAIL_TAIL_PLAYER.g, ArtDirection.TIER3_TRAIL_TAIL_PLAYER.b, 0.45))
				g.add_point(1.0, ArtDirection.TIER3_TRAIL_HEAD_PLAYER)
			else:
				g.add_point(0.0, ArtDirection.TIER3_TRAIL_TAIL_ENEMY)
				g.add_point(lerpf(0.3, 0.7, stretch), Color(ArtDirection.TIER3_TRAIL_TAIL_ENEMY.r, ArtDirection.TIER3_TRAIL_TAIL_ENEMY.g, ArtDirection.TIER3_TRAIL_TAIL_ENEMY.b, 0.4))
				g.add_point(1.0, ArtDirection.TIER3_TRAIL_HEAD_ENEMY)
			_trail.gradient = g
		if _trail:
			_trail.width = trail_width


func _steer_toward_nearest_enemy(delta: float) -> void:
	var nearest: Node2D = null
	var best_dist := 9999.0
	for node in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(node):
			continue
		var n := node as Node2D
		var d := global_position.distance_squared_to(n.global_position)
		if d < best_dist:
			best_dist = d
			nearest = n
	if nearest:
		var to_enemy := (nearest.global_position - global_position).normalized()
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
	if Engine.get_process_frames() % 2 != 0:
		return
	# Subtle flicker/pulse in glow intensity; keep reduced alpha so player stays priority
	if _visual_glow:
		var base := ArtDirection.TIER2_BULLET_GLOW_PLAYER if _is_player else ArtDirection.TIER2_BULLET_GLOW_ENEMY
		var flicker: float = 0.88 + 0.12 * sin(Time.get_ticks_msec() * 0.008)
		var alpha_mult: float = BULLET_GLOW_ALPHA_SCALE * flicker
		# Light Language: homing = curve trails with delayed glow (ramp up after straight phase)
		if _is_homing and _is_player and LightLanguage and LightLanguage.is_delayed_glow_trail("homing"):
			var now := Time.get_ticks_msec() * 0.001
			var ramp_sec: float = LightLanguage.get_delayed_glow_ramp_sec("homing")
			var initial: float = LightLanguage.get_delayed_glow_initial_alpha("homing")
			var glow_t: float = 0.0 if ramp_sec <= 0.0 else clampf((now - _homing_straight_until) / ramp_sec, 0.0, 1.0)
			alpha_mult *= lerpf(initial, 1.0, glow_t)
		# Weapon evolution Tier 2: experimental — slightly unstable glow (faster, subtle wobble)
		if _is_player and SynergyManager and SynergyManager.get_evolution_tier() >= 2:
			var unstable: float = 0.97 + 0.06 * sin(Time.get_ticks_msec() * 0.022)
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
		## 依子彈陣營採用合理預設 HDR 色
		c = Color(0.4, 1.8, 3.0, 1.0) if _is_player else Color(3.0, 0.5, 0.9, 1.0)
	var amt: int = 14 if is_impact else 6
	HitSpark.spawn(tree.current_scene, global_position, c, amt)


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
	# Thick head, thin tail; palette gradient
	if _trail.get_point_count() > 1:
		if _trail.gradient == null:
			var g := Gradient.new()
			if _is_player:
				g.add_point(0.0, ArtDirection.TIER3_TRAIL_TAIL_PLAYER)
				g.add_point(1.0, ArtDirection.TIER3_TRAIL_HEAD_PLAYER)
			else:
				g.add_point(0.0, ArtDirection.TIER3_TRAIL_TAIL_ENEMY)
				g.add_point(1.0, ArtDirection.TIER3_TRAIL_HEAD_ENEMY)
			_trail.gradient = g
		if _trail.width_curve == null:
			var curve := Curve.new()
			curve.add_point(Vector2(0.0, 0.12))
			curve.add_point(Vector2(0.5, 0.5))
			curve.add_point(Vector2(1.0, 1.0))
			_trail.width_curve = curve
	_trail.width = trail_width


func _return() -> void:
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
