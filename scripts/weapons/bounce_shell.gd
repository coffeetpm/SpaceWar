extends Area2D
class_name BounceShell
## Neon Tank「反彈砲彈」：撞畫面邊界會反彈（最多 N 次），出界後消失。
## 獨立於 BulletPool，因為生命週期同物理行為同一般子彈唔同。

signal expired

@export var speed: float = 320.0
@export var damage: int = 1
@export var max_bounces: int = 3
@export var lifetime: float = 6.0
## 反彈邊界內縮（相對 viewport）；留少少邊距令反彈點更易讀。
@export var bounce_margin: float = 24.0
## HDR 核心色（橘紅電光）
@export var core_color: Color = Color(6.0, 1.8, 0.5, 1.0)

var _velocity: Vector2 = Vector2.ZERO
var _bounces_left: int = 0
var _timer: float = 0.0
var _core: Polygon2D
var _halo: Line2D


func _ready() -> void:
	collision_layer = 8  ## enemy_bullet layer（同 bullet.gd 對齊）
	collision_mask = 2   ## 偵測玩家
	body_entered.connect(_on_body_entered)
	_build_visual()
	_bounces_left = max_bounces
	_timer = lifetime


func setup(origin: Vector2, direction: Vector2, spd: float = -1.0, dmg: int = -1, bounces: int = -1) -> void:
	global_position = origin
	if spd > 0.0:
		speed = spd
	if dmg > 0:
		damage = dmg
	if bounces >= 0:
		max_bounces = bounces
	_bounces_left = max_bounces
	_velocity = direction.normalized() * speed
	rotation = _velocity.angle()


func _build_visual() -> void:
	var mat := load("res://resources/materials/additive_material.tres") as Material
	_halo = Line2D.new()
	_halo.width = 3.0
	_halo.default_color = Color(core_color.r * 0.6, core_color.g * 0.6, core_color.b * 0.6, 0.9)
	if mat:
		_halo.material = mat
	## 菱形殼
	var pts := PackedVector2Array([
		Vector2(10, 0), Vector2(0, 6), Vector2(-8, 0), Vector2(0, -6), Vector2(10, 0)
	])
	_halo.points = pts
	add_child(_halo)
	_core = Polygon2D.new()
	_core.color = core_color
	_core.polygon = PackedVector2Array([
		Vector2(6, 0), Vector2(0, 3), Vector2(-4, 0), Vector2(0, -3)
	])
	if mat:
		_core.material = mat
	add_child(_core)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	add_child(shape)


func _physics_process(delta: float) -> void:
	if RunState and RunState.gameplay_frozen:
		return
	_timer -= delta
	if _timer <= 0.0:
		_despawn()
		return
	global_position += _velocity * delta
	rotation = _velocity.angle()
	_check_bounce()


func _check_bounce() -> void:
	var vp := get_viewport_rect() if get_viewport() else Rect2(Vector2.ZERO, Vector2(1920, 1080))
	var min_x: float = vp.position.x + bounce_margin
	var max_x: float = vp.position.x + vp.size.x - bounce_margin
	var min_y: float = vp.position.y + bounce_margin
	var max_y: float = vp.position.y + vp.size.y - bounce_margin
	var bounced: bool = false
	if global_position.x < min_x and _velocity.x < 0.0:
		global_position.x = min_x
		_velocity.x = -_velocity.x
		bounced = true
	elif global_position.x > max_x and _velocity.x > 0.0:
		global_position.x = max_x
		_velocity.x = -_velocity.x
		bounced = true
	if global_position.y < min_y and _velocity.y < 0.0:
		global_position.y = min_y
		_velocity.y = -_velocity.y
		bounced = true
	elif global_position.y > max_y and _velocity.y > 0.0:
		global_position.y = max_y
		_velocity.y = -_velocity.y
		bounced = true
	if bounced:
		_bounces_left -= 1
		if EventBus and EventBus.has_signal("explosion_requested"):
			EventBus.explosion_requested.emit(global_position, 0.35, core_color)
		if _bounces_left < 0:
			_despawn()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage, self)
		_despawn()


func _despawn() -> void:
	expired.emit()
	queue_free()
